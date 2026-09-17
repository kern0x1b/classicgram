#import "TGCallsEngineSession.h"

#import <AVFoundation/AVFoundation.h>

#include "Instance.h"
#include "StaticThreads.h"
#include "VideoCaptureInterface.h"
#include "VideoCapturerInterface.h"
#include "platform/PlatformInterface.h"
#include "v2/InstanceV2Impl.h"
#include "platform/darwin/iOS/tgcalls_audio_device_module_ios.h"
#import "platform/darwin/iOS/RTCAudioSession.h"
#import "platform/darwin/iOS/RTCAudioSessionConfiguration.h"

#include "api/video/i420_buffer.h"
#include "api/video/video_frame.h"
#include "api/video_codecs/builtin_video_decoder_factory.h"
#include "api/video_codecs/builtin_video_encoder_factory.h"
#include "media/base/adapted_video_track_source.h"
#include "media/base/media_constants.h"
#include "pc/video_track_source_proxy.h"
#include "rtc_base/time_utils.h"
#include "libyuv.h"

#include <mutex>
#include <vector>

__attribute__((visibility("default")))
@interface TGCallsEngineSession : NSObject <TGCallsEngineSession>
@end

namespace {
class CameraTrackSource : public rtc::AdaptedVideoTrackSource {
public:
	CameraTrackSource() : rtc::AdaptedVideoTrackSource(2) {
	}

	bool is_screencast() const override {
		return false;
	}

	absl::optional<bool> needs_denoising() const override {
		return false;
	}

	webrtc::MediaSourceInterface::SourceState state() const override {
		return webrtc::MediaSourceInterface::kLive;
	}

	bool remote() const override {
		return false;
	}

	void requestFormat(int width, int height, int fps) {
		video_adapter()->OnOutputFormatRequest(std::make_pair(width, height), width * height, fps);
	}

	void deliver(CVPixelBufferRef pixelBuffer) {
		if (CVPixelBufferGetPlaneCount(pixelBuffer) != 2)
			return;
		int width = (int)CVPixelBufferGetWidth(pixelBuffer);
		int height = (int)CVPixelBufferGetHeight(pixelBuffer);
		int64_t timeUs = rtc::TimeMicros();
		int adaptedWidth = 0, adaptedHeight = 0, cropWidth = 0, cropHeight = 0, cropX = 0, cropY = 0;
		if (!AdaptFrame(width, height, timeUs, &adaptedWidth, &adaptedHeight, &cropWidth, &cropHeight, &cropX, &cropY))
			return;

		CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
		auto planar = webrtc::I420Buffer::Create(width, height);
		libyuv::NV12ToI420(
			(const uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0), (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0),
			(const uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1), (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1),
			planar->MutableDataY(), planar->StrideY(), planar->MutableDataU(), planar->StrideU(), planar->MutableDataV(), planar->StrideV(),
			width, height);
		CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

		webrtc::scoped_refptr<webrtc::VideoFrameBuffer> buffer = planar;
		if (adaptedWidth != width || adaptedHeight != height || cropWidth != width || cropHeight != height) {
			auto scaled = webrtc::I420Buffer::Create(adaptedWidth, adaptedHeight);
			scaled->CropAndScaleFrom(*planar, cropX, cropY, cropWidth, cropHeight);
			buffer = scaled;
		}
		OnFrame(webrtc::VideoFrame::Builder()
			.set_video_frame_buffer(buffer)
			.set_rotation(webrtc::kVideoRotation_0)
			.set_timestamp_us(timeUs)
			.build());
	}
};

std::mutex cameraMutex;
webrtc::scoped_refptr<CameraTrackSource> activeCamera;
bool activeCameraPaused = false;

CameraTrackSource *cameraSourceOf(webrtc::scoped_refptr<webrtc::VideoTrackSourceInterface> source) {
	auto proxy = static_cast<webrtc::VideoTrackSourceProxy *>(source.get());
	return static_cast<CameraTrackSource *>(proxy->internal());
}

class CameraCapturer final : public tgcalls::VideoCapturerInterface {
public:
	CameraCapturer(webrtc::scoped_refptr<CameraTrackSource> source, std::function<void(tgcalls::VideoState)> stateUpdated) :
	_source(source),
	_stateUpdated(stateUpdated) {
		std::lock_guard<std::mutex> lock(cameraMutex);
		activeCamera = _source;
		activeCameraPaused = false;
	}

	~CameraCapturer() override {
		std::lock_guard<std::mutex> lock(cameraMutex);
		if (activeCamera.get() == _source.get())
			activeCamera = nullptr;
	}

	void setState(tgcalls::VideoState state) override {
		{
			std::lock_guard<std::mutex> lock(cameraMutex);
			if (activeCamera.get() == _source.get())
				activeCameraPaused = state != tgcalls::VideoState::Active;
		}
		if (_stateUpdated)
			_stateUpdated(state);
	}

	void setPreferredCaptureAspectRatio(float aspectRatio) override {
	}

	void setUncroppedOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) override {
	}

	int getRotation() override {
		return 0;
	}

private:
	webrtc::scoped_refptr<CameraTrackSource> _source;
	std::function<void(tgcalls::VideoState)> _stateUpdated;
};

class ClassicPlatform final : public tgcalls::PlatformInterface {
public:
	std::unique_ptr<webrtc::VideoEncoderFactory> makeVideoEncoderFactory(bool preferHardwareEncoding, bool isScreencast) override {
		return webrtc::CreateBuiltinVideoEncoderFactory();
	}

	std::unique_ptr<webrtc::VideoDecoderFactory> makeVideoDecoderFactory() override {
		return webrtc::CreateBuiltinVideoDecoderFactory();
	}

	bool supportsEncoding(const std::string &codecName) override {
		return codecName == cricket::kVp8CodecName;
	}

	webrtc::scoped_refptr<webrtc::VideoTrackSourceInterface> makeVideoSource(rtc::Thread *signalingThread, rtc::Thread *workerThread) override {
		return webrtc::VideoTrackSourceProxy::Create(signalingThread, workerThread, rtc::make_ref_counted<CameraTrackSource>());
	}

	void adaptVideoSource(webrtc::scoped_refptr<webrtc::VideoTrackSourceInterface> videoSource, int width, int height, int fps) override {
		cameraSourceOf(videoSource)->requestFormat(width, height, fps);
	}

	std::unique_ptr<tgcalls::VideoCapturerInterface> makeVideoCapturer(
		webrtc::scoped_refptr<webrtc::VideoTrackSourceInterface> source,
		std::string deviceId,
		std::function<void(tgcalls::VideoState)> stateUpdated,
		std::function<void(tgcalls::PlatformCaptureInfo)> captureInfoUpdated,
		std::shared_ptr<tgcalls::PlatformContext> platformContext,
		std::pair<int, int> &outResolution) override {
		outResolution = std::make_pair(480, 640);
		return std::make_unique<CameraCapturer>(webrtc::scoped_refptr<CameraTrackSource>(cameraSourceOf(source)), stateUpdated);
	}
};

class RemoteVideoSink final : public rtc::VideoSinkInterface<webrtc::VideoFrame> {
public:
	explicit RemoteVideoSink(void (^onFrame)(const uint8_t *, int, int, int)) : _onFrame([onFrame copy]) {
	}

	void OnFrame(const webrtc::VideoFrame &frame) override {
		void (^onFrame)(const uint8_t *, int, int, int) = _onFrame;
		if (!onFrame)
			return;
		webrtc::scoped_refptr<webrtc::I420BufferInterface> planar = frame.video_frame_buffer()->ToI420();
		if (!planar)
			return;
		if (frame.rotation() != webrtc::kVideoRotation_0)
			planar = webrtc::I420Buffer::Rotate(*planar, frame.rotation());
		int width = planar->width();
		int height = planar->height();
		_bgra.resize((size_t)width * (size_t)height * 4);
		libyuv::I420ToARGB(planar->DataY(), planar->StrideY(), planar->DataU(), planar->StrideU(), planar->DataV(), planar->StrideV(),
			_bgra.data(), width * 4, width, height);
		onFrame(_bgra.data(), width, height, width * 4);
	}

private:
	void (^_onFrame)(const uint8_t *, int, int, int);
	std::vector<uint8_t> _bgra;
};

TGCallsEngineState engineStateFor(tgcalls::State state) {
	switch (state) {
		case tgcalls::State::Established:
			return TGCallsEngineStateEstablished;
		case tgcalls::State::Reconnecting:
			return TGCallsEngineStateReconnecting;
		case tgcalls::State::Failed:
			return TGCallsEngineStateFailed;
		default:
			return TGCallsEngineStateConnecting;
	}
}

void registerImplementations() {
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		tgcalls::Register<tgcalls::InstanceV2Impl>();
	});
}
}

namespace tgcalls {
std::unique_ptr<PlatformInterface> CreatePlatformInterface() {
	return std::make_unique<ClassicPlatform>();
}
}

@implementation TGCallsEngineSession {
	NSString *_version;
	NSData *_encryptionKey;
	BOOL _outgoing;
	BOOL _allowP2P;
	NSArray *_rtcServers;
	NSString *_customParameters;
	std::shared_ptr<std::unique_ptr<tgcalls::Instance>> _instance;
	std::shared_ptr<tgcalls::VideoCaptureInterface> _videoCapture;
	std::shared_ptr<RemoteVideoSink> _remoteVideoSink;
}

@synthesize onStateChanged = _onStateChanged;
@synthesize onSignalingData = _onSignalingData;
@synthesize onRemoteMediaChanged = _onRemoteMediaChanged;
@synthesize onRemoteVideoFrame = _onRemoteVideoFrame;

+ (NSArray *)libraryVersions {
	registerImplementations();
	NSMutableArray *versions = [NSMutableArray array];
	for (const auto &version : tgcalls::Meta::Versions())
		[versions addObject:[NSString stringWithUTF8String:version.c_str()]];
	[versions sortUsingSelector:@selector(compare:)];
	return versions;
}

+ (int32_t)maxLayer {
	registerImplementations();
	return (int32_t)tgcalls::Meta::MaxLayer();
}

- (instancetype)initWithVersion:(NSString *)version
				  encryptionKey:(NSData *)encryptionKey
					   outgoing:(BOOL)outgoing
					   allowP2P:(BOOL)allowP2P
					 rtcServers:(NSArray *)rtcServers
			   customParameters:(NSString *)customParameters {
	self = [super init];
	if (self) {
		_version = [version copy];
		_encryptionKey = [encryptionKey copy];
		_outgoing = outgoing;
		_allowP2P = allowP2P;
		_rtcServers = [rtcServers copy];
		_customParameters = [customParameters copy];
	}
	return self;
}

- (void)dealloc {
	[self stop];
}

- (void)configureAudioSession {
	RTC_OBJC_TYPE(RTCAudioSession) *session = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
	session.useManualAudio = YES;
	RTC_OBJC_TYPE(RTCAudioSessionConfiguration) *configuration = [RTC_OBJC_TYPE(RTCAudioSessionConfiguration) webRTCConfiguration];
	configuration.mode = AVAudioSessionModeVoiceChat;
	configuration.outputNumberOfChannels = 1;
	[RTC_OBJC_TYPE(RTCAudioSessionConfiguration) setWebRTCConfiguration:configuration];
}

- (std::vector<tgcalls::RtcServer>)parsedRtcServers {
	std::vector<tgcalls::RtcServer> servers;
	for (NSDictionary *entry in _rtcServers) {
		tgcalls::RtcServer server;
		server.id = (uint8_t)[entry[@"id"] unsignedCharValue];
		server.host = [entry[@"host"] UTF8String] ?: "";
		server.port = (uint16_t)[entry[@"port"] unsignedShortValue];
		server.login = [entry[@"login"] UTF8String] ?: "";
		server.password = [entry[@"password"] UTF8String] ?: "";
		server.isTurn = [entry[@"turn"] boolValue];
		server.isTcp = [entry[@"tcp"] boolValue];
		servers.push_back(server);
	}
	return servers;
}

- (void)start {
	if (_instance || _encryptionKey.length != tgcalls::EncryptionKey::kSize)
		return;
	registerImplementations();
	[self configureAudioSession];

	auto keyBytes = std::make_shared<std::array<uint8_t, tgcalls::EncryptionKey::kSize>>();
	memcpy(keyBytes->data(), _encryptionKey.bytes, tgcalls::EncryptionKey::kSize);

	tgcalls::Config config;
	config.initializationTimeout = 30.0;
	config.receiveTimeout = 20.0;
	config.dataSaving = tgcalls::DataSaving::Never;
	config.enableP2P = _allowP2P;
	config.enableNS = true;
	config.enableAGC = true;
	config.maxApiLayer = tgcalls::Meta::MaxLayer();
	config.preferredVideoCodecs = {cricket::kVp8CodecName};
	config.customParameters = _customParameters.length ? std::string(_customParameters.UTF8String) : std::string("{}");

	__weak TGCallsEngineSession *weakSelf = self;
	tgcalls::Descriptor descriptor{
		.version = std::string(_version.UTF8String),
		.config = config,
		.rtcServers = [self parsedRtcServers],
		.initialNetworkType = tgcalls::NetworkType::WiFi,
		.encryptionKey = tgcalls::EncryptionKey(keyBytes, _outgoing),
		.stateUpdated = [weakSelf](tgcalls::State state) {
			dispatch_async(dispatch_get_main_queue(), ^{
				TGCallsEngineSession *strongSelf = weakSelf;
				if (strongSelf.onStateChanged)
					strongSelf.onStateChanged(engineStateFor(state));
			});
		},
		.remoteMediaStateUpdated = [weakSelf](tgcalls::AudioState audioState, tgcalls::VideoState videoState) {
			dispatch_async(dispatch_get_main_queue(), ^{
				TGCallsEngineSession *strongSelf = weakSelf;
				if (strongSelf.onRemoteMediaChanged)
					strongSelf.onRemoteMediaChanged(audioState == tgcalls::AudioState::Muted, videoState == tgcalls::VideoState::Active);
			});
		},
		.signalingDataEmitted = [weakSelf](const std::vector<uint8_t> &data) {
			NSData *payload = [NSData dataWithBytes:data.data() length:data.size()];
			dispatch_async(dispatch_get_main_queue(), ^{
				TGCallsEngineSession *strongSelf = weakSelf;
				if (strongSelf.onSignalingData)
					strongSelf.onSignalingData(payload);
			});
		},
		.createAudioDeviceModule = [](webrtc::TaskQueueFactory *taskQueueFactory) -> webrtc::scoped_refptr<webrtc::AudioDeviceModule> {
			return rtc::make_ref_counted<webrtc::tgcalls_ios_adm::AudioDeviceModuleIOS>(false, false, false, 1);
		},
	};

	_instance = std::make_shared<std::unique_ptr<tgcalls::Instance>>(tgcalls::Meta::Create(_version.UTF8String, std::move(descriptor)));
	if (!*_instance) {
		_instance = nullptr;
		if (_onStateChanged)
			_onStateChanged(TGCallsEngineStateFailed);
		return;
	}

	_remoteVideoSink = std::make_shared<RemoteVideoSink>(^(const uint8_t *bgra, int width, int height, int bytesPerRow) {
		TGCallsEngineSession *strongSelf = weakSelf;
		if (strongSelf.onRemoteVideoFrame)
			strongSelf.onRemoteVideoFrame(bgra, width, height, bytesPerRow);
	});
	(*_instance)->setIncomingVideoOutput(_remoteVideoSink);
}

- (void)receiveSignalingData:(NSData *)data {
	if (!_instance || !data.length)
		return;
	const uint8_t *bytes = (const uint8_t *)data.bytes;
	(*_instance)->receiveSignalingData(std::vector<uint8_t>(bytes, bytes + data.length));
}

- (void)setMuted:(BOOL)muted {
	if (_instance)
		(*_instance)->setMuteMicrophone(muted);
}

- (void)setAudioSessionActive:(BOOL)active {
	RTC_OBJC_TYPE(RTCAudioSession) *session = [RTC_OBJC_TYPE(RTCAudioSession) sharedInstance];
	AVAudioSession *systemSession = [AVAudioSession sharedInstance];
	if (active)
		[session audioSessionDidActivate:systemSession];
	else
		[session audioSessionDidDeactivate:systemSession];
	session.isAudioEnabled = active;
}

- (void)setCameraEnabled:(BOOL)enabled {
	if (!_instance)
		return;
	if (enabled) {
		if (!_videoCapture) {
			_videoCapture = std::shared_ptr<tgcalls::VideoCaptureInterface>(
				tgcalls::VideoCaptureInterface::Create(tgcalls::StaticThreads::getThreads(), "", false, nullptr));
			(*_instance)->setVideoCapture(_videoCapture);
		}
		_videoCapture->setState(tgcalls::VideoState::Active);
	} else if (_videoCapture) {
		_videoCapture->setState(tgcalls::VideoState::Inactive);
		(*_instance)->setVideoCapture(nullptr);
		_videoCapture = nullptr;
	}
}

- (void)pushCameraPixelBuffer:(CVPixelBufferRef)pixelBuffer {
	webrtc::scoped_refptr<CameraTrackSource> camera;
	{
		std::lock_guard<std::mutex> lock(cameraMutex);
		if (activeCameraPaused)
			return;
		camera = activeCamera;
	}
	if (camera)
		camera->deliver(pixelBuffer);
}

- (int64_t)preferredRelayId {
	return _instance ? (*_instance)->getPreferredRelayId() : 0;
}

- (void)stop {
	auto instance = _instance;
	_instance = nullptr;
	_videoCapture = nullptr;
	_remoteVideoSink = nullptr;
	if (!instance || !*instance)
		return;
	(*instance)->stop([instance](tgcalls::FinalState finalState) {
		dispatch_async(dispatch_get_main_queue(), ^{
			instance->reset();
		});
	});
}

@end

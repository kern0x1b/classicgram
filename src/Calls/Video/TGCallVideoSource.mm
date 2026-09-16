#include "TGCallVideoSource.h"
#include "libtgvoip/PrivateDefines.h"
#include "libtgvoip/logging.h"
#include <chrono>

using namespace tgvoip;
using namespace tgvoip::video;

static const unsigned int kValidatedMaxWidth = 320;
static const unsigned int kValidatedMaxHeight = 240;
static const unsigned int kValidatedFps = 15;
static const int kVP8CpuUsed = 12;

static double TGMonotonicMs(){
	return std::chrono::duration<double, std::milli>(
			std::chrono::steady_clock::now().time_since_epoch()).count();
}

TGCallVideoSource::TGCallVideoSource(){
}

TGCallVideoSource::~TGCallVideoSource(){
	vp8.Close();
}

std::vector<uint32_t> VideoSource::GetAvailableEncoders(){
	return {CODEC_VP8};
}

std::shared_ptr<VideoSource> VideoSource::Create(){
	return std::make_shared<TGCallVideoSource>();
}

void VideoSource::SetCallback(std::function<void(const Buffer &, uint32_t)> callback){
	this->callback=callback;
}

bool VideoSource::Failed(){
	return failed;
}

std::string VideoSource::GetErrorDescription(){
	return error;
}

void TGCallVideoSource::Start(){
	running = true;
}

void TGCallVideoSource::Stop(){
	running = false;
	vp8.Close();
}

void TGCallVideoSource::Reset(uint32_t newCodec, int maxResolution){
	(void)maxResolution;
	vp8.Close();

	codec = newCodec;
	csd.clear();

	targetWidth = kValidatedMaxWidth;
	targetHeight = kValidatedMaxHeight;
	width = targetWidth;
	height = targetHeight;

	failed = false;
	error.clear();

	if (codec != CODEC_VP8){
		LOGE("TGCallVideoSource: unsupported codec requested 0x%x", newCodec);
		failed = true;
		error = "unsupported outgoing video codec";
		return;
	}
	if (!vp8.Open(targetWidth, targetHeight, kValidatedFps, targetBitrate, kVP8CpuUsed)){
		failed = true;
		error = "libvpx failed to open a VP8 encoder";
	}
}

void TGCallVideoSource::RequestKeyFrame(){
	vp8.RequestKeyFrame();
}

void TGCallVideoSource::SetBitrate(uint32_t bitrate){
	targetBitrate = bitrate;
	vp8.SetBitrate(bitrate);
}

void TGCallVideoSource::PushPixelBuffer(CVPixelBufferRef pixelBuffer, int64_t ptsUs){
	if (!running || !pixelBuffer || codec != CODEC_VP8)
		return;
	EncodeWithVP8(pixelBuffer, ptsUs);
}

void TGCallVideoSource::EncodeWithVP8(CVPixelBufferRef pixelBuffer, int64_t ptsUs){
	CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

	const uint8_t* yPlane = (const uint8_t*)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
	int yStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
	const uint8_t* cbcrPlane = (const uint8_t*)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
	int cbcrStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);

	unsigned int chromaWidth = (targetWidth + 1) / 2;
	unsigned int chromaHeight = (targetHeight + 1) / 2;
	if (chromaScratchU.size() != (size_t)chromaWidth * chromaHeight){
		chromaScratchU.resize((size_t)chromaWidth * chromaHeight);
		chromaScratchV.resize((size_t)chromaWidth * chromaHeight);
	}
	for (unsigned int row = 0; row < chromaHeight; row++){
		const uint8_t* src = cbcrPlane + row * cbcrStride;
		uint8_t* dstU = chromaScratchU.data() + row * chromaWidth;
		uint8_t* dstV = chromaScratchV.data() + row * chromaWidth;
		for (unsigned int col = 0; col < chromaWidth; col++){
			dstU[col] = src[col * 2];
			dstV[col] = src[col * 2 + 1];
		}
	}

	std::vector<Buffer> packets;
	bool keyframe = false;
	bool ok = vp8.EncodeI420(yPlane, yStride,
			chromaScratchU.data(), (int)chromaWidth,
			chromaScratchV.data(), (int)chromaWidth,
			ptsUs, packets, keyframe);

	CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

	framesSinceLog++;
	double now = TGMonotonicMs();
	if (now - lastStatsLogAt > 5000.0){
		LOGI("TGCallVideoSource: vp8 encode avg=%.2fms frames=%u dropped=%u",
				vp8.lastEncodeMs, vp8.framesEncoded, vp8.framesDropped);
		lastStatsLogAt = now;
		framesSinceLog = 0;
	}
	if (statsCallback)
		statsCallback(vp8.lastEncodeMs, ok ? 1 : 0, ok ? 0 : 1);

	if (!ok || packets.empty() || !callback)
		return;

	for (Buffer& packet : packets){
		uint32_t frameFlags = keyframe ? VIDEO_FRAME_FLAG_KEYFRAME : 0;
		callback(packet, frameFlags);
	}
}

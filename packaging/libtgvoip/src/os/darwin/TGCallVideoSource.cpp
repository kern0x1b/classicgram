#include "TGCallVideoSource.h"
#include "TGVTDynamic.h"
#include "../../PrivateDefines.h"
#include "../../logging.h"
#include <chrono>
#include <cstring>

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

static void TGVTEncoderOutputCallback(void* refCon, void* sourceFrameRefCon, OSStatus status,
									   VTEncodeInfoFlags flags, CMSampleBufferRef buffer){
	(void)sourceFrameRefCon;
	if (!refCon)
		return;
	reinterpret_cast<TGCallVideoSource*>(refCon)->VTEncoderCallback(status, buffer, (uint32_t)flags);
}

TGCallVideoSource::TGCallVideoSource(){
}

TGCallVideoSource::~TGCallVideoSource(){
	CloseVideoToolbox();
	vp8.Close();
}

std::vector<uint32_t> VideoSource::GetAvailableEncoders(){
	std::vector<uint32_t> result;
	if (TGVTLoad())
		result.push_back(CODEC_AVC);
	result.push_back(CODEC_VP8);
	return result;
}

std::shared_ptr<VideoSource> VideoSource::Create(){
	return std::make_shared<TGCallVideoSource>();
}

void TGCallVideoSource::Start(){
	running = true;
}

void TGCallVideoSource::Stop(){
	running = false;
	CloseVideoToolbox();
	vp8.Close();
}

void TGCallVideoSource::Reset(uint32_t newCodec, int maxResolution){
	(void)maxResolution;
	CloseVideoToolbox();
	vp8.Close();

	codec = newCodec;
	needCSD = true;
	keyframeRequested = true;
	csd.clear();

	targetWidth = kValidatedMaxWidth;
	targetHeight = kValidatedMaxHeight;
	width = targetWidth;
	height = targetHeight;

	failed = false;
	error.clear();

	if (codec == CODEC_AVC){
		OpenVideoToolbox();
		if (!vtSession){
			failed = true;
			error = "VideoToolbox failed to open a compression session";
		}
	} else if (codec == CODEC_VP8){
		if (!vp8.Open(targetWidth, targetHeight, kValidatedFps, targetBitrate, kVP8CpuUsed)){
			failed = true;
			error = "libvpx failed to open a VP8 encoder";
		}
	} else {
		LOGE("TGCallVideoSource: unsupported codec requested 0x%x", newCodec);
		failed = true;
		error = "unsupported outgoing video codec";
	}
}

void TGCallVideoSource::RequestKeyFrame(){
	keyframeRequested = true;
	vp8.RequestKeyFrame();
}

void TGCallVideoSource::SetBitrate(uint32_t bitrate){
	targetBitrate = bitrate;
	if (vtSession)
		SetEncoderBitrateAndLimit(bitrate);
	vp8.SetBitrate(bitrate);
}

void TGCallVideoSource::OpenVideoToolbox(){
	const TGVTFunctionTable* fn = TGVTGetFunctions();
	if (!fn){
		LOGE("TGCallVideoSource: VideoToolbox unavailable, cannot open H.264 encoder");
		return;
	}
	VTCompressionSessionRef session = NULL;
	OSStatus status = fn->CompressionSessionCreate(NULL, (int32_t)targetWidth, (int32_t)targetHeight,
			kCMVideoCodecType_H264, NULL, NULL, NULL,
			TGVTEncoderOutputCallback, this, &session);
	if (status != noErr || !session){
		LOGE("TGCallVideoSource: VTCompressionSessionCreate failed: %d", (int)status);
		return;
	}
	vtSession = session;
	fn->SessionSetProperty(session, fn->KeyRealTime, kCFBooleanTrue);
	fn->SessionSetProperty(session, fn->KeyAllowFrameReordering, kCFBooleanFalse);

	int64_t interval = 3;
	CFNumberRef intervalNum = CFNumberCreate(NULL, kCFNumberSInt64Type, &interval);
	fn->SessionSetProperty(session, fn->KeyMaxKeyFrameIntervalDuration, intervalNum);
	CFRelease(intervalNum);

	SetEncoderBitrateAndLimit(targetBitrate);
	LOGI("TGCallVideoSource: opened VideoToolbox H.264 session %ux%u", targetWidth, targetHeight);
}

void TGCallVideoSource::CloseVideoToolbox(){
	if (!vtSession)
		return;
	const TGVTFunctionTable* fn = TGVTGetFunctions();
	VTCompressionSessionRef session = (VTCompressionSessionRef)vtSession;
	if (fn && fn->CompressionSessionInvalidate)
		fn->CompressionSessionInvalidate(session);
	CFRelease(session);
	vtSession = nullptr;
}

void TGCallVideoSource::SetEncoderBitrateAndLimit(uint32_t bitrate){
	const TGVTFunctionTable* fn = TGVTGetFunctions();
	if (!fn || !vtSession)
		return;
	VTCompressionSessionRef session = (VTCompressionSessionRef)vtSession;

	int64_t bitrateValue = bitrate;
	CFNumberRef bitrateNum = CFNumberCreate(NULL, kCFNumberSInt64Type, &bitrateValue);
	fn->SessionSetProperty(session, fn->KeyAverageBitRate, bitrateNum);
	CFRelease(bitrateNum);

	int64_t bytesPerSecondValue = bitrate / 8;
	CFNumberRef bytesPerSecond = CFNumberCreate(NULL, kCFNumberSInt64Type, &bytesPerSecondValue);
	int64_t oneSecondValue = 1;
	CFNumberRef oneSecond = CFNumberCreate(NULL, kCFNumberSInt64Type, &oneSecondValue);
	const void* limitValues[] = { bytesPerSecond, oneSecond };
	CFArrayRef limits = CFArrayCreate(NULL, limitValues, 2, &kCFTypeArrayCallBacks);
	fn->SessionSetProperty(session, fn->KeyDataRateLimits, limits);
	CFRelease(limits);
	CFRelease(bytesPerSecond);
	CFRelease(oneSecond);
}

void TGCallVideoSource::PushPixelBuffer(CVPixelBufferRef pixelBuffer, int64_t ptsUs){
	if (!running || !pixelBuffer)
		return;
	if (codec == CODEC_AVC)
		EncodeWithVideoToolbox(pixelBuffer, ptsUs);
	else if (codec == CODEC_VP8)
		EncodeWithVP8(pixelBuffer, ptsUs);
}

void TGCallVideoSource::EncodeWithVideoToolbox(CVPixelBufferRef pixelBuffer, int64_t ptsUs){
	const TGVTFunctionTable* fn = TGVTGetFunctions();
	if (!fn || !vtSession)
		return;

	CFDictionaryRef frameProps = NULL;
	if (keyframeRequested){
		const void* keys[] = { fn->KeyForceKeyFrame };
		const void* values[] = { kCFBooleanTrue };
		frameProps = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
		keyframeRequested = false;
	}

	CMTime pts = CMTimeMake(ptsUs, 1000000);
	VTEncodeInfoFlags infoFlags = 0;
	OSStatus status = fn->CompressionSessionEncodeFrame((VTCompressionSessionRef)vtSession,
			pixelBuffer, pts, kCMTimeInvalid, frameProps, NULL, &infoFlags);
	if (frameProps)
		CFRelease(frameProps);
	if (status != noErr)
		LOGW("TGCallVideoSource: VTCompressionSessionEncodeFrame failed: %d", (int)status);
}

void TGCallVideoSource::UpdateCSDFromFormatDescription(CMFormatDescriptionRef format){
	const uint8_t startCode[] = { 0, 0, 0, 1 };
	csd.clear();

	CFDictionaryRef atoms = (CFDictionaryRef)CMFormatDescriptionGetExtension(format,
			kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms);
	CFDataRef avcC = atoms ? (CFDataRef)CFDictionaryGetValue(atoms, CFSTR("avcC")) : NULL;
	if (!avcC){
		LOGE("TGCallVideoSource: format description has no avcC atom");
		return;
	}

	const uint8_t* bytes = CFDataGetBytePtr(avcC);
	size_t length = (size_t)CFDataGetLength(avcC);
	if (length < 6){
		LOGE("TGCallVideoSource: avcC atom too short (%zu bytes)", length);
		return;
	}

	size_t offset = 5;
	uint8_t numSps = bytes[offset] & 0x1F;
	offset += 1;
	for (uint8_t i = 0; i < numSps && offset + 2 <= length; i++){
		uint16_t setLen = (uint16_t)((bytes[offset] << 8) | bytes[offset + 1]);
		offset += 2;
		if (offset + setLen > length)
			break;
		Buffer b((size_t)setLen + 4);
		b.CopyFrom(startCode, 0, 4);
		b.CopyFrom(bytes + offset, 4, setLen);
		csd.push_back(std::move(b));
		offset += setLen;
	}
	if (offset >= length){
		LOGE("TGCallVideoSource: avcC atom truncated before PPS count");
		csd.clear();
		return;
	}
	uint8_t numPps = bytes[offset];
	offset += 1;
	for (uint8_t i = 0; i < numPps && offset + 2 <= length; i++){
		uint16_t setLen = (uint16_t)((bytes[offset] << 8) | bytes[offset + 1]);
		offset += 2;
		if (offset + setLen > length)
			break;
		Buffer b((size_t)setLen + 4);
		b.CopyFrom(startCode, 0, 4);
		b.CopyFrom(bytes + offset, 4, setLen);
		csd.push_back(std::move(b));
		offset += setLen;
	}

	if (csd.size() != 2){
		LOGE("TGCallVideoSource: expected 1 SPS + 1 PPS from avcC, got %zu buffers", csd.size());
		csd.clear();
	}
}

void TGCallVideoSource::VTEncoderCallback(OSStatus status, CMSampleBufferRef buffer, uint32_t vtFlags){
	if (status != noErr){
		LOGE("TGCallVideoSource: encoder callback error %d", (int)status);
		return;
	}
	if (vtFlags & kVTEncodeInfo_FrameDropped){
		LOGW("TGCallVideoSource: hardware encoder dropped a frame");
		if (statsCallback)
			statsCallback(0, 0, 1);
		return;
	}
	if (!buffer || !CMSampleBufferGetNumSamples(buffer))
		return;

	double t0 = TGMonotonicMs();

	if (needCSD){
		CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(buffer);
		UpdateCSDFromFormatDescription(format);
		needCSD = false;
	}

	CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(buffer);
	size_t len = CMBlockBufferGetDataLength(blockBuffer);

	int frameFlags = 0;
	CFArrayRef attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(buffer, false);
	if (attachmentsArray && CFArrayGetCount(attachmentsArray)){
		CFDictionaryRef dict = (CFDictionaryRef)CFArrayGetValueAtIndex(attachmentsArray, 0);
		CFBooleanRef notSync = NULL;
		Boolean keyExists = CFDictionaryGetValueIfPresent(dict, kCMSampleAttachmentKey_NotSync, (const void**)&notSync);
		if (!keyExists || !CFBooleanGetValue(notSync))
			frameFlags |= VIDEO_FRAME_FLAG_KEYFRAME;
	} else {
		frameFlags |= VIDEO_FRAME_FLAG_KEYFRAME;
	}

	Buffer frame(len);
	CMBlockBufferCopyDataBytes(blockBuffer, 0, len, *frame);
	size_t offset = 0;
	while (offset + 4 <= len){
		uint8_t* p = *frame + offset;
		uint32_t nalLen = ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | (uint32_t)p[3];
		p[0] = 0; p[1] = 0; p[2] = 0; p[3] = 1;
		offset += nalLen + 4;
	}

	double encodeMs = TGMonotonicMs() - t0;
	emaEncodeMs = emaEncodeMs > 0 ? emaEncodeMs * 0.9 + encodeMs * 0.1 : encodeMs;
	framesSinceLog++;
	double now = TGMonotonicMs();
	if (now - lastStatsLogAt > 5000.0){
		LOGI("TGCallVideoSource: h264 encode avg=%.2fms frames=%u", emaEncodeMs, framesSinceLog);
		lastStatsLogAt = now;
		framesSinceLog = 0;
	}
	if (statsCallback)
		statsCallback(encodeMs, 1, 0);

	if (callback)
		callback(frame, (uint32_t)frameFlags, rotation);
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
		callback(packet, frameFlags, rotation);
	}
}

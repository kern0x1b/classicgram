#include "TGCallVideoRenderer.h"
#include "TGVTDynamic.h"
#include "../../PrivateDefines.h"
#include "../../logging.h"
#include <chrono>
#include <cstring>

using namespace tgvoip;
using namespace tgvoip::video;

static double TGMonotonicMs(){
	return std::chrono::duration<double, std::milli>(
			std::chrono::steady_clock::now().time_since_epoch()).count();
}

static inline uint8_t TGClampByte(int v){
	return v < 0 ? 0 : (v > 255 ? 255 : (uint8_t)v);
}

static void TGConvertI420ToBGRA(const uint8_t* yPlane, int yStride,
								 const uint8_t* uPlane, int uStride,
								 const uint8_t* vPlane, int vStride,
								 unsigned int width, unsigned int height,
								 uint8_t* dst, int dstStride){
	for (unsigned int row = 0; row < height; row++){
		const uint8_t* yRow = yPlane + row * yStride;
		const uint8_t* uRow = uPlane + (row / 2) * uStride;
		const uint8_t* vRow = vPlane + (row / 2) * vStride;
		uint8_t* dstRow = dst + row * dstStride;
		for (unsigned int col = 0; col < width; col++){
			int y = yRow[col];
			int u = uRow[col / 2] - 128;
			int v = vRow[col / 2] - 128;
			int r = y + ((91881 * v) >> 16);
			int g = y - ((22554 * u + 46802 * v) >> 16);
			int b = y + ((116130 * u) >> 16);
			uint8_t* px = dstRow + col * 4;
			px[0] = TGClampByte(b);
			px[1] = TGClampByte(g);
			px[2] = TGClampByte(r);
			px[3] = 255;
		}
	}
}

static void TGVTDecoderOutputCallback(void* decompressionOutputRefCon, void* sourceFrameRefCon,
									   OSStatus status, VTDecodeInfoFlags infoFlags,
									   CVImageBufferRef imageBuffer, CMTime presentationTimeStamp,
									   CMTime presentationDuration){
	(void)sourceFrameRefCon; (void)infoFlags; (void)presentationTimeStamp; (void)presentationDuration;
	if (!decompressionOutputRefCon)
		return;
	reinterpret_cast<TGCallVideoRenderer*>(decompressionOutputRefCon)->VTDecoderCallback(status, imageBuffer);
}

static void TGAnnexBToLengthPrefixed(Buffer& frame){
	uint8_t* data = *frame;
	size_t len = frame.Length();
	size_t pos = 0;
	while (pos + 4 <= len){
		size_t nalStart = pos + 4;
		size_t nextStart = len;
		for (size_t i = nalStart; i + 4 <= len; i++){
			if (data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 0 && data[i + 3] == 1){
				nextStart = i;
				break;
			}
		}
		uint32_t nalLen = (uint32_t)(nextStart - nalStart);
		data[pos + 0] = (uint8_t)(nalLen >> 24);
		data[pos + 1] = (uint8_t)(nalLen >> 16);
		data[pos + 2] = (uint8_t)(nalLen >> 8);
		data[pos + 3] = (uint8_t)nalLen;
		pos = nextStart;
	}
}

TGCallVideoRenderer::TGCallVideoRenderer(){
}

TGCallVideoRenderer::~TGCallVideoRenderer(){
	CloseVideoToolbox();
	vp8.Close();
}

void TGCallVideoRenderer::Reset(uint32_t newCodec, unsigned int w, unsigned int h, std::vector<Buffer>& csd){
	CloseVideoToolbox();
	vp8.Close();

	codec = newCodec;
	frameWidth = w;
	frameHeight = h;
	LOGI("TGCallVideoRenderer: reset codec=0x%x %ux%u", newCodec, w, h);

	if (codec == CODEC_AVC){
		OpenVideoToolbox(csd);
	} else if (codec == CODEC_VP8){
		vp8.Open();
	} else {
		LOGE("TGCallVideoRenderer: unsupported codec 0x%x", newCodec);
	}
}

static CFDataRef TGBuildAVCCAtom(std::vector<Buffer>& csd){
	if (csd.size() != 2)
		return NULL;
	const uint8_t* sps = *csd[0] + 4;
	size_t spsLen = csd[0].Length() - 4;
	const uint8_t* pps = *csd[1] + 4;
	size_t ppsLen = csd[1].Length() - 4;
	if (spsLen < 4)
		return NULL;

	std::vector<uint8_t> box;
	box.push_back(1);
	box.push_back(sps[1]);
	box.push_back(sps[2]);
	box.push_back(sps[3]);
	box.push_back(0xFF);
	box.push_back(0xE1);
	box.push_back((uint8_t)((spsLen >> 8) & 0xFF));
	box.push_back((uint8_t)(spsLen & 0xFF));
	box.insert(box.end(), sps, sps + spsLen);
	box.push_back(1);
	box.push_back((uint8_t)((ppsLen >> 8) & 0xFF));
	box.push_back((uint8_t)(ppsLen & 0xFF));
	box.insert(box.end(), pps, pps + ppsLen);

	return CFDataCreate(NULL, box.data(), (CFIndex)box.size());
}

void TGCallVideoRenderer::OpenVideoToolbox(std::vector<Buffer>& csd){
	const TGVTFunctionTable* fn = TGVTGetFunctions();
	if (!fn){
		LOGE("TGCallVideoRenderer: VideoToolbox unavailable, cannot open H.264 decoder");
		return;
	}
	if (csd.size() != 2){
		LOGE("TGCallVideoRenderer: H264 requires exactly 2 CSD buffers, got %zu", csd.size());
		return;
	}

	CFDataRef avcC = TGBuildAVCCAtom(csd);
	if (!avcC){
		LOGE("TGCallVideoRenderer: could not build avcC atom from CSD");
		return;
	}

	CFMutableDictionaryRef atoms = CFDictionaryCreateMutable(NULL, 0,
			&kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	CFDictionarySetValue(atoms, CFSTR("avcC"), avcC);
	CFMutableDictionaryRef extensions = CFDictionaryCreateMutable(NULL, 0,
			&kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	CFDictionarySetValue(extensions, kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms, atoms);

	CMFormatDescriptionRef format = NULL;
	OSStatus status = CMVideoFormatDescriptionCreate(NULL, kCMVideoCodecType_H264,
			(int32_t)frameWidth, (int32_t)frameHeight, extensions, &format);
	CFRelease(extensions);
	CFRelease(atoms);
	CFRelease(avcC);
	if (status != noErr || !format){
		LOGE("TGCallVideoRenderer: CMVideoFormatDescriptionCreate failed: %d", (int)status);
		return;
	}
	formatDesc = (void*)format;

	CFMutableDictionaryRef destAttrs = CFDictionaryCreateMutable(NULL, 0,
			&kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	int32_t pixelFormat = kCVPixelFormatType_32BGRA;
	CFNumberRef pixelFormatNum = CFNumberCreate(NULL, kCFNumberSInt32Type, &pixelFormat);
	CFDictionarySetValue(destAttrs, kCVPixelBufferPixelFormatTypeKey, pixelFormatNum);
	CFRelease(pixelFormatNum);

	VTDecompressionOutputCallbackRecord callbackRecord;
	callbackRecord.decompressionOutputCallback = TGVTDecoderOutputCallback;
	callbackRecord.decompressionOutputRefCon = this;

	VTDecompressionSessionRef session = NULL;
	status = fn->DecompressionSessionCreate(NULL, format, NULL, destAttrs, &callbackRecord, &session);
	CFRelease(destAttrs);
	if (status != noErr || !session){
		LOGE("TGCallVideoRenderer: VTDecompressionSessionCreate failed: %d", (int)status);
		return;
	}
	vtSession = session;
	LOGI("TGCallVideoRenderer: opened VideoToolbox H.264 decode session");
}

void TGCallVideoRenderer::CloseVideoToolbox(){
	if (formatDesc){
		CFRelease((CMFormatDescriptionRef)formatDesc);
		formatDesc = nullptr;
	}
	if (!vtSession)
		return;
	const TGVTFunctionTable* fn = TGVTGetFunctions();
	VTDecompressionSessionRef session = (VTDecompressionSessionRef)vtSession;
	if (fn && fn->DecompressionSessionInvalidate)
		fn->DecompressionSessionInvalidate(session);
	CFRelease(session);
	vtSession = nullptr;
}

void TGCallVideoRenderer::DecodeAndDisplay(Buffer frame, uint32_t pts){
	(void)pts;
	if (paused || !enabled)
		return;
	if (codec == CODEC_AVC)
		DecodeWithVideoToolbox(frame);
	else if (codec == CODEC_VP8)
		DecodeWithVP8(frame);
}

void TGCallVideoRenderer::DecodeWithVideoToolbox(Buffer& frame){
	const TGVTFunctionTable* fn = TGVTGetFunctions();
	if (!fn || !vtSession || !formatDesc)
		return;

	TGAnnexBToLengthPrefixed(frame);

	CMBlockBufferRef blockBuffer = NULL;
	OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, *frame, frame.Length(),
			kCFAllocatorNull, NULL, 0, frame.Length(), 0, &blockBuffer);
	if (status != noErr){
		LOGE("TGCallVideoRenderer: CMBlockBufferCreateWithMemoryBlock failed: %d", (int)status);
		return;
	}

	CMSampleBufferRef sampleBuffer = NULL;
	status = CMSampleBufferCreate(kCFAllocatorDefault, blockBuffer, true, NULL, NULL,
			(CMFormatDescriptionRef)formatDesc, 1, 0, NULL, 0, NULL, &sampleBuffer);
	CFRelease(blockBuffer);
	if (status != noErr || !sampleBuffer){
		LOGE("TGCallVideoRenderer: CMSampleBufferCreate failed: %d", (int)status);
		return;
	}

	VTDecodeInfoFlags infoFlags = 0;
	status = fn->DecompressionSessionDecodeFrame((VTDecompressionSessionRef)vtSession, sampleBuffer,
			0, NULL, &infoFlags);
	CFRelease(sampleBuffer);
	if (status != noErr){
		LOGW("TGCallVideoRenderer: VTDecompressionSessionDecodeFrame failed: %d", (int)status);
		if (statsCallback)
			statsCallback(0, 0, 1);
	}
}

void TGCallVideoRenderer::VTDecoderCallback(OSStatus status, CVImageBufferRef imageBuffer){
	double t0 = TGMonotonicMs();
	if (status != noErr || !imageBuffer){
		LOGW("TGCallVideoRenderer: decode callback status %d", (int)status);
		if (statsCallback)
			statsCallback(0, 0, 1);
		return;
	}
	DeliverBGRAFromPixelBuffer(imageBuffer);
	double decodeMs = TGMonotonicMs() - t0;
	emaDecodeMs = emaDecodeMs > 0 ? emaDecodeMs * 0.9 + decodeMs * 0.1 : decodeMs;
	framesSinceLog++;
	double now = TGMonotonicMs();
	if (now - lastStatsLogAt > 5000.0){
		LOGI("TGCallVideoRenderer: h264 decode+render avg=%.2fms frames=%u", emaDecodeMs, framesSinceLog);
		lastStatsLogAt = now;
		framesSinceLog = 0;
	}
	if (statsCallback)
		statsCallback(decodeMs, 1, 0);
}

void TGCallVideoRenderer::DecodeWithVP8(Buffer& frame){
	const uint8_t* y = NULL; int yStride = 0;
	const uint8_t* u = NULL; int uStride = 0;
	const uint8_t* v = NULL; int vStride = 0;
	unsigned int w = 0, h = 0;
	bool ok = vp8.DecodeToI420(*frame, frame.Length(), &y, &yStride, &u, &uStride, &v, &vStride, &w, &h);

	framesSinceLog++;
	double now = TGMonotonicMs();
	if (now - lastStatsLogAt > 5000.0){
		LOGI("TGCallVideoRenderer: vp8 decode avg=%.2fms frames=%u failed=%u",
				vp8.lastDecodeMs, vp8.framesDecoded, vp8.framesFailed);
		lastStatsLogAt = now;
		framesSinceLog = 0;
	}
	if (statsCallback)
		statsCallback(vp8.lastDecodeMs, ok ? 1 : 0, ok ? 0 : 1);
	if (!ok || !frameCallback)
		return;

	size_t needed = (size_t)w * h * 4;
	if (bgraScratch.size() != needed)
		bgraScratch.resize(needed);
	TGConvertI420ToBGRA(y, yStride, u, uStride, v, vStride, w, h, bgraScratch.data(), (int)w * 4);
	frameCallback(bgraScratch.data(), w, h, (int)w * 4);
}

void TGCallVideoRenderer::DeliverBGRAFromPixelBuffer(CVPixelBufferRef pixelBuffer){
	if (!frameCallback)
		return;
	CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
	const uint8_t* base = (const uint8_t*)CVPixelBufferGetBaseAddress(pixelBuffer);
	int stride = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
	unsigned int w = (unsigned int)CVPixelBufferGetWidth(pixelBuffer);
	unsigned int h = (unsigned int)CVPixelBufferGetHeight(pixelBuffer);
	if (base)
		frameCallback(base, w, h, stride);
	CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
}

void TGCallVideoRenderer::SetStreamEnabled(bool isEnabled){
	enabled = isEnabled;
}

void TGCallVideoRenderer::SetRotation(uint16_t rotation){
	(void)rotation;
}

void TGCallVideoRenderer::SetStreamPaused(bool isPaused){
	paused = isPaused;
}

int VideoRenderer::GetMaximumResolution(){
	return INIT_VIDEO_RES_240;
}

std::vector<uint32_t> VideoRenderer::GetAvailableDecoders(){
	std::vector<uint32_t> result;
	if (TGVTLoad())
		result.push_back(CODEC_AVC);
	result.push_back(CODEC_VP8);
	return result;
}

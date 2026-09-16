#include "TGCallVideoRenderer.h"
#include "libtgvoip/PrivateDefines.h"
#include "libtgvoip/logging.h"
#include <chrono>

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

TGCallVideoRenderer::TGCallVideoRenderer(){
}

TGCallVideoRenderer::~TGCallVideoRenderer(){
	vp8.Close();
}

void TGCallVideoRenderer::Reset(uint32_t newCodec, unsigned int w, unsigned int h, std::vector<Buffer>& csd){
	(void)csd;
	vp8.Close();

	codec = newCodec;
	LOGI("TGCallVideoRenderer: reset codec=0x%x %ux%u", newCodec, w, h);

	if (codec == CODEC_VP8)
		vp8.Open();
	else
		LOGE("TGCallVideoRenderer: unsupported codec 0x%x", newCodec);
}

void TGCallVideoRenderer::DecodeAndDisplay(Buffer frame, uint32_t pts){
	(void)pts;
	if (!enabled || codec != CODEC_VP8)
		return;
	DecodeWithVP8(frame);
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

void TGCallVideoRenderer::SetStreamEnabled(bool isEnabled){
	enabled = isEnabled;
}

int VideoRenderer::GetMaximumResolution(){
	return INIT_VIDEO_RES_240;
}

std::vector<uint32_t> VideoRenderer::GetAvailableDecoders(){
	return {CODEC_VP8};
}

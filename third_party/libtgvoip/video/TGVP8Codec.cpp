#include "TGVP8Codec.h"
#include "../logging.h"
#include <chrono>
#include <cstring>

#include "vpx/vpx_encoder.h"
#include "vpx/vpx_decoder.h"
#include "vpx/vp8cx.h"
#include "vpx/vp8dx.h"

using namespace tgvoip;
using namespace tgvoip::video;

static double TGMonotonicMs(){
	return std::chrono::duration<double, std::milli>(
			std::chrono::steady_clock::now().time_since_epoch()).count();
}

TGVP8Encoder::TGVP8Encoder(){
}

TGVP8Encoder::~TGVP8Encoder(){
	Close();
}

bool TGVP8Encoder::Open(unsigned int w, unsigned int h, unsigned int fps, uint32_t bitrateBps, int cpuUsed){
	Close();

	vpx_codec_enc_cfg_t cfg;
	vpx_codec_iface_t* iface = vpx_codec_vp8_cx();
	if (vpx_codec_enc_config_default(iface, &cfg, 0) != VPX_CODEC_OK){
		LOGE("TGVP8Encoder: enc_config_default failed");
		return false;
	}

	cfg.g_w = w;
	cfg.g_h = h;
	cfg.g_timebase.num = 1;
	cfg.g_timebase.den = 1000000;
	cfg.rc_target_bitrate = bitrateBps / 1000;
	cfg.g_error_resilient = VPX_ERROR_RESILIENT_DEFAULT;
	cfg.g_lag_in_frames = 0;
	cfg.g_pass = VPX_RC_ONE_PASS;
	cfg.rc_end_usage = VPX_CBR;
	cfg.g_threads = 1;
	cfg.rc_min_quantizer = 4;
	cfg.rc_max_quantizer = 56;
	cfg.rc_dropframe_thresh = 0;
	cfg.rc_resize_allowed = 0;
	cfg.rc_buf_sz = 1000;
	cfg.rc_buf_initial_sz = 500;
	cfg.rc_buf_optimal_sz = 600;
	cfg.kf_mode = VPX_KF_AUTO;
	cfg.kf_max_dist = fps ? fps * 10 : 150;

	vpx_codec_ctx_t* c = new vpx_codec_ctx_t();
	memset(c, 0, sizeof(vpx_codec_ctx_t));
	if (vpx_codec_enc_init(c, iface, &cfg, 0) != VPX_CODEC_OK){
		LOGE("TGVP8Encoder: enc_init failed: %s", vpx_codec_error_detail(c));
		delete c;
		return false;
	}
	vpx_codec_control(c, VP8E_SET_CPUUSED, cpuUsed);
	vpx_codec_control(c, VP8E_SET_NOISE_SENSITIVITY, (unsigned int)0);

	vpx_image_t* im = new vpx_image_t();
	memset(im, 0, sizeof(vpx_image_t));
	if (!vpx_img_alloc(im, VPX_IMG_FMT_I420, w, h, 1)){
		LOGE("TGVP8Encoder: vpx_img_alloc failed");
		vpx_codec_destroy(c);
		delete c;
		delete im;
		return false;
	}

	ctx = c;
	img = im;
	width = w;
	height = h;
	currentBitrate = bitrateBps;
	keyframeRequested = true;
	frameIndex = 0;
	framesEncoded = 0;
	framesDropped = 0;
	opened = true;
	LOGI("TGVP8Encoder: opened %ux%u fps=%u bitrate=%u cpuused=%d", w, h, fps, bitrateBps, cpuUsed);
	return true;
}

void TGVP8Encoder::Close(){
	if (!opened)
		return;
	vpx_codec_ctx_t* c = (vpx_codec_ctx_t*)ctx;
	vpx_image_t* im = (vpx_image_t*)img;
	if (c){
		vpx_codec_destroy(c);
		delete c;
	}
	if (im){
		vpx_img_free(im);
		delete im;
	}
	ctx = nullptr;
	img = nullptr;
	opened = false;
}

void TGVP8Encoder::SetBitrate(uint32_t bitrateBps){
	if (!opened || bitrateBps == currentBitrate)
		return;
	currentBitrate = bitrateBps;
	vpx_codec_ctx_t* c = (vpx_codec_ctx_t*)ctx;
	vpx_codec_enc_cfg_t cfg = *c->config.enc;
	cfg.rc_target_bitrate = bitrateBps / 1000;
	vpx_codec_enc_config_set(c, &cfg);
}

void TGVP8Encoder::RequestKeyFrame(){
	keyframeRequested = true;
}

bool TGVP8Encoder::EncodeI420(const uint8_t* yPlane, int yStride,
							   const uint8_t* uPlane, int uStride,
							   const uint8_t* vPlane, int vStride,
							   int64_t ptsUs,
							   std::vector<Buffer>& outPackets, bool& outKeyframe){
	if (!opened)
		return false;

	double t0 = TGMonotonicMs();
	vpx_image_t* im = (vpx_image_t*)img;
	for (unsigned int row = 0; row < height; row++)
		memcpy(im->planes[VPX_PLANE_Y] + row * im->stride[VPX_PLANE_Y], yPlane + row * yStride, width);
	unsigned int cw = (width + 1) / 2, ch = (height + 1) / 2;
	for (unsigned int row = 0; row < ch; row++){
		memcpy(im->planes[VPX_PLANE_U] + row * im->stride[VPX_PLANE_U], uPlane + row * uStride, cw);
		memcpy(im->planes[VPX_PLANE_V] + row * im->stride[VPX_PLANE_V], vPlane + row * vStride, cw);
	}

	vpx_enc_frame_flags_t flags = 0;
	if (keyframeRequested){
		flags |= VPX_EFLAG_FORCE_KF;
		keyframeRequested = false;
	}

	vpx_codec_ctx_t* c = (vpx_codec_ctx_t*)ctx;
	vpx_codec_err_t err = vpx_codec_encode(c, im, frameIndex++, 1, flags, VPX_DL_REALTIME);
	if (err != VPX_CODEC_OK){
		LOGE("TGVP8Encoder: encode failed: %s", vpx_codec_error_detail(c));
		framesDropped++;
		return false;
	}

	outPackets.clear();
	outKeyframe = false;
	vpx_codec_iter_t iter = nullptr;
	const vpx_codec_cx_pkt_t* pkt;
	while ((pkt = vpx_codec_get_cx_data(c, &iter)) != nullptr){
		if (pkt->kind != VPX_CODEC_CX_FRAME_PKT)
			continue;
		Buffer b(pkt->data.frame.sz);
		b.CopyFrom(pkt->data.frame.buf, 0, pkt->data.frame.sz);
		outPackets.push_back(std::move(b));
		if (pkt->data.frame.flags & VPX_FRAME_IS_KEY)
			outKeyframe = true;
	}

	lastEncodeMs = TGMonotonicMs() - t0;
	if (!outPackets.empty())
		framesEncoded++;
	else
		framesDropped++;
	return !outPackets.empty();
}

TGVP8Decoder::TGVP8Decoder(){
}

TGVP8Decoder::~TGVP8Decoder(){
	Close();
}

bool TGVP8Decoder::Open(){
	Close();
	vpx_codec_ctx_t* c = new vpx_codec_ctx_t();
	memset(c, 0, sizeof(vpx_codec_ctx_t));
	vpx_codec_dec_cfg_t cfg;
	cfg.threads = 1;
	cfg.w = 0;
	cfg.h = 0;
	if (vpx_codec_dec_init(c, vpx_codec_vp8_dx(), &cfg, 0) != VPX_CODEC_OK){
		LOGE("TGVP8Decoder: dec_init failed");
		delete c;
		return false;
	}
	ctx = c;
	opened = true;
	framesDecoded = 0;
	framesFailed = 0;
	LOGI("TGVP8Decoder: opened");
	return true;
}

void TGVP8Decoder::Close(){
	if (!opened)
		return;
	vpx_codec_ctx_t* c = (vpx_codec_ctx_t*)ctx;
	vpx_codec_destroy(c);
	delete c;
	ctx = nullptr;
	opened = false;
}

bool TGVP8Decoder::DecodeToI420(const uint8_t* data, size_t length,
								 const uint8_t** outY, int* outYStride,
								 const uint8_t** outU, int* outUStride,
								 const uint8_t** outV, int* outVStride,
								 unsigned int* outWidth, unsigned int* outHeight){
	if (!opened)
		return false;

	double t0 = TGMonotonicMs();
	vpx_codec_ctx_t* c = (vpx_codec_ctx_t*)ctx;
	if (vpx_codec_decode(c, data, (unsigned int)length, nullptr, 0) != VPX_CODEC_OK){
		LOGW("TGVP8Decoder: decode failed: %s", vpx_codec_error_detail(c));
		framesFailed++;
		return false;
	}
	vpx_codec_iter_t iter = nullptr;
	vpx_image_t* im = vpx_codec_get_frame(c, &iter);
	if (!im){
		framesFailed++;
		return false;
	}
	*outY = im->planes[VPX_PLANE_Y];
	*outYStride = im->stride[VPX_PLANE_Y];
	*outU = im->planes[VPX_PLANE_U];
	*outUStride = im->stride[VPX_PLANE_U];
	*outV = im->planes[VPX_PLANE_V];
	*outVStride = im->stride[VPX_PLANE_V];
	*outWidth = im->d_w;
	*outHeight = im->d_h;
	lastDecodeMs = TGMonotonicMs() - t0;
	framesDecoded++;
	return true;
}

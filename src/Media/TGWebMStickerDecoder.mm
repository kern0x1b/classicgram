#import "TGWebMStickerDecoder.h"

#include <webm/buffer_reader.h>
#include <webm/callback.h>
#include <webm/webm_parser.h>
#include <vpx/vp8dx.h>
#include <vpx/vpx_decoder.h>
#include <libyuv.h>

#include <algorithm>
#include <cstring>
#include <string>
#include <vector>

namespace {
const std::uint64_t TGWebMAlphaAdditionId = 1;
const NSTimeInterval TGWebMDefaultFrameDuration = 1.0 / 30.0;
const NSUInteger TGWebMMaximumSide = 512;

struct TGWebMFrame {
	std::uint64_t position;
	std::uint64_t size;
	std::int64_t timecodeMs;
	std::vector<std::uint8_t> alpha;
};

class TGWebMFrameCollector : public webm::Callback {
public:
	std::vector<TGWebMFrame> frames;
	std::uint64_t videoTrack = 0;
	std::string codec;
	std::uint64_t width = 0;
	std::uint64_t height = 0;
	std::uint64_t timecodeScale = 1000000;

	webm::Status OnInfo(const webm::ElementMetadata &metadata, const webm::Info &info) override {
		timecodeScale = info.timecode_scale.value();
		return webm::Status(webm::Status::kOkCompleted);
	}

	webm::Status OnTrackEntry(const webm::ElementMetadata &metadata, const webm::TrackEntry &entry) override {
		if (videoTrack || !entry.video.is_present())
			return webm::Status(webm::Status::kOkCompleted);
		const std::string &codecId = entry.codec_id.value();
		if (codecId != "V_VP9" && codecId != "V_VP8")
			return webm::Status(webm::Status::kOkCompleted);
		videoTrack = entry.track_number.value();
		codec = codecId;
		width = entry.video.value().pixel_width.value();
		height = entry.video.value().pixel_height.value();
		return webm::Status(webm::Status::kOkCompleted);
	}

	webm::Status OnClusterBegin(const webm::ElementMetadata &metadata, const webm::Cluster &cluster, webm::Action *action) override {
		_clusterTimecode = (std::int64_t)cluster.timecode.value();
		*action = webm::Action::kRead;
		return webm::Status(webm::Status::kOkCompleted);
	}

	webm::Status OnSimpleBlockBegin(const webm::ElementMetadata &metadata, const webm::SimpleBlock &block, webm::Action *action) override {
		return beginBlock(block, action);
	}

	webm::Status OnBlockGroupBegin(const webm::ElementMetadata &metadata, webm::Action *action) override {
		_groupFrameIndex = SIZE_MAX;
		*action = webm::Action::kRead;
		return webm::Status(webm::Status::kOkCompleted);
	}

	webm::Status OnBlockBegin(const webm::ElementMetadata &metadata, const webm::Block &block, webm::Action *action) override {
		return beginBlock(block, action);
	}

	webm::Status OnFrame(const webm::FrameMetadata &metadata, webm::Reader *reader, std::uint64_t *bytesRemaining) override {
		if (_blockIsVideo) {
			TGWebMFrame frame;
			frame.position = metadata.position;
			frame.size = metadata.size;
			frame.timecodeMs = (_clusterTimecode + _blockTimecode) * (std::int64_t)timecodeScale / 1000000;
			frames.push_back(frame);
			_groupFrameIndex = frames.size() - 1;
		}
		return webm::Callback::OnFrame(metadata, reader, bytesRemaining);
	}

	webm::Status OnBlockGroupEnd(const webm::ElementMetadata &metadata, const webm::BlockGroup &group) override {
		if (_groupFrameIndex >= frames.size() || !group.additions.is_present())
			return webm::Status(webm::Status::kOkCompleted);
		for (const auto &more : group.additions.value().block_mores) {
			if (more.value().id.value() == TGWebMAlphaAdditionId)
				frames[_groupFrameIndex].alpha = more.value().data.value();
		}
		return webm::Status(webm::Status::kOkCompleted);
	}

private:
	std::int64_t _clusterTimecode = 0;
	std::int64_t _blockTimecode = 0;
	bool _blockIsVideo = false;
	std::size_t _groupFrameIndex = SIZE_MAX;

	webm::Status beginBlock(const webm::Block &block, webm::Action *action) {
		_blockIsVideo = videoTrack != 0 && block.track_number == videoTrack;
		_blockTimecode = block.timecode;
		*action = webm::Action::kRead;
		return webm::Status(webm::Status::kOkCompleted);
	}
};

bool TGWebMOpenDecoder(vpx_codec_ctx_t *context, const std::string &codec) {
	vpx_codec_iface_t *interface = codec == "V_VP8" ? vpx_codec_vp8_dx() : vpx_codec_vp9_dx();
	vpx_codec_dec_cfg_t config = {1, 0, 0};
	return vpx_codec_dec_init(context, interface, &config, 0) == VPX_CODEC_OK;
}

vpx_image_t *TGWebMDecodeFrame(vpx_codec_ctx_t *context, const std::uint8_t *data, std::size_t size) {
	if (vpx_codec_decode(context, data, (unsigned int)size, NULL, 0) != VPX_CODEC_OK)
		return NULL;
	vpx_codec_iter_t iterator = NULL;
	vpx_image_t *image = NULL;
	vpx_image_t *next = NULL;
	while ((next = vpx_codec_get_frame(context, &iterator)))
		image = next;
	return image;
}

void TGWebMReleaseBytes(void *info, const void *data, size_t size) {
	free((void *)data);
}
}

@implementation TGWebMStickerDecoder {
	NSData *_bytes;
	std::vector<TGWebMFrame> _frames;
	std::string _codec;
	vpx_codec_ctx_t _colour;
	vpx_codec_ctx_t _alpha;
	BOOL _colourOpen;
	BOOL _alphaOpen;
	NSUInteger _nextFrame;
	std::vector<std::uint8_t> _opaqueAlpha;
	std::vector<std::uint8_t> _scaled;
}

- (instancetype)initWithPath:(NSString *)path {
	self = [super init];
	if (!self)
		return nil;

	_bytes = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:NULL];
	if (!_bytes.length)
		return nil;

	const std::uint8_t *start = (const std::uint8_t *)_bytes.bytes;
	webm::BufferReader reader(std::vector<std::uint8_t>(start, start + _bytes.length));
	TGWebMFrameCollector collector;
	webm::WebmParser parser;
	webm::Status status = parser.Feed(&collector, &reader);
	if (!status.completed_ok() && collector.frames.empty())
		return nil;
	if (!collector.videoTrack || collector.frames.empty() || !collector.width || !collector.height)
		return nil;

	_frames = std::move(collector.frames);
	_codec = collector.codec;
	_pixelSize = CGSizeMake(collector.width, collector.height);
	_frameCount = _frames.size();

	std::int64_t span = _frames.back().timecodeMs - _frames.front().timecodeMs;
	_frameDuration = _frames.size() > 1 && span > 0
		? (NSTimeInterval)span / 1000.0 / (NSTimeInterval)(_frames.size() - 1)
		: TGWebMDefaultFrameDuration;

	if (!TGWebMOpenDecoder(&_colour, _codec))
		return nil;
	_colourOpen = YES;
	return self;
}

- (void)dealloc {
	if (_colourOpen)
		vpx_codec_destroy(&_colour);
	if (_alphaOpen)
		vpx_codec_destroy(&_alpha);
}

- (void)rewind {
	_nextFrame = 0;
}

- (const std::uint8_t *)alphaPlaneForFrame:(const TGWebMFrame &)frame width:(int)width height:(int)height stride:(int *)stride {
	if (!frame.alpha.empty()) {
		if (!_alphaOpen)
			_alphaOpen = TGWebMOpenDecoder(&_alpha, _codec);
		vpx_image_t *image = _alphaOpen ? TGWebMDecodeFrame(&_alpha, frame.alpha.data(), frame.alpha.size()) : NULL;
		if (image && (int)image->d_w == width && (int)image->d_h == height) {
			*stride = image->stride[VPX_PLANE_Y];
			return image->planes[VPX_PLANE_Y];
		}
	}
	_opaqueAlpha.assign((size_t)width * (size_t)height, 0xFF);
	*stride = width;
	return _opaqueAlpha.data();
}

- (CGImageRef)copyNextFrameFittingSide:(NSUInteger)side {
	if (!_colourOpen || _frames.empty())
		return NULL;
	if (_nextFrame >= _frames.size())
		return NULL;

	const TGWebMFrame &frame = _frames[_nextFrame++];
	if (frame.position + frame.size > _bytes.length)
		return NULL;
	vpx_image_t *colour = TGWebMDecodeFrame(&_colour, (const std::uint8_t *)_bytes.bytes + frame.position, (std::size_t)frame.size);
	if (!colour || colour->fmt != VPX_IMG_FMT_I420)
		return NULL;

	int width = (int)colour->d_w;
	int height = (int)colour->d_h;
	int alphaStride = 0;
	const std::uint8_t *alpha = [self alphaPlaneForFrame:frame width:width height:height stride:&alphaStride];

	NSUInteger limit = MIN(MAX(side, (NSUInteger)1), TGWebMMaximumSide);
	double scale = MIN(1.0, (double)limit / (double)MAX(width, height));
	int outWidth = MAX(2, (int)lround(width * scale));
	int outHeight = MAX(2, (int)lround(height * scale));

	const std::uint8_t *planeY = colour->planes[VPX_PLANE_Y];
	const std::uint8_t *planeU = colour->planes[VPX_PLANE_U];
	const std::uint8_t *planeV = colour->planes[VPX_PLANE_V];
	const std::uint8_t *planeA = alpha;
	int strideY = colour->stride[VPX_PLANE_Y];
	int strideU = colour->stride[VPX_PLANE_U];
	int strideV = colour->stride[VPX_PLANE_V];
	int strideA = alphaStride;

	if (outWidth != width || outHeight != height) {
		int chromaWidth = (outWidth + 1) / 2;
		int chromaHeight = (outHeight + 1) / 2;
		_scaled.resize((size_t)outWidth * (size_t)outHeight * 2 + (size_t)chromaWidth * (size_t)chromaHeight * 2);
		std::uint8_t *scaledY = _scaled.data();
		std::uint8_t *scaledA = scaledY + outWidth * outHeight;
		std::uint8_t *scaledU = scaledA + outWidth * outHeight;
		std::uint8_t *scaledV = scaledU + chromaWidth * chromaHeight;
		libyuv::I420Scale(planeY, strideY, planeU, strideU, planeV, strideV, width, height,
			scaledY, outWidth, scaledU, chromaWidth, scaledV, chromaWidth, outWidth, outHeight, libyuv::kFilterBilinear);
		libyuv::ScalePlane(planeA, strideA, width, height, scaledA, outWidth, outWidth, outHeight, libyuv::kFilterBilinear);
		planeY = scaledY;
		planeU = scaledU;
		planeV = scaledV;
		planeA = scaledA;
		strideY = outWidth;
		strideU = chromaWidth;
		strideV = chromaWidth;
		strideA = outWidth;
	}

	size_t length = (size_t)outWidth * (size_t)outHeight * 4;
	std::uint8_t *pixels = (std::uint8_t *)malloc(length);
	if (!pixels)
		return NULL;
	libyuv::I420AlphaToARGB(planeY, strideY, planeU, strideU, planeV, strideV, planeA, strideA,
		pixels, outWidth * 4, outWidth, outHeight, 1);

	CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixels, length, TGWebMReleaseBytes);
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGImageRef image = CGImageCreate(outWidth, outHeight, 8, 32, (size_t)outWidth * 4, space,
		kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst, provider, NULL, false, kCGRenderingIntentDefault);
	CGColorSpaceRelease(space);
	CGDataProviderRelease(provider);
	return image;
}

@end

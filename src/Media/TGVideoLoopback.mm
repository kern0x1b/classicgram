#import "TGVideoLoopback.h"
#import "TGVideoCapture.h"
#import "TGVideoFrameView.h"

extern "C" unsigned long long TGResidentBytes(void);

#include "libtgvoip/video/TGVP8Codec.h"
#include "libtgvoip/os/darwin/TGCallVideoRenderer.h"
#include "libtgvoip/PrivateDefines.h"
#include <chrono>
#include <vector>
#include <algorithm>

using namespace tgvoip;
using namespace tgvoip::video;

static const unsigned int kNativeWidth = 320;
static const unsigned int kNativeHeight = 240;
static const unsigned int kLoopbackFps = 15;
static const uint32_t kLoopbackBitrate = 220 * 1024;
static const int kLoopbackVP8CpuUsed = 12;

static double TGLoopbackNowMs(){
	return std::chrono::duration<double, std::milli>(
			std::chrono::steady_clock::now().time_since_epoch()).count();
}

static void TGLoopbackResizePlane(const uint8_t *src, int srcStride, unsigned int srcW, unsigned int srcH,
		uint8_t *dst, int dstStride, unsigned int dstW, unsigned int dstH){
	for (unsigned int y = 0; y < dstH; y++){
		unsigned int sy = (y * srcH) / dstH;
		const uint8_t *srow = src + (size_t)sy * srcStride;
		uint8_t *drow = dst + (size_t)y * dstStride;
		for (unsigned int x = 0; x < dstW; x++){
			unsigned int sx = (x * srcW) / dstW;
			drow[x] = srow[sx];
		}
	}
}

@interface TGVideoLoopbackStats : NSObject
@property (nonatomic, assign) unsigned int framesCaptured;
@property (nonatomic, assign) unsigned int framesEncodedStart;
@property (nonatomic, assign) unsigned int framesDroppedStart;
@property (nonatomic, assign) unsigned int framesDecodedTotal;
@property (nonatomic, assign) unsigned int framesFailedTotal;
@property (nonatomic, assign) double encodeMsSum;
@property (nonatomic, assign) double encodeMsMin;
@property (nonatomic, assign) double encodeMsMax;
@property (nonatomic, assign) unsigned int encodeMsCount;
@property (nonatomic, assign) double renderMsSum;
@property (nonatomic, assign) double renderMsMin;
@property (nonatomic, assign) double renderMsMax;
@property (nonatomic, assign) unsigned int renderMsCount;
@property (nonatomic, assign) unsigned long long rssStart;
@property (nonatomic, assign) unsigned long long rssPeak;
@property (nonatomic, assign) double startedAtMs;
@end

@implementation TGVideoLoopbackStats
@end

@implementation TGVideoLoopback

static BOOL gLoopbackRunning = NO;

+ (BOOL)isRunning {
	return gLoopbackRunning;
}

+ (void)runAtWidth:(unsigned int)width height:(unsigned int)height seconds:(NSTimeInterval)seconds {
	if (gLoopbackRunning){
		NSLog(@"VIDEOLOOP already running, ignoring request");
		return;
	}
	if (width < 16 || height < 16 || width > kNativeWidth || height > kNativeHeight){
		NSLog(@"VIDEOLOOP rejecting out-of-range resolution %ux%u", width, height);
		return;
	}
	if (![TGVideoCapture isCameraAvailable]){
		NSLog(@"VIDEOLOOP no camera available on this device, cannot run");
		return;
	}
	gLoopbackRunning = YES;

	TGVideoLoopbackStats *stats = [[TGVideoLoopbackStats alloc] init];
	stats.encodeMsMin = 1e9;
	stats.renderMsMin = 1e9;
	stats.rssStart = TGResidentBytes();
	stats.rssPeak = stats.rssStart;
	stats.startedAtMs = TGLoopbackNowMs();

	__block TGVP8Encoder *encoder = new TGVP8Encoder();
	__block TGCallVideoRenderer *renderer = new TGCallVideoRenderer();
	std::vector<Buffer> emptyCsd;
	renderer->Reset(CODEC_VP8, width, height, emptyCsd);

	TGVideoFrameView *offscreenView = [[TGVideoFrameView alloc] initWithFrame:CGRectMake(0, 0, width, height)];

	renderer->frameCallback = [offscreenView](const uint8_t *bgra, unsigned int w, unsigned int h, int stride){
		[offscreenView presentBGRABytes:bgra width:(int)w height:(int)h bytesPerRow:stride];
	};
	renderer->statsCallback = [stats](double decodeMs, uint32_t decoded, uint32_t failed){
		stats.framesDecodedTotal += decoded;
		stats.framesFailedTotal += failed;
		(void)decodeMs;
	};

	if (!encoder->Open(width, height, kLoopbackFps, kLoopbackBitrate, kLoopbackVP8CpuUsed)){
		NSLog(@"VIDEOLOOP %ux%u: TGVP8Encoder failed to open", width, height);
		delete encoder;
		delete renderer;
		gLoopbackRunning = NO;
		return;
	}
	stats.framesEncodedStart = encoder->framesEncoded;
	stats.framesDroppedStart = encoder->framesDropped;

	__block std::vector<uint8_t> yScratch;
	__block std::vector<uint8_t> uNativeScratch;
	__block std::vector<uint8_t> vNativeScratch;
	__block std::vector<uint8_t> uScratch;
	__block std::vector<uint8_t> vScratch;

	TGVideoCapture *capture = [[TGVideoCapture alloc] init];
	capture.onPixelBuffer = ^(CVPixelBufferRef pixelBuffer, int64_t ptsUs){
		stats.framesCaptured++;

		CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
		const uint8_t *yPlane = (const uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
		int yStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
		const uint8_t *cbcrPlane = (const uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
		int cbcrStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);

		unsigned int nativeChromaW = (kNativeWidth + 1) / 2;
		unsigned int nativeChromaH = (kNativeHeight + 1) / 2;
		if (uNativeScratch.size() != (size_t)nativeChromaW * nativeChromaH){
			uNativeScratch.resize((size_t)nativeChromaW * nativeChromaH);
			vNativeScratch.resize((size_t)nativeChromaW * nativeChromaH);
		}
		for (unsigned int row = 0; row < nativeChromaH; row++){
			const uint8_t *src = cbcrPlane + (size_t)row * cbcrStride;
			uint8_t *dstU = uNativeScratch.data() + (size_t)row * nativeChromaW;
			uint8_t *dstV = vNativeScratch.data() + (size_t)row * nativeChromaW;
			for (unsigned int col = 0; col < nativeChromaW; col++){
				dstU[col] = src[col * 2];
				dstV[col] = src[col * 2 + 1];
			}
		}

		const uint8_t *finalY = yPlane;
		int finalYStride = yStride;
		const uint8_t *finalU = uNativeScratch.data();
		int finalUStride = (int)nativeChromaW;
		const uint8_t *finalV = vNativeScratch.data();
		int finalVStride = (int)nativeChromaW;

		unsigned int chromaW = (width + 1) / 2;
		unsigned int chromaH = (height + 1) / 2;

		if (width != kNativeWidth || height != kNativeHeight){
			if (yScratch.size() != (size_t)width * height)
				yScratch.resize((size_t)width * height);
			TGLoopbackResizePlane(yPlane, yStride, kNativeWidth, kNativeHeight,
					yScratch.data(), (int)width, width, height);
			if (uScratch.size() != (size_t)chromaW * chromaH){
				uScratch.resize((size_t)chromaW * chromaH);
				vScratch.resize((size_t)chromaW * chromaH);
			}
			TGLoopbackResizePlane(uNativeScratch.data(), (int)nativeChromaW, nativeChromaW, nativeChromaH,
					uScratch.data(), (int)chromaW, chromaW, chromaH);
			TGLoopbackResizePlane(vNativeScratch.data(), (int)nativeChromaW, nativeChromaW, nativeChromaH,
					vScratch.data(), (int)chromaW, chromaW, chromaH);
			finalY = yScratch.data();
			finalYStride = (int)width;
			finalU = uScratch.data();
			finalUStride = (int)chromaW;
			finalV = vScratch.data();
			finalVStride = (int)chromaW;
		}

		std::vector<Buffer> packets;
		bool keyframe = false;
		double t0 = TGLoopbackNowMs();
		bool ok = encoder->EncodeI420(finalY, finalYStride, finalU, finalUStride, finalV, finalVStride,
				ptsUs, packets, keyframe);
		double encodeMs = TGLoopbackNowMs() - t0;

		CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
		if (ok){
			stats.encodeMsSum += encodeMs;
			stats.encodeMsCount++;
			stats.encodeMsMin = std::min(stats.encodeMsMin, encodeMs);
			stats.encodeMsMax = std::max(stats.encodeMsMax, encodeMs);
		}

		for (Buffer &packet : packets){
			double r0 = TGLoopbackNowMs();
			renderer->DecodeAndDisplay(std::move(packet), 0);
			double renderMs = TGLoopbackNowMs() - r0;
			stats.renderMsSum += renderMs;
			stats.renderMsCount++;
			stats.renderMsMin = std::min(stats.renderMsMin, renderMs);
			stats.renderMsMax = std::max(stats.renderMsMax, renderMs);
		}

		unsigned long long rss = TGResidentBytes();
		if (rss > stats.rssPeak)
			stats.rssPeak = rss;
	};

	if (![capture start]){
		NSLog(@"VIDEOLOOP %ux%u: camera capture failed to start", width, height);
		delete encoder;
		delete renderer;
		gLoopbackRunning = NO;
		return;
	}

	NSString *cache = [NSSearchPathForDirectoriesInDomains(
			NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString *outputPath = [cache stringByAppendingPathComponent:
			[NSString stringWithFormat:@"videoloop_%ux%u.txt", width, height]];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{
		[capture stop];
		dispatch_async(dispatch_get_main_queue(), ^{
			unsigned int framesEncoded = encoder->framesEncoded - stats.framesEncodedStart;
			unsigned int framesDropped = encoder->framesDropped - stats.framesDroppedStart;
			double elapsed = (TGLoopbackNowMs() - stats.startedAtMs) / 1000.0;
			double measuredFps = elapsed > 0 ? stats.framesCaptured / elapsed : 0;
			double encodeAvg = stats.encodeMsCount ? stats.encodeMsSum / stats.encodeMsCount : 0;
			double renderAvg = stats.renderMsCount ? stats.renderMsSum / stats.renderMsCount : 0;

			NSMutableString *report = [NSMutableString string];
			[report appendFormat:@"resolution=%ux%u\n", width, height];
			[report appendFormat:@"duration_s=%.2f\n", elapsed];
			[report appendFormat:@"frames_captured=%u\n", stats.framesCaptured];
			[report appendFormat:@"measured_fps=%.2f\n", measuredFps];
			[report appendFormat:@"frames_encoded=%u\n", framesEncoded];
			[report appendFormat:@"frames_dropped_encode=%u\n", framesDropped];
			[report appendFormat:@"frames_decoded=%u\n", stats.framesDecodedTotal];
			[report appendFormat:@"frames_failed_decode=%u\n", stats.framesFailedTotal];
			[report appendFormat:@"encode_ms_avg=%.2f\n", encodeAvg];
			[report appendFormat:@"encode_ms_min=%.2f\n", stats.encodeMsCount ? stats.encodeMsMin : 0];
			[report appendFormat:@"encode_ms_max=%.2f\n", stats.encodeMsMax];
			[report appendFormat:@"decode_render_ms_avg=%.2f\n", renderAvg];
			[report appendFormat:@"decode_render_ms_min=%.2f\n", stats.renderMsCount ? stats.renderMsMin : 0];
			[report appendFormat:@"decode_render_ms_max=%.2f\n", stats.renderMsMax];
			[report appendFormat:@"rss_start_mb=%.2f\n", stats.rssStart / 1048576.0];
			[report appendFormat:@"rss_peak_mb=%.2f\n", stats.rssPeak / 1048576.0];
			[report appendFormat:@"rss_end_mb=%.2f\n", TGResidentBytes() / 1048576.0];

			NSError *error = nil;
			[report writeToFile:outputPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
			NSLog(@"VIDEOLOOP %ux%u done, wrote %@ (error=%@)", width, height, outputPath, error);

			delete encoder;
			delete renderer;
			gLoopbackRunning = NO;
		});
	});
}

@end

#import <Foundation/Foundation.h>
#include <string.h>
#include "TGVTDynamic.h"
#include "../../logging.h"
#import "TGLazyFramework.h"

static TGVTFunctionTable gTable;
static bool gLoaded = false;
static bool gAvailable = false;

static void* TGVTSym(NSString* name) {
	return TGFrameworkSymbol(@"VideoToolbox", [name UTF8String]);
}

static CFStringRef TGVTKey(NSString* name) {
	NSString* value = TGFrameworkString(@"VideoToolbox", [name UTF8String]);
	return (__bridge CFStringRef)value;
}

static void TGVTEncoderProbeCallback(void* refCon, void* sourceFrameRefCon, OSStatus status,
									  VTEncodeInfoFlags flags, CMSampleBufferRef buffer) {
	(void)refCon; (void)sourceFrameRefCon; (void)status; (void)flags; (void)buffer;
}

bool TGVTLoad(void) {
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		memset(&gTable, 0, sizeof(gTable));

		gTable.CompressionSessionCreate = (TGVTCompressionSessionCreateFn)
				TGVTSym(@"VTCompressionSessionCreate");
		gTable.CompressionSessionInvalidate = (TGVTCompressionSessionInvalidateFn)
				TGVTSym(@"VTCompressionSessionInvalidate");
		gTable.CompressionSessionEncodeFrame = (TGVTCompressionSessionEncodeFrameFn)
				TGVTSym(@"VTCompressionSessionEncodeFrame");
		gTable.CompressionSessionCompleteFrames = (TGVTCompressionSessionCompleteFramesFn)
				TGVTSym(@"VTCompressionSessionCompleteFrames");
		gTable.SessionSetProperty = (TGVTSessionSetPropertyFn)
				TGVTSym(@"VTSessionSetProperty");
		gTable.DecompressionSessionCreate = (TGVTDecompressionSessionCreateFn)
				TGVTSym(@"VTDecompressionSessionCreate");
		gTable.DecompressionSessionDecodeFrame = (TGVTDecompressionSessionDecodeFrameFn)
				TGVTSym(@"VTDecompressionSessionDecodeFrame");
		gTable.DecompressionSessionInvalidate = (TGVTDecompressionSessionInvalidateFn)
				TGVTSym(@"VTDecompressionSessionInvalidate");
		gTable.DecompressionSessionWaitForAsynchronousFrames = (TGVTDecompressionSessionWaitForAsynchronousFramesFn)
				TGVTSym(@"VTDecompressionSessionWaitForAsynchronousFrames");

		gTable.KeyRealTime = TGVTKey(@"kVTCompressionPropertyKey_RealTime");
		gTable.KeyAllowFrameReordering = TGVTKey(@"kVTCompressionPropertyKey_AllowFrameReordering");
		gTable.KeyAverageBitRate = TGVTKey(@"kVTCompressionPropertyKey_AverageBitRate");
		gTable.KeyDataRateLimits = TGVTKey(@"kVTCompressionPropertyKey_DataRateLimits");
		gTable.KeyMaxKeyFrameIntervalDuration = TGVTKey(@"kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration");
		gTable.KeyForceKeyFrame = TGVTKey(@"kVTEncodeFrameOptionKey_ForceKeyFrame");

		gLoaded = true;

		if (!gTable.CompressionSessionCreate || !gTable.CompressionSessionInvalidate ||
			!gTable.CompressionSessionEncodeFrame || !gTable.SessionSetProperty ||
			!gTable.DecompressionSessionCreate || !gTable.DecompressionSessionDecodeFrame ||
			!gTable.DecompressionSessionInvalidate || !gTable.KeyRealTime){
			LOGW("TGVTDynamic: VideoToolbox symbols missing, hardware H.264 unavailable");
			gAvailable = false;
			return;
		}

		VTCompressionSessionRef session = NULL;
		OSStatus status = gTable.CompressionSessionCreate(NULL, 176, 144, kCMVideoCodecType_H264,
				NULL, NULL, NULL, TGVTEncoderProbeCallback, NULL, &session);
		if (status != noErr || !session){
			LOGW("TGVTDynamic: trial VTCompressionSessionCreate failed: %d", (int)status);
			gAvailable = false;
			return;
		}
		gTable.CompressionSessionInvalidate(session);
		CFRelease(session);
		gAvailable = true;
		LOGI("TGVTDynamic: hardware H.264 probe succeeded, VideoToolbox available");
	});
	return gAvailable;
}

const TGVTFunctionTable* TGVTGetFunctions(void) {
	if (!gLoaded)
		TGVTLoad();
	return gAvailable ? &gTable : NULL;
}

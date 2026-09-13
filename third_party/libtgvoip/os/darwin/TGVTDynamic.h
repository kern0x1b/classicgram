#ifndef LIBTGVOIP_TGVTDYNAMIC_H
#define LIBTGVOIP_TGVTDYNAMIC_H

#include <CoreMedia/CoreMedia.h>
#include <VideoToolbox/VideoToolbox.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef OSStatus (*TGVTCompressionSessionCreateFn)(
		CFAllocatorRef, int32_t, int32_t, CMVideoCodecType,
		CFDictionaryRef, CFDictionaryRef, CFAllocatorRef,
		VTCompressionOutputCallback, void*, VTCompressionSessionRef*);
typedef void (*TGVTCompressionSessionInvalidateFn)(VTCompressionSessionRef);
typedef OSStatus (*TGVTCompressionSessionEncodeFrameFn)(
		VTCompressionSessionRef, CVImageBufferRef, CMTime, CMTime,
		CFDictionaryRef, void*, VTEncodeInfoFlags*);
typedef OSStatus (*TGVTCompressionSessionCompleteFramesFn)(VTCompressionSessionRef, CMTime);
typedef OSStatus (*TGVTSessionSetPropertyFn)(VTSessionRef, CFStringRef, CFTypeRef);

typedef OSStatus (*TGVTDecompressionSessionCreateFn)(
		CFAllocatorRef, CMVideoFormatDescriptionRef, CFDictionaryRef, CFDictionaryRef,
		const VTDecompressionOutputCallbackRecord*, VTDecompressionSessionRef*);
typedef OSStatus (*TGVTDecompressionSessionDecodeFrameFn)(
		VTDecompressionSessionRef, CMSampleBufferRef, VTDecodeFrameFlags,
		void*, VTDecodeInfoFlags*);
typedef void (*TGVTDecompressionSessionInvalidateFn)(VTDecompressionSessionRef);
typedef OSStatus (*TGVTDecompressionSessionWaitForAsynchronousFramesFn)(VTDecompressionSessionRef);

typedef struct TGVTFunctionTable {
	TGVTCompressionSessionCreateFn CompressionSessionCreate;
	TGVTCompressionSessionInvalidateFn CompressionSessionInvalidate;
	TGVTCompressionSessionEncodeFrameFn CompressionSessionEncodeFrame;
	TGVTCompressionSessionCompleteFramesFn CompressionSessionCompleteFrames;
	TGVTSessionSetPropertyFn SessionSetProperty;
	TGVTDecompressionSessionCreateFn DecompressionSessionCreate;
	TGVTDecompressionSessionDecodeFrameFn DecompressionSessionDecodeFrame;
	TGVTDecompressionSessionInvalidateFn DecompressionSessionInvalidate;
	TGVTDecompressionSessionWaitForAsynchronousFramesFn DecompressionSessionWaitForAsynchronousFrames;

	CFStringRef KeyRealTime;
	CFStringRef KeyAllowFrameReordering;
	CFStringRef KeyAverageBitRate;
	CFStringRef KeyDataRateLimits;
	CFStringRef KeyMaxKeyFrameIntervalDuration;
	CFStringRef KeyForceKeyFrame;
} TGVTFunctionTable;

bool TGVTLoad(void);
const TGVTFunctionTable* TGVTGetFunctions(void);

#ifdef __cplusplus
}
#endif

#endif

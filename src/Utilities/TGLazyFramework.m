#import "TGLazyFramework.h"

#import <dlfcn.h>

static void *TGFrameworkHandle(NSString *framework) {
	static NSMutableDictionary *handles = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		handles = [[NSMutableDictionary alloc] init];
	});
	@synchronized(handles) {
		NSNumber *cached = [handles objectForKey:framework];
		if (cached)
			return (void *)(uintptr_t)[cached unsignedLongLongValue];
		NSString *path = [NSString stringWithFormat:
				@"/System/Library/Frameworks/%@.framework/%@", framework, framework];
		void *handle = dlopen([path fileSystemRepresentation], RTLD_LAZY | RTLD_GLOBAL);
		if (!handle)
			NSLog(@"lazy framework %@ did not load: %s", framework, dlerror());
		[handles setObject:@((uintptr_t)handle) forKey:framework];
		return handle;
	}
}

Class TGFrameworkClass(NSString *framework, NSString *className) {
	Class cls = NSClassFromString(className);
	if (cls)
		return cls;
	if (!TGFrameworkHandle(framework))
		return Nil;
	cls = NSClassFromString(className);
	if (!cls)
		NSLog(@"lazy framework %@ has no class %@", framework, className);
	return cls;
}

void *TGFrameworkSymbol(NSString *framework, const char *symbol) {
	void *found = dlsym(RTLD_DEFAULT, symbol);
	if (found)
		return found;
	void *handle = TGFrameworkHandle(framework);
	if (!handle)
		return NULL;
	found = dlsym(handle, symbol);
	if (!found)
		NSLog(@"lazy framework %@ has no symbol %s", framework, symbol);
	return found;
}

NSString *TGFrameworkString(NSString *framework, const char *symbol) {
	NSString *__unsafe_unretained *slot =
		(NSString * __unsafe_unretained *)TGFrameworkSymbol(framework, symbol);
	return slot ? *slot : nil;
}

static NSDictionary *TGLazySymbolIndex(void) {
	return @{
		@"AVFoundation" : @[
			@"AVAssetExportSession", @"AVAssetImageGenerator", @"AVAudioPlayer",
			@"AVAudioRecorder", @"AVAudioSession", @"AVCaptureDevice",
			@"AVCaptureDeviceInput", @"AVCaptureMetadataOutput",
			@"AVCaptureMovieFileOutput", @"AVCaptureSession",
			@"AVCaptureVideoDataOutput", @"AVCaptureVideoPreviewLayer",
			@"AVPlayer", @"AVPlayerLayer", @"AVSampleBufferDisplayLayer",
			@"AVURLAsset",
			@"=AVAssetExportPresetAppleM4A", @"=AVAudioSessionCategoryPlayAndRecord",
			@"=AVAudioSessionCategoryPlayback", @"=AVAudioSessionModeVoiceChat",
			@"=AVCaptureSessionErrorKey",
			@"=AVCaptureSessionInterruptionEndedNotification",
			@"=AVCaptureSessionPreset1280x720", @"=AVCaptureSessionPreset640x480",
			@"=AVCaptureSessionPresetLow", @"=AVCaptureSessionPresetMedium",
			@"=AVCaptureSessionRuntimeErrorNotification",
			@"=AVCaptureSessionWasInterruptedNotification",
			@"=AVErrorRecordingSuccessfullyFinishedKey", @"=AVFileTypeAppleM4A",
			@"=AVFormatIDKey", @"=AVLayerVideoGravityResizeAspect",
			@"=AVLayerVideoGravityResizeAspectFill", @"=AVLinearPCMBitDepthKey",
			@"=AVLinearPCMIsBigEndianKey", @"=AVLinearPCMIsFloatKey",
			@"=AVMediaTypeAudio", @"=AVMediaTypeVideo",
			@"=AVNumberOfChannelsKey",
			@"=AVPlayerItemDidPlayToEndTimeNotification", @"=AVSampleRateKey"
		],
		@"MediaPlayer" : @[
			@"MPMediaPickerController", @"MPMoviePlayerController",
			@"MPMoviePlayerViewController", @"MPNowPlayingInfoCenter",
			@"MPMediaItemArtwork",
			@"=MPMediaItemPropertyArtist", @"=MPMediaItemPropertyArtwork",
			@"=MPMediaItemPropertyAlbumTitle", @"=MPMediaItemPropertyAssetURL",
			@"=MPMediaItemPropertyPlaybackDuration", @"=MPMediaItemPropertyTitle",
			@"=MPMoviePlayerPlaybackDidFinishNotification",
			@"=MPNowPlayingInfoPropertyElapsedPlaybackTime",
			@"=MPNowPlayingInfoPropertyPlaybackRate"
		],
		@"AssetsLibrary" : @[
			@"ALAssetsFilter", @"ALAssetsLibrary",
			@"=ALAssetsGroupPropertyName"
		],
		@"CoreLocation" : @[
			@"CLLocationManager", @"=kCLLocationAccuracyHundredMeters"
		],
		@"AddressBookUI" : @[ @"ABPeoplePickerNavigationController" ],
		@"EventKit" : @[ @"EKEventStore", @"EKEvent", @"EKReminder", @"EKAlarm" ],
		@"EventKitUI" : @[ @"EKEventEditViewController" ],
		@"VideoToolbox" : @[
			@"=VTCompressionSessionCreate", @"=VTCompressionSessionInvalidate",
			@"=VTCompressionSessionEncodeFrame", @"=VTCompressionSessionCompleteFrames",
			@"=VTSessionSetProperty",
			@"=VTDecompressionSessionCreate", @"=VTDecompressionSessionDecodeFrame",
			@"=VTDecompressionSessionInvalidate",
			@"=VTDecompressionSessionWaitForAsynchronousFrames",
			@"=kVTCompressionPropertyKey_RealTime",
			@"=kVTCompressionPropertyKey_AllowFrameReordering",
			@"=kVTCompressionPropertyKey_AverageBitRate",
			@"=kVTCompressionPropertyKey_DataRateLimits",
			@"=kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration",
			@"=kVTEncodeFrameOptionKey_ForceKeyFrame"
		],
	};
}

void TGFrameworkSelfTest(void) {
	NSDictionary *index = TGLazySymbolIndex();
	NSInteger checked = 0, missing = 0;
	for (NSString *framework in index) {
		for (NSString *name in index[framework]) {
			checked++;
			if ([name hasPrefix:@"="]) {
				NSString *symbol = [name substringFromIndex:1];
				if (!TGFrameworkSymbol(framework, [symbol UTF8String]))
					missing++;
			} else if (!TGFrameworkClass(framework, name)) {
				missing++;
			}
		}
	}
	NSLog(@"PERF lazyframeworks checked=%lu missing=%lu",
		(unsigned long)checked, (unsigned long)missing);
}

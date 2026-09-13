#import "TGVideoRecorder.h"
#import "TGLazyFramework.h"
#import <CoreMedia/CoreMedia.h>

NSString *const TGVideoRecorderErrorDomain = @"TGVideoRecorderErrorDomain";

static const NSTimeInterval kVideoRecorderVideoMaxDuration = 600.0;
static const NSTimeInterval kVideoRecorderNoteMaxDuration = 60.0;
static const NSTimeInterval kVideoRecorderMinDuration = 0.4;
static const NSTimeInterval kVideoRecorderTick = 0.1;

static const long long TGVideoRecorderVideoMaxFileSize = 64ll * 1024ll * 1024ll;
static const long long TGVideoRecorderNoteMaxFileSize = 12ll * 1024ll * 1024ll;
static const long long TGVideoRecorderVideoDiskFloor = 40ll * 1024ll * 1024ll;
static const long long TGVideoRecorderNoteDiskFloor = 12ll * 1024ll * 1024ll;

@interface TGVideoRecorder () <AVCaptureFileOutputRecordingDelegate>

@property (nonatomic, assign) TGVideoRecorderMode mode;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;
@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSString *outputPath;
@property (nonatomic, strong) NSDate *startedAt;
@property (nonatomic, assign) NSTimeInterval lastDuration;
@property (nonatomic, assign) AVCaptureDevicePosition cameraPosition;
@property (nonatomic, assign) BOOL ready;
@property (nonatomic, assign) BOOL recording;
@property (nonatomic, assign) BOOL discarding;
@property (nonatomic, assign) BOOL observing;
@property (nonatomic, assign) BOOL sessionWasRunning;
@property (nonatomic, strong) NSError *pendingError;
@property (nonatomic, strong) id sessionRuntimeErrorObserverToken;
@property (nonatomic, strong) id sessionWasInterruptedObserverToken;
@property (nonatomic, strong) id sessionInterruptionEndedObserverToken;
@property (nonatomic, strong) id applicationDidEnterBackgroundObserverToken;
@property (nonatomic, strong) id applicationWillEnterForegroundObserverToken;
@property (nonatomic, assign) NSUInteger teardownGeneration;

@end

@implementation TGVideoRecorder

- (instancetype)initWithMode:(TGVideoRecorderMode)mode {
	self = [super init];
	if (self) {
		_mode = mode;
		_cameraPosition = (mode == TGVideoRecorderModeNote)
			? AVCaptureDevicePositionFront
			: AVCaptureDevicePositionBack;
	}
	return self;
}

- (void)dealloc {
	[self teardown];
}

- (NSTimeInterval)maximumDuration {
	return self.mode == TGVideoRecorderModeNote
		? kVideoRecorderNoteMaxDuration
		: kVideoRecorderVideoMaxDuration;
}

- (long long)maximumFileSize {
	return self.mode == TGVideoRecorderModeNote
		? TGVideoRecorderNoteMaxFileSize
		: TGVideoRecorderVideoMaxFileSize;
}

- (long long)diskFloor {
	return self.mode == TGVideoRecorderModeNote
		? TGVideoRecorderNoteDiskFloor
		: TGVideoRecorderVideoDiskFloor;
}

- (NSTimeInterval)duration {
	if (!self.recording)
		return self.lastDuration;
	AVCaptureMovieFileOutput *output = self.movieOutput;
	if (output) {
		CMTime recorded = output.recordedDuration;
		if (CMTIME_IS_NUMERIC(recorded)) {
			Float64 seconds = CMTimeGetSeconds(recorded);
			if (seconds > 0)
				return seconds;
		}
	}
	if (self.startedAt)
		return -[self.startedAt timeIntervalSinceNow];
	return 0;
}

- (BOOL)canSwitchCamera {
	return [TGAVClass(AVCaptureDevice) devicesWithMediaType:TGAVString(AVMediaTypeVideo)].count > 1;
}

#pragma mark - errors

- (NSError *)errorWithCode:(TGVideoRecorderErrorCode)code {
	return [NSError errorWithDomain:TGVideoRecorderErrorDomain code:code userInfo:nil];
}

- (void)failWithCode:(TGVideoRecorderErrorCode)code {
	NSError *error = [self errorWithCode:code];
	id<TGVideoRecorderDelegate> delegate = self.delegate;
	if ([delegate respondsToSelector:@selector(videoRecorder:didFailWithError:)])
		[delegate videoRecorder:self didFailWithError:error];
}

#pragma mark - disk

- (long long)freeDiskSpace {
	NSDictionary *attrs = [[NSFileManager defaultManager]
		attributesOfFileSystemForPath:NSTemporaryDirectory()
								error:nil];
	NSNumber *free = attrs[NSFileSystemFreeSize];
	return free ? [free longLongValue] : LLONG_MAX;
}

- (NSString *)temporaryPath {
	NSString *name = [NSString stringWithFormat:@"video-%.0f-%u.mp4",
		[[NSDate date] timeIntervalSince1970] * 1000.0, arc4random() % 100000];
	return [NSTemporaryDirectory() stringByAppendingPathComponent:name];
}

#pragma mark - permissions

- (BOOL)cameraAccessAllowedRequestingIfNeeded {
	if (![TGAVClass(AVCaptureDevice) respondsToSelector:@selector(authorizationStatusForMediaType:)])
		return YES;

	AVAuthorizationStatus status =
		[TGAVClass(AVCaptureDevice) authorizationStatusForMediaType:TGAVString(AVMediaTypeVideo)];
	if (status == AVAuthorizationStatusAuthorized)
		return YES;

	if (status == AVAuthorizationStatusNotDetermined) {
		__weak typeof(self) weakSelf = self;
		NSUInteger generation = self.teardownGeneration;
		Class captureDeviceClass = TGAVClass(AVCaptureDevice);
		NSString *videoType = TGAVString(AVMediaTypeVideo);
		[captureDeviceClass requestAccessForMediaType:videoType completionHandler:^(BOOL granted) {
			dispatch_async(dispatch_get_main_queue(), ^{
				TGVideoRecorder *strongSelf = weakSelf;
				if (!strongSelf || strongSelf.teardownGeneration != generation)
					return;
				if (granted)
					[strongSelf prepare];
				else
					[strongSelf failWithCode:TGVideoRecorderErrorCameraAccessDenied];
			});
		}];
		return NO;
	}

	[self failWithCode:TGVideoRecorderErrorCameraAccessDenied];
	return NO;
}

- (void)requestMicrophoneAccess {
	AVAudioSession *audio = [TGAVClass(AVAudioSession) sharedInstance];
	if (![audio respondsToSelector:@selector(requestRecordPermission:)])
		return;
	__weak typeof(self) weakSelf = self;
	NSUInteger generation = self.teardownGeneration;
	[audio requestRecordPermission:^(BOOL granted) {
		if (granted)
			return;
		dispatch_async(dispatch_get_main_queue(), ^{
			TGVideoRecorder *strongSelf = weakSelf;
			if (!strongSelf || strongSelf.teardownGeneration != generation)
				return;
			if (strongSelf.recording)
				[strongSelf cancel];
			[strongSelf failWithCode:TGVideoRecorderErrorMicrophoneAccessDenied];
		});
	}];
}

#pragma mark - setup

- (AVCaptureDevice *)cameraAtPosition:(AVCaptureDevicePosition)position {
	NSArray *devices = [TGAVClass(AVCaptureDevice) devicesWithMediaType:TGAVString(AVMediaTypeVideo)];
	for (AVCaptureDevice *device in devices) {
		if (device.position == position)
			return device;
	}
	return [TGAVClass(AVCaptureDevice) defaultDeviceWithMediaType:TGAVString(AVMediaTypeVideo)];
}

- (NSString *)preferredPresetForSession:(AVCaptureSession *)session {
	NSArray *candidates = (self.mode == TGVideoRecorderModeNote)
		? @[ TGAVString(AVCaptureSessionPreset640x480), TGAVString(AVCaptureSessionPresetMedium), TGAVString(AVCaptureSessionPresetLow) ]
		: @[ TGAVString(AVCaptureSessionPreset1280x720), TGAVString(AVCaptureSessionPreset640x480), TGAVString(AVCaptureSessionPresetMedium) ];
	for (NSString *preset in candidates) {
		if ([session canSetSessionPreset:preset])
			return preset;
	}
	return TGAVString(AVCaptureSessionPresetMedium);
}

- (void)configureDevice:(AVCaptureDevice *)device {
	NSError *error = nil;
	if (![device lockForConfiguration:&error])
		return;
	if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
		device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
	if ([device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
		device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
	if ([device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance])
		device.whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
	if (device.isTorchActive && [device isTorchModeSupported:AVCaptureTorchModeOff])
		device.torchMode = AVCaptureTorchModeOff;
	[device unlockForConfiguration];
}

- (void)applyConnectionSettings {
	AVCaptureConnection *video = [self.movieOutput connectionWithMediaType:TGAVString(AVMediaTypeVideo)];
	if (!video)
		return;
	if (video.isVideoOrientationSupported)
		video.videoOrientation = AVCaptureVideoOrientationPortrait;
	if (video.isVideoMirroringSupported) {
		video.automaticallyAdjustsVideoMirroring = NO;
		video.videoMirrored = (self.cameraPosition == AVCaptureDevicePositionFront);
	}
}

- (void)prepare {
	if (self.session)
		return;

	if (![self cameraAccessAllowedRequestingIfNeeded])
		return;

	AVCaptureDevice *camera = [self cameraAtPosition:self.cameraPosition];
	if (!camera) {
		[self failWithCode:TGVideoRecorderErrorNoCamera];
		return;
	}
	self.cameraPosition = camera.position;

	NSError *error = nil;
	Class deviceInputClass = TGAVClass(AVCaptureDeviceInput);
	AVCaptureDeviceInput *videoInput = [deviceInputClass deviceInputWithDevice:camera error:&error];
	if (!videoInput) {
		NSLog(@"TGVideoRecorder: video input: %@", error);
		[self failWithCode:TGVideoRecorderErrorNoCamera];
		return;
	}

	AVAudioSession *audio = [TGAVClass(AVAudioSession) sharedInstance];
	NSError *audioError = nil;
	[audio setCategory:TGAVString(AVAudioSessionCategoryPlayAndRecord) error:&audioError];
	[audio setActive:YES error:&audioError];

	AVCaptureDevice *microphone = [TGAVClass(AVCaptureDevice) defaultDeviceWithMediaType:TGAVString(AVMediaTypeAudio)];
	AVCaptureDeviceInput *audioInput = microphone
		? [TGAVClass(AVCaptureDeviceInput) deviceInputWithDevice:microphone error:nil]
		: nil;

	AVCaptureSession *session = [[TGAVClass(AVCaptureSession) alloc] init];
	[session beginConfiguration];

	if ([session canAddInput:videoInput])
		[session addInput:videoInput];
	else {
		[session commitConfiguration];
		[self failWithCode:TGVideoRecorderErrorNoCamera];
		return;
	}
	if (audioInput && [session canAddInput:audioInput])
		[session addInput:audioInput];
	else
		audioInput = nil;

	AVCaptureMovieFileOutput *output = [[TGAVClass(AVCaptureMovieFileOutput) alloc] init];
	output.maxRecordedDuration = CMTimeMakeWithSeconds(self.maximumDuration, 30);
	output.maxRecordedFileSize = [self maximumFileSize];
	output.minFreeDiskSpaceLimit = [self diskFloor] / 2;
	if ([session canAddOutput:output])
		[session addOutput:output];
	else {
		[session commitConfiguration];
		[self failWithCode:TGVideoRecorderErrorRecordingFailed];
		return;
	}
	session.sessionPreset = [self preferredPresetForSession:session];
	[session commitConfiguration];

	self.session = session;
	self.videoInput = videoInput;
	self.audioInput = audioInput;
	self.movieOutput = output;

	[self configureDevice:camera];
	[self applyConnectionSettings];

	AVCaptureVideoPreviewLayer *preview = [TGAVClass(AVCaptureVideoPreviewLayer) layerWithSession:session];
	preview.videoGravity = TGAVString(AVLayerVideoGravityResizeAspectFill);
	self.previewLayer = preview;

	[self startObserving];
	[session startRunning];
	self.ready = YES;

	[self requestMicrophoneAccess];

	id<TGVideoRecorderDelegate> delegate = self.delegate;
	if ([delegate respondsToSelector:@selector(videoRecorderDidBecomeReady:)])
		[delegate videoRecorderDidBecomeReady:self];
}

- (void)switchCamera {
	if (!self.session || self.recording || !self.canSwitchCamera)
		return;

	AVCaptureDevicePosition next = (self.cameraPosition == AVCaptureDevicePositionBack)
		? AVCaptureDevicePositionFront
		: AVCaptureDevicePositionBack;
	AVCaptureDevice *camera = [self cameraAtPosition:next];
	if (!camera || camera.position == self.cameraPosition)
		return;

	AVCaptureDeviceInput *input = [TGAVClass(AVCaptureDeviceInput) deviceInputWithDevice:camera error:nil];
	if (!input)
		return;

	[self.session beginConfiguration];
	if (self.videoInput)
		[self.session removeInput:self.videoInput];
	if ([self.session canAddInput:input]) {
		[self.session addInput:input];
		self.videoInput = input;
		self.cameraPosition = camera.position;
	} else if (self.videoInput) {
		[self.session addInput:self.videoInput];
	}
	self.session.sessionPreset = [self preferredPresetForSession:self.session];
	[self.session commitConfiguration];

	[self configureDevice:camera];
	[self applyConnectionSettings];
}

#pragma mark - recording

- (void)startRecording {
	if (self.recording)
		return;
	if (!self.session) {
		[self prepare];
		if (!self.session)
			return;
	}
	if (!self.session.isRunning)
		[self.session startRunning];

	if ([self freeDiskSpace] < [self diskFloor]) {
		[self failWithCode:TGVideoRecorderErrorNotEnoughDiskSpace];
		return;
	}

	[self applyConnectionSettings];

	NSString *path = [self temporaryPath];
	[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
	self.outputPath = path;
	self.discarding = NO;
	self.pendingError = nil;
	self.lastDuration = 0;
	self.startedAt = [NSDate date];
	self.recording = YES;

	[self.movieOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:path]
								  recordingDelegate:self];

	[self startTimer];

	id<TGVideoRecorderDelegate> delegate = self.delegate;
	if ([delegate respondsToSelector:@selector(videoRecorderDidStartRecording:)])
		[delegate videoRecorderDidStartRecording:self];
}

- (void)stopRecording {
	if (!self.recording)
		return;
	self.lastDuration = self.duration;
	[self stopTimer];
	if (self.movieOutput.isRecording)
		[self.movieOutput stopRecording];
	else
		self.recording = NO;
}

- (void)cancel {
	if (!self.recording) {
		[self discardOutputFile];
		return;
	}
	self.discarding = YES;
	[self stopRecording];
}

- (void)discardOutputFile {
	if (self.outputPath)
		[[NSFileManager defaultManager] removeItemAtPath:self.outputPath error:nil];
	self.outputPath = nil;
	self.lastDuration = 0;
}

#pragma mark - timer

- (void)startTimer {
	[self stopTimer];
	self.timer = [NSTimer
		scheduledTimerWithTimeInterval:kVideoRecorderTick
								target:self
							  selector:@selector(tick)
							  userInfo:nil
							   repeats:YES];
}

- (void)stopTimer {
	[self.timer invalidate];
	self.timer = nil;
}

- (void)tick {
	if (!self.recording) {
		[self stopTimer];
		return;
	}

	NSTimeInterval seconds = self.duration;
	NSTimeInterval maximum = self.maximumDuration;
	float progress = maximum > 0 ? (float)(seconds / maximum) : 0.0f;
	if (progress > 1.0f)
		progress = 1.0f;

	id<TGVideoRecorderDelegate> delegate = self.delegate;
	if ([delegate respondsToSelector:@selector(videoRecorder:didUpdateDuration:progress:)])
		[delegate videoRecorder:self didUpdateDuration:seconds progress:progress];

	if ([self freeDiskSpace] < [self diskFloor] / 2) {
		self.pendingError = [self errorWithCode:TGVideoRecorderErrorNotEnoughDiskSpace];
		[self stopRecording];
		return;
	}

	if (seconds >= maximum)
		[self stopRecording];
}

#pragma mark - notifications

- (void)startObserving {
	if (self.observing)
		return;
	self.observing = YES;
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	__weak typeof(self) weakSelf = self;
	self.sessionRuntimeErrorObserverToken = [center
		addObserverForName:TGAVString(AVCaptureSessionRuntimeErrorNotification)
					object:self.session
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf sessionRuntimeError:note];
				}];
	self.sessionWasInterruptedObserverToken = [center
		addObserverForName:TGAVString(AVCaptureSessionWasInterruptedNotification)
					object:self.session
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf sessionWasInterrupted:note];
				}];
	self.sessionInterruptionEndedObserverToken = [center
		addObserverForName:TGAVString(AVCaptureSessionInterruptionEndedNotification)
					object:self.session
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf sessionInterruptionEnded:note];
				}];
	self.applicationDidEnterBackgroundObserverToken = [center
		addObserverForName:UIApplicationDidEnterBackgroundNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf applicationDidEnterBackground:note];
				}];
	self.applicationWillEnterForegroundObserverToken = [center
		addObserverForName:UIApplicationWillEnterForegroundNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf applicationWillEnterForeground:note];
				}];
}

- (void)stopObserving {
	if (!self.observing)
		return;
	self.observing = NO;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.sessionRuntimeErrorObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.sessionRuntimeErrorObserverToken];
	if (self.sessionWasInterruptedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.sessionWasInterruptedObserverToken];
	if (self.sessionInterruptionEndedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.sessionInterruptionEndedObserverToken];
	if (self.applicationDidEnterBackgroundObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.applicationDidEnterBackgroundObserverToken];
	if (self.applicationWillEnterForegroundObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.applicationWillEnterForegroundObserverToken];
}

- (void)sessionRuntimeError:(NSNotification *)notification {
	NSError *error = notification.userInfo[TGAVString(AVCaptureSessionErrorKey)];
	NSLog(@"TGVideoRecorder: runtime error %@", error);
	if (self.recording) {
		self.pendingError = [self errorWithCode:TGVideoRecorderErrorRecordingFailed];
		[self stopRecording];
	}
}

- (void)sessionWasInterrupted:(NSNotification *)notification {
	if (self.recording) {
		self.pendingError = [self errorWithCode:TGVideoRecorderErrorInterrupted];
		[self stopRecording];
	}
}

- (void)sessionInterruptionEnded:(NSNotification *)notification {
	if (self.session && !self.session.isRunning && [UIApplication sharedApplication].applicationState != UIApplicationStateBackground)
		[self.session startRunning];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
	self.sessionWasRunning = self.session.isRunning;
	if (self.recording) {
		self.pendingError = [self errorWithCode:TGVideoRecorderErrorEnteredBackground];
		[self stopRecording];
	}
	[self stopTimer];
	if (self.session.isRunning)
		[self.session stopRunning];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
	if (self.session && self.sessionWasRunning && !self.session.isRunning)
		[self.session startRunning];
}

#pragma mark - AVCaptureFileOutputRecordingDelegate

- (void)captureOutput:(AVCaptureFileOutput *)output
	didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
						fromConnections:(NSArray *)connections
								  error:(NSError *)error {
	if (![NSThread isMainThread]) {
		__weak typeof(self) weakSelf = self;
		dispatch_async(dispatch_get_main_queue(), ^{
			TGVideoRecorder *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[strongSelf captureOutput:output
				didFinishRecordingToOutputFileAtURL:outputFileURL
									fromConnections:connections
											  error:error];
		});
		return;
	}

	self.recording = NO;
	[self stopTimer];

	BOOL usable = (error == nil);
	if (error) {
		NSNumber *finished = error.userInfo[TGAVString(AVErrorRecordingSuccessfullyFinishedKey)];
		usable = finished ? [finished boolValue] : NO;
		if (!usable)
			NSLog(@"TGVideoRecorder: recording error %@", error);
	}

	NSString *path = outputFileURL.path ?: self.outputPath;
	self.outputPath = path;

	if (self.discarding) {
		self.discarding = NO;
		self.pendingError = nil;
		[self discardOutputFile];
		return;
	}

	NSError *pending = self.pendingError;
	self.pendingError = nil;

	if (!usable || pending) {
		[self discardOutputFile];
		TGVideoRecorderErrorCode code = pending
			? (TGVideoRecorderErrorCode)pending.code
			: TGVideoRecorderErrorRecordingFailed;
		[self failWithCode:code];
		return;
	}

	[self deliverFileAtPath:path];
}

- (void)deliverFileAtPath:(NSString *)path {
	if (!path) {
		[self failWithCode:TGVideoRecorderErrorRecordingFailed];
		return;
	}

	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSTimeInterval seconds = 0;
		CGSize dimensions = CGSizeZero;

		@autoreleasepool {
			Class assetClass = TGAVClass(AVURLAsset);
			NSURL *url = [NSURL fileURLWithPath:path];
			AVURLAsset *asset = [assetClass URLAssetWithURL:url options:nil];
			CMTime assetDuration = asset.duration;
			if (CMTIME_IS_NUMERIC(assetDuration))
				seconds = CMTimeGetSeconds(assetDuration);

			NSArray *tracks = [asset tracksWithMediaType:TGAVString(AVMediaTypeVideo)];
			if (tracks.count > 0) {
				AVAssetTrack *track = tracks[0];
				CGSize natural = CGSizeApplyAffineTransform(track.naturalSize,
					track.preferredTransform);
				dimensions = CGSizeMake(fabs(natural.width), fabs(natural.height));
			}
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			TGVideoRecorder *strongSelf = weakSelf;
			if (!strongSelf)
				return;

			if (seconds < kVideoRecorderMinDuration) {
				[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
				strongSelf.outputPath = nil;
				strongSelf.lastDuration = 0;
				[strongSelf failWithCode:TGVideoRecorderErrorTooShort];
				return;
			}

			CGSize reported = dimensions;
			if (strongSelf.mode == TGVideoRecorderModeNote) {
				CGFloat side = MIN(dimensions.width, dimensions.height);
				if (side > 0)
					reported = CGSizeMake(side, side);
			}

			strongSelf.lastDuration = seconds;
			strongSelf.outputPath = nil;

			id<TGVideoRecorderDelegate> delegate = strongSelf.delegate;
			if ([delegate respondsToSelector:
						@selector(videoRecorder:didFinishRecordingToPath:duration:dimensions:)])
				[delegate videoRecorder:strongSelf
					didFinishRecordingToPath:path
									duration:seconds
								  dimensions:reported];
		});
	});
}

#pragma mark - teardown

- (void)teardown {
	self.teardownGeneration++;
	[self stopTimer];
	[self stopObserving];

	if (self.movieOutput.isRecording) {
		self.discarding = YES;
		[self.movieOutput stopRecording];
	}
	self.recording = NO;
	self.ready = NO;

	AVCaptureSession *session = self.session;
	if (session.isRunning)
		[session stopRunning];
	if (session) {
		[session beginConfiguration];
		for (AVCaptureInput *input in [session.inputs copy])
			[session removeInput:input];
		for (AVCaptureOutput *output in [session.outputs copy])
			[session removeOutput:output];
		[session commitConfiguration];
	}

	[self.previewLayer removeFromSuperlayer];
	self.previewLayer = nil;
	self.movieOutput = nil;
	self.videoInput = nil;
	self.audioInput = nil;
	self.session = nil;
	self.startedAt = nil;

	AVAudioSession *audio = [TGAVClass(AVAudioSession) sharedInstance];
	NSError *audioError = nil;
	[audio setCategory:TGAVString(AVAudioSessionCategoryPlayback) error:&audioError];
	[audio setActive:YES error:&audioError];
}

@end

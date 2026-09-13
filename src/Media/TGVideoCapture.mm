#import "TGVideoCapture.h"
#import "TGLazyFramework.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

static const int kVideoCaptureWidth = 320;
static const int kVideoCaptureHeight = 240;
static const NSTimeInterval kVideoCaptureMinFrameInterval = 1.0 / 15.0;

@interface TGVideoCapture () <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *dataOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, assign) AVCaptureDevicePosition cameraPosition;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) BOOL paused;
@property (nonatomic, strong) dispatch_queue_t sampleQueue;
@property (nonatomic, assign) CFAbsoluteTime lastDeliveredFrameTime;
@end

@implementation TGVideoCapture

+ (BOOL)isCameraAvailable {
	return [TGAVClass(AVCaptureDevice) defaultDeviceWithMediaType:TGAVString(AVMediaTypeVideo)] != nil;
}

- (instancetype)init {
	if ((self = [super init])){
		_cameraPosition = AVCaptureDevicePositionFront;
		_sampleQueue = dispatch_queue_create("org.telegram.videocall.capture", DISPATCH_QUEUE_SERIAL);
	}
	return self;
}

- (BOOL)isFrontFacing {
	return self.cameraPosition == AVCaptureDevicePositionFront;
}

- (BOOL)isRunning {
	return self.running;
}

- (AVCaptureDevice *)cameraAtPosition:(AVCaptureDevicePosition)position {
	NSArray *devices = [TGAVClass(AVCaptureDevice) devicesWithMediaType:TGAVString(AVMediaTypeVideo)];
	for (AVCaptureDevice *device in devices){
		if (device.position == position)
			return device;
	}
	return [TGAVClass(AVCaptureDevice) defaultDeviceWithMediaType:TGAVString(AVMediaTypeVideo)];
}

- (BOOL)canSwitchCamera {
	return [TGAVClass(AVCaptureDevice) devicesWithMediaType:TGAVString(AVMediaTypeVideo)].count > 1;
}

- (NSString *)preferredPresetForSession:(AVCaptureSession *)session {
	NSArray *candidates = @[TGAVString(AVCaptureSessionPreset640x480),
			TGAVString(AVCaptureSessionPresetMedium), TGAVString(AVCaptureSessionPresetLow)];
	for (NSString *preset in candidates){
		if ([session canSetSessionPreset:preset])
			return preset;
	}
	return TGAVString(AVCaptureSessionPresetLow);
}

- (void)applyConnectionSettings {
	AVCaptureConnection *connection = [self.dataOutput connectionWithMediaType:TGAVString(AVMediaTypeVideo)];
	if (!connection)
		return;
	if (connection.isVideoOrientationSupported)
		connection.videoOrientation = AVCaptureVideoOrientationPortrait;
	if (connection.isVideoMirroringSupported){
		connection.automaticallyAdjustsVideoMirroring = NO;
		connection.videoMirrored = (self.cameraPosition == AVCaptureDevicePositionFront);
	}
}

- (BOOL)start {
	if (self.session)
		return YES;
	if (![TGVideoCapture isCameraAvailable])
		return NO;

	AVCaptureDevice *camera = [self cameraAtPosition:self.cameraPosition];
	if (!camera)
		return NO;
	self.cameraPosition = camera.position;

	NSError *error = nil;
	AVCaptureDeviceInput *input = [TGAVClass(AVCaptureDeviceInput) deviceInputWithDevice:camera error:&error];
	if (!input){
		NSLog(@"TGVideoCapture: device input failed: %@", error);
		return NO;
	}

	AVCaptureSession *session = [[TGAVClass(AVCaptureSession) alloc] init];
	[session beginConfiguration];

	if ([session canAddInput:input])
		[session addInput:input];
	else {
		[session commitConfiguration];
		return NO;
	}

	AVCaptureVideoDataOutput *output = [[TGAVClass(AVCaptureVideoDataOutput) alloc] init];
	output.alwaysDiscardsLateVideoFrames = YES;
	output.videoSettings = @{
		(NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
		(NSString *)kCVPixelBufferWidthKey : @(kVideoCaptureWidth),
		(NSString *)kCVPixelBufferHeightKey : @(kVideoCaptureHeight),
	};
	[output setSampleBufferDelegate:self queue:self.sampleQueue];
	if ([session canAddOutput:output])
		[session addOutput:output];
	else {
		[session commitConfiguration];
		return NO;
	}

	session.sessionPreset = [self preferredPresetForSession:session];
	[session commitConfiguration];

	self.session = session;
	self.videoInput = input;
	self.dataOutput = output;
	[self applyConnectionSettings];

	AVCaptureVideoPreviewLayer *preview = [TGAVClass(AVCaptureVideoPreviewLayer) layerWithSession:session];
	preview.videoGravity = TGAVString(AVLayerVideoGravityResizeAspectFill);
	self.previewLayer = preview;

	self.running = YES;
	self.paused = NO;
	[session startRunning];
	return YES;
}

- (void)stop {
	if (!self.session)
		return;
	[self.session stopRunning];
	self.session = nil;
	self.videoInput = nil;
	self.dataOutput = nil;
	self.previewLayer = nil;
	self.running = NO;
}

- (void)setPaused:(BOOL)paused {
	_paused = paused;
}

- (void)switchCamera {
	if (!self.session || !self.canSwitchCamera)
		return;
	AVCaptureDevicePosition next = (self.cameraPosition == AVCaptureDevicePositionBack)
			? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
	AVCaptureDevice *camera = [self cameraAtPosition:next];
	if (!camera || camera.position == self.cameraPosition)
		return;

	AVCaptureDeviceInput *input = [TGAVClass(AVCaptureDeviceInput) deviceInputWithDevice:camera error:nil];
	if (!input)
		return;

	[self.session beginConfiguration];
	if (self.videoInput)
		[self.session removeInput:self.videoInput];
	if ([self.session canAddInput:input]){
		[self.session addInput:input];
		self.videoInput = input;
		self.cameraPosition = camera.position;
	} else if (self.videoInput){
		[self.session addInput:self.videoInput];
	}
	[self.session commitConfiguration];
	[self applyConnectionSettings];
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
		fromConnection:(AVCaptureConnection *)connection {
	if (self.paused || !self.onPixelBuffer)
		return;
	CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
	if (now - self.lastDeliveredFrameTime < kVideoCaptureMinFrameInterval)
		return;
	self.lastDeliveredFrameTime = now;
	CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	if (!pixelBuffer)
		return;
	CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
	int64_t ptsUs = CMTIME_IS_VALID(pts) ? (int64_t)(CMTimeGetSeconds(pts) * 1000000.0)
			: (int64_t)(now * 1000000.0);
	self.onPixelBuffer(pixelBuffer, ptsUs);
}

@end

#import "TGQRViewController.h"
#import "TGLocalization.h"
#import "TGLazyFramework.h"
#import "TGChatViewController.h"
#import "TGSettingsService.h"
#import "TGTheme.h"
#import "TGWebViewController.h"
#import "quirc/quirc.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>

static const NSTimeInterval kQRDecodeInterval = 0.2;
static const int kQRDecodeLongestSide = 640;
static const CGFloat kQRWindowSlack = 0.12f;

static NSString *TGQRMetadataObjectTypeQRCode(void) {
	static NSString *type = nil;
	static BOOL resolved = NO;

	if (!resolved) {
		type = TGAVString(AVMetadataObjectTypeQRCode);
		resolved = YES;
	}
	return type;
}

static Class TGQRMetadataOutputClass(void) {
	if (!TGQRMetadataObjectTypeQRCode())
		return Nil;
	return TGAVClass(AVCaptureMetadataOutput);
}

@interface TGQRViewController () <AVCaptureMetadataOutputObjectsDelegate,
	AVCaptureVideoDataOutputSampleBufferDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *preview;
@property (nonatomic, strong) id output;
@property (nonatomic, strong) AVCaptureVideoDataOutput *frames;
@property (nonatomic, strong) dispatch_queue_t decodeQueue;
@property (nonatomic, assign) struct quirc *decoder;
@property (nonatomic, assign) int decoderWidth;
@property (nonatomic, assign) int decoderHeight;
@property (nonatomic, assign) NSTimeInterval lastDecode;
@property (atomic, assign) CGRect scanFraction;
@property (atomic, assign) BOOL viewIsPortrait;
@property (atomic, assign) BOOL scanning;
@property (nonatomic, strong) AVCaptureDevice *camera;
@property (nonatomic, strong) UILabel *hint;
@property (nonatomic, strong) UIButton *torch;
@property (nonatomic, strong) UIView *wash;
@property (nonatomic, strong) UIView *outline;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UILabel *failureLabel;
@property (nonatomic, strong) NSString *failure;
@property (nonatomic, strong) NSString *pendingLink;
@property (nonatomic, assign) CGRect window;
@property (nonatomic, assign) BOOL handled;
@end

@implementation TGQRViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	self.title = TGL(@"AuthSessions.AddDevice.ScanTitle", @"Scan QR Code");
	self.view.backgroundColor = [UIColor colorWithRed:0x22 / 255.0f green:0x22 / 255.0f
												 blue:0x22 / 255.0f
												alpha:1.0f];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	[self buildFrame];
	[self startCamera];
	if (self.failure.length)
		[self showFailure:self.failure];
}

- (void)startCamera {
	if ([TGAVClass(AVCaptureDevice) respondsToSelector:@selector(authorizationStatusForMediaType:)]) {
		AVAuthorizationStatus status =
			[TGAVClass(AVCaptureDevice) authorizationStatusForMediaType:TGAVString(AVMediaTypeVideo)];
		if (status == AVAuthorizationStatusDenied || status == AVAuthorizationStatusRestricted) {
			self.failure = TGL(@"QR.CameraAccessDenied",
								@"Telegram does not have access to the camera. You can allow it in Settings > Privacy > Camera."
								 "in Settings > Privacy > Camera.");
			return;
		}
		if (status == AVAuthorizationStatusNotDetermined) {
			__weak typeof(self) weakSelf = self;
			Class captureDeviceClass = TGAVClass(AVCaptureDevice);
			[captureDeviceClass
				requestAccessForMediaType:TGAVString(AVMediaTypeVideo)
						completionHandler:^(BOOL granted) {
							dispatch_async(dispatch_get_main_queue(), ^{
								TGQRViewController *strongSelf = weakSelf;
								if (!strongSelf || !strongSelf.isViewLoaded)
									return;
								if (granted) {
									[strongSelf startCamera];
									[strongSelf applyScanWindow];
								} else {
									[strongSelf showFailure:TGL(@"QR.CameraAccessDenied",
														@"Telegram does not have access to the camera. You can allow it in Settings > Privacy > Camera."
														 "camera. You can allow it in Settings > "
														 "Privacy > Camera.")];
								}
							});
						}];
			return;
		}
	}

	AVCaptureDevice *camera = [TGAVClass(AVCaptureDevice) defaultDeviceWithMediaType:TGAVString(AVMediaTypeVideo)];
	NSError *error = nil;
	AVCaptureDeviceInput *input = camera
		? [TGAVClass(AVCaptureDeviceInput) deviceInputWithDevice:camera error:&error]
		: nil;
	if (!input) {
		self.failure = TGL(@"QR.NoCameraToScanWith", @"This device has no camera to scan with.");
		return;
	}
	self.camera = camera;

	self.session = [[TGAVClass(AVCaptureSession) alloc] init];
	[self.session addInput:input];

	if (![self attachMetadataReader] && ![self attachFrameReader]) {
		self.failure = TGL(@"QR.CannotRecogniseQRCodes", @"This device cannot recognise QR codes.");
		self.session = nil;
		return;
	}

	self.preview = [TGAVClass(AVCaptureVideoPreviewLayer) layerWithSession:self.session];
	self.preview.videoGravity = TGAVString(AVLayerVideoGravityResizeAspectFill);
	self.preview.frame = self.view.bounds;
	[self.view.layer insertSublayer:self.preview atIndex:0];

	self.failure = nil;
	[self hideFailure];
	[self.session startRunning];
	[self applyScanWindow];
	[self updateTorchButton];
}

- (BOOL)attachMetadataReader {
	Class outputClass = TGQRMetadataOutputClass();
	NSString *type = TGQRMetadataObjectTypeQRCode();
	id codes;

	if (!outputClass || !type)
		return NO;
	codes = [[outputClass alloc] init];
	if (![self.session canAddOutput:codes])
		return NO;
	[self.session addOutput:codes];
	if (![[codes availableMetadataObjectTypes] containsObject:type]) {
		[self.session removeOutput:codes];
		return NO;
	}
	[codes setMetadataObjectTypes:@[ type ]];
	[codes setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
	self.output = codes;
	return YES;
}

- (BOOL)attachFrameReader {
	AVCaptureVideoDataOutput *frames = [[TGAVClass(AVCaptureVideoDataOutput) alloc] init];

	if ([self.session canSetSessionPreset:TGAVString(AVCaptureSessionPreset640x480)])
		self.session.sessionPreset = TGAVString(AVCaptureSessionPreset640x480);
	if (![self.session canAddOutput:frames])
		return NO;

	frames.alwaysDiscardsLateVideoFrames = YES;
	[self.session addOutput:frames];

	NSArray *offered = frames.availableVideoCVPixelFormatTypes;
	NSNumber *format = nil;
	NSNumber *wanted[3] = {
		@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
		@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
		@(kCVPixelFormatType_32BGRA)};
	for (NSInteger i = 0; i < 3 && !format; i++) {
		if (!offered.count || [offered containsObject:wanted[i]])
			format = wanted[i];
	}
	if (!format) {
		[self.session removeOutput:frames];
		return NO;
	}
	frames.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : format};

	self.decodeQueue = dispatch_queue_create("tg.qr.decode", NULL);
	[frames setSampleBufferDelegate:self queue:self.decodeQueue];
	self.frames = frames;
	self.scanning = YES;
	return YES;
}

- (void)applyScanWindow {
	if (!self.preview || CGRectIsEmpty(self.window))
		return;

	if (self.frames)
		[self applyFrameScanWindow];

	if (![self.preview respondsToSelector:@selector(metadataOutputRectOfInterestForRect:)])
		return;
	CGRect interest = [self.preview metadataOutputRectOfInterestForRect:self.window];
	if (interest.size.width > 0 && interest.size.height > 0 && [self.output respondsToSelector:@selector(setRectOfInterest:)])
		[self.output setRectOfInterest:interest];
}

- (void)applyFrameScanWindow {
	CGRect bounds = self.view.bounds;
	BOOL portrait = bounds.size.height >= bounds.size.width;
	CGFloat contentWidth = portrait ? 3.0f : 4.0f;
	CGFloat contentHeight = portrait ? 4.0f : 3.0f;

	if (bounds.size.width <= 0 || bounds.size.height <= 0)
		return;

	CGFloat scale = MAX(bounds.size.width / contentWidth,
		bounds.size.height / contentHeight);
	CGFloat shownWidth = contentWidth * scale;
	CGFloat shownHeight = contentHeight * scale;
	CGFloat left = (bounds.size.width - shownWidth) / 2;
	CGFloat top = (bounds.size.height - shownHeight) / 2;

	CGFloat x0 = (CGRectGetMinX(self.window) - left) / shownWidth;
	CGFloat x1 = (CGRectGetMaxX(self.window) - left) / shownWidth;
	CGFloat y0 = (CGRectGetMinY(self.window) - top) / shownHeight;
	CGFloat y1 = (CGRectGetMaxY(self.window) - top) / shownHeight;

	CGFloat slackX = (x1 - x0) * kQRWindowSlack;
	CGFloat slackY = (y1 - y0) * kQRWindowSlack;
	x0 = MAX(0.0f, x0 - slackX);
	x1 = MIN(1.0f, x1 + slackX);
	y0 = MAX(0.0f, y0 - slackY);
	y1 = MIN(1.0f, y1 + slackY);
	if (x1 - x0 < 0.1f || y1 - y0 < 0.1f)
		return;

	CGFloat mirroredX0 = MIN(x0, 1.0f - x1);
	CGFloat mirroredX1 = MAX(x1, 1.0f - x0);
	CGFloat mirroredY0 = MIN(y0, 1.0f - y1);
	CGFloat mirroredY1 = MAX(y1, 1.0f - y0);

	self.viewIsPortrait = portrait;
	self.scanFraction = CGRectMake(mirroredX0, mirroredY0,
		mirroredX1 - mirroredX0,
		mirroredY1 - mirroredY0);
}

- (NSString *)defaultHintText {
	if (self.deviceLinkSubject)
		return TGL(@"AuthSessions.AddDevice.ScanInstallInfo", @"Go to getdesktop.telegram.org or web.telegram.org to get the QR code");
	return @"";
}

- (BOOL)torchAvailable {
	return self.camera && [self.camera respondsToSelector:@selector(hasTorch)] && self.camera.hasTorch && [self.camera isTorchModeSupported:AVCaptureTorchModeOn];
}

- (void)updateTorchButton {
	if (!self.torch)
		return;
	self.torch.hidden = ![self torchAvailable] || self.failureLabel != nil;
	BOOL on = self.camera.torchMode == AVCaptureTorchModeOn;
	[self.torch setTitle:on ? TGL(@"QR.LightOff", @"Light Off") : TGL(@"QR.LightOn", @"Light On") forState:UIControlStateNormal];
}

- (void)toggleTorch {
	if (![self torchAvailable])
		return;
	NSError *error = nil;
	if (![self.camera lockForConfiguration:&error])
		return;
	self.camera.torchMode = self.camera.torchMode == AVCaptureTorchModeOn
		? AVCaptureTorchModeOff
		: AVCaptureTorchModeOn;
	[self.camera unlockForConfiguration];
	[self updateTorchButton];
}

- (void)buildFrame {
	CGRect b = self.view.bounds;
	CGFloat panelHeight = b.size.height > 440.0f ? 136.0f : 92.0f;
	CGRect area = CGRectMake(0, 0, b.size.width, b.size.height - panelHeight);
	CGFloat side = (int)(MIN(area.size.width, area.size.height) * 0.66f);
	CGRect window = CGRectMake((int)((area.size.width - side) / 2),
		(int)((area.size.height - side) / 2), side, side);

	self.wash = [[UIView alloc] initWithFrame:b];
	self.wash.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5f];
	self.wash.userInteractionEnabled = NO;

	CAShapeLayer *mask = [CAShapeLayer layer];
	UIBezierPath *path = [UIBezierPath bezierPathWithRect:b];
	[path appendPath:[UIBezierPath bezierPathWithRoundedRect:window cornerRadius:8]];
	mask.path = path.CGPath;
	mask.fillRule = kCAFillRuleEvenOdd;
	self.wash.layer.mask = mask;
	[self.view addSubview:self.wash];

	self.outline = [[UIView alloc] initWithFrame:window];
	self.outline.layer.borderColor = [UIColor whiteColor].CGColor;
	self.outline.layer.borderWidth = 2;
	self.outline.layer.cornerRadius = 8;
	self.outline.userInteractionEnabled = NO;
	[self.view addSubview:self.outline];

	CGRect panelFrame = CGRectMake(0, b.size.height - panelHeight, b.size.width, panelHeight);
	self.panel = [[UIView alloc] initWithFrame:panelFrame];
	self.panel.backgroundColor = [UIColor clearColor];
	UIImageView *panelBackground = [[UIImageView alloc] initWithFrame:self.panel.bounds];
	panelBackground.image = [[UIImage imageNamed:@"CameraStripeBottom.png"]
		stretchableImageWithLeftCapWidth:6
							topCapHeight:0];
	panelBackground.userInteractionEnabled = NO;
	[self.panel addSubview:panelBackground];
	[self.view addSubview:self.panel];

	CGRect hintFrame = CGRectMake(20, 8, b.size.width - 40, 32);
	self.hint = [[UILabel alloc] initWithFrame:hintFrame];
	self.hint.text = [self defaultHintText];
	self.hint.numberOfLines = 2;
	self.hint.textAlignment = NSTextAlignmentCenter;
	self.hint.font = [UIFont boldSystemFontOfSize:14];
	self.hint.textColor = [UIColor whiteColor];
	self.hint.shadowColor = [UIColor colorWithWhite:0 alpha:0.5f];
	self.hint.shadowOffset = CGSizeMake(0, -1);
	self.hint.backgroundColor = [UIColor clearColor];
	self.hint.userInteractionEnabled = NO;
	[self.panel addSubview:self.hint];

	self.window = window;
	[self applyScanWindow];

	UIImage *plate = [[UIImage imageNamed:@"GroupedActionButton.png"]
		stretchableImageWithLeftCapWidth:24
							topCapHeight:0];
	UIImage *platePressed = [[UIImage imageNamed:@"GroupedActionButton_Highlighted.png"]
		stretchableImageWithLeftCapWidth:24
							topCapHeight:0];
	self.torch = [UIButton buttonWithType:UIButtonTypeCustom];
	self.torch.frame = CGRectMake((int)((b.size.width - 132) / 2),
		(int)(panelHeight - 43 - 8), 132, 43);
	self.torch.titleLabel.font = [UIFont boldSystemFontOfSize:14];
	self.torch.titleLabel.shadowOffset = CGSizeMake(0, -1);
	[self.torch setBackgroundImage:plate forState:UIControlStateNormal];
	[self.torch setBackgroundImage:platePressed forState:UIControlStateHighlighted];
	[self.torch setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[self.torch setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.5f]
						   forState:UIControlStateNormal];
	[self.torch addTarget:self action:@selector(toggleTorch)
		 forControlEvents:UIControlEventTouchUpInside];
	self.torch.hidden = YES;
	[self.panel addSubview:self.torch];
	[self updateTorchButton];
}

- (void)hideFailure {
	[self.failureLabel removeFromSuperview];
	self.failureLabel = nil;
	self.wash.hidden = NO;
	self.outline.hidden = NO;
	self.hint.hidden = NO;
	[self updateTorchButton];
}

- (void)showFailure:(NSString *)message {
	self.failure = message;
	self.wash.hidden = YES;
	self.outline.hidden = YES;
	self.hint.hidden = YES;

	if (!self.failureLabel) {
		self.failureLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		self.failureLabel.numberOfLines = 0;
		self.failureLabel.textAlignment = NSTextAlignmentCenter;
		self.failureLabel.font = [UIFont boldSystemFontOfSize:14];
		self.failureLabel.textColor = [UIColor whiteColor];
		self.failureLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.5f];
		self.failureLabel.shadowOffset = CGSizeMake(0, -1);
		self.failureLabel.backgroundColor = [UIColor clearColor];
	}
	self.failureLabel.text = message;

	CGRect b = self.view.bounds;
	CGFloat width = b.size.width - 48;
	CGFloat panelHeight = self.panel ? self.panel.frame.size.height : 0;
	CGSize fit = [message sizeWithFont:self.failureLabel.font
					 constrainedToSize:CGSizeMake(width, b.size.height)
						 lineBreakMode:NSLineBreakByWordWrapping];
	self.failureLabel.frame = CGRectMake(24,
		(int)((b.size.height - panelHeight - fit.height) / 2), width, fit.height);
	[self.view addSubview:self.failureLabel];
	[self.view bringSubviewToFront:self.failureLabel];
	[self updateTorchButton];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self resumeScanning];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	if (self.camera && self.camera.torchMode == AVCaptureTorchModeOn && [self.camera lockForConfiguration:NULL]) {
		self.camera.torchMode = AVCaptureTorchModeOff;
		[self.camera unlockForConfiguration];
		[self updateTorchButton];
	}
	[self.session stopRunning];
}

- (void)dealloc {
	struct quirc *decoder = _decoder;
	dispatch_queue_t queue = _decodeQueue;

	[_session stopRunning];
	[_frames setSampleBufferDelegate:nil queue:NULL];
	_decoder = NULL;
	if (queue)
		dispatch_sync(queue, ^{ if (decoder) quirc_destroy(decoder); });
	else if (decoder)
		quirc_destroy(decoder);
}

#pragma mark - reading

- (void)captureOutput:(AVCaptureOutput *)output
	didOutputMetadataObjects:(NSArray *)objects
			  fromConnection:(AVCaptureConnection *)connection {
	NSString *type = TGQRMetadataObjectTypeQRCode();

	if (self.handled)
		return;
	for (AVMetadataMachineReadableCodeObject *code in objects) {
		if (![code.type isEqualToString:type] || !code.stringValue.length)
			continue;
		[self foundCode:code.stringValue];
		return;
	}
}

- (void)captureOutput:(AVCaptureOutput *)output
	didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
		   fromConnection:(AVCaptureConnection *)connection {
	if (!self.scanning)
		return;

	NSTimeInterval now = CFAbsoluteTimeGetCurrent();
	if (now - self.lastDecode < kQRDecodeInterval)
		return;
	self.lastDecode = now;

	CVImageBufferRef pixels = CMSampleBufferGetImageBuffer(sampleBuffer);
	if (!pixels)
		return;
	if (CVPixelBufferLockBaseAddress(pixels, kCVPixelBufferLock_ReadOnly) != 0)
		return;

	NSString *payload = [self decodeLuminanceOf:pixels];
	CVPixelBufferUnlockBaseAddress(pixels, kCVPixelBufferLock_ReadOnly);
	if (!payload.length)
		return;

	self.scanning = NO;
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf foundCode:payload]; });
}

- (NSString *)decodeLuminanceOf:(CVImageBufferRef)pixels {
	BOOL planar = CVPixelBufferIsPlanar(pixels);
	const uint8_t *base = planar ? CVPixelBufferGetBaseAddressOfPlane(pixels, 0)
								 : CVPixelBufferGetBaseAddress(pixels);
	size_t stride = planar ? CVPixelBufferGetBytesPerRowOfPlane(pixels, 0)
						   : CVPixelBufferGetBytesPerRow(pixels);
	int width = (int)(planar ? CVPixelBufferGetWidthOfPlane(pixels, 0)
							 : CVPixelBufferGetWidth(pixels));
	int height = (int)(planar ? CVPixelBufferGetHeightOfPlane(pixels, 0)
							  : CVPixelBufferGetHeight(pixels));
	int sourceStep = planar ? 1 : 4;
	int sourceOffset = planar ? 0 : 1;

	if (!base || width <= 0 || height <= 0)
		return nil;

	CGRect fraction = self.scanFraction;
	int left = 0;
	int top = 0;
	int cropWidth = width;
	int cropHeight = height;

	if (!CGRectIsEmpty(fraction)) {
		if (self.viewIsPortrait != (height >= width))
			fraction = CGRectMake(fraction.origin.y, fraction.origin.x,
				fraction.size.height, fraction.size.width);
		left = (int)(fraction.origin.x * width);
		top = (int)(fraction.origin.y * height);
		cropWidth = (int)(fraction.size.width * width);
		cropHeight = (int)(fraction.size.height * height);
	}
	if (left < 0)
		left = 0;
	if (top < 0)
		top = 0;
	if (cropWidth > width - left)
		cropWidth = width - left;
	if (cropHeight > height - top)
		cropHeight = height - top;
	if (cropWidth < 48 || cropHeight < 48) {
		left = 0;
		top = 0;
		cropWidth = width;
		cropHeight = height;
	}

	int step = 1;
	while (cropWidth / step > kQRDecodeLongestSide || cropHeight / step > kQRDecodeLongestSide)
		step++;

	int outWidth = cropWidth / step;
	int outHeight = cropHeight / step;
	if (outWidth < 48 || outHeight < 48)
		return nil;

	if (!self.decoder) {
		self.decoder = quirc_new();
		self.decoderWidth = 0;
		self.decoderHeight = 0;
	}
	if (!self.decoder)
		return nil;
	if (self.decoderWidth != outWidth || self.decoderHeight != outHeight) {
		if (quirc_resize(self.decoder, outWidth, outHeight) < 0)
			return nil;
		self.decoderWidth = outWidth;
		self.decoderHeight = outHeight;
	}

	uint8_t *target = quirc_begin(self.decoder, NULL, NULL);
	if (!target)
		return nil;
	for (NSInteger y = 0; y < outHeight; y++) {
		const uint8_t *source = base + (size_t)(top + y * step) * stride + (size_t)left * sourceStep + sourceOffset;
		uint8_t *row = target + (size_t)y * outWidth;

		if (step == 1 && sourceStep == 1) {
			memcpy(row, source, (size_t)outWidth);
			continue;
		}
		for (NSInteger x = 0; x < outWidth; x++)
			row[x] = source[x * step * sourceStep];
	}
	quirc_end(self.decoder);

	NSInteger count = quirc_count(self.decoder);
	for (NSInteger i = 0; i < count; i++) {
		struct quirc_code code;
		struct quirc_data data;

		quirc_extract(self.decoder, i, &code);
		if (quirc_decode(&code, &data) != QUIRC_SUCCESS) {
			quirc_flip(&code);
			if (quirc_decode(&code, &data) != QUIRC_SUCCESS)
				continue;
		}
		if (data.payload_len <= 0)
			continue;

		NSInteger payloadLength = (NSUInteger)data.payload_len;
		NSString *text = [[NSString alloc]
			initWithBytes:data.payload
				   length:payloadLength
				 encoding:NSUTF8StringEncoding];
		if (!text)
			text = [[NSString alloc] initWithBytes:data.payload
											length:payloadLength
										  encoding:NSISOLatin1StringEncoding];
		if (text.length)
			return text;
	}
	return nil;
}

- (void)foundCode:(NSString *)payload {
	NSString *text = [payload stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (self.handled || !text.length)
		return;
	self.handled = YES;
	self.scanning = NO;
	[self.session stopRunning];
	if (self.onCode && self.onCode(text))
		return;
	[self actOn:text];
}

- (void)resumeScanning {
	self.handled = NO;
	self.lastDecode = 0;
	self.scanning = YES;
	if (self.session && !self.session.isRunning)
		[self.session startRunning];
}

- (NSString *)usernameIn:(NSString *)text {
	NSString *candidate = nil;
	NSRange marker = [text rangeOfString:@"t.me/"];
	if (marker.location != NSNotFound) {
		NSString *rest = [text substringFromIndex:NSMaxRange(marker)];
		NSRange stop = [rest rangeOfCharacterFromSet:
				[NSCharacterSet characterSetWithCharactersInString:@"/?#"]];
		candidate = stop.location == NSNotFound ? rest : [rest substringToIndex:stop.location];
	}
	if (!candidate) {
		marker = [text rangeOfString:@"domain="];
		if (marker.location != NSNotFound) {
			NSString *rest = [text substringFromIndex:NSMaxRange(marker)];
			NSRange stop = [rest rangeOfCharacterFromSet:
					[NSCharacterSet characterSetWithCharactersInString:@"&#"]];
			candidate = stop.location == NSNotFound ? rest : [rest substringToIndex:stop.location];
		}
	}
	if (!candidate && [text hasPrefix:@"@"] && ![text rangeOfString:@" "].length)
		candidate = [text substringFromIndex:1];
	if (!candidate)
		return nil;

	candidate = [candidate stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([candidate hasPrefix:@"@"])
		candidate = [candidate substringFromIndex:1];
	if (!candidate.length || [candidate hasPrefix:@"+"] || [candidate isEqualToString:@"joinchat"] || [candidate isEqualToString:@"login"])
		return nil;

	NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
			@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"];
	if ([candidate rangeOfCharacterFromSet:[allowed invertedSet]].location != NSNotFound)
		return nil;
	return candidate;
}

- (void)actOn:(NSString *)text {
	text = [text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!text.length) {
		[self resumeScanning];
		return;
	}

	NSString *username = [self usernameIn:text];
	if (!username.length) {
		self.hint.text = text;
		BOOL isLink = [text hasPrefix:@"http://"] || [text hasPrefix:@"https://"] || [text hasPrefix:@"mailto:"] || [text hasPrefix:@"tel:"];
		self.pendingLink = isLink ? text : nil;
		UIAlertView *alert = [[UIAlertView alloc]
				initWithTitle:TGL(@"PeerInfo.QRCode.Title", @"QR Code")
					  message:text
					 delegate:self
			cancelButtonTitle:isLink ? TGL(@"Common.Cancel", @"Cancel") : TGL(@"Common.OK", @"OK")
			otherButtonTitles:(isLink ? TGL(@"Conversation.LinkDialogOpen", @"Open") : nil), nil];
		[alert show];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[TGSettingsService chatWithUsername:username completion:^(int64_t chatId,
		NSString *title) {
		TGQRViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!chatId) {
			[strongSelf resumeScanning];
			return;
		}
		strongSelf.hint.text = [strongSelf defaultHintText];
		TGChatViewController *chat = [[TGChatViewController alloc] init];
		chat.chatId = chatId;
		chat.chatTitle = title ?: username;
		if (strongSelf.navigationController)
			[strongSelf.navigationController pushViewController:chat animated:YES];
		else
			[strongSelf presentModalViewController:
					[[UINavigationController alloc] initWithRootViewController:chat]
								  animated:YES];
	}];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	NSString *link = self.pendingLink;
	self.pendingLink = nil;
	if (link.length && buttonIndex != alertView.cancelButtonIndex) {
		NSURL *url = [NSURL URLWithString:link];
		NSString *scheme = url.scheme.lowercaseString;
		BOOL isWebScheme = [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
		if (isWebScheme) {
			[TGWebViewController openURLString:link fromViewController:self];
			return;
		}
		if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
			[[UIApplication sharedApplication] openURL:url];
			return;
		}
	}
	self.hint.text = [self defaultHintText];
	[self resumeScanning];
}

@end

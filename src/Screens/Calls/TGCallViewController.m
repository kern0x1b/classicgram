#import "TGCallPeerStateText.h"
#import "TGTextFieldStyle.h"
#import "TGCallViewController.h"
#import "TGStringTruncation.h"
#import "TGCallEndText.h"
#import "TGLazyFramework.h"
#import "TGEmoji.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TGCall.h"
#import "TGCallService.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"

@interface TGCallViewController () <UITextFieldDelegate>
@property (nonatomic, strong) id videoStateChangedObserverToken;
@property (nonatomic, strong) id routeChangeObserverToken;
@property (nonatomic, strong) id interruptionObserverToken;
@property (nonatomic, assign) int64_t userId;
@property (nonatomic, strong) NSString *peerName;
@property (nonatomic, assign) BOOL outgoing;
@property (nonatomic, assign) BOOL requestedVideo;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, assign) BOOL peerAudioMuted;
@property (nonatomic, assign) BOOL peerVideoPaused;
@property (nonatomic, strong) id peerMediaStateObserver;
@property (nonatomic, strong) UILabel *emojiKeyLabel;
@property (nonatomic, strong) UILabel *videoNoticeLabel;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UIView *remoteVideoContainer;
@property (nonatomic, strong) UIView *localPreviewContainer;
@property (nonatomic, strong) UIButton *videoToggleButton;
@property (nonatomic, strong) UIButton *cameraSwitchButton;
@property (nonatomic, assign) BOOL videoUIVisible;
@property (nonatomic, strong) UIButton *muteButton;
@property (nonatomic, strong) UIButton *speakerButton;
@property (nonatomic, assign) BOOL speakerOn;
@property (nonatomic, strong) AVAudioPlayer *tonePlayer;
@property (nonatomic, strong) NSTimer *vibrateTimer;
@property (nonatomic, assign) BOOL tonesFinished;
@property (nonatomic, strong) UIButton *endButton;
@property (nonatomic, strong) UIButton *acceptButton;
@property (nonatomic, strong) NSTimer *ticker;
@property (nonatomic, assign) BOOL dismissing;
@property (nonatomic, assign) BOOL proximityWasEnabled;
@property (nonatomic, assign) BOOL idleTimerWasDisabled;
@property (nonatomic, assign) int32_t lastCallId;
@property (nonatomic, assign) BOOL wasEstablished;
@property (nonatomic, assign) NSInteger lastDuration;
@property (nonatomic, assign) BOOL rating;
@property (nonatomic, assign) NSInteger stars;
@property (nonatomic, strong) UIView *ratingPanel;
@property (nonatomic, strong) NSMutableArray *starButtons;
@property (nonatomic, strong) NSMutableArray *problemButtons;
@property (nonatomic, strong) NSArray *problemKeys;
@property (nonatomic, strong) UITextField *commentField;
@property (nonatomic, strong) UIImageView *commentBackgroundView;
@property (nonatomic, strong) UILabel *ratingTitleLabel;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UIButton *laterButton;
@property (nonatomic, assign) CGFloat keyboardShift;
@end

@implementation TGCallViewController

+ (void)presentForUserId:(int64_t)userId name:(NSString *)name outgoing:(BOOL)outgoing video:(BOOL)video {
	UIWindow *window = [UIApplication sharedApplication].keyWindow;
	if (window == nil)
		window = [[UIApplication sharedApplication].windows count] ? [[UIApplication sharedApplication].windows objectAtIndex:0] : nil;
	UIViewController *top = window.rootViewController;
	if (top == nil)
		return;
	while (top.presentedViewController)
		top = top.presentedViewController;

	if ([top isKindOfClass:[TGCallViewController class]])
		return;
	if ([top isBeingPresented] || [top isBeingDismissed])
		return;

	TGCallViewController *screen = [[TGCallViewController alloc]
		initWithUserId:userId
				  name:name
			  outgoing:outgoing
				 video:video];
	screen.modalPresentationStyle = UIModalPresentationFullScreen;
	[top presentViewController:screen animated:YES completion:nil];
}

- (instancetype)initWithUserId:(int64_t)userId name:(NSString *)name outgoing:(BOOL)outgoing video:(BOOL)video {
	if ((self = [super init])) {
		_userId = userId;
		_peerName = [(name ?: @"") stringByTrimmingCharactersInSet:
				[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		_outgoing = outgoing;
		_requestedVideo = video;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	CGFloat retinaPixel = ([UIScreen mainScreen].scale > 1.0f) ? 0.5f : 0.0f;

	UIImage *linen = [UIImage imageNamed:@"DarkLinen.png"];
	if (linen != nil)
		self.view.backgroundColor = [UIColor colorWithPatternImage:linen];
	else {
		UIColor *bg = [UIColor colorWithRed:0x2f / 255.0f green:0x39 / 255.0f
									   blue:0x48 / 255.0f
									  alpha:1.0f];
		self.view.backgroundColor = bg;
	}

	UIImage *shadowImage = [UIImage imageNamed:@"LoginShadow.png"];
	if (shadowImage != nil) {
		UIImageView *shadowView = [[UIImageView alloc] initWithFrame:self.view.bounds];
		shadowView.image = shadowImage;
		shadowView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self.view addSubview:shadowView];
	}

	CGRect b = self.view.bounds;

	self.remoteVideoContainer = [[UIView alloc] initWithFrame:b];
	self.remoteVideoContainer.backgroundColor = [UIColor blackColor];
	self.remoteVideoContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.remoteVideoContainer.hidden = YES;
	[self.view addSubview:self.remoteVideoContainer];

	CGFloat side = 90;
	CGFloat avatarY = (CGFloat)(int)(b.size.height * 0.16f);
	self.avatarView = [[UIImageView alloc] initWithFrame:
			CGRectMake((CGFloat)(int)((b.size.width - side) / 2), avatarY, side, side)];
	self.avatarView.layer.cornerRadius = (CGFloat)(int)(side / 11.0f + 0.5f);
	self.avatarView.clipsToBounds = YES;
	UIImage *img = [TGIcons avatarWithInitials:[self initials]
										  size:side
									  colourId:self.userId];
	self.avatarView.image = img;
	[self.view addSubview:self.avatarView];

	UIColor *chromeShadow = [UIColor colorWithRed:0x32 / 255.0f green:0x3c / 255.0f
											 blue:0x4a / 255.0f
											alpha:1.0f];

	self.nameLabel = [[TGEmojiLabel alloc] initWithFrame:
			CGRectMake(9, avatarY + side + 18 + retinaPixel, b.size.width - 18, 24)];
	self.nameLabel.text = self.peerName.length ? self.peerName : TGL(@"User.DeletedAccount", @"Deleted Account");
	self.nameLabel.adjustsFontSizeToFitWidth = YES;
	if ([self.nameLabel respondsToSelector:@selector(setMinimumScaleFactor:)])
		self.nameLabel.minimumScaleFactor = 0.7f;
	self.nameLabel.font = [UIFont boldSystemFontOfSize:19];
	self.nameLabel.textColor = [UIColor whiteColor];
	self.nameLabel.shadowColor = chromeShadow;
	self.nameLabel.shadowOffset = CGSizeMake(0, 1);
	self.nameLabel.textAlignment = NSTextAlignmentCenter;
	self.nameLabel.backgroundColor = [UIColor clearColor];
	[self.view addSubview:self.nameLabel];

	self.statusLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(9, CGRectGetMaxY(self.nameLabel.frame) + 4, b.size.width - 18, 24)];
	self.statusLabel.font = [UIFont systemFontOfSize:14];
	UIColor *dim = [UIColor colorWithRed:0xc0 / 255.0f green:0xc5 / 255.0f
									blue:0xcc / 255.0f
								   alpha:1.0f];
	self.statusLabel.textColor = dim;
	self.statusLabel.shadowColor = chromeShadow;
	self.statusLabel.shadowOffset = CGSizeMake(0, 1);
	self.statusLabel.textAlignment = NSTextAlignmentCenter;
	self.statusLabel.backgroundColor = [UIColor clearColor];
	[self.view addSubview:self.statusLabel];

	self.emojiKeyLabel = [[TGEmojiLabel alloc] initWithFrame:
			CGRectMake(9, CGRectGetMaxY(self.statusLabel.frame) + 2, b.size.width - 18, 28)];
	self.emojiKeyLabel.font = [UIFont systemFontOfSize:22];
	self.emojiKeyLabel.textAlignment = NSTextAlignmentCenter;
	self.emojiKeyLabel.backgroundColor = [UIColor clearColor];
	self.emojiKeyLabel.hidden = YES;
	[self.view addSubview:self.emojiKeyLabel];

	self.videoNoticeLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(9, CGRectGetMaxY(self.statusLabel.frame) + 2, b.size.width - 18, 32)];
	self.videoNoticeLabel.numberOfLines = 2;
	self.videoNoticeLabel.font = [UIFont systemFontOfSize:12];
	UIColor *dimAlpha = [UIColor colorWithRed:0xc0 / 255.0f green:0xc5 / 255.0f
										 blue:0xcc / 255.0f
										alpha:0.8f];
	self.videoNoticeLabel.textColor = dimAlpha;
	self.videoNoticeLabel.shadowColor = chromeShadow;
	self.videoNoticeLabel.shadowOffset = CGSizeMake(0, 1);
	self.videoNoticeLabel.textAlignment = NSTextAlignmentCenter;
	self.videoNoticeLabel.backgroundColor = [UIColor clearColor];
	self.videoNoticeLabel.hidden = YES;
	[self.view addSubview:self.videoNoticeLabel];

	BOOL video = self.outgoing ? self.requestedVideo : [TGCall shared].video;
	self.requestedVideo = video;
	if (video) {
		CGFloat previewSide = 96;
		self.localPreviewContainer = [[UIView alloc] initWithFrame:
				CGRectMake(b.size.width - 9 - previewSide * 0.75f, 36, previewSide * 0.75f, previewSide)];
		self.localPreviewContainer.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
		self.localPreviewContainer.layer.cornerRadius = 8;
		self.localPreviewContainer.clipsToBounds = YES;
		self.localPreviewContainer.hidden = YES;
		[self.view addSubview:self.localPreviewContainer];
	}

	CGFloat buttonWidth = (CGFloat)(int)((b.size.width - 9 * 2 - 10) / 2);
	CGFloat baseline = b.size.height - 20;
	CGRect leftFrame = CGRectMake(9, baseline - 43, buttonWidth, 43);
	CGRect rightFrame = CGRectMake(b.size.width - 9 - buttonWidth, baseline - 45, buttonWidth, 45);
	CGRect speakerFrame = CGRectMake(9, baseline - 43 - 45, b.size.width - 18, 43);
	CGRect videoRowFrame = CGRectMake(9, baseline - 43 - 45 - 45, b.size.width - 18, 43);
	CGFloat videoButtonWidth = (CGFloat)(int)((b.size.width - 9 * 2 - 10) / 2);

	self.speakerButton = [self buttonWithTitle:TGL(@"Call.Speaker", @"Speaker")
										 asset:@"GroupedActionButton"
										 frame:speakerFrame
										action:@selector(toggleSpeaker)];
	self.speakerButton.hidden = YES;

	if (video) {
		CGRect videoToggleFrame = CGRectMake(videoRowFrame.origin.x, videoRowFrame.origin.y,
			videoButtonWidth, videoRowFrame.size.height);
		UIButton *btn = [self buttonWithTitle:TGL(@"Call.Video", @"video")
										asset:@"GroupedActionButton"
										frame:videoToggleFrame
									   action:@selector(toggleLocalVideo)];
		self.videoToggleButton = btn;
		self.videoToggleButton.selected = !self.requestedVideo;
		CGRect cameraSwitchFrame = CGRectMake(CGRectGetMaxX(videoRowFrame) - videoButtonWidth,
			videoRowFrame.origin.y, videoButtonWidth, videoRowFrame.size.height);
		btn = [self buttonWithTitle:TGL(@"Call.Flip", @"flip")
							  asset:@"GroupedActionButton"
							  frame:cameraSwitchFrame
							 action:@selector(switchCamera)];
		self.cameraSwitchButton = btn;
		self.videoToggleButton.hidden = YES;
		self.cameraSwitchButton.hidden = YES;
	}
	self.muteButton = [self buttonWithTitle:TGL(@"Call.Mute", @"Mute")
									  asset:@"GroupedActionButton"
									  frame:leftFrame
									 action:@selector(toggleMute)];
	NSString *endTitle = self.outgoing ? TGL(@"Call.End", @"End") : TGL(@"Call.Decline", @"Decline");
	self.endButton = [self buttonWithTitle:endTitle
									 asset:@"MenuRedButton"
									 frame:rightFrame
									action:@selector(end)];

	if (!self.outgoing) {
		self.acceptButton = [self buttonWithTitle:TGL(@"Call.Accept", @"Accept")
											asset:@"GroupedActionButtonGreen"
											frame:leftFrame
										   action:@selector(answer)];
		self.muteButton.hidden = YES;
	}

	self.idleTimerWasDisabled = [UIApplication sharedApplication].idleTimerDisabled;
	[UIApplication sharedApplication].idleTimerDisabled = YES;

	__weak typeof(self) weakSelf = self;
	[TGCall shared].onStateChanged = ^(TGCallState state) {
		TGCallViewController *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf.dismissing)
			return;
		[strongSelf applyState:state];
	};

	if (video) {
		NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
		__weak typeof(self) weakSelf = self;
		self.videoStateChangedObserverToken = [centre
			addObserverForName:TGCallVideoStateDidChangeNotification
						object:nil
						 queue:nil
					usingBlock:^(NSNotification *note) {
						__strong typeof(weakSelf) strongSelf = weakSelf;
						if (!strongSelf)
							return;
						[strongSelf videoStateChanged];
					}];
		[[TGCall shared] attachRemoteVideoToView:self.remoteVideoContainer];
		[[TGCall shared] attachLocalPreviewToView:self.localPreviewContainer];
	}

	__weak typeof(self) weakSelfForPeer = self;
	self.peerMediaStateObserver = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGCallPeerMediaStateDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelfForPeer) strongSelf = weakSelfForPeer;
					if (!strongSelf)
						return;
					strongSelf.peerAudioMuted = [note.userInfo[@"audioMuted"] boolValue];
					strongSelf.peerVideoPaused = [note.userInfo[@"videoPaused"] boolValue];
					[strongSelf tick];
				}];

	NSNotificationCenter *audioCentre = [NSNotificationCenter defaultCenter];
	__weak typeof(self) weakSelfForRoute = self;
	self.routeChangeObserverToken = [audioCentre
		addObserverForName:TGAVString(AVAudioSessionRouteChangeNotification)
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelfForRoute) strongSelf = weakSelfForRoute;
					if (!strongSelf)
						return;
					[strongSelf audioRouteDidChange];
				}];

	self.interruptionObserverToken = [audioCentre
		addObserverForName:TGAVString(AVAudioSessionInterruptionNotification)
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelfForRoute) strongSelf = weakSelfForRoute;
					if (!strongSelf)
						return;
					[strongSelf audioSessionInterruptionDidChange:note];
				}];

	TGCallState current = [TGCall shared].state;
	if (self.outgoing && current != TGCallStatePending && current != TGCallStateExchangingKeys && current != TGCallStateConnecting && current != TGCallStateEstablished)
		[[TGCall shared] callUser:self.userId video:self.requestedVideo];
	[self applyState:[TGCall shared].state];
	if (video)
		[self videoStateChanged];

	NSTimer *tmr = [NSTimer scheduledTimerWithTimeInterval:1.0
													target:self
												  selector:@selector(tick)
												  userInfo:nil
												   repeats:YES];
	self.ticker = tmr;
}

- (void)videoStateChanged {
	if (self.dismissing)
		return;
	TGCall *call = [TGCall shared];
	BOOL remoteActive = call.remoteVideoActive;
	self.remoteVideoContainer.hidden = !remoteActive;
	self.avatarView.hidden = remoteActive;
	self.localPreviewContainer.hidden = !call.localVideoActive;
	self.videoToggleButton.hidden = !self.wasEstablished;
	self.cameraSwitchButton.hidden = !self.wasEstablished || !call.canSwitchCamera;
	self.videoToggleButton.selected = !self.requestedVideo;
	if (self.requestedVideo && self.wasEstablished && !call.localVideoActive) {
		self.videoNoticeLabel.text = TGL(@"Call.VideoSendUnavailable",
			@"This device can't send video. Continuing with audio only.");
		self.videoNoticeLabel.hidden = NO;
	} else {
		self.videoNoticeLabel.hidden = YES;
	}
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
	return UIInterfaceOrientationIsPortrait(orientation);
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate {
	return NO;
}

- (NSString *)initials {
	if (self.peerName.length == 0)
		return @"?";
	return [TGSafeFirstCharacter(self.peerName) uppercaseString];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self teardown];
}

- (void)teardown {
	[self.ticker invalidate];
	self.ticker = nil;
	[self stopTone];
	if (self.speakerOn) {
		self.speakerOn = NO;
		AVAudioSession *session = [TGAVClass(AVAudioSession) sharedInstance];
		[session overrideOutputAudioPort:AVAudioSessionPortOverrideNone
								   error:nil];
	}
	[self setProximityEnabled:NO];
	[UIApplication sharedApplication].idleTimerDisabled = self.idleTimerWasDisabled;
	if ([TGCall shared].onStateChanged != nil)
		[TGCall shared].onStateChanged = nil;
	if (self.videoStateChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.videoStateChangedObserverToken];
	if (self.peerMediaStateObserver) {
		[[NSNotificationCenter defaultCenter] removeObserver:self.peerMediaStateObserver];
		self.peerMediaStateObserver = nil;
	}
	if (self.routeChangeObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.routeChangeObserverToken];
	if (self.interruptionObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.interruptionObserverToken];
	[[TGCall shared] detachVideoViews];
}

- (void)toggleLocalVideo {
	if (self.dismissing)
		return;
	self.requestedVideo = !self.requestedVideo;
	[[TGCall shared] setLocalVideoEnabled:self.requestedVideo];
	[self videoStateChanged];
}

- (void)switchCamera {
	if (self.dismissing)
		return;
	[[TGCall shared] switchCamera];
}

- (void)setProximityEnabled:(BOOL)enabled {
	UIDevice *device = [UIDevice currentDevice];
	if (![device respondsToSelector:@selector(setProximityMonitoringEnabled:)])
		return;
	if (enabled && !self.proximityWasEnabled) {
		device.proximityMonitoringEnabled = YES;
		self.proximityWasEnabled = YES;
	} else if (!enabled && self.proximityWasEnabled) {
		device.proximityMonitoringEnabled = NO;
		self.proximityWasEnabled = NO;
	}
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[self teardown];
}

- (UIButton *)buttonWithTitle:(NSString *)title asset:(NSString *)asset
						frame:(CGRect)frame
					   action:(SEL)action {
	UIImage *raw = [UIImage imageNamed:[asset stringByAppendingString:@".png"]];
	UIImage *rawHighlighted = [UIImage imageNamed:
			[asset stringByAppendingString:@"_Highlighted.png"]];

	BOOL centreStretch = [asset isEqualToString:@"MenuRedButton"];
	NSInteger topCap = centreStretch ? (NSInteger)(raw.size.height / 2) : 0;
	NSInteger topCapHighlighted = centreStretch ? (NSInteger)(rawHighlighted.size.height / 2) : 0;

	UIImage *bg = [raw stretchableImageWithLeftCapWidth:(NSInteger)(raw.size.width / 2)
										   topCapHeight:topCap];
	UIImage *backgroundHighlighted = [rawHighlighted
		stretchableImageWithLeftCapWidth:(NSInteger)(rawHighlighted.size.width / 2)
							topCapHeight:topCapHighlighted];

	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.frame = frame;
	button.exclusiveTouch = YES;
	button.adjustsImageWhenDisabled = NO;
	[button setBackgroundImage:bg forState:UIControlStateNormal];
	[button setBackgroundImage:backgroundHighlighted forState:UIControlStateHighlighted];
	[button setBackgroundImage:backgroundHighlighted forState:UIControlStateSelected];
	[button setBackgroundImage:backgroundHighlighted
					  forState:UIControlStateSelected | UIControlStateHighlighted];
	[button setTitle:title forState:UIControlStateNormal];

	if ([asset isEqualToString:@"GroupedActionButton"]) {
		[button setTitleColor:[UIColor colorWithRed:0x4a / 255.0f green:0x65 / 255.0f
											   blue:0x87 / 255.0f
											  alpha:1.0f]
					 forState:UIControlStateNormal];
		[button setTitleShadowColor:[UIColor colorWithWhite:1.0f alpha:0.45f]
						   forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
		[button setTitleShadowColor:[UIColor clearColor] forState:UIControlStateHighlighted];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
		[button setTitleShadowColor:[UIColor clearColor] forState:UIControlStateSelected];
		[button setTitleColor:[UIColor whiteColor]
					 forState:UIControlStateSelected | UIControlStateHighlighted];
		button.titleLabel.font = [UIFont boldSystemFontOfSize:14];
		button.titleLabel.shadowOffset = CGSizeMake(0, 1);
	} else {
		BOOL green = [asset isEqualToString:@"GroupedActionButtonGreen"];
		UIColor *shadow = green
			? [UIColor colorWithRed:0x12 / 255.0f green:0x46 / 255.0f blue:0x06 / 255.0f alpha:0.3f]
			: [UIColor colorWithRed:0xa1 / 255.0f green:0x06 / 255.0f blue:0x03 / 255.0f alpha:0.5f];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
		[button setTitleShadowColor:shadow forState:UIControlStateNormal];
		[button setTitleShadowColor:shadow forState:UIControlStateHighlighted];
		button.titleLabel.font = [UIFont boldSystemFontOfSize:green ? 16 : 17];
		button.titleLabel.shadowOffset = CGSizeMake(0, -1);
	}

	[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:button];
	return button;
}

#pragma mark - call tones

static void TGCallToneAppend(NSMutableData *samples, double freqA, double freqB,
	double seconds, double rate) {
	NSInteger count = (NSUInteger)(seconds * rate);
	int16_t *buffer = (int16_t *)malloc(count * sizeof(int16_t));
	if (buffer == NULL)
		return;
	for (NSInteger i = 0; i < count; i++) {
		double t = (double)i / rate;
		double value = 0.0;
		if (freqA > 0.0)
			value += sin(2.0 * M_PI * freqA * t);
		if (freqB > 0.0)
			value += sin(2.0 * M_PI * freqB * t);
		if (freqA > 0.0 && freqB > 0.0)
			value *= 0.5;
		double fade = 1.0;
		double fadeSamples = rate * 0.005;
		if (i < fadeSamples)
			fade = (double)i / fadeSamples;
		else if (count > (NSUInteger)fadeSamples && i > count - (NSUInteger)fadeSamples)
			fade = (double)(count - i) / fadeSamples;
		buffer[i] = (int16_t)(value * fade * 9000.0);
	}
	[samples appendBytes:buffer length:count * sizeof(int16_t)];
	free(buffer);
}

static void TGCallToneAppendSilence(NSMutableData *samples, double seconds, double rate) {
	NSInteger count = (NSUInteger)(seconds * rate);
	NSInteger bytes = count * sizeof(int16_t);
	[samples increaseLengthBy:bytes];
}

static NSData *TGCallToneWrap(NSData *samples, double rate) {
	uint32_t sampleRate = (uint32_t)rate;
	uint32_t dataSize = (uint32_t)[samples length];
	uint32_t byteRate = sampleRate * 2;
	NSMutableData *wav = [NSMutableData dataWithCapacity:dataSize + 44];
	uint32_t chunkSize = dataSize + 36;
	uint32_t sixteen = 16;
	uint16_t one = 1;
	uint16_t bits = 16;
	uint16_t align = 2;
	[wav appendBytes:"RIFF" length:4];
	[wav appendBytes:&chunkSize length:4];
	[wav appendBytes:"WAVEfmt " length:8];
	[wav appendBytes:&sixteen length:4];
	[wav appendBytes:&one length:2];
	[wav appendBytes:&one length:2];
	[wav appendBytes:&sampleRate length:4];
	[wav appendBytes:&byteRate length:4];
	[wav appendBytes:&align length:2];
	[wav appendBytes:&bits length:2];
	[wav appendBytes:"data" length:4];
	[wav appendBytes:&dataSize length:4];
	[wav appendData:samples];
	return wav;
}

- (void)playToneData:(NSData *)data loop:(BOOL)loop volume:(float)volume {
	[self stopTone];
	if (data == nil)
		return;
	AVAudioSession *session = [TGAVClass(AVAudioSession) sharedInstance];
	if ([TGCall shared].state != TGCallStateEstablished) {
		[session setCategory:TGAVString(AVAudioSessionCategoryPlayback) error:nil];
		[session setActive:YES error:nil];
	}
	NSError *error = nil;
	AVAudioPlayer *player = [[TGAVClass(AVAudioPlayer) alloc] initWithData:data error:&error];
	if (player == nil)
		return;
	player.numberOfLoops = loop ? -1 : 0;
	player.volume = volume;
	[player prepareToPlay];
	[player play];
	self.tonePlayer = player;
}

- (void)startRingingTone {
	if (self.tonePlayer != nil || self.tonesFinished || self.dismissing)
		return;

	double rate = 8000.0;
	NSMutableData *samples = [NSMutableData data];
	if (self.outgoing) {
		TGCallToneAppend(samples, 425.0, 0.0, 1.0, rate);
		TGCallToneAppendSilence(samples, 3.0, rate);
	} else {
		TGCallToneAppend(samples, 440.0, 480.0, 1.2, rate);
		TGCallToneAppendSilence(samples, 2.4, rate);
	}
	[self playToneData:TGCallToneWrap(samples, rate) loop:YES volume:self.outgoing ? 0.5f : 1.0f];

	if (!self.outgoing && self.vibrateTimer == nil) {
		AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
		self.vibrateTimer = [NSTimer scheduledTimerWithTimeInterval:3.6
															 target:self
														   selector:@selector(vibrate)
														   userInfo:nil
															repeats:YES];
	}
}

- (void)vibrate {
	if (self.dismissing || self.tonePlayer == nil)
		return;
	AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

- (void)playEndTone {
	if (self.tonesFinished)
		return;
	[self stopTone];
	self.tonesFinished = YES;
	double rate = 8000.0;
	NSMutableData *samples = [NSMutableData data];
	for (NSInteger i = 0; i < 3; i++) {
		TGCallToneAppend(samples, 425.0, 0.0, 0.2, rate);
		TGCallToneAppendSilence(samples, 0.2, rate);
	}
	[self playToneData:TGCallToneWrap(samples, rate) loop:NO volume:0.6f];
}

- (void)stopTone {
	[self.vibrateTimer invalidate];
	self.vibrateTimer = nil;
	if (self.tonePlayer != nil) {
		[self.tonePlayer stop];
		self.tonePlayer = nil;
	}
}

- (void)applyVerificationEmojis {
	NSArray *emojis = [TGCall shared].verificationEmojis;
	if (![emojis isKindOfClass:NSArray.class] || emojis.count == 0) {
		self.emojiKeyLabel.hidden = YES;
		return;
	}
	NSMutableArray *glyphs = [NSMutableArray array];
	for (NSString *emoji in emojis)
		if ([emoji isKindOfClass:NSString.class] && emoji.length)
			[glyphs addObject:emoji];
	self.emojiKeyLabel.text = [glyphs componentsJoinedByString:@"  "];
	self.emojiKeyLabel.hidden = glyphs.count == 0;
}

- (void)applyState:(TGCallState)state {
	if (self.dismissing)
		return;

	if ([TGCall shared].callId != 0)
		self.lastCallId = [TGCall shared].callId;

	switch (state) {
		case TGCallStateNone:
			self.statusLabel.text = self.outgoing ? TGL(@"Call.StatusRequesting", @"Contacting...")
												  : (self.requestedVideo ? TGL(@"Call.StatusIncomingVideo", @"Telegram Video...")
																		 : TGL(@"Call.StatusIncoming", @"Telegram Audio..."));
			[self startRingingTone];
			break;
		case TGCallStatePending:
			self.statusLabel.text = self.outgoing ? TGL(@"Call.StatusRinging", @"Ringing...")
												  : (self.requestedVideo ? TGL(@"Call.StatusIncomingVideo", @"Telegram Video...")
																		 : TGL(@"Call.StatusIncoming", @"Telegram Audio..."));
			[self startRingingTone];
			self.acceptButton.hidden = self.outgoing;
			self.muteButton.hidden = !self.outgoing;
			break;
		case TGCallStateExchangingKeys:
			self.statusLabel.text = TGL(@"Call.StatusConnecting", @"Connecting...");
			self.acceptButton.hidden = YES;
			self.muteButton.hidden = NO;
			[self setEndButtonEnding];
			[self stopTone];
			break;
		case TGCallStateConnecting:
			self.statusLabel.text = TGL(@"Call.StatusConnecting", @"Connecting...");
			self.acceptButton.hidden = YES;
			self.muteButton.hidden = NO;
			[self setEndButtonEnding];
			[self stopTone];
			break;
		case TGCallStateEstablished:
			self.acceptButton.hidden = YES;
			self.muteButton.hidden = NO;
			[self setEndButtonEnding];
			self.wasEstablished = YES;
			[self stopTone];
			[self setProximityEnabled:!self.speakerOn];
			[self tick];
			[self videoStateChanged];
			[self applyVerificationEmojis];
			break;
		case TGCallStateFailed:
			self.statusLabel.text = [self endText:TGL(@"Call.StatusFailed", @"Call Failed")];
			self.emojiKeyLabel.hidden = YES;
			[self playEndTone];
			[self finish];
			break;
		case TGCallStateEnded:
			self.statusLabel.text = [self endText:TGL(@"Call.StatusEnded", @"Call Ended")];
			self.emojiKeyLabel.hidden = YES;
			[self playEndTone];
			[self finish];
			break;
		default:
			break;
	}

	if (state != TGCallStateEnded && state != TGCallStateFailed) {
		[self syncMuteTitle];
		self.speakerButton.hidden = self.muteButton.hidden;
	} else {
		self.speakerButton.hidden = YES;
	}
}

- (NSString *)endText:(NSString *)fallback {
	return TGCallEndText([TGCall shared].endReason, fallback);
}

- (void)setEndButtonEnding {
	[self.endButton setTitle:TGL(@"Call.End", @"End") forState:UIControlStateNormal];
}

- (void)syncMuteTitle {
	BOOL muted = [TGCall shared].muted;
	[self.muteButton setTitle:(muted ? TGL(@"Conversation.Unmute", @"Unmute") : TGL(@"Call.Mute", @"Mute"))
					 forState:UIControlStateNormal];
}

- (void)tick {
	if (self.dismissing)
		return;
	if ([TGCall shared].state != TGCallStateEstablished)
		return;
	NSTimeInterval elapsed = [[TGCall shared] duration];
	if (elapsed < 0)
		elapsed = 0;
	NSInteger seconds = (NSInteger)elapsed;
	self.lastDuration = seconds;
	NSString *durationString;
	if (seconds >= 3600)
		durationString = [NSString stringWithFormat:@"%02d:%02d:%02d",
			(int)(seconds / 3600), (int)((seconds / 60) % 60), (int)(seconds % 60)];
	else
		durationString = [NSString stringWithFormat:@"%02d:%02d",
			(int)((seconds / 60) % 60), (int)(seconds % 60)];
	NSString *line = [NSString stringWithFormat:
			self.requestedVideo ? TGL(@"Call.StatusOngoingVideo", @"Telegram Video %@")
								: TGL(@"Call.StatusOngoing", @"Telegram Audio %@"), durationString];
	NSString *peerState = TGCallPeerStateSuffix(self.peerAudioMuted,
			self.peerVideoPaused,
			self.requestedVideo);
	if (peerState.length)
		line = [NSString stringWithFormat:TGL(@"Call.StatusWithPeerState", @"%@ - %@"),
				line, peerState];
	self.statusLabel.text = line;
}

- (void)toggleMute {
	if (self.dismissing)
		return;
	[[TGCall shared] setMuted:![TGCall shared].muted];
	[self syncMuteTitle];
}

- (void)toggleSpeaker {
	if (self.dismissing)
		return;
	self.speakerOn = !self.speakerOn;
	[self applySpeakerRoute];
}

- (void)applySpeakerRoute {
	AVAudioSession *session = [TGAVClass(AVAudioSession) sharedInstance];
	[session overrideOutputAudioPort:(self.speakerOn
											 ? AVAudioSessionPortOverrideSpeaker
											 : AVAudioSessionPortOverrideNone)
							   error:nil];
	[self.speakerButton setTitle:TGL(@"Call.Speaker", @"Speaker") forState:UIControlStateNormal];
	self.speakerButton.selected = self.speakerOn;
	if ([TGCall shared].state == TGCallStateEstablished)
		[self setProximityEnabled:!self.speakerOn];
	else
		[self setProximityEnabled:NO];
}

- (void)audioRouteDidChange {
	if (self.dismissing)
		return;
	AVAudioSession *session = [TGAVClass(AVAudioSession) sharedInstance];
	BOOL speaker = NO;
	for (AVAudioSessionPortDescription *output in session.currentRoute.outputs)
		if ([output.portType isEqualToString:TGAVString(AVAudioSessionPortBuiltInSpeaker)])
			speaker = YES;
	self.speakerOn = speaker;
	self.speakerButton.selected = speaker;
	if ([TGCall shared].state == TGCallStateEstablished)
		[self setProximityEnabled:!speaker];
}

- (void)audioSessionInterruptionDidChange:(NSNotification *)note {
	if (self.dismissing)
		return;
	NSNumber *typeValue = note.userInfo[TGAVString(AVAudioSessionInterruptionTypeKey)];
	if (typeValue.unsignedIntegerValue != AVAudioSessionInterruptionTypeEnded)
		return;
	NSNumber *optionsValue = note.userInfo[TGAVString(AVAudioSessionInterruptionOptionKey)];
	if (optionsValue.unsignedIntegerValue & AVAudioSessionInterruptionOptionShouldResume)
		[[TGCall shared] reactivateAudioSessionAfterInterruption];
}

- (void)answer {
	if (self.dismissing)
		return;
	[self stopTone];
	self.acceptButton.hidden = YES;
	self.muteButton.hidden = NO;
	self.speakerButton.hidden = NO;
	[self setEndButtonEnding];
	self.statusLabel.text = TGL(@"Call.StatusConnecting", @"Connecting...");
	[[TGCall shared] accept];
}

- (void)end {
	if (self.dismissing)
		return;
	[[TGCall shared] hangUp];
	self.statusLabel.text = [self endText:TGL(@"Call.StatusEnded", @"Call Ended")];
	[self playEndTone];
	[self finish];
}

- (void)finish {
	if (self.dismissing)
		return;
	self.dismissing = YES;
	self.speakerButton.hidden = YES;
	self.muteButton.enabled = NO;
	self.acceptButton.enabled = NO;
	self.endButton.enabled = NO;
	[self.ticker invalidate];
	self.ticker = nil;
	[self setProximityEnabled:NO];
	[TGCall shared].onStateChanged = nil;

	if (self.wasEstablished && self.lastDuration > 0 && self.lastCallId != 0) {
		[self presentRating];
		return;
	}
	[self performSelector:@selector(dismissNow) withObject:nil afterDelay:1.0];
}

#pragma mark - post-call rating

- (void)presentRating {
	self.rating = YES;
	self.muteButton.hidden = YES;
	self.acceptButton.hidden = YES;
	self.endButton.hidden = YES;
	self.videoNoticeLabel.hidden = YES;

	CGRect b = self.view.bounds;
	self.problemKeys = [NSArray arrayWithObjects:@"echo", @"noise", @"interruptions",
		@"distortedSpeech", @"silentRemote", @"dropped", nil];

	CGRect nameFrame = self.nameLabel.frame;
	nameFrame.origin.y = 26;
	CGRect statusFrame = self.statusLabel.frame;
	statusFrame.origin.y = CGRectGetMaxY(nameFrame) + 2;
	[UIView animateWithDuration:0.2 animations:^{
		self.avatarView.alpha = 0.0f;
		self.nameLabel.frame = nameFrame;
		self.statusLabel.frame = statusFrame;
	}];

	CGFloat top = CGRectGetMaxY(statusFrame) + 12;
	self.ratingPanel = [[UIView alloc] initWithFrame:
			CGRectMake(0, top, b.size.width, b.size.height - top)];
	self.ratingPanel.backgroundColor = [UIColor clearColor];
	self.ratingPanel.alpha = 0.0f;
	[self.view addSubview:self.ratingPanel];

	UIColor *chromeShadow = [UIColor colorWithRed:0x32 / 255.0f green:0x3c / 255.0f
											 blue:0x4a / 255.0f
											alpha:1.0f];

	self.ratingTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(9, 0, b.size.width - 18, 40)];
	self.ratingTitleLabel.numberOfLines = 2;
	self.ratingTitleLabel.text = TGL(@"Calls.RatingTitle", @"Please rate the quality\nof your Telegram call");
	self.ratingTitleLabel.font = [UIFont boldSystemFontOfSize:17];
	self.ratingTitleLabel.textColor = [UIColor whiteColor];
	self.ratingTitleLabel.shadowColor = chromeShadow;
	self.ratingTitleLabel.shadowOffset = CGSizeMake(0, 1);
	self.ratingTitleLabel.textAlignment = NSTextAlignmentCenter;
	self.ratingTitleLabel.backgroundColor = [UIColor clearColor];
	[self.ratingPanel addSubview:self.ratingTitleLabel];

	self.starButtons = [NSMutableArray array];
	CGFloat starsWidth = 246;
	CGFloat starsHeight = 38;
	CGFloat starsY = 46;
	CGFloat starsX = (CGFloat)(int)((b.size.width - starsWidth) / 2);
	UIView *starsStrip = [[UIView alloc] initWithFrame:
			CGRectMake(starsX, starsY, starsWidth, starsHeight)];
	starsStrip.backgroundColor = [UIColor clearColor];
	[starsStrip addGestureRecognizer:[[UIPanGestureRecognizer alloc]
										 initWithTarget:self
												 action:@selector(handleStarPan:)]];
	[self.ratingPanel addSubview:starsStrip];
	for (NSInteger i = 0; i < 5; i++) {
		UIButton *star = [UIButton buttonWithType:UIButtonTypeCustom];
		star.frame = CGRectMake(18 + 42 * i, 0, 42, starsHeight);
		star.tag = i + 1;
		star.exclusiveTouch = YES;
		star.adjustsImageWhenHighlighted = NO;
		star.backgroundColor = [UIColor clearColor];
		star.titleLabel.font = [UIFont systemFontOfSize:30];
		[star setTitle:@"☆" forState:UIControlStateNormal];
		star.accessibilityLabel = TGLPlural(@"Call.RatingStars", star.tag, @"%@ star", @"%@ stars");
		[star setTitleColor:[UIColor colorWithWhite:1.0f alpha:0.6f] forState:UIControlStateNormal];
		[star addTarget:self action:@selector(starPressed:)
			forControlEvents:UIControlEventTouchUpInside];
		[starsStrip addSubview:star];
		[self.starButtons addObject:star];
	}

	CGFloat y = starsY + starsHeight + 8;
	self.problemButtons = [NSMutableArray array];
	NSArray *titles = [NSArray arrayWithObjects:
			TGL(@"CallFeedback.ReasonEcho", @"Echo"),
		TGL(@"CallFeedback.ReasonNoise", @"Noise"),
		TGL(@"CallFeedback.ReasonInterruption", @"Interruptions"),
		TGL(@"CallFeedback.ReasonDistortedSpeech", @"Distorted speech"),
		TGL(@"CallFeedback.ReasonSilentRemote", @"Silent remote"),
		TGL(@"CallFeedback.ReasonDropped", @"Dropped"), nil];
	CGFloat cellWidth = (CGFloat)(int)((b.size.width - 9 * 2 - 10) / 2);
	for (NSInteger i = 0; i < [titles count]; i++) {
		CGFloat px = (i % 2 == 0) ? 9 : (b.size.width - 9 - cellWidth);
		CGFloat py = y + (CGFloat)(int)(i / 2) * 45;
		UIButton *chip = [self ratingButtonWithTitle:[titles objectAtIndex:i]
											   asset:@"GroupedActionButton"
											   frame:CGRectMake(px, py, cellWidth, 43)
											  action:@selector(problemPressed:)];
		chip.tag = (NSInteger)i;
		chip.titleLabel.font = [UIFont boldSystemFontOfSize:14];
		chip.hidden = YES;
		[self.problemButtons addObject:chip];
	}

	CGRect plateFrame = CGRectMake(9, y + 3 * 45 + 4, b.size.width - 18, 43);
	UIImage *rawInput = [UIImage imageNamed:@"LoginInput.png"];
	self.commentBackgroundView = [[UIImageView alloc] initWithImage:
			[rawInput stretchableImageWithLeftCapWidth:(NSInteger)(rawInput.size.width / 2)
										  topCapHeight:0]];
	self.commentBackgroundView.frame = plateFrame;
	self.commentBackgroundView.hidden = YES;
	[self.ratingPanel addSubview:self.commentBackgroundView];

	self.commentField = [[UITextField alloc] initWithFrame:
			CGRectMake(plateFrame.origin.x + 9, plateFrame.origin.y + 10,
				plateFrame.size.width - 20, 22)];
	self.commentField.borderStyle = UITextBorderStyleNone;
	self.commentField.backgroundColor = [UIColor colorWithWhite:0xf5 / 255.0f alpha:1.0f];
	self.commentField.font = [UIFont systemFontOfSize:16];
	self.commentField.placeholder = TGL(@"Calls.RatingFeedback", @"Write a comment...");
	self.commentField.returnKeyType = UIReturnKeyDone;
	self.commentField.autocorrectionType = UITextAutocorrectionTypeDefault;
	self.commentField.clearButtonMode = UITextFieldViewModeWhileEditing;
	TGStyleTextField(self.commentField);
	self.commentField.delegate = self;
	self.commentField.hidden = YES;
	[self.ratingPanel addSubview:self.commentField];

	CGFloat baseline = b.size.height - 20 - self.ratingPanel.frame.origin.y;
	CGFloat buttonWidth = (CGFloat)(int)((b.size.width - 9 * 2 - 10) / 2);
	CGRect laterFrame = CGRectMake(9, baseline - 43, buttonWidth, 43);
	CGRect sendFrame = CGRectMake(b.size.width - 9 - buttonWidth, baseline - 43, buttonWidth, 43);
	self.laterButton = [self ratingButtonWithTitle:TGL(@"Common.NotNow", @"Not Now")
											 asset:@"GroupedActionButton"
											 frame:laterFrame
											action:@selector(skipRating)];
	self.sendButton = [self ratingButtonWithTitle:TGL(@"CallFeedback.Send", @"Submit")
											asset:@"GroupedActionButtonGreen"
											frame:sendFrame
										   action:@selector(submitRating)];
	self.sendButton.enabled = NO;
	self.sendButton.alpha = 0.7f;

	[UIView animateWithDuration:0.2 animations:^{
		self.ratingPanel.alpha = 1.0f;
	}];
}

- (UIButton *)ratingButtonWithTitle:(NSString *)title asset:(NSString *)asset
							  frame:(CGRect)frame
							 action:(SEL)action {
	UIButton *button = [self buttonWithTitle:title asset:asset frame:frame action:action];
	[button removeFromSuperview];
	[self.ratingPanel addSubview:button];
	return button;
}

- (void)starPressed:(UIButton *)sender {
	self.stars = sender.tag;
	for (UIButton *star in self.starButtons) {
		BOOL on = star.tag <= self.stars;
		[star setTitle:(on ? @"★" : @"☆") forState:UIControlStateNormal];
		star.accessibilityValue = on ? TGL(@"Call.RatingStarSelected", @"Selected") : nil;
		[star setTitleColor:(on ? [UIColor whiteColor] : [UIColor colorWithWhite:1.0f alpha:0.6f])
				   forState:UIControlStateNormal];
	}

	BOOL detail = (self.stars > 0 && self.stars < 5);
	if (!detail) {
		[self.commentField resignFirstResponder];
		for (UIButton *chip in self.problemButtons)
			[self setChip:chip selected:NO];
	}
	for (UIButton *chip in self.problemButtons)
		chip.hidden = !detail;
	self.commentField.hidden = !detail;
	self.commentBackgroundView.hidden = !detail;

	self.commentField.placeholder = (self.stars > 0 && self.stars < 4)
		? TGL(@"Call.ReportPlaceholder", @"What went wrong?")
		: TGL(@"Calls.RatingFeedback", @"Write a comment...");

	self.sendButton.enabled = (self.stars > 0);
	self.sendButton.alpha = (self.stars > 0) ? 1.0f : 0.7f;
}

- (void)handleStarPan:(UIPanGestureRecognizer *)recognizer {
	if (recognizer.state != UIGestureRecognizerStateChanged)
		return;
	CGPoint location = [recognizer locationInView:recognizer.view];
	location.x = MAX(0.0f, MIN(recognizer.view.frame.size.width, location.x));
	location.y = 0;
	for (UIButton *star in self.starButtons) {
		CGPoint inStar = [recognizer.view convertPoint:location toView:star];
		if ([star pointInside:inStar withEvent:nil])
			[self starPressed:star];
	}
}

- (void)setChip:(UIButton *)chip selected:(BOOL)selected {
	chip.selected = selected;
}

- (void)problemPressed:(UIButton *)sender {
	[self setChip:sender selected:!sender.selected];
}

- (NSArray *)selectedProblems {
	NSMutableArray *problems = [NSMutableArray array];
	for (UIButton *chip in self.problemButtons) {
		if (chip.selected && (NSUInteger)chip.tag < [self.problemKeys count])
			[problems addObject:[self.problemKeys objectAtIndex:(NSUInteger)chip.tag]];
	}
	return problems;
}

- (NSString *)callDebugInformation {
	NSMutableString *info = [NSMutableString string];
	[info appendFormat:@"call_id=%d\n", (int)self.lastCallId];
	[info appendFormat:@"direction=%@\n", [TGCall shared].outgoing ? @"outgoing" : @"incoming"];
	[info appendFormat:@"duration_seconds=%ld\n", (long)self.lastDuration];
	[info appendFormat:@"end_reason=%@\n", [TGCall shared].endReason ?: @"unknown"];
	[info appendFormat:@"rating=%ld\n", (long)self.stars];
	NSArray *problems = [self selectedProblems];
	[info appendFormat:@"problems=%@\n",
		problems.count ? [problems componentsJoinedByString:@","] : @"none"];
	return info;
}

- (void)submitRating {
	if (self.stars <= 0)
		return;
	[self.commentField resignFirstResponder];

	NSString *comment = [self.commentField.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	self.sendButton.enabled = NO;
	self.laterButton.enabled = NO;
	self.statusLabel.text = TGL(@"Call.RatingSending", @"Sending...");

	if (self.stars > 0 && self.stars < 4)
		[TGCallService sendCallDebugInformation:[self callDebugInformation]
									  forCallId:self.lastCallId
									 completion:nil];

	__weak typeof(self) weakSelf = self;
	[TGCallService rateCallId:self.lastCallId
					   rating:self.stars
					  comment:(comment.length ? comment : nil)
		problems:[self selectedProblems]
				   completion:^(BOOL ok) {
					   TGCallViewController *strongSelf = weakSelf;
					   if (strongSelf == nil)
						   return;
					   strongSelf.statusLabel.text = ok ? TGL(@"CallFeedback.Success", @"Thank you")
														: TGL(@"Call.RatingSendFailed", @"Could not send rating");
					   [strongSelf closeRating];
				   }];
}

- (void)skipRating {
	[self.commentField resignFirstResponder];
	[self closeRating];
}

- (void)closeRating {
	if (!self.rating)
		return;
	self.rating = NO;
	[UIView animateWithDuration:0.2 animations:^{
		self.ratingPanel.alpha = 0.0f;
	} completion:^(BOOL finished) {
		[self.ratingPanel removeFromSuperview];
		self.ratingPanel = nil;
	}];
	[self performSelector:@selector(dismissNow) withObject:nil afterDelay:0.8];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return NO;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
	if (self.keyboardShift > 0)
		return;
	CGFloat needed = CGRectGetMaxY(self.view.bounds) - 216 - (self.ratingPanel.frame.origin.y + CGRectGetMaxY(self.commentBackgroundView.frame) + 8);
	if (needed >= 0)
		return;
	self.keyboardShift = -needed;
	CGRect frame = self.view.frame;
	frame.origin.y -= self.keyboardShift;
	[UIView animateWithDuration:0.25 animations:^{
		self.view.frame = frame;
	}];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
	if (self.keyboardShift <= 0)
		return;
	CGRect frame = self.view.frame;
	frame.origin.y += self.keyboardShift;
	self.keyboardShift = 0;
	[UIView animateWithDuration:0.25 animations:^{
		self.view.frame = frame;
	}];
}

- (void)dismissNow {
	[UIApplication sharedApplication].idleTimerDisabled = self.idleTimerWasDisabled;
	if (self.presentingViewController != nil)
		[self dismissViewControllerAnimated:YES completion:nil];
}

@end

#import "TGVideoCaptureViewController.h"
#import "TGDurationText.h"
#import "TGLocalization.h"
#import "TGLazyFramework.h"
#import "TGVideoRecorder.h"
#import "TGTheme.h"

#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

static const CGFloat kVideoCaptureShutterSide = 68.0f;
static const NSTimeInterval kVideoCaptureMinimum = 0.6;

static const CGFloat kNoteCircleSide = 216.0f;
static const CGFloat kNoteShadowInset = 19.0f;
static const CGFloat kNoteRingSide = 234.0f;
static const CGFloat kNoteRingWidth = 4.0f;
static const CGFloat kNoteMuteSide = 24.0f;
static const CGFloat kNoteCancelSlide = 110.0f;
static const CGFloat kNoteLockRise = 46.0f;
static const CGFloat kNoteLockWidth = 30.0f;
static const CGFloat kNoteLockHeight = 44.0f;
static const CGFloat kNoteControlSide = 44.0f;

typedef NS_ENUM(NSInteger, TGNoteStage) {
	TGNoteStageIdle = 0,
	TGNoteStageRecording,
	TGNoteStagePreview
};

static UIColor *TGNoteRecordColour(void) {
	return [UIColor colorWithRed:0xf3 / 255.0f green:0x3d / 255.0f
							blue:0x2b / 255.0f
						   alpha:1.0f];
}

static UIColor *TGNoteHintColour(void) {
	return [UIColor colorWithRed:0x95 / 255.0f green:0x97 / 255.0f
							blue:0xa0 / 255.0f
						   alpha:1.0f];
}

static UIImage *TGVideoCaptureShutterImage(BOOL recording, BOOL pressed) {
	CGFloat side = kVideoCaptureShutterSide;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0.0f);
	CGContextRef context = UIGraphicsGetCurrentContext();

	CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 2.0f,
		[UIColor colorWithWhite:0 alpha:0.4f].CGColor);
	CGContextSetStrokeColorWithColor(context,
		[UIColor colorWithWhite:1 alpha:pressed ? 0.7f : 1.0f].CGColor);
	CGContextSetLineWidth(context, 4.0f);
	CGContextStrokeEllipseInRect(context, CGRectMake(4, 4, side - 8, side - 8));
	CGContextSetShadowWithColor(context, CGSizeZero, 0, NULL);

	CGContextSetFillColorWithColor(context,
		[UIColor colorWithRed:0.85f green:0.16f blue:0.14f
						alpha:pressed ? 0.7f : 1.0f]
			.CGColor);
	if (recording) {
		CGFloat inner = 26.0f;
		CGRect square = CGRectMake((side - inner) / 2, (side - inner) / 2, inner, inner);
		CGContextAddPath(context,
			[UIBezierPath bezierPathWithRoundedRect:square cornerRadius:4].CGPath);
		CGContextFillPath(context);
	} else {
		CGFloat inner = side - 20;
		CGContextFillEllipseInRect(context,
			CGRectMake((side - inner) / 2, (side - inner) / 2, inner, inner));
	}

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

static UIImage *TGNoteMuteBadgeImage(void) {
	static UIImage *badge = nil;
	if (badge != nil)
		return badge;

	CGFloat side = kNoteMuteSide;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0.0f);
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetFillColorWithColor(context,
		[UIColor colorWithWhite:0 alpha:0.4f].CGColor);
	CGContextFillEllipseInRect(context, CGRectMake(0, 0, side, side));

	[[UIColor whiteColor] setFill];
	UIBezierPath *speaker = [UIBezierPath bezierPath];
	[speaker moveToPoint:CGPointMake(6.5f, 10.0f)];
	[speaker addLineToPoint:CGPointMake(9.5f, 10.0f)];
	[speaker addLineToPoint:CGPointMake(13.0f, 6.0f)];
	[speaker addLineToPoint:CGPointMake(13.0f, 18.0f)];
	[speaker addLineToPoint:CGPointMake(9.5f, 14.0f)];
	[speaker addLineToPoint:CGPointMake(6.5f, 14.0f)];
	[speaker closePath];
	[speaker fill];

	UIBezierPath *slash = [UIBezierPath bezierPath];
	slash.lineWidth = 1.5f;
	slash.lineCapStyle = kCGLineCapRound;
	[slash moveToPoint:CGPointMake(15.5f, 9.0f)];
	[slash addLineToPoint:CGPointMake(19.5f, 15.0f)];
	[slash moveToPoint:CGPointMake(19.5f, 9.0f)];
	[slash addLineToPoint:CGPointMake(15.5f, 15.0f)];
	[[UIColor whiteColor] setStroke];
	[slash stroke];

	badge = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return badge;
}

static UIImage *TGNoteLockPlateImage(BOOL engaged) {
	CGFloat width = kNoteLockWidth;
	CGFloat height = kNoteLockHeight;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), NO, 0.0f);
	CGContextRef context = UIGraphicsGetCurrentContext();
	UIColor *accent = [[TGTheme shared] accentColour];

	CGRect plate = CGRectInset(CGRectMake(0, 0, width, height), 1.0f, 1.0f);
	CGFloat plateRadius = plate.size.width / 2;
	UIBezierPath *shell = [UIBezierPath bezierPathWithRoundedRect:plate cornerRadius:plateRadius];
	CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 2.0f,
		[UIColor colorWithWhite:0 alpha:0.25f].CGColor);
	[(engaged ? accent : [UIColor whiteColor]) setFill];
	[shell fill];
	CGContextSetShadowWithColor(context, CGSizeZero, 0, NULL);
	shell.lineWidth = 1.0f;
	[[UIColor colorWithWhite:0 alpha:0.15f] setStroke];
	[shell stroke];

	UIColor *ink = engaged ? [UIColor whiteColor] : accent;
	[ink setFill];
	[ink setStroke];

	CGFloat centre = width / 2;
	CGFloat bodyTop = 17.0f;
	CGPoint shackleCentre = CGPointMake(centre, bodyTop);
	UIBezierPath *shackle = [UIBezierPath
		bezierPathWithArcCenter:shackleCentre
						 radius:4.0f
					 startAngle:M_PI
					   endAngle:0
					  clockwise:YES];
	shackle.lineWidth = 1.5f;
	[shackle stroke];
	if (!engaged) {
		UIBezierPath *stem = [UIBezierPath bezierPath];
		stem.lineWidth = 1.5f;
		[stem moveToPoint:CGPointMake(centre + 4.0f, bodyTop)];
		[stem addLineToPoint:CGPointMake(centre + 4.0f, bodyTop + 2.5f)];
		[stem stroke];
	}
	[[UIBezierPath bezierPathWithRoundedRect:
			CGRectMake(centre - 6.0f, bodyTop, 12.0f, 10.0f)
								cornerRadius:2.0f] fill];

	if (!engaged) {
		UIBezierPath *chevron = [UIBezierPath bezierPath];
		chevron.lineWidth = 1.5f;
		chevron.lineCapStyle = kCGLineCapRound;
		chevron.lineJoinStyle = kCGLineJoinRound;
		[chevron moveToPoint:CGPointMake(centre - 4.0f, height - 8.0f)];
		[chevron addLineToPoint:CGPointMake(centre, height - 12.0f)];
		[chevron addLineToPoint:CGPointMake(centre + 4.0f, height - 8.0f)];
		[chevron stroke];
	}

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

static UIImage *TGNoteStopImage(BOOL pressed) {
	CGFloat side = kNoteControlSide;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0.0f);
	CGContextRef context = UIGraphicsGetCurrentContext();

	CGRect disc = CGRectInset(CGRectMake(0, 0, side, side), 5.0f, 5.0f);
	CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 1.5f,
		[UIColor colorWithWhite:0 alpha:0.25f].CGColor);
	CGContextSetFillColorWithColor(context,
		[TGNoteRecordColour() colorWithAlphaComponent:pressed ? 0.7f : 1.0f].CGColor);
	CGContextFillEllipseInRect(context, disc);
	CGContextSetShadowWithColor(context, CGSizeZero, 0, NULL);

	CGFloat inner = 13.0f;
	CGRect square = CGRectMake((side - inner) / 2, (side - inner) / 2, inner, inner);
	[[UIColor whiteColor] setFill];
	[[UIBezierPath bezierPathWithRoundedRect:square cornerRadius:2.0f] fill];

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

static UIColor *TGNoteDiscardColour(void) {
	return [UIColor colorWithRed:0.784f green:0.145f blue:0.114f alpha:1.0f];
}

static UIImage *TGNotePlateImage(NSString *name, UIColor *tint) {
	UIImage *art = [UIImage imageNamed:name];
	if (art == nil)
		return nil;
	UIImage *plate = art;
	if (tint != nil) {
		CGSize size = art.size;
		UIGraphicsBeginImageContextWithOptions(size, NO, art.scale);
		CGContextRef context = UIGraphicsGetCurrentContext();
		[art drawAtPoint:CGPointZero];
		CGContextSetBlendMode(context, kCGBlendModeColor);
		[tint setFill];
		CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
		[art drawAtPoint:CGPointZero blendMode:kCGBlendModeDestinationIn alpha:1.0f];
		plate = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
	}
	return [plate stretchableImageWithLeftCapWidth:(int)(art.size.width / 2)
									  topCapHeight:0];
}

@interface TGVideoCaptureViewController () <TGVideoRecorderDelegate>

@property (nonatomic, assign) BOOL roundVideoNote;
@property (nonatomic, assign) BOOL reviewing;
@property (nonatomic, assign) BOOL prepared;

@property (nonatomic, strong) TGVideoRecorder *recorder;

@property (nonatomic, strong) UIView *stage;
@property (nonatomic, strong) CAShapeLayer *progressRing;

@property (nonatomic, strong) UIView *topPanel;
@property (nonatomic, strong) UIView *bottomPanel;

@property (nonatomic, strong) UIButton *shutter;
@property (nonatomic, strong) UIButton *flip;
@property (nonatomic, strong) UIButton *cancel;
@property (nonatomic, strong) UIView *timeBadge;
@property (nonatomic, strong) UIView *timeDot;
@property (nonatomic, strong) UILabel *timeLabel;

@property (nonatomic, strong) UIButton *retake;
@property (nonatomic, strong) UIButton *send;

@property (nonatomic, strong) NSString *resultPath;
@property (nonatomic, assign) NSTimeInterval resultDuration;
@property (nonatomic, assign) CGSize resultDimensions;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) id circlePreviewReachedEndObserverToken;
@property (nonatomic, strong) id stagePreviewReachedEndObserverToken;

@property (nonatomic, assign) BOOL overlay;
@property (nonatomic, assign) CGRect controlsFrame;
@property (nonatomic, assign) CGRect overlayBounds;
@property (nonatomic, assign) TGNoteStage noteStage;
@property (nonatomic, assign) BOOL locked;
@property (nonatomic, assign) BOOL holding;
@property (nonatomic, assign) BOOL startWhenReady;
@property (nonatomic, assign) BOOL sendWhenFinished;
@property (nonatomic, assign) BOOL previewMuted;
@property (nonatomic, assign) BOOL sendingResult;

@property (nonatomic, strong) UIView *curtain;
@property (nonatomic, strong) UIView *circleWrapper;
@property (nonatomic, strong) UIView *circle;
@property (nonatomic, strong) UIView *circleRim;
@property (nonatomic, strong) CAShapeLayer *noteRing;
@property (nonatomic, strong) UIImageView *muteBadge;
@property (nonatomic, strong) UIImageView *lockPlate;

@property (nonatomic, strong) UIView *controlsRow;
@property (nonatomic, strong) UIView *noteDot;
@property (nonatomic, strong) UILabel *noteClock;
@property (nonatomic, strong) UILabel *noteSlide;
@property (nonatomic, strong) UIButton *noteCancel;
@property (nonatomic, strong) UIButton *noteStop;
@property (nonatomic, strong) UIButton *noteDiscard;
@property (nonatomic, strong) UIButton *noteSend;
@property (nonatomic, assign) CGFloat slideFree;

@end

@implementation TGVideoCaptureViewController

- (id)initWithRoundVideoNote:(BOOL)round {
	self = [super initWithNibName:nil bundle:nil];
	if (self) {
		_roundVideoNote = round;
		TGVideoRecorderMode mode = round ? TGVideoRecorderModeNote : TGVideoRecorderModeVideo;
		_recorder = [[TGVideoRecorder alloc] initWithMode:mode];
		_recorder.delegate = self;
		_maximumDuration = _recorder.maximumDuration;
		_minimumDuration = kVideoCaptureMinimum;
		_previewMuted = YES;
		self.wantsFullScreenLayout = YES;
	}
	return self;
}

- (id)initWithNibName:(NSString *)name bundle:(NSBundle *)bundle {
	return [self initWithRoundVideoNote:NO];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (_circlePreviewReachedEndObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_circlePreviewReachedEndObserverToken];
	if (_stagePreviewReachedEndObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_stagePreviewReachedEndObserverToken];
	[_player pause];
	_recorder.delegate = nil;
	[_recorder teardown];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	if (self.roundVideoNote) {
		self.view.backgroundColor = [UIColor clearColor];
		[self buildNoteOverlay];
		return;
	}

	self.view.backgroundColor = [UIColor colorWithRed:0x22 / 255.0f green:0x22 / 255.0f
												 blue:0x22 / 255.0f
												alpha:1.0f];
	[self.navigationController setNavigationBarHidden:YES animated:NO];

	[self buildStage];
	[self buildTopPanel];
	[self buildBottomPanel];
	[self updateChrome];
}

#pragma mark - round note overlay

- (void)presentOverParent:(UIViewController *)parent controlsFrame:(CGRect)controlsFrame {
	if (parent == nil || !self.roundVideoNote)
		return;

	self.overlay = YES;
	self.controlsFrame = controlsFrame;
	self.overlayBounds = parent.view.bounds;

	[parent addChildViewController:self];
	self.view.frame = parent.view.bounds;
	[parent.view addSubview:self.view];
	[self didMoveToParentViewController:parent];

	[self transitionNoteIn];
}

- (void)buildNoteOverlay {
	CGRect bounds =
		CGRectIsEmpty(self.overlayBounds) ? self.view.bounds : self.overlayBounds;
	CGRect row = self.controlsFrame;
	if (CGRectIsEmpty(row))
		row = CGRectMake(0, bounds.size.height - 43.0f, bounds.size.width, 43.0f);

	self.curtain = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, bounds.size.width, CGRectGetMinY(row))];
	self.curtain.backgroundColor = [UIColor colorWithWhite:1 alpha:0.6f];
	self.curtain.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.view addSubview:self.curtain];

	CGFloat wrapperSide = kNoteCircleSide + kNoteShadowInset * 2;
	CGFloat wrapperY = floorf((CGRectGetMinY(row) - wrapperSide) / 2);
	if (wrapperY < 4.0f)
		wrapperY = 4.0f;
	CGRect wrapperFrame = CGRectMake(floorf((bounds.size.width - wrapperSide) / 2), wrapperY,
		wrapperSide, wrapperSide);
	self.circleWrapper = [[UIView alloc] initWithFrame:wrapperFrame];
	self.circleWrapper.backgroundColor = [UIColor clearColor];
	[self.view addSubview:self.circleWrapper];

	CGRect rimFrame = CGRectInset(self.circleWrapper.bounds,
		kNoteShadowInset - 2.0f, kNoteShadowInset - 2.0f);
	self.circleRim = [[UIView alloc] initWithFrame:rimFrame];
	self.circleRim.backgroundColor = [UIColor whiteColor];
	self.circleRim.layer.cornerRadius = rimFrame.size.width / 2;
	self.circleRim.layer.shadowColor = [UIColor blackColor].CGColor;
	self.circleRim.layer.shadowOpacity = 0.32f;
	self.circleRim.layer.shadowRadius = 10.0f;
	self.circleRim.layer.shadowOffset = CGSizeMake(0, 2);
	self.circleRim.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:
										   self.circleRim.bounds]
										  .CGPath;
	[self.circleWrapper addSubview:self.circleRim];

	CGRect circleFrame = CGRectMake(kNoteShadowInset, kNoteShadowInset, kNoteCircleSide, kNoteCircleSide);
	self.circle = [[UIView alloc] initWithFrame:circleFrame];
	self.circle.backgroundColor = [UIColor blackColor];
	self.circle.layer.cornerRadius = kNoteCircleSide / 2;
	self.circle.layer.masksToBounds = YES;
	[self.circleWrapper addSubview:self.circle];
	self.stage = self.circle;

	self.noteRing = [CAShapeLayer layer];
	self.noteRing.frame = CGRectMake(
		floorf((wrapperSide - kNoteRingSide) / 2),
		floorf((wrapperSide - kNoteRingSide) / 2),
		kNoteRingSide, kNoteRingSide);
	CGRect ringRect = CGRectInset(CGRectMake(0, 0, kNoteRingSide, kNoteRingSide),
		kNoteRingWidth / 2, kNoteRingWidth / 2);
	self.noteRing.path = [UIBezierPath bezierPathWithOvalInRect:ringRect].CGPath;
	self.noteRing.fillColor = [UIColor clearColor].CGColor;
	self.noteRing.strokeColor = [[TGTheme shared] accentColour].CGColor;
	self.noteRing.lineWidth = kNoteRingWidth;
	self.noteRing.lineCap = kCALineCapRound;
	self.noteRing.strokeStart = 0.0f;
	self.noteRing.strokeEnd = 0.0f;
	self.noteRing.transform = CATransform3DMakeRotation(-M_PI_2, 0, 0, 1);
	[self.circleWrapper.layer addSublayer:self.noteRing];

	self.muteBadge = [[UIImageView alloc] initWithImage:TGNoteMuteBadgeImage()];
	self.muteBadge.frame = CGRectMake(
		floorf(CGRectGetMidX(self.circle.bounds) - kNoteMuteSide / 2),
		CGRectGetMaxY(self.circle.bounds) - kNoteMuteSide - 8.0f,
		kNoteMuteSide, kNoteMuteSide);
	self.muteBadge.hidden = YES;
	[self.circle addSubview:self.muteBadge];

	UITapGestureRecognizer *unmute = [[UITapGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(previewTapped)];
	[self.circle addGestureRecognizer:unmute];
	self.circle.userInteractionEnabled = YES;

	[self buildNoteControlsRow:row];

	self.lockPlate = [[UIImageView alloc] initWithImage:TGNoteLockPlateImage(NO)];
	self.lockPlate.frame = CGRectMake(
		bounds.size.width - kNoteLockWidth - 14.0f,
		CGRectGetMinY(row) - kNoteLockHeight - 12.0f,
		kNoteLockWidth, kNoteLockHeight);
	self.lockPlate.alpha = 0.0f;
	[self.view addSubview:self.lockPlate];
}

- (void)buildNoteControlsRow:(CGRect)row {
	self.controlsRow = [[UIView alloc] initWithFrame:row];
	self.controlsRow.backgroundColor = [[TGTheme shared] inputBarColour];
	self.controlsRow.clipsToBounds = YES;
	[self.view addSubview:self.controlsRow];

	UIImage *strip = [UIImage imageNamed:@"ConversationInputPanel_Background"];
	if (strip != nil) {
		UIImageView *stripView = [[UIImageView alloc] initWithFrame:
				self.controlsRow.bounds];
		stripView.image = [strip stretchableImageWithLeftCapWidth:0 topCapHeight:0];
		stripView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleHeight;
		stripView.userInteractionEnabled = NO;
		[self.controlsRow addSubview:stripView];
	}

	UIImage *shadow = [UIImage imageNamed:@"ChatInputContainer_Shadow"];
	if (shadow != nil) {
		CGRect shadowFrame = CGRectMake(0, 0, row.size.width, shadow.size.height);
		UIImageView *shadowView = [[UIImageView alloc] initWithFrame:shadowFrame];
		shadowView.image = [shadow stretchableImageWithLeftCapWidth:0 topCapHeight:0];
		shadowView.userInteractionEnabled = NO;
		[self.controlsRow addSubview:shadowView];
	} else {
		UIView *hair = [[UIView alloc] initWithFrame:CGRectMake(0, 0, row.size.width, 1)];
		hair.backgroundColor = [[TGTheme shared] separatorColour];
		[self.controlsRow addSubview:hair];
	}

	CGFloat height = row.size.height;

	CGRect dotFrame = CGRectMake(11.0f, floorf((height - 9.0f) / 2), 9.0f, 9.0f);
	self.noteDot = [[UIView alloc] initWithFrame:dotFrame];
	self.noteDot.backgroundColor = TGNoteRecordColour();
	self.noteDot.layer.cornerRadius = 4.5f;
	[self.controlsRow addSubview:self.noteDot];

	CGRect clockFrame = CGRectMake(26.0f, floorf((height - 20.0f) / 2), 76.0f, 20.0f);
	self.noteClock = [[UILabel alloc] initWithFrame:clockFrame];
	self.noteClock.backgroundColor = [UIColor clearColor];
	self.noteClock.font = [UIFont systemFontOfSize:15];
	self.noteClock.textColor = [[TGTheme shared] primaryTextColour];
	self.noteClock.text = @"0:00,0";
	[self.controlsRow addSubview:self.noteClock];

	self.noteSlide = [[UILabel alloc] initWithFrame:CGRectZero];
	self.noteSlide.backgroundColor = [UIColor clearColor];
	self.noteSlide.font = [UIFont systemFontOfSize:15];
	self.noteSlide.textColor = TGNoteHintColour();
	self.noteSlide.text = TGL(@"Conversation.SlideToCancel", @"‹ Slide to cancel");
	[self.noteSlide sizeToFit];
	self.noteSlide.frame = CGRectMake(
		floorf((row.size.width - self.noteSlide.frame.size.width) / 2),
		floorf((height - self.noteSlide.frame.size.height) / 2),
		self.noteSlide.frame.size.width, self.noteSlide.frame.size.height);
	[self.controlsRow addSubview:self.noteSlide];

	self.slideFree = MAX(0.0f, CGRectGetMinX(self.noteSlide.frame) - 6.0f - CGRectGetMaxX(self.noteClock.frame));

	self.noteCancel = [UIButton buttonWithType:UIButtonTypeCustom];
	self.noteCancel.titleLabel.font = [UIFont systemFontOfSize:17];
	[self.noteCancel setTitle:TGL(@"Common.Cancel", @"Cancel") forState:UIControlStateNormal];
	[self.noteCancel setTitleColor:[[TGTheme shared] accentColour]
						  forState:UIControlStateNormal];
	[self.noteCancel setTitleColor:[[[TGTheme shared] accentColour]
									   colorWithAlphaComponent:0.5f]
						  forState:UIControlStateHighlighted];
	[self.noteCancel sizeToFit];
	self.noteCancel.frame = CGRectMake(
		floorf((row.size.width - self.noteCancel.frame.size.width) / 2),
		floorf((height - self.noteCancel.frame.size.height) / 2),
		self.noteCancel.frame.size.width, self.noteCancel.frame.size.height);
	self.noteCancel.alpha = 0.0f;
	[self.noteCancel addTarget:self action:@selector(cancelPressed)
			  forControlEvents:UIControlEventTouchUpInside];
	[self.controlsRow addSubview:self.noteCancel];

	self.noteStop = [UIButton buttonWithType:UIButtonTypeCustom];
	self.noteStop.exclusiveTouch = YES;
	self.noteStop.frame = CGRectMake(row.size.width - kNoteControlSide - 4.0f,
		floorf((height - kNoteControlSide) / 2),
		kNoteControlSide, kNoteControlSide);
	[self.noteStop setImage:TGNoteStopImage(NO) forState:UIControlStateNormal];
	[self.noteStop setImage:TGNoteStopImage(YES) forState:UIControlStateHighlighted];
	self.noteStop.alpha = 0.0f;
	self.noteStop.userInteractionEnabled = NO;
	self.noteStop.accessibilityLabel = TGL(@"VoiceOver.Recording.StopAndPreview", @"Stop and preview");
	[self.noteStop addTarget:self action:@selector(stopPressed)
			forControlEvents:UIControlEventTouchUpInside];
	[self.controlsRow addSubview:self.noteStop];

	self.noteDiscard = [self plateButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")
											 tint:TGNoteDiscardColour()
										   action:@selector(cancelPressed)];
	self.noteDiscard.frame = CGRectMake(5.0f, floorf((height - 29.0f) / 2), 62.0f, 29.0f);
	[self.controlsRow addSubview:self.noteDiscard];

	self.noteSend = [self plateButtonWithTitle:TGL(@"MediaPicker.Send", @"Send") tint:nil
										action:@selector(sendPressed)];
	self.noteSend.frame = CGRectMake(row.size.width - 67.0f,
		floorf((height - 29.0f) / 2), 62.0f, 29.0f);
	[self.controlsRow addSubview:self.noteSend];
}

- (UIButton *)plateButtonWithTitle:(NSString *)title tint:(UIColor *)tint
							action:(SEL)action {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.exclusiveTouch = YES;
	button.titleLabel.font = [UIFont boldSystemFontOfSize:14.5f];
	button.titleLabel.shadowOffset = CGSizeMake(0, -1);
	[button setTitle:title forState:UIControlStateNormal];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[button setTitleShadowColor:[UIColor colorWithWhite:0.0f alpha:0.3f]
					   forState:UIControlStateNormal];
	UIImage *plate = TGNotePlateImage(@"SendButton", tint);
	if (plate != nil) {
		[button setBackgroundImage:plate forState:UIControlStateNormal];
		UIImage *pressed = TGNotePlateImage(@"SendButton_Pressed", tint);
		if (pressed != nil)
			[button setBackgroundImage:pressed forState:UIControlStateHighlighted];
	} else {
		button.backgroundColor = tint ?: [[TGTheme shared] accentColour];
		button.layer.cornerRadius = 4.0f;
	}
	button.alpha = 0.0f;
	button.userInteractionEnabled = NO;
	[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	return button;
}

- (void)transitionNoteIn {
	self.curtain.alpha = 0.0f;
	self.controlsRow.alpha = 0.0f;
	self.circleWrapper.alpha = 0.0f;
	self.circleWrapper.transform = CGAffineTransformMakeScale(0.3f, 0.3f);

	[UIView animateWithDuration:0.25 animations:^{
		self.curtain.alpha = 1.0f;
		self.controlsRow.alpha = 1.0f;
		self.circleWrapper.alpha = 1.0f;
	}];
	[UIView animateWithDuration:0.22 delay:0.0
		options:UIViewAnimationOptionCurveEaseOut animations:^{
			self.circleWrapper.transform = CGAffineTransformMakeScale(1.05f, 1.05f);
		} completion:^(BOOL finished) {
			[UIView animateWithDuration:0.12 animations:^{
				self.circleWrapper.transform = CGAffineTransformIdentity;
			}];
		}];
}

- (void)dismissOverlay {
	self.view.userInteractionEnabled = NO;
	[UIView animateWithDuration:0.15 animations:^{
		self.circleWrapper.alpha = 0.0f;
		self.circleWrapper.transform = CGAffineTransformMakeScale(0.3f, 0.3f);
		self.curtain.alpha = 0.0f;
		self.controlsRow.alpha = 0.0f;
		self.lockPlate.alpha = 0.0f;
	} completion:^(BOOL finished) {
		[self willMoveToParentViewController:nil];
		[self.view removeFromSuperview];
		[self removeFromParentViewController];
	}];
}

#pragma mark - round note gesture

- (void)beginHold {
	self.holding = YES;
	self.startWhenReady = YES;
	self.sendWhenFinished = YES;
	if (!self.prepared)
		[self startSession];
	if (self.recorder.ready)
		[self beginRecording];
}

- (void)holdMovedBy:(CGPoint)offset {
	if (!self.holding || self.noteStage == TGNoteStagePreview)
		return;

	if (offset.x < -kNoteCancelSlide) {
		[self cancelHold];
		return;
	}
	if (offset.y < -kNoteLockRise) {
		[self engageLock];
		return;
	}

	CGFloat slide = MAX(0.0f, -offset.x - 5.0f);
	self.noteSlide.transform = CGAffineTransformMakeTranslation(-slide, 0);
	CGFloat free = self.slideFree;
	CGFloat drag = slide > free ? free - slide : 0.0f;
	self.noteDot.transform = CGAffineTransformMakeTranslation(drag, 0);
	self.noteClock.transform = CGAffineTransformMakeTranslation(drag, 0);

	CGFloat rise = MIN(kNoteLockRise, MAX(0.0f, -offset.y));
	self.lockPlate.alpha = MIN(1.0f, rise / 12.0f);
	self.lockPlate.transform = CGAffineTransformMakeTranslation(0, -rise / 4.0f);
}

- (void)engageLock {
	if (self.locked)
		return;
	self.locked = YES;
	self.holding = NO;
	self.sendWhenFinished = NO;

	self.lockPlate.image = TGNoteLockPlateImage(YES);
	self.lockPlate.alpha = 1.0f;
	[UIView animateWithDuration:0.2 animations:^{
		self.lockPlate.transform = CGAffineTransformMakeTranslation(0, -kNoteLockRise / 4.0f);
	} completion:^(BOOL finished) {
		[UIView animateWithDuration:0.25 delay:0.25 options:0 animations:^{
			self.lockPlate.alpha = 0.0f;
		} completion:nil];
	}];

	CGAffineTransform gone = CGAffineTransformScale(
		CGAffineTransformMakeTranslation(0, -22.0f), 0.25f, 0.25f);
	self.noteCancel.transform = CGAffineTransformScale(
		CGAffineTransformMakeTranslation(0, 22.0f), 0.25f, 0.25f);
	self.noteCancel.alpha = 0.0f;
	self.noteStop.transform = CGAffineTransformMakeScale(0.4f, 0.4f);

	[UIView animateWithDuration:0.3 animations:^{
		self.noteSlide.transform = gone;
		self.noteSlide.alpha = 0.0f;
		self.noteCancel.transform = CGAffineTransformIdentity;
		self.noteCancel.alpha = 1.0f;
		self.noteStop.transform = CGAffineTransformIdentity;
		self.noteStop.alpha = 1.0f;
	} completion:nil];
	self.noteStop.userInteractionEnabled = YES;
}

- (void)endHold {
	if (!self.holding)
		return;
	self.holding = NO;

	if (self.noteStage != TGNoteStageRecording) {
		[self cancelHold];
		return;
	}
	if (self.recorder.duration < self.minimumDuration) {
		[self cancelHold];
		return;
	}
	self.sendWhenFinished = YES;
	[self stopNoteRecordingChrome];
	[self.recorder stopRecording];
}

- (void)cancelHold {
	self.holding = NO;
	self.sendWhenFinished = NO;
	if (self.recorder.recording)
		[self.recorder cancel];
	[self cancelPressed];
}

- (void)beginLockedRecording {
	self.startWhenReady = YES;
	self.sendWhenFinished = NO;
	self.holding = NO;
	if (!self.prepared)
		[self startSession];
	if (self.recorder.ready)
		[self beginRecording];

	self.noteSlide.alpha = 0.0f;
	self.noteCancel.alpha = 1.0f;
	self.noteStop.alpha = 1.0f;
	self.noteStop.userInteractionEnabled = YES;
	self.locked = YES;
}

- (void)stopPressed {
	self.noteStop.userInteractionEnabled = NO;
	self.sendWhenFinished = NO;
	if (self.recorder.recording) {
		[self stopNoteRecordingChrome];
		[self.recorder stopRecording];
	}
}

#pragma mark - round note recording chrome

- (void)showNoteRecordingChrome {
	CAKeyframeAnimation *blink = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
	blink.values = @[ @1.0f, @1.0f, @0.0f ];
	blink.keyTimes = @[ @0.0f, @0.4546f, @1.0f ];
	blink.duration = 0.5;
	blink.autoreverses = YES;
	blink.repeatCount = HUGE_VALF;
	[self.noteDot.layer addAnimation:blink forKey:@"blink"];

	CABasicAnimation *fill = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
	fill.fromValue = @0.0f;
	fill.toValue = @1.0f;
	fill.duration = self.maximumDuration;
	fill.timingFunction = [CAMediaTimingFunction
		functionWithName:kCAMediaTimingFunctionLinear];
	fill.fillMode = kCAFillModeForwards;
	fill.removedOnCompletion = NO;
	[self.noteRing addAnimation:fill forKey:@"fill"];
}

- (void)stopNoteRecordingChrome {
	[self.noteDot.layer removeAnimationForKey:@"blink"];
	[self.noteRing removeAnimationForKey:@"fill"];
	[UIView animateWithDuration:0.2 animations:^{
		self.noteDot.alpha = 0.0f;
		self.noteDot.transform = CGAffineTransformMakeTranslation(-90.0f, 0);
		self.noteClock.alpha = 0.0f;
		self.noteClock.transform = CGAffineTransformMakeTranslation(-90.0f, 0);
		self.noteSlide.alpha = 0.0f;
		self.noteCancel.alpha = 0.0f;
		self.noteStop.alpha = 0.0f;
		self.lockPlate.alpha = 0.0f;
	} completion:nil];
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	self.noteRing.strokeEnd = 0.0f;
	[CATransaction commit];
	[UIView animateWithDuration:0.2 animations:^{
		self.noteRing.opacity = 0.0f;
	}];
}

- (void)enterNotePreview {
	self.noteStage = TGNoteStagePreview;
	self.reviewing = YES;
	[self stopSession];

	self.noteDiscard.transform = CGAffineTransformMakeScale(0.6f, 0.6f);
	self.noteSend.transform = CGAffineTransformMakeScale(0.6f, 0.6f);
	[UIView animateWithDuration:0.25 delay:0.1 options:0 animations:^{
		self.noteDiscard.alpha = 1.0f;
		self.noteDiscard.transform = CGAffineTransformIdentity;
		self.noteSend.alpha = 1.0f;
		self.noteSend.transform = CGAffineTransformIdentity;
	} completion:nil];
	self.noteDiscard.userInteractionEnabled = YES;
	self.noteSend.userInteractionEnabled = YES;

	self.player = [TGAVClass(AVPlayer) playerWithURL:[NSURL fileURLWithPath:self.resultPath]];
	self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
	self.playerLayer = [TGAVClass(AVPlayerLayer) playerLayerWithPlayer:self.player];
	self.playerLayer.videoGravity = TGAVString(AVLayerVideoGravityResizeAspectFill);
	self.playerLayer.frame = self.circle.bounds;
	[self.circle.layer insertSublayer:self.playerLayer atIndex:0];

	self.previewMuted = YES;
	[self applyPreviewVolume:0.0f];
	self.muteBadge.hidden = NO;
	self.muteBadge.alpha = 1.0f;
	self.muteBadge.transform = CGAffineTransformIdentity;
	[self.circle bringSubviewToFront:self.muteBadge];

	__weak typeof(self) weakSelf = self;
	self.circlePreviewReachedEndObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGAVString(AVPlayerItemDidPlayToEndTimeNotification)
					object:self.player.currentItem
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf playbackReachedEnd:note];
				}];
	[self.player play];

	self.recorder.previewLayer.hidden = YES;
}

- (void)applyPreviewVolume:(float)volume {
	AVPlayerItem *item = self.player.currentItem;
	AVAssetTrack *track = [[item.asset tracksWithMediaType:TGAVString(AVMediaTypeAudio)] firstObject];
	if (track == nil)
		return;
	AVMutableAudioMixInputParameters *parameters =
		[TGAVClass(AVMutableAudioMixInputParameters) audioMixInputParametersWithTrack:track];
	[parameters setVolume:volume atTime:kCMTimeZero];
	AVMutableAudioMix *mix = [TGAVClass(AVMutableAudioMix) audioMix];
	mix.inputParameters = @[ parameters ];
	item.audioMix = mix;
}

- (void)setPreviewMutedState:(BOOL)muted {
	if (muted == self.previewMuted)
		return;
	self.previewMuted = muted;
	[self applyPreviewVolume:muted ? 0.0f : 1.0f];

	UIView *badge = self.muteBadge;
	[badge.layer removeAllAnimations];
	CGAffineTransform shrunk = CGAffineTransformMakeScale(0.01f, 0.01f);
	if (badge.transform.a < 0.3f || badge.alpha < 0.01f) {
		badge.transform = shrunk;
		badge.alpha = 0.0f;
	}
	[UIView animateWithDuration:0.3 delay:0.0
						options:UIViewAnimationOptionBeginFromCurrentState animations:^{
							badge.transform = muted ? CGAffineTransformIdentity : shrunk;
						}
					 completion:nil];
	[UIView animateWithDuration:0.2 delay:0.0
						options:UIViewAnimationOptionBeginFromCurrentState animations:^{
							badge.alpha = muted ? 1.0f : 0.0f;
						}
					 completion:nil];
}

- (void)previewTapped {
	if (self.noteStage != TGNoteStagePreview || !self.previewMuted)
		return;
	[self setPreviewMutedState:NO];
	[self.player seekToTime:kCMTimeZero];
	[self.player play];
}

#pragma mark - full screen camera

- (CGFloat)topPanelHeight {
	return self.view.bounds.size.height > 440.0f ? 112.0f : 68.0f;
}

- (CGFloat)bottomPanelHeight {
	return self.view.bounds.size.height > 440.0f ? 136.0f : 92.0f;
}

- (void)buildStage {
	self.stage = [[UIView alloc] initWithFrame:self.view.bounds];
	self.stage.backgroundColor = [UIColor blackColor];
	self.stage.clipsToBounds = YES;
	[self.view addSubview:self.stage];
}

- (void)attachPreviewLayer {
	CALayer *preview = self.recorder.previewLayer;
	if (preview == nil || self.stage == nil)
		return;
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	preview.frame = self.stage.bounds;
	[CATransaction commit];
	if (preview.superlayer != self.stage.layer)
		[self.stage.layer insertSublayer:preview atIndex:0];
	preview.hidden = self.reviewing;
}

- (UIButton *)panelTextButtonWithTitle:(NSString *)title {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.exclusiveTouch = YES;
	button.showsTouchWhenHighlighted = YES;
	button.titleLabel.font = [UIFont boldSystemFontOfSize:14];
	button.titleLabel.shadowOffset = CGSizeMake(0, 1);
	[button setTitle:title forState:UIControlStateNormal];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[button setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.3f]
					   forState:UIControlStateNormal];
	return button;
}

- (UIButton *)plateButtonWithTitle:(NSString *)title green:(BOOL)green {
	NSString *normal = green ? @"GroupedActionButtonGreen.png" : @"GroupedActionButton.png";
	NSString *pressed = green ? @"GroupedActionButtonGreen_Highlighted.png"
							  : @"GroupedActionButton_Highlighted.png";
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.exclusiveTouch = YES;
	button.titleLabel.font = [UIFont boldSystemFontOfSize:16];
	button.titleLabel.shadowOffset = CGSizeMake(0, -1);
	UIImage *normalImage = [UIImage imageNamed:normal];
	[button setBackgroundImage:[normalImage stretchableImageWithLeftCapWidth:24 topCapHeight:0]
					  forState:UIControlStateNormal];
	UIImage *pressedImage = [UIImage imageNamed:pressed];
	[button setBackgroundImage:[pressedImage stretchableImageWithLeftCapWidth:24 topCapHeight:0]
					  forState:UIControlStateHighlighted];
	[button setTitle:title forState:UIControlStateNormal];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[button setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.3f]
					   forState:UIControlStateNormal];
	return button;
}

- (void)buildTopPanel {
	CGRect bounds = self.view.bounds;
	CGFloat height = [self topPanelHeight];

	self.topPanel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, height)];
	self.topPanel.backgroundColor = [UIColor clearColor];
	UIImageView *background = [[UIImageView alloc] initWithFrame:self.topPanel.bounds];
	background.image = [[UIImage imageNamed:@"CameraStripeTop.png"]
		stretchableImageWithLeftCapWidth:6
							topCapHeight:20];
	background.userInteractionEnabled = NO;
	[self.topPanel addSubview:background];
	[self.view addSubview:self.topPanel];

	CGFloat row = height - 40.0f;

	self.timeBadge = [[UIView alloc] initWithFrame:CGRectMake(12, row, 92, 26)];
	self.timeBadge.backgroundColor = [UIColor clearColor];
	self.timeBadge.hidden = YES;
	[self.topPanel addSubview:self.timeBadge];

	self.timeDot = [[UIView alloc] initWithFrame:CGRectMake(0, 9, 8, 8)];
	self.timeDot.backgroundColor = TGNoteRecordColour();
	self.timeDot.layer.cornerRadius = 4.0f;
	[self.timeBadge addSubview:self.timeDot];

	self.timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 3, 78, 20)];
	self.timeLabel.backgroundColor = [UIColor clearColor];
	self.timeLabel.textColor = [UIColor whiteColor];
	self.timeLabel.font = [UIFont boldSystemFontOfSize:15];
	self.timeLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.4f];
	self.timeLabel.shadowOffset = CGSizeMake(0, 1);
	self.timeLabel.text = @"0:00";
	[self.timeBadge addSubview:self.timeLabel];

	UIImage *reverseArt = [UIImage imageNamed:@"Camera_Reverse.png"];
	if (reverseArt) {
		self.flip = [UIButton buttonWithType:UIButtonTypeCustom];
		self.flip.exclusiveTouch = YES;
		self.flip.showsTouchWhenHighlighted = YES;
		[self.flip setImage:reverseArt forState:UIControlStateNormal];
	} else {
		self.flip = [self panelTextButtonWithTitle:TGL(@"Paint.Flip", @"Flip")];
	}
	self.flip.accessibilityLabel = TGL(@"VoiceOver.Camera.Flip", @"Switch camera");
	CGSize flipSize = reverseArt ? reverseArt.size : CGSizeMake(80, 26);
	self.flip.frame = CGRectMake((int)((bounds.size.width - flipSize.width) / 2),
		(int)(row + 13 - flipSize.height / 2),
		flipSize.width, flipSize.height);
	[self.flip addTarget:self action:@selector(flipPressed)
		forControlEvents:UIControlEventTouchUpInside];
	[self.topPanel addSubview:self.flip];

	self.cancel = [self panelTextButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	self.cancel.frame = CGRectMake(bounds.size.width - 88, row, 76, 26);
	[self.cancel addTarget:self action:@selector(cancelPressed)
		  forControlEvents:UIControlEventTouchUpInside];
	[self.topPanel addSubview:self.cancel];
}

- (void)buildBottomPanel {
	CGRect bounds = self.view.bounds;
	CGFloat height = [self bottomPanelHeight];

	CGRect bottomFrame = CGRectMake(0, bounds.size.height - height, bounds.size.width, height);
	self.bottomPanel = [[UIView alloc] initWithFrame:bottomFrame];
	self.bottomPanel.backgroundColor = [UIColor clearColor];
	UIImageView *background = [[UIImageView alloc] initWithFrame:self.bottomPanel.bounds];
	background.image = [[UIImage imageNamed:@"CameraStripeBottom.png"]
		stretchableImageWithLeftCapWidth:6
							topCapHeight:0];
	background.userInteractionEnabled = NO;
	[self.bottomPanel addSubview:background];
	[self.view addSubview:self.bottomPanel];

	CGFloat side = kVideoCaptureShutterSide;
	self.shutter = [UIButton buttonWithType:UIButtonTypeCustom];
	self.shutter.exclusiveTouch = YES;
	self.shutter.frame = CGRectMake((int)((bounds.size.width - side) / 2),
		(int)(height - side - 14), side, side);
	[self.shutter setBackgroundImage:TGVideoCaptureShutterImage(NO, NO)
							forState:UIControlStateNormal];
	[self.shutter setBackgroundImage:TGVideoCaptureShutterImage(NO, YES)
							forState:UIControlStateHighlighted];
	self.shutter.accessibilityLabel = TGL(@"VoiceOver.Camera.Shutter", @"Record");
	[self.shutter addTarget:self action:@selector(shutterPressed)
		   forControlEvents:UIControlEventTouchUpInside];
	[self.bottomPanel addSubview:self.shutter];

	self.retake = [self plateButtonWithTitle:TGL(@"Camera.Retake", @"Retake") green:NO];
	self.retake.frame = CGRectMake(12, (int)(height - 43 - 20), 130, 43);
	self.retake.hidden = YES;
	[self.retake addTarget:self action:@selector(retakePressed)
		  forControlEvents:UIControlEventTouchUpInside];
	[self.bottomPanel addSubview:self.retake];

	self.send = [self plateButtonWithTitle:TGL(@"MediaPicker.Send", @"Send") green:YES];
	self.send.frame = CGRectMake(bounds.size.width - 142, (int)(height - 43 - 20), 130, 43);
	self.send.hidden = YES;
	[self.send addTarget:self action:@selector(sendPressed)
		forControlEvents:UIControlEventTouchUpInside];
	[self.bottomPanel addSubview:self.send];
}

#pragma mark - lifecycle

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (!self.overlay)
		[self.navigationController setNavigationBarHidden:YES animated:animated];
	if (!self.reviewing)
		[self startSession];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self.player pause];
	[self stopSession];
}

- (BOOL)shouldAutorotate {
	return NO;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
	return orientation == UIInterfaceOrientationPortrait;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskPortrait;
}

- (void)startSession {
	if (!self.prepared) {
		self.prepared = YES;
		[self.recorder prepare];
	}
	[self attachPreviewLayer];
	self.shutter.enabled = self.recorder.ready;
	[self updateChrome];
}

- (void)stopSession {
	if (!self.prepared)
		return;
	self.prepared = NO;
	[self.recorder teardown];
}

- (void)shutterPressed {
	if (self.recorder.recording)
		[self.recorder stopRecording];
	else
		[self beginRecording];
}

- (void)beginRecording {
	if (!self.prepared)
		[self startSession];
	self.startWhenReady = NO;
	[self.recorder startRecording];
}

- (void)showRecordingChrome {
	[self.shutter setBackgroundImage:TGVideoCaptureShutterImage(YES, NO)
							forState:UIControlStateNormal];
	[self.shutter setBackgroundImage:TGVideoCaptureShutterImage(YES, YES)
							forState:UIControlStateHighlighted];
	self.shutter.accessibilityLabel = TGL(@"VoiceOver.Camera.StopRecording", @"Stop recording");
	self.timeBadge.hidden = NO;
	self.timeDot.hidden = NO;
	self.timeDot.alpha = 1.0f;
	self.timeLabel.text = @"0:00";
	self.cancel.hidden = YES;
	self.flip.hidden = YES;
}

- (void)setElapsedText:(NSTimeInterval)elapsed {
	NSInteger seconds = (NSInteger)elapsed;
	if (seconds < 0)
		seconds = 0;
	self.timeLabel.text = TGDurationText(seconds);
}

#pragma mark - recorder

- (void)videoRecorderDidBecomeReady:(TGVideoRecorder *)recorder {
	[self attachPreviewLayer];
	self.shutter.enabled = YES;
	[self updateChrome];
	if (self.startWhenReady && !recorder.recording)
		[self beginRecording];
}

- (void)videoRecorderDidStartRecording:(TGVideoRecorder *)recorder {
	if (self.roundVideoNote) {
		self.noteStage = TGNoteStageRecording;
		[self showNoteRecordingChrome];
		return;
	}
	[self showRecordingChrome];
}

- (void)videoRecorder:(TGVideoRecorder *)recorder
	didUpdateDuration:(NSTimeInterval)duration
			 progress:(float)progress {
	if (self.roundVideoNote) {
		NSInteger whole = (NSInteger)duration;
		self.noteClock.text = [NSString stringWithFormat:@"%d:%02d,%d",
			(int)(whole / 60), (int)(whole % 60), (int)(duration * 10) % 10];
		return;
	}

	[self setElapsedText:duration];
	self.timeDot.alpha = ((NSInteger)(duration * 2)) % 2 == 0 ? 1.0f : 0.2f;

	if (self.progressRing != nil) {
		CGFloat fraction = progress;
		if (fraction < 0.0f)
			fraction = 0.0f;
		if (fraction > 1.0f)
			fraction = 1.0f;
		[CATransaction begin];
		[CATransaction setDisableActions:YES];
		self.progressRing.strokeEnd = fraction;
		[CATransaction commit];
	}
}

- (void)videoRecorder:(TGVideoRecorder *)recorder
	didFinishRecordingToPath:(NSString *)path
					duration:(NSTimeInterval)duration
				  dimensions:(CGSize)dimensions {
	self.holding = NO;
	self.timeDot.alpha = 1.0f;
	if (path.length == 0 || duration < self.minimumDuration) {
		if (path.length)
			[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
		if (self.roundVideoNote) {
			[self cancelPressed];
			return;
		}
		[self resetToCamera];
		return;
	}
	self.resultPath = path;
	self.resultDuration = duration;
	self.resultDimensions = dimensions;

	if (self.roundVideoNote) {
		[self stopNoteRecordingChrome];
		if (self.sendWhenFinished) {
			[self sendPressed];
			return;
		}
		[self enterNotePreview];
		return;
	}
	[self enterReview];
}

- (void)videoRecorder:(TGVideoRecorder *)recorder didFailWithError:(NSError *)error {
	if (self.roundVideoNote) {
		[self cancelPressed];
		return;
	}
	[self resetToCamera];
}

#pragma mark - review

- (void)enterReview {
	self.reviewing = YES;
	[self stopSession];

	self.timeBadge.hidden = YES;
	self.cancel.hidden = NO;
	self.flip.hidden = YES;
	self.shutter.hidden = YES;
	self.retake.hidden = NO;
	self.send.hidden = NO;

	[self setElapsedText:self.resultDuration + 0.5];
	self.timeDot.hidden = YES;
	self.timeBadge.hidden = NO;

	self.player = [TGAVClass(AVPlayer) playerWithURL:[NSURL fileURLWithPath:self.resultPath]];
	self.playerLayer = [TGAVClass(AVPlayerLayer) playerLayerWithPlayer:self.player];
	self.playerLayer.videoGravity = TGAVString((AVLayerVideoGravityResizeAspectFill));
	self.playerLayer.frame = self.stage.bounds;
	[self.stage.layer addSublayer:self.playerLayer];

	__weak typeof(self) weakStageSelf = self;
	self.stagePreviewReachedEndObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGAVString(AVPlayerItemDidPlayToEndTimeNotification)
					object:self.player.currentItem
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakStageSelf) strongSelf = weakStageSelf;
					if (!strongSelf)
						return;
					[strongSelf playbackReachedEnd:note];
				}];
	[self.player play];
	[self updateChrome];
}

- (void)playbackReachedEnd:(NSNotification *)notification {
	[self.player seekToTime:kCMTimeZero];
	if (self.roundVideoNote && !self.previewMuted)
		[self setPreviewMutedState:YES];
	[self.player play];
}

- (void)resetToCamera {
	if (self.circlePreviewReachedEndObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:self.circlePreviewReachedEndObserverToken];
		self.circlePreviewReachedEndObserverToken = nil;
	}
	if (self.stagePreviewReachedEndObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:self.stagePreviewReachedEndObserverToken];
		self.stagePreviewReachedEndObserverToken = nil;
	}
	[self.player pause];
	self.player = nil;
	[self.playerLayer removeFromSuperlayer];
	self.playerLayer = nil;

	self.reviewing = NO;
	self.resultPath = nil;
	self.resultDuration = 0;
	self.resultDimensions = CGSizeZero;

	self.timeBadge.hidden = YES;
	self.timeDot.hidden = NO;
	self.timeDot.alpha = 1.0f;
	self.timeLabel.text = @"0:00";
	self.progressRing.strokeEnd = 0.0f;
	self.shutter.hidden = NO;
	self.shutter.enabled = YES;
	self.retake.hidden = YES;
	self.send.hidden = YES;
	self.cancel.hidden = NO;

	[self.shutter setBackgroundImage:TGVideoCaptureShutterImage(NO, NO)
							forState:UIControlStateNormal];
	[self.shutter setBackgroundImage:TGVideoCaptureShutterImage(NO, YES)
							forState:UIControlStateHighlighted];
	self.shutter.accessibilityLabel = TGL(@"VoiceOver.Camera.Shutter", @"Record");

	if (self.view.window != nil)
		[self startSession];
	[self updateChrome];
}

- (void)updateChrome {
	if (self.roundVideoNote)
		return;
	self.flip.hidden = self.reviewing || self.recorder.recording || !self.recorder.canSwitchCamera;
	self.progressRing.hidden = self.reviewing;
	self.recorder.previewLayer.hidden = self.reviewing;
}

- (void)flipPressed {
	if (self.recorder.recording || !self.recorder.canSwitchCamera)
		return;

	UIView *snapshot = [[UIView alloc] initWithFrame:self.stage.bounds];
	snapshot.backgroundColor = [UIColor blackColor];
	snapshot.alpha = 0.0f;
	[self.stage addSubview:snapshot];

	__weak TGVideoCaptureViewController *weakSelf = self;
	[UIView animateWithDuration:0.12 animations:^{
		snapshot.alpha = 1.0f;
	} completion:^(BOOL finished) {
		TGVideoCaptureViewController *strongSelf = weakSelf;
		[strongSelf.recorder switchCamera];
		[UIView animateWithDuration:0.18 animations:^{
			snapshot.alpha = 0.0f;
		} completion:^(BOOL done) {
			[snapshot removeFromSuperview];
		}];
	}];
}

- (void)retakePressed {
	NSString *path = self.resultPath;
	[self resetToCamera];
	if (path.length)
		[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
}

- (void)sendPressed {
	if (self.sendingResult)
		return;
	NSString *path = self.resultPath;
	NSTimeInterval duration = self.resultDuration;
	CGSize dimensions = self.resultDimensions;
	if (path.length == 0)
		return;
	self.sendingResult = YES;

	[self.player pause];
	[self stopSession];

	if (self.onFinish)
		self.onFinish(path, duration, dimensions);
	if ([self.delegate respondsToSelector:
				@selector(videoCaptureController:didFinishWithPath:duration:dimensions:round:)])
		[self.delegate videoCaptureController:self
							didFinishWithPath:path
									 duration:duration
								   dimensions:dimensions
										round:self.roundVideoNote];
	[self dismiss];
}

- (void)cancelPressed {
	self.holding = NO;
	if (self.recorder.recording) {
		[self.recorder cancel];
		if (!self.roundVideoNote) {
			[self resetToCamera];
			return;
		}
	}
	if (self.reviewing) {
		NSString *path = self.resultPath;
		if (self.roundVideoNote) {
			[self.player pause];
			self.resultPath = nil;
		} else {
			[self resetToCamera];
		}
		if (path.length)
			[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
	}

	[self stopSession];
	if (self.onCancel)
		self.onCancel();
	if ([self.delegate respondsToSelector:@selector(videoCaptureControllerDidCancel:)])
		[self.delegate videoCaptureControllerDidCancel:self];
	[self dismiss];
}

- (void)dismiss {
	if (self.overlay) {
		[self dismissOverlay];
		return;
	}
	if (self.navigationController != nil && self.navigationController.viewControllers.count > 1)
		[self.navigationController popViewControllerAnimated:YES];
	else if (self.presentingViewController != nil)
		[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	if (!self.reviewing && !self.view.window)
		[self stopSession];
}

@end

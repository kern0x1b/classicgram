#import "TGStoryAreaEditorViewController.h"
#import "TGIcons.h"

#import "TGClient+Stories.h"
#import "TGForwardPicker.h"
#import "TGStoryMessagePickerViewController.h"
#import "TGAlertView.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGPlateMetrics.h"
#import "TGSnackbar.h"
#import "TGLazyFramework.h"
#import "TGReactionPickerView.h"

#import <CoreLocation/CoreLocation.h>

static const NSInteger kTGStoryAreaMaxLocations = 10;
static const NSInteger kTGStoryAreaMaxLinksPremiumFallback = 3;
static const NSInteger kTGStoryAreaMaxMessages = 1;
static const NSInteger kTGStoryAreaMaxReactionsFallback = 1;

@interface TGStoryAreaChip : UIView
@property (nonatomic, copy) NSString *kind;
@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;
@property (nonatomic, copy) NSString *urlValue;
@property (nonatomic, assign) int64_t chatIdValue;
@property (nonatomic, assign) int64_t messageIdValue;
@property (nonatomic, copy) NSString *reactionEmojiValue;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UIView *plate;
@property (nonatomic, assign) BOOL selectedChip;
@end

@implementation TGStoryAreaChip

- (instancetype)initWithText:(NSString *)text {
	self = [super initWithFrame:CGRectZero];
	if (self) {
		self.backgroundColor = [UIColor clearColor];

		_plate = [[UIView alloc] initWithFrame:CGRectZero];
		_plate.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.45f];
		_plate.layer.cornerRadius = kPlateCornerRadius;
		_plate.layer.masksToBounds = YES;
		_plate.layer.borderWidth = 2.0f;
		_plate.layer.borderColor = [UIColor clearColor].CGColor;
		[self addSubview:_plate];

		_label = [[UILabel alloc] initWithFrame:CGRectZero];
		_label.backgroundColor = [UIColor clearColor];
		_label.textColor = [UIColor whiteColor];
		_label.font = [UIFont systemFontOfSize:14];
		_label.text = text;
		[_label sizeToFit];
		[_plate addSubview:_label];

		CGSize size = CGSizeMake(_label.bounds.size.width + 20.0f, _label.bounds.size.height + 12.0f);
		self.bounds = CGRectMake(0, 0, size.width, size.height);
		_plate.frame = self.bounds;
		_label.center = CGPointMake(size.width / 2.0f, size.height / 2.0f);
	}
	return self;
}

- (void)setSelectedChip:(BOOL)selectedChip {
	_selectedChip = selectedChip;
	_plate.layer.borderColor = selectedChip ? [UIColor whiteColor].CGColor : [UIColor clearColor].CGColor;
}

@end

@interface TGStoryAreaEditorViewController () <UIGestureRecognizerDelegate, UIAlertViewDelegate,
	CLLocationManagerDelegate> {
	UIView *_canvas;
	UIImageView *_imageView;
	NSMutableArray *_chips;
	TGStoryAreaChip *_selectedChip;
	CLLocationManager *_locationManager;
	BOOL _finished;
	UIButton *_removeButton;
	NSInteger _linkAreaCountMax;
	NSInteger _reactionAreaCountMax;
}
@end

@implementation TGStoryAreaEditorViewController

- (instancetype)init {
	self = [super init];
	if (self) {
		self.title = TGL(@"Story.Areas.Title", @"Add to Your Story");
		_chips = [[NSMutableArray alloc] init];
		_linkAreaCountMax = kTGStoryAreaMaxLinksPremiumFallback;
		_reactionAreaCountMax = kTGStoryAreaMaxReactionsFallback;
	}
	return self;
}

- (void)refreshLinkAreaCountMax {
	if (!self.premium)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] storyLinkAreaCountMaxWithCompletion:^(NSInteger countMax) {
		typeof(self) strongSelf = weakSelf;
		if (strongSelf == nil || countMax <= 0)
			return;
		strongSelf->_linkAreaCountMax = countMax;
	}];
}

- (void)refreshReactionAreaCountMax {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] storyReactionAreaCountMaxWithCompletion:^(NSInteger countMax) {
		typeof(self) strongSelf = weakSelf;
		if (strongSelf == nil || countMax <= 0)
			return;
		strongSelf->_reactionAreaCountMax = countMax;
	}];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = [UIColor blackColor];

	UIBarButtonItem *locationButton = [[UIBarButtonItem alloc]
		initWithTitle:@"\U0001F4CD"
				style:UIBarButtonItemStylePlain
			   target:self
			   action:@selector(addLocationArea)];
	UIBarButtonItem *linkButton = [[UIBarButtonItem alloc]
		initWithTitle:@"\U0001F517"
				style:UIBarButtonItemStylePlain
			   target:self
			   action:@selector(addLinkArea)];
	UIBarButtonItem *messageButton = [[UIBarButtonItem alloc]
		initWithTitle:@"\U0001F4AC"
				style:UIBarButtonItemStylePlain
			   target:self
			   action:@selector(addMessageArea)];
	UIBarButtonItem *reactionButton = [[UIBarButtonItem alloc]
		initWithTitle:@"\U00002764"
				style:UIBarButtonItemStylePlain
			   target:self
			   action:@selector(addReactionArea)];
	self.navigationItem.rightBarButtonItems = @[ messageButton, reactionButton, linkButton, locationButton ];
	self.navigationItem.leftBarButtonItem =
		[TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Done", @"Done") bold:YES
									   target:self
									   action:@selector(donePressed)];

	_canvas = [[UIView alloc] initWithFrame:self.view.bounds];
	_canvas.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_canvas.backgroundColor = [UIColor clearColor];
	_canvas.clipsToBounds = YES;
	[self.view addSubview:_canvas];

	_imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_imageView.contentMode = UIViewContentModeScaleAspectFit;
	_imageView.backgroundColor = [UIColor blackColor];
	_imageView.image = self.preview;
	[_canvas addSubview:_imageView];

	_removeButton = [UIButton buttonWithType:UIButtonTypeCustom];
	_removeButton.frame = CGRectMake(12, 12, 32, 32);
	_removeButton.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
	_removeButton.layer.cornerRadius = 16.0f;
	[_removeButton setTitle:@"✕" forState:UIControlStateNormal];
	[_removeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[_removeButton addTarget:self action:@selector(removeSelectedChip)
			forControlEvents:UIControlEventTouchUpInside];
	_removeButton.hidden = YES;
	[self.view addSubview:_removeButton];

	UITapGestureRecognizer *backgroundTap = [[UITapGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(canvasTapped:)];
	[_canvas addGestureRecognizer:backgroundTap];

	for (NSDictionary *existing in self.existingAreas)
		[self restoreChipFromInputArea:existing];

	[self refreshLinkAreaCountMax];
	[self refreshReactionAreaCountMax];
}

- (void)viewWillLayoutSubviews {
	[super viewWillLayoutSubviews];
	_imageView.frame = [self storyFrame];
	[self layoutRemoveButton];
}

- (CGRect)storyFrame {
	CGRect area = _canvas.bounds;
	CGSize size = CGSizeMake(9.0f, 16.0f);
	if (area.size.width < 1.0f || area.size.height < 1.0f)
		return CGRectZero;
	CGFloat scale = MIN(area.size.width / size.width, area.size.height / size.height);
	CGFloat drawWidth = floorf(size.width * scale);
	CGFloat drawHeight = floorf(size.height * scale);
	return CGRectMake(floorf((area.size.width - drawWidth) / 2.0f),
		floorf((area.size.height - drawHeight) / 2.0f),
		drawWidth, drawHeight);
}

- (void)layoutRemoveButton {
	if (_selectedChip == nil) {
		_removeButton.hidden = YES;
		return;
	}
	_removeButton.hidden = NO;
}

#pragma mark - restoring already-placed areas (re-entering the editor)

- (void)restoreChipFromInputArea:(NSDictionary *)area {
	if (![area isKindOfClass:[NSDictionary class]])
		return;
	NSDictionary *position = area[@"position"];
	NSDictionary *type = area[@"type"];
	if (![position isKindOfClass:[NSDictionary class]] || ![type isKindOfClass:[NSDictionary class]])
		return;

	NSString *typeName = TGTDLibTypeOf(type);
	NSString *kind = nil;
	NSString *text = nil;
	double latitude = 0, longitude = 0;
	NSString *url = nil;
	int64_t chatId = 0, messageId = 0;

	if ([typeName isEqualToString:@"inputStoryAreaTypeLocation"]) {
		kind = @"location";
		text = [NSString stringWithFormat:@"\U0001F4CD %@", TGL(@"Map.Location", @"Location")];
		NSDictionary *loc = type[@"location"];
		latitude = [loc[@"latitude"] doubleValue];
		longitude = [loc[@"longitude"] doubleValue];
	} else if ([typeName isEqualToString:@"inputStoryAreaTypeLink"]) {
		kind = @"link";
		url = type[@"url"];
		text = @"\U0001F517 Link";
	} else if ([typeName isEqualToString:@"inputStoryAreaTypeMessage"]) {
		kind = @"message";
		chatId = [type[@"chat_id"] longLongValue];
		messageId = [type[@"message_id"] longLongValue];
		text = @"\U0001F4AC Message";
	}
	NSString *reactionEmoji = nil;
	if ([typeName isEqualToString:@"inputStoryAreaTypeSuggestedReaction"]) {
		kind = @"reaction";
		id emojiValue = type[@"reaction_type"][@"emoji"];
		reactionEmoji = [emojiValue isKindOfClass:NSString.class] ? emojiValue : nil;
		text = reactionEmoji.length ? reactionEmoji : @"\U00002764";
	}
	if (!kind)
		return;

	TGStoryAreaChip *chip = [[TGStoryAreaChip alloc] initWithText:text];
	chip.kind = kind;
	chip.latitude = latitude;
	chip.longitude = longitude;
	chip.urlValue = url;
	chip.chatIdValue = chatId;
	chip.messageIdValue = messageId;
	chip.reactionEmojiValue = reactionEmoji;

	CGRect frame = [self storyFrame];
	double xPct = [position[@"x_percentage"] doubleValue];
	double yPct = [position[@"y_percentage"] doubleValue];
	chip.center = CGPointMake(frame.origin.x + frame.size.width * (CGFloat)(xPct / 100.0),
		frame.origin.y + frame.size.height * (CGFloat)(yPct / 100.0));

	double widthPct = [position[@"width_percentage"] doubleValue];
	if (widthPct > 0 && frame.size.width > 0)
		[self resizeChip:chip toWidth:frame.size.width * (CGFloat)(widthPct / 100.0)];

	[self addChipToCanvas:chip];
}

#pragma mark - adding a new area

- (NSInteger)countOfKind:(NSString *)kind {
	NSInteger count = 0;
	for (TGStoryAreaChip *chip in _chips)
		if ([chip.kind isEqualToString:kind])
			count++;
	return count;
}

- (void)addLocationArea {
	if ([self countOfKind:@"location"] >= kTGStoryAreaMaxLocations) {
		[self showMessage:TGL(@"Story.Areas.TooManyLocations", @"You can add up to 10 location areas.")];
		return;
	}

	Class managerClass = TGCLClass(CLLocationManager);
	if (!managerClass) {
		[self showMessage:TGL(@"Chat.LocationIsNotAvailable", @"Location is not available.")];
		return;
	}
	if (_locationManager == nil) {
		_locationManager = [[managerClass alloc] init];
		_locationManager.delegate = self;
	}
	[self showMessage:TGL(@"Map.Locating", @"Finding your current location…")];
	[_locationManager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
	[manager stopUpdatingLocation];
	CLLocation *fix = [locations lastObject];
	if (!fix)
		return;
	[self placeLocationChipWithLatitude:fix.coordinate.latitude longitude:fix.coordinate.longitude];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	(void)error;
	[manager stopUpdatingLocation];
	[self showMessage:TGL(@"Chat.LocationIsNotAvailable", @"Location is not available.")];
}

- (void)placeLocationChipWithLatitude:(double)latitude longitude:(double)longitude {
	NSString *text = [NSString stringWithFormat:@"\U0001F4CD %@", TGL(@"Map.Location", @"Location")];
	TGStoryAreaChip *chip = [[TGStoryAreaChip alloc] initWithText:text];
	chip.kind = @"location";
	chip.latitude = latitude;
	chip.longitude = longitude;
	[self placeNewChipAtCenter:chip];
}

- (void)addLinkArea {
	if (!self.premium) {
		[self showMessage:TGL(@"Story.Editor.TooltipPremiumExpiration", @"Other durations need Telegram Premium.")];
		return;
	}
	if ([self countOfKind:@"link"] >= _linkAreaCountMax) {
		NSString *value = TGLPlural(@"Story.Editor.TooltipLinkLimitValue",
			_linkAreaCountMax, @"%@ link", @"%@ links");
		[self showMessage:[NSString stringWithFormat:
			TGL(@"Story.Editor.TooltipReachedLinkLimitText", @"You can't add more than %@ to a story."), value]];
		return;
	}
	UIAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"Conversation.LinkDialogOpen", @"Open")
				  message:nil
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Common.Done", @"Done"), nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert textFieldAtIndex:0].placeholder = @"https://";
	[alert textFieldAtIndex:0].keyboardType = UIKeyboardTypeURL;
	alert.tag = 1;
	[alert show];
}

- (void)addMessageArea {
	if ([self countOfKind:@"message"] >= kTGStoryAreaMaxMessages) {
		[self showMessage:TGL(@"Story.Areas.OnlyOneMessage", @"Only one message area can be added.")];
		return;
	}
	TGForwardPicker *picker = [[TGForwardPicker alloc] init];
	picker.allowsMultiplePicks = NO;
	picker.requiredKind = @"channel";
	__weak typeof(self) weakSelf = self;
	picker.onPicked = ^(NSArray *chatIds) {
		typeof(self) strongSelf = weakSelf;
		if (strongSelf == nil || chatIds.count == 0)
			return;
		int64_t chatId = [[chatIds objectAtIndex:0] longLongValue];
		[strongSelf dismissViewControllerAnimated:YES completion:^{
			typeof(self) innerSelf = weakSelf;
			if (innerSelf == nil)
				return;
			[innerSelf presentMessagePickerForChat:chatId];
		}];
	};
	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
	[[TGTheme shared] styleNavigationBar:nav.navigationBar];
	[self presentViewController:nav animated:YES completion:nil];
}

- (void)presentMessagePickerForChat:(int64_t)chatId {
	TGStoryMessagePickerViewController *picker = [[TGStoryMessagePickerViewController alloc] init];
	picker.chatId = chatId;
	__weak typeof(self) weakSelf = self;
	picker.onPicked = ^(int64_t messageId) {
		typeof(self) strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		[strongSelf dismissViewControllerAnimated:YES completion:^{
			typeof(self) innerSelf = weakSelf;
			if (innerSelf == nil)
				return;
			TGStoryAreaChip *chip = [[TGStoryAreaChip alloc] initWithText:@"\U0001F4AC Message"];
			chip.kind = @"message";
			chip.chatIdValue = chatId;
			chip.messageIdValue = messageId;
			[innerSelf placeNewChipAtCenter:chip];
		}];
	};
	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
	[[TGTheme shared] styleNavigationBar:nav.navigationBar];
	[self presentViewController:nav animated:YES completion:nil];
}

- (void)addReactionArea {
	if ([self countOfKind:@"reaction"] >= _reactionAreaCountMax) {
		NSString *value = TGLPlural(@"Story.Editor.TooltipPremiumReactionLimitValue",
			_reactionAreaCountMax, @"%@ reaction tag", @"%@ reactions tags");
		NSString *text = [NSString stringWithFormat:
			TGL(@"Story.Editor.TooltipReachedReactionLimitText", @"You can't add up more than %@ to a story."), value];
		NSString *title = TGL(@"Story.Editor.TooltipReachedReactionLimitTitle", @"Limit Reached");
		[self showMessage:[NSString stringWithFormat:@"%@ %@", title, text]];
		return;
	}

	UIView *host = self.view;
	CGRect anchor = CGRectMake(floorf(host.bounds.size.width / 2.0f) - 1.0f, 70.0f, 2.0f, 2.0f);
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] storyReactionsWithLimit:12 completion:^(NSArray *emoji) {
		typeof(self) strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		if (![emoji isKindOfClass:NSArray.class] || emoji.count == 0)
			return;

		TGReactionPickerView *picker =
			[TGReactionPickerView showForMessage:0
										   inChat:0
										 fromRect:anchor
										   inView:host
										   picked:^(NSString *chosen, BOOL nowChosen) {
											   (void)nowChosen;
											   typeof(self) innerSelf = weakSelf;
											   if (innerSelf == nil || chosen.length == 0)
												   return;
											   TGStoryAreaChip *chip = [[TGStoryAreaChip alloc] initWithText:chosen];
											   chip.kind = @"reaction";
											   chip.reactionEmojiValue = chosen;
											   [innerSelf placeNewChipAtCenter:chip];
										   }];
		if (picker != nil)
			[picker setEmoji:emoji reason:nil];
	}];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (alertView.tag != 1 || buttonIndex == alertView.cancelButtonIndex)
		return;
	NSString *text = [[alertView textFieldAtIndex:0].text
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!text.length)
		return;
	if (![text.lowercaseString hasPrefix:@"http://"] && ![text.lowercaseString hasPrefix:@"https://"])
		text = [@"https://" stringByAppendingString:text];

	TGStoryAreaChip *chip = [[TGStoryAreaChip alloc] initWithText:@"\U0001F517 Link"];
	chip.kind = @"link";
	chip.urlValue = text;
	[self placeNewChipAtCenter:chip];
}

- (void)placeNewChipAtCenter:(TGStoryAreaChip *)chip {
	CGRect frame = [self storyFrame];
	chip.center = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
	[self addChipToCanvas:chip];
}

- (void)addChipToCanvas:(TGStoryAreaChip *)chip {
	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(handlePan:)];
	UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(handlePinch:)];
	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(handleChipTap:)];
	pan.delegate = self;
	pinch.delegate = self;
	[chip addGestureRecognizer:pan];
	[chip addGestureRecognizer:pinch];
	[chip addGestureRecognizer:tap];
	chip.userInteractionEnabled = YES;
	[_canvas addSubview:chip];
	[_chips addObject:chip];
	[self selectChip:chip];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
	shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
	return YES;
}

- (void)canvasTapped:(UITapGestureRecognizer *)recognizer {
	(void)recognizer;
	[self selectChip:nil];
}

- (void)handleChipTap:(UITapGestureRecognizer *)recognizer {
	TGStoryAreaChip *chip = (TGStoryAreaChip *)recognizer.view;
	[self selectChip:chip];
}

- (void)selectChip:(TGStoryAreaChip *)chip {
	_selectedChip.selectedChip = NO;
	_selectedChip = chip;
	_selectedChip.selectedChip = YES;
	[self layoutRemoveButton];
}

- (void)removeSelectedChip {
	if (_selectedChip == nil)
		return;
	[_chips removeObject:_selectedChip];
	[_selectedChip removeFromSuperview];
	_selectedChip = nil;
	[self layoutRemoveButton];
}

- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
	TGStoryAreaChip *chip = (TGStoryAreaChip *)recognizer.view;
	if (recognizer.state == UIGestureRecognizerStateBegan)
		[self selectChip:chip];
	if (recognizer.state != UIGestureRecognizerStateChanged)
		return;
	CGPoint translation = [recognizer translationInView:_canvas];
	[recognizer setTranslation:CGPointZero inView:_canvas];

	CGRect frame = [self storyFrame];
	CGPoint center = CGPointMake(chip.center.x + translation.x, chip.center.y + translation.y);
	CGSize size = chip.bounds.size;

	CGFloat minX = frame.origin.x + size.width / 2.0f;
	CGFloat maxX = CGRectGetMaxX(frame) - size.width / 2.0f;
	if (maxX > minX)
		center.x = MAX(minX, MIN(maxX, center.x));
	CGFloat minY = frame.origin.y + size.height / 2.0f;
	CGFloat maxY = CGRectGetMaxY(frame) - size.height / 2.0f;
	if (maxY > minY)
		center.y = MAX(minY, MIN(maxY, center.y));
	chip.center = center;
}

- (void)resizeChip:(TGStoryAreaChip *)chip toWidth:(CGFloat)newWidth {
	CGSize size = chip.bounds.size;
	if (size.width < 1.0f)
		return;
	CGFloat clampedWidth = MAX(60.0f, MIN(260.0f, newWidth));
	CGFloat ratio = clampedWidth / size.width;
	CGSize newSize = CGSizeMake(clampedWidth, size.height * ratio);
	CGPoint center = chip.center;
	chip.bounds = CGRectMake(0, 0, newSize.width, newSize.height);
	chip.center = center;
	chip.plate.frame = chip.bounds;
	chip.label.center = CGPointMake(newSize.width / 2.0f, newSize.height / 2.0f);
	chip.label.transform = CGAffineTransformMakeScale(clampedWidth / size.width, clampedWidth / size.width);
}

- (void)handlePinch:(UIPinchGestureRecognizer *)recognizer {
	TGStoryAreaChip *chip = (TGStoryAreaChip *)recognizer.view;
	if (recognizer.state == UIGestureRecognizerStateBegan)
		[self selectChip:chip];
	if (recognizer.state != UIGestureRecognizerStateChanged)
		return;
	CGFloat scale = recognizer.scale;
	recognizer.scale = 1.0f;
	[self resizeChip:chip toWidth:chip.bounds.size.width * scale];
}

#pragma mark - finishing

- (void)showMessage:(NSString *)message {
	[TGSnackbar showInView:self.view text:message seconds:3 onCommit:nil];
}

- (void)donePressed {
	_finished = YES;
	[self finishWithAreas:[self buildAreaDicts]];
}

- (NSArray *)buildAreaDicts {
	CGRect frame = [self storyFrame];
	if (frame.size.width < 1.0f || frame.size.height < 1.0f)
		return @[];

	NSMutableArray *out = [[NSMutableArray alloc] init];
	for (TGStoryAreaChip *chip in _chips) {
		double xPct = ((chip.center.x - frame.origin.x) / frame.size.width) * 100.0;
		double yPct = ((chip.center.y - frame.origin.y) / frame.size.height) * 100.0;
		double widthPct = (chip.bounds.size.width / frame.size.width) * 100.0;
		double heightPct = (chip.bounds.size.height / frame.size.height) * 100.0;

		TGClient *client = [TGClient shared];
		NSDictionary *area = [client
			inputStoryAreaWithKind:chip.kind
						  xPercent:xPct
						  yPercent:yPct
					  widthPercent:widthPct
					 heightPercent:heightPct
						  latitude:chip.latitude
						 longitude:chip.longitude
							   url:chip.urlValue
							chatId:chip.chatIdValue
						 messageId:chip.messageIdValue
					 reactionEmoji:chip.reactionEmojiValue];
		if (area != nil)
			[out addObject:area];
	}
	return out;
}

- (void)finishWithAreas:(NSArray *)areas {
	void (^onDone)(NSArray *) = self.onDone;
	self.onDone = nil;
	if (onDone != nil)
		onDone(areas);
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	if (_finished)
		return;
	if ([self isMovingFromParentViewController] || self.isBeingDismissed)
		[self finishWithAreas:(self.existingAreas ?: @[])];
}

@end

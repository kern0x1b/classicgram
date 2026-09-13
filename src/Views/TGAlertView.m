#import "TGAlertView.h"
#import "TGLocalization.h"
#import <QuartzCore/QuartzCore.h>

static NSInteger TGAlertViewSystemVersionComponent(NSUInteger index) {
	static NSArray *components = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		components = [[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."];
	});

	if (components == nil || index >= components.count)
		return 0;

	return [[components objectAtIndex:index] integerValue];
}

static NSString *TGAlertViewNormalizedMessage(NSString *title, NSString *message) {
	if (message == nil)
		return nil;

	if (title == nil && TGAlertViewSystemVersionComponent(0) >= 8 && TGAlertViewSystemVersionComponent(1) < 1)
		return [@"\n" stringByAppendingString:message];

	return message;
}

static const CGFloat kAlertPanelWidth = 276.0f;
static const CGFloat kAlertPanelRadius = 10.0f;
static const CGFloat kAlertPanelBorder = 1.5f;
static const CGFloat kAlertPanelSideInset = 8.0f;
static const CGFloat kAlertPanelTopInset = 15.0f;
static const CGFloat kAlertPanelBottomInset = 6.0f;
static const CGFloat kAlertPanelTitleToMessage = 10.0f;
static const CGFloat kAlertPanelTextToField = 18.0f;
static const CGFloat kAlertPanelFieldHeight = 28.0f;
static const CGFloat kAlertPanelFieldToButtons = 18.0f;
static const CGFloat kAlertPanelButtonHeight = 40.0f;
static const CGFloat kAlertPanelButtonGap = 11.0f;
static const CGFloat kAlertPanelButtonRadius = 7.0f;
static const CGFloat kAlertPanelGlossHeight = 31.0f;
static const CGFloat kAlertPanelScreenMargin = 20.0f;
static const CGFloat kAlertPanelButtonLabelPadding = 24.0f;
static const CGFloat kAlertPanelDimAlpha = 0.485f;

static NSMutableSet *TGAlertViewVisiblePanels(void) {
	static NSMutableSet *panels = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		panels = [[NSMutableSet alloc] init];
	});

	return panels;
}

static UIFont *TGAlertPanelTitleFont(void) {
	return [UIFont boldSystemFontOfSize:17.0f];
}

static UIFont *TGAlertPanelMessageFont(void) {
	return [UIFont systemFontOfSize:15.0f];
}

static UIFont *TGAlertPanelButtonFont(void) {
	return [UIFont boldSystemFontOfSize:17.0f];
}

static void TGAlertPanelDrawGradient(CGContextRef context, CGRect rect, const CGFloat *components, const CGFloat *locations, size_t count) {
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGGradientRef gradient = CGGradientCreateWithColorComponents(space, components, locations, count);

	CGContextSaveGState(context);
	CGContextClipToRect(context, rect);
	CGContextDrawLinearGradient(context, gradient,
		CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect)),
		CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect)), 0);
	CGContextRestoreGState(context);

	CGGradientRelease(gradient);
	CGColorSpaceRelease(space);
}

static void TGAlertPanelAddRoundedRect(CGContextRef context, CGRect rect, CGFloat radius) {
	CGFloat minX = CGRectGetMinX(rect), maxX = CGRectGetMaxX(rect);
	CGFloat minY = CGRectGetMinY(rect), maxY = CGRectGetMaxY(rect);

	CGContextMoveToPoint(context, minX + radius, minY);
	CGContextAddArcToPoint(context, maxX, minY, maxX, maxY, radius);
	CGContextAddArcToPoint(context, maxX, maxY, minX, maxY, radius);
	CGContextAddArcToPoint(context, minX, maxY, minX, minY, radius);
	CGContextAddArcToPoint(context, minX, minY, maxX, minY, radius);
	CGContextClosePath(context);
}

@interface TGAlertPanelButton : UIButton
@end

@implementation TGAlertPanelButton

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		self.opaque = NO;
		self.backgroundColor = [UIColor clearColor];
		self.titleLabel.font = TGAlertPanelButtonFont();
		self.titleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
		[self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		[self setTitleShadowColor:[UIColor colorWithWhite:0.0f alpha:0.4f] forState:UIControlStateNormal];
	}
	return self;
}

- (void)setHighlighted:(BOOL)highlighted {
	[super setHighlighted:highlighted];
	[self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
	(void)rect;

	CGContextRef context = UIGraphicsGetCurrentContext();
	CGRect bounds = CGRectInset(self.bounds, 0.5f, 0.5f);

	CGContextSaveGState(context);
	TGAlertPanelAddRoundedRect(context, bounds, kAlertPanelButtonRadius);
	CGContextClip(context);

	CGFloat top = CGRectGetMinY(bounds);
	CGFloat height = CGRectGetHeight(bounds);
	CGRect upper = CGRectMake(CGRectGetMinX(bounds), top, CGRectGetWidth(bounds), height / 2.0f);
	CGRect lower = CGRectMake(CGRectGetMinX(bounds), top + height / 2.0f, CGRectGetWidth(bounds), height / 2.0f);

	if (self.highlighted) {
		CGFloat pressedUpper[8] = {0.35f, 0.55f, 0.85f, 1.0f, 0.15f, 0.32f, 0.66f, 1.0f};
		CGFloat pressedLower[8] = {0.10f, 0.25f, 0.58f, 1.0f, 0.20f, 0.38f, 0.72f, 1.0f};
		CGFloat locations[2] = {0.0f, 1.0f};
		TGAlertPanelDrawGradient(context, upper, pressedUpper, locations, 2);
		TGAlertPanelDrawGradient(context, lower, pressedLower, locations, 2);
	} else {
		CGFloat normalUpper[8] = {0.549f, 0.580f, 0.667f, 1.0f, 0.255f, 0.310f, 0.447f, 1.0f};
		CGFloat normalLower[8] = {0.188f, 0.243f, 0.400f, 1.0f, 0.275f, 0.325f, 0.467f, 1.0f};
		CGFloat locations[2] = {0.0f, 1.0f};
		TGAlertPanelDrawGradient(context, upper, normalUpper, locations, 2);
		TGAlertPanelDrawGradient(context, lower, normalLower, locations, 2);

		CGContextSetRGBFillColor(context, 0.329f, 0.376f, 0.502f, 1.0f);
		CGContextFillRect(context, CGRectMake(CGRectGetMinX(bounds), CGRectGetMaxY(bounds) - 1.0f, CGRectGetWidth(bounds), 1.0f));
	}

	CGContextRestoreGState(context);

	TGAlertPanelAddRoundedRect(context, bounds, kAlertPanelButtonRadius);
	CGContextSetRGBStrokeColor(context, 0.784f, 0.812f, 0.859f, 1.0f);
	CGContextSetLineWidth(context, 1.0f);
	CGContextStrokePath(context);
}

@end

@interface TGAlertPanelView : UIView <UITextFieldDelegate>

@property (nonatomic, strong) id owner;

@end

@implementation TGAlertPanelView

- (void)panelButtonTapped:(UIButton *)button {
	if ([self.owner respondsToSelector:@selector(panelButtonTapped:)])
		[self.owner performSelector:@selector(panelButtonTapped:) withObject:button];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	if ([self.owner respondsToSelector:@selector(panelFieldShouldReturn)])
		[self.owner performSelector:@selector(panelFieldShouldReturn)];

	return NO;
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		self.opaque = NO;
		self.backgroundColor = [UIColor clearColor];
	}
	return self;
}

- (void)drawRect:(CGRect)rect {
	(void)rect;

	CGContextRef context = UIGraphicsGetCurrentContext();
	CGRect bounds = CGRectInset(self.bounds, kAlertPanelBorder / 2.0f, kAlertPanelBorder / 2.0f);

	CGContextSaveGState(context);
	TGAlertPanelAddRoundedRect(context, bounds, kAlertPanelRadius);
	CGContextClip(context);

	CGFloat height = MAX(1.0f, CGRectGetHeight(bounds));
	CGFloat gloss = MIN(kAlertPanelGlossHeight, height / 2.0f);

	CGFloat components[20] = {
		0.784f, 0.804f, 0.839f, 1.0f,
		0.400f, 0.443f, 0.549f, 1.0f,
		0.235f, 0.282f, 0.408f, 1.0f,
		0.078f, 0.137f, 0.294f, 1.0f,
		0.149f, 0.208f, 0.365f, 1.0f};
	CGFloat locations[5] = {
		0.0f,
		gloss * 0.16f / height,
		gloss * 0.55f / height,
		gloss / height,
		1.0f};
	TGAlertPanelDrawGradient(context, bounds, components, locations, 5);

	CGContextRestoreGState(context);

	TGAlertPanelAddRoundedRect(context, bounds, kAlertPanelRadius);
	CGContextSetRGBStrokeColor(context, 0.667f, 0.690f, 0.737f, 1.0f);
	CGContextSetLineWidth(context, kAlertPanelBorder);
	CGContextStrokePath(context);
}

@end

@interface TGAlertView () <UIAlertViewDelegate> {
	UIAlertViewStyle _requestedStyle;
	UIView *_panelHost;
	TGAlertPanelView *_panel;
	UILabel *_panelTitleLabel;
	UILabel *_panelMessageLabel;
	UITextField *_panelField;
	NSMutableArray *_panelButtons;
	CGFloat _panelKeyboardHeight;
	BOOL _panelVisible;
}

@property (nonatomic, copy) void (^completionBlock)(bool okButtonPressed);
@property (nonatomic, strong) id keyboardWillShowObserverToken;
@property (nonatomic, strong) id keyboardWillHideObserverToken;
@property (nonatomic, strong) id statusBarOrientationObserverToken;

@end

@implementation TGAlertView

- (id)initWithTitle:(NSString *)title message:(NSString *)message cancelButtonTitle:(NSString *)cancelButtonTitle okButtonTitle:(NSString *)okButtonTitle completionBlock:(void (^)(bool okButtonPressed))completionBlock {
	return [self initWithTitle:title message:message cancelButtonTitle:cancelButtonTitle otherButtonTitles:okButtonTitle == nil ? nil : [NSArray arrayWithObject:okButtonTitle] completionBlock:completionBlock];
}

- (id)initWithTitle:(NSString *)title message:(NSString *)message cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSArray *)otherButtonTitles completionBlock:(void (^)(bool okButtonPressed))completionBlock {
	self = [super initWithTitle:title message:TGAlertViewNormalizedMessage(title, message) delegate:self cancelButtonTitle:cancelButtonTitle otherButtonTitles:nil];
	if (self != nil) {
		for (id otherButtonTitle in otherButtonTitles) {
			if ([otherButtonTitle isKindOfClass:[NSString class]] && ((NSString *)otherButtonTitle).length != 0)
				[self addButtonWithTitle:otherButtonTitle];
		}

		if (self.numberOfButtons == 0)
			[self addButtonWithTitle:TGL(@"Common.OK", @"OK")];

		_completionBlock = [completionBlock copy];
	}
	return self;
}

- (id)initWithTitle:(NSString *)title message:(NSString *)message delegate:(id)delegate cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ... {
	self = [super initWithTitle:title message:TGAlertViewNormalizedMessage(title, message) delegate:delegate cancelButtonTitle:cancelButtonTitle otherButtonTitles:nil];
	if (self != nil && otherButtonTitles != nil) {
		[self addButtonWithTitle:otherButtonTitles];

		va_list arguments;
		va_start(arguments, otherButtonTitles);
		NSString *nextTitle = nil;
		while ((nextTitle = va_arg(arguments, NSString *)) != nil)
			[self addButtonWithTitle:nextTitle];
		va_end(arguments);
	}
	return self;
}

- (NSInteger)firstOtherButtonIndex {
	NSInteger index = [super firstOtherButtonIndex];
	if (index >= 0)
		return index;

	for (NSInteger candidate = 0; candidate < self.numberOfButtons; candidate++) {
		if (candidate != self.cancelButtonIndex)
			return candidate;
	}

	return -1;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.keyboardWillShowObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.keyboardWillShowObserverToken];
	if (self.keyboardWillHideObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.keyboardWillHideObserverToken];
	if (self.statusBarOrientationObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.statusBarOrientationObserverToken];
}

- (BOOL)usesOwnLayoutForStyle:(UIAlertViewStyle)style {
	if (TGAlertViewSystemVersionComponent(0) >= 7)
		return NO;

	if (![self respondsToSelector:@selector(setAlertViewStyle:)])
		return NO;

	if (style == UIAlertViewStyleDefault)
		return NO;

	return self.numberOfButtons > 2;
}

- (BOOL)usesOwnLayout {
	return [self usesOwnLayoutForStyle:_requestedStyle];
}

- (void)setAlertViewStyle:(UIAlertViewStyle)alertViewStyle {
	_requestedStyle = alertViewStyle;

	if ([self usesOwnLayoutForStyle:alertViewStyle])
		return;

	[super setAlertViewStyle:alertViewStyle];
}

- (UIAlertViewStyle)alertViewStyle {
	if (_requestedStyle != UIAlertViewStyleDefault)
		return _requestedStyle;

	return [super alertViewStyle];
}

- (UITextField *)ownTextField {
	if (_panelField != nil)
		return _panelField;

	UITextField *field = [[UITextField alloc] initWithFrame:CGRectZero];
	field.borderStyle = UITextBorderStyleNone;
	field.backgroundColor = [UIColor whiteColor];
	field.font = TGAlertPanelMessageFont();
	field.textColor = [UIColor blackColor];
	field.secureTextEntry = (_requestedStyle == UIAlertViewStyleSecureTextInput);
	field.layer.borderWidth = 1.0f;
	field.layer.cornerRadius = 4.0f;
	field.layer.borderColor = [UIColor colorWithRed:0.184f green:0.227f blue:0.318f alpha:1.0f].CGColor;
	field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 6.0f, kAlertPanelFieldHeight)];
	field.leftViewMode = UITextFieldViewModeAlways;
	_panelField = field;

	return _panelField;
}

- (UITextField *)textFieldAtIndex:(NSInteger)index {
	if ([self usesOwnLayout] && index == 0)
		return [self ownTextField];

	return [super textFieldAtIndex:index];
}

- (void)show {
	if (![self usesOwnLayout]) {
		if ([NSThread isMainThread])
			[super show];
		else {
			dispatch_async(dispatch_get_main_queue(), ^{
				[super show];
			});
		}
		return;
	}

	if ([NSThread isMainThread])
		[self presentPanel];
	else {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self presentPanel];
		});
	}
}

- (UIView *)hostViewForPanel {
	UIWindow *window = [[UIApplication sharedApplication] keyWindow];
	if (window == nil) {
		NSArray *windows = [[UIApplication sharedApplication] windows];
		window = windows.count != 0 ? [windows objectAtIndex:0] : nil;
	}

	UIViewController *controller = window.rootViewController;
	while (controller.presentedViewController != nil)
		controller = controller.presentedViewController;

	return controller.view != nil ? controller.view : window;
}

- (void)presentPanel {
	if (_panelVisible)
		return;

	UIView *host = [self hostViewForPanel];
	if (host == nil)
		return;

	_panelVisible = YES;
	_panelKeyboardHeight = 0.0f;
	[TGAlertViewVisiblePanels() addObject:self];

	_panelHost = [[UIView alloc] initWithFrame:host.bounds];
	_panelHost.backgroundColor = [UIColor colorWithWhite:0.0f alpha:kAlertPanelDimAlpha];
	_panelHost.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

	_panel = [[TGAlertPanelView alloc] initWithFrame:CGRectZero];
	_panel.owner = self;
	[_panelHost addSubview:_panel];

	if (self.title.length != 0) {
		_panelTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		_panelTitleLabel.backgroundColor = [UIColor clearColor];
		_panelTitleLabel.textColor = [UIColor whiteColor];
		_panelTitleLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
		_panelTitleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
		_panelTitleLabel.font = TGAlertPanelTitleFont();
		_panelTitleLabel.textAlignment = NSTextAlignmentCenter;
		_panelTitleLabel.numberOfLines = 0;
		_panelTitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
		_panelTitleLabel.text = self.title;
		[_panel addSubview:_panelTitleLabel];
	}

	if (self.message.length != 0) {
		_panelMessageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		_panelMessageLabel.backgroundColor = [UIColor clearColor];
		_panelMessageLabel.textColor = [UIColor whiteColor];
		_panelMessageLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
		_panelMessageLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
		_panelMessageLabel.font = TGAlertPanelMessageFont();
		_panelMessageLabel.textAlignment = NSTextAlignmentCenter;
		_panelMessageLabel.numberOfLines = 0;
		_panelMessageLabel.lineBreakMode = NSLineBreakByWordWrapping;
		_panelMessageLabel.text = self.message;
		[_panel addSubview:_panelMessageLabel];
	}

	[self ownTextField].delegate = _panel;
	[_panel addSubview:_panelField];

	_panelButtons = [[NSMutableArray alloc] init];
	for (NSInteger index = 0; index < self.numberOfButtons; index++) {
		if (index == self.cancelButtonIndex)
			continue;
		[self addPanelButtonWithTitle:[self buttonTitleAtIndex:index] index:index];
	}
	if (self.cancelButtonIndex >= 0)
		[self addPanelButtonWithTitle:[self buttonTitleAtIndex:self.cancelButtonIndex] index:self.cancelButtonIndex];

	[host addSubview:_panelHost];

	__weak typeof(self) weakSelf = self;
	self.keyboardWillShowObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIKeyboardWillShowNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf panelKeyboardChanged:note];
				}];
	self.keyboardWillHideObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIKeyboardWillHideNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf panelKeyboardChanged:note];
				}];
	self.statusBarOrientationObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIApplicationDidChangeStatusBarOrientationNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf panelOrientationChanged:note];
				}];

	[self layoutPanel];

	_panelHost.alpha = 0.0f;
	_panel.transform = CGAffineTransformMakeScale(1.18f, 1.18f);
	[UIView animateWithDuration:0.2
					 animations:^{
						 _panelHost.alpha = 1.0f;
						 _panel.transform = CGAffineTransformIdentity;
					 }];

	[_panelField becomeFirstResponder];
}

- (void)addPanelButtonWithTitle:(NSString *)title index:(NSInteger)index {
	if (title == nil)
		return;

	TGAlertPanelButton *button = [[TGAlertPanelButton alloc] initWithFrame:CGRectZero];
	[button setTitle:title forState:UIControlStateNormal];
	button.tag = index;
	[button addTarget:_panel action:@selector(panelButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
	[_panel addSubview:button];
	[_panelButtons addObject:button];
}

- (void)panelKeyboardChanged:(NSNotification *)notification {
	if (!_panelVisible)
		return;

	CGFloat height = 0.0f;
	if ([notification.name isEqualToString:UIKeyboardWillShowNotification]) {
		CGRect frame = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
		frame = [_panelHost convertRect:frame fromView:nil];
		height = MAX(0.0f, CGRectGetHeight(_panelHost.bounds) - CGRectGetMinY(frame));
	}

	_panelKeyboardHeight = height;

	NSTimeInterval duration = [[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	[UIView animateWithDuration:duration > 0.0 ? duration : 0.25
					 animations:^{
						 [self layoutPanel];
					 }];
}

- (void)panelOrientationChanged:(NSNotification *)notification {
	(void)notification;

	if (!_panelVisible)
		return;

	[self layoutPanel];
}

- (CGFloat)panelContentWidth:(CGFloat)panelWidth {
	return panelWidth - 2.0f * kAlertPanelSideInset;
}

- (BOOL)panelStacksButtonsForWidth:(CGFloat)contentWidth {
	if (_panelButtons.count != 2)
		return _panelButtons.count > 2;

	CGFloat half = (contentWidth - kAlertPanelButtonGap) / 2.0f;
	for (UIButton *button in _panelButtons) {
		NSString *title = [button titleForState:UIControlStateNormal];
		CGSize size = [title sizeWithFont:TGAlertPanelButtonFont()];
		if (size.width + kAlertPanelButtonLabelPadding > half)
			return YES;
	}

	return NO;
}

- (void)layoutPanel {
	if (_panelHost == nil || _panel == nil)
		return;

	CGFloat hostWidth = CGRectGetWidth(_panelHost.bounds);
	CGFloat hostHeight = CGRectGetHeight(_panelHost.bounds);
	CGFloat panelWidth = MIN(kAlertPanelWidth, hostWidth - 2.0f * kAlertPanelScreenMargin);
	CGFloat contentWidth = [self panelContentWidth:panelWidth];

	CGFloat titleHeight = 0.0f;
	if (_panelTitleLabel != nil) {
		CGSize size = [self.title sizeWithFont:TGAlertPanelTitleFont()
							 constrainedToSize:CGSizeMake(contentWidth, CGFLOAT_MAX)
								 lineBreakMode:NSLineBreakByWordWrapping];
		titleHeight = ceilf(size.height);
	}

	CGFloat messageHeight = 0.0f;
	if (_panelMessageLabel != nil) {
		CGSize size = [self.message sizeWithFont:TGAlertPanelMessageFont()
							   constrainedToSize:CGSizeMake(contentWidth, CGFLOAT_MAX)
								   lineBreakMode:NSLineBreakByWordWrapping];
		messageHeight = ceilf(size.height);
	}

	BOOL stacked = [self panelStacksButtonsForWidth:contentWidth] || _panelButtons.count == 1;
	NSInteger rows = stacked ? _panelButtons.count : 1;
	NSInteger gapCount = rows > 0 ? rows - 1 : 0;
	BOOL hasText = (_panelTitleLabel != nil || _panelMessageLabel != nil);
	BOOL hasBoth = (_panelTitleLabel != nil && _panelMessageLabel != nil);

	CGFloat buttonHeight = kAlertPanelButtonHeight;
	CGFloat fixed = titleHeight + messageHeight + kAlertPanelFieldHeight + rows * buttonHeight;

	CGFloat nominal = kAlertPanelTopInset + kAlertPanelBottomInset + kAlertPanelFieldToButtons +
		(hasBoth ? kAlertPanelTitleToMessage : 0.0f) +
		(hasText ? kAlertPanelTextToField : 0.0f) +
		gapCount * kAlertPanelButtonGap;
	CGFloat minimum = 8.0f + 4.0f + 8.0f +
		(hasBoth ? 4.0f : 0.0f) +
		(hasText ? 8.0f : 0.0f) +
		gapCount * 6.0f;

	CGFloat available = hostHeight - _panelKeyboardHeight - kAlertPanelScreenMargin;
	CGFloat factor = 1.0f;
	if (fixed + nominal > available && nominal > minimum)
		factor = MAX(0.0f, MIN(1.0f, (available - fixed - minimum) / (nominal - minimum)));

	if (factor <= 0.0f && rows > 1) {
		CGFloat room = available - (titleHeight + messageHeight + kAlertPanelFieldHeight) - minimum;
		buttonHeight = MAX(32.0f, MIN(kAlertPanelButtonHeight, room / (CGFloat)rows));
	}

	CGFloat topInset = 8.0f + (kAlertPanelTopInset - 8.0f) * factor;
	CGFloat bottomInset = 4.0f + (kAlertPanelBottomInset - 4.0f) * factor;
	CGFloat titleToMessage = 4.0f + (kAlertPanelTitleToMessage - 4.0f) * factor;
	CGFloat textToField = 8.0f + (kAlertPanelTextToField - 8.0f) * factor;
	CGFloat fieldToButtons = 8.0f + (kAlertPanelFieldToButtons - 8.0f) * factor;
	CGFloat buttonGap = 6.0f + (kAlertPanelButtonGap - 6.0f) * factor;

	CGFloat top = topInset;

	if (_panelTitleLabel != nil) {
		_panelTitleLabel.frame = CGRectMake(kAlertPanelSideInset, top, contentWidth, titleHeight);
		top = CGRectGetMaxY(_panelTitleLabel.frame);
	}

	if (_panelMessageLabel != nil) {
		if (_panelTitleLabel != nil)
			top += titleToMessage;

		_panelMessageLabel.frame = CGRectMake(kAlertPanelSideInset, top, contentWidth, messageHeight);
		top = CGRectGetMaxY(_panelMessageLabel.frame);
	}

	if (hasText)
		top += textToField;

	_panelField.frame = CGRectMake(kAlertPanelSideInset, top, contentWidth, kAlertPanelFieldHeight);
	top = CGRectGetMaxY(_panelField.frame) + fieldToButtons;

	if (stacked) {
		for (UIButton *button in _panelButtons) {
			button.frame = CGRectMake(kAlertPanelSideInset, top, contentWidth, buttonHeight);
			top = CGRectGetMaxY(button.frame) + buttonGap;
		}
		if (_panelButtons.count != 0)
			top -= buttonGap;
	} else {
		CGFloat half = (contentWidth - buttonGap) / 2.0f;
		UIButton *first = [_panelButtons objectAtIndex:0];
		UIButton *second = [_panelButtons objectAtIndex:1];
		second.frame = CGRectMake(kAlertPanelSideInset, top, half, buttonHeight);
		first.frame = CGRectMake(kAlertPanelSideInset + half + buttonGap, top, half, buttonHeight);
		top += buttonHeight;
	}

	CGFloat panelHeight = top + bottomInset;
	CGFloat originY = floorf((hostHeight - _panelKeyboardHeight - panelHeight) / 2.0f);
	if (originY < kAlertPanelScreenMargin / 2.0f)
		originY = kAlertPanelScreenMargin / 2.0f;

	CGAffineTransform transform = _panel.transform;
	_panel.transform = CGAffineTransformIdentity;
	_panel.frame = CGRectMake(floorf((hostWidth - panelWidth) / 2.0f), originY, panelWidth, panelHeight);
	_panel.transform = transform;
	[_panel setNeedsDisplay];
}

- (void)panelButtonTapped:(UIButton *)button {
	[self dismissPanelWithButtonIndex:button.tag];
}

- (void)panelFieldShouldReturn {
	NSInteger index = self.firstOtherButtonIndex;
	if (index < 0)
		index = self.cancelButtonIndex;
	if (index < 0)
		index = 0;

	[self dismissPanelWithButtonIndex:index];
}

- (void)dismissPanelWithButtonIndex:(NSInteger)index {
	if (!_panelVisible)
		return;

	_panelVisible = NO;

	if (self.keyboardWillShowObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:self.keyboardWillShowObserverToken];
		self.keyboardWillShowObserverToken = nil;
	}
	if (self.keyboardWillHideObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:self.keyboardWillHideObserverToken];
		self.keyboardWillHideObserverToken = nil;
	}
	if (self.statusBarOrientationObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:self.statusBarOrientationObserverToken];
		self.statusBarOrientationObserverToken = nil;
	}

	[_panelField resignFirstResponder];
	_panelField.delegate = nil;

	UIView *host = _panelHost;
	_panelHost = nil;
	_panel = nil;
	_panelTitleLabel = nil;
	_panelMessageLabel = nil;
	_panelButtons = nil;

	[UIView animateWithDuration:0.2
		animations:^{
			host.alpha = 0.0f;
		}
		completion:^(BOOL finished) {
			(void)finished;
			[host removeFromSuperview];
		}];

	id<UIAlertViewDelegate> delegate = self.delegate;
	if (delegate != nil && delegate != self && [delegate respondsToSelector:@selector(alertView:clickedButtonAtIndex:)])
		[delegate alertView:self clickedButtonAtIndex:index];

	[self invokeCompletionWithResult:(self.cancelButtonIndex < 0 || index != self.cancelButtonIndex)];

	if (delegate != nil && delegate != self && [delegate respondsToSelector:@selector(alertView:didDismissWithButtonIndex:)])
		[delegate alertView:self didDismissWithButtonIndex:index];

	dispatch_async(dispatch_get_main_queue(), ^{
		[TGAlertViewVisiblePanels() removeObject:self];
	});
}

- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated {
	if (_panelVisible) {
		[self dismissPanelWithButtonIndex:buttonIndex];
		return;
	}

	[super dismissWithClickedButtonIndex:buttonIndex animated:animated];
}

- (BOOL)isVisible {
	return _panelVisible ? YES : [super isVisible];
}

- (void)invokeCompletionWithResult:(bool)okButtonPressed {
	void (^block)(bool) = _completionBlock;
	_completionBlock = nil;

	if (block != nil)
		block(okButtonPressed);
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	[self invokeCompletionWithResult:(alertView.cancelButtonIndex < 0 || buttonIndex != alertView.cancelButtonIndex)];
}

- (void)alertViewCancel:(UIAlertView *)alertView {
	(void)alertView;
	[self invokeCompletionWithResult:false];
}

@end

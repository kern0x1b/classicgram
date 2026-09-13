#import "TGLoginViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGCountryPickerViewController.h"
#import "TGPhoneFormat.h"
#import "TGActionSheet.h"
#import "TGAccountManager.h"
#import "TGBackspaceTextField.h"
#import "TGLoginToolbarButton.h"
#import <QuartzCore/QuartzCore.h>
#import "TGLoginViewControllerInternal.h"
#import "TGHexColour.h"

static inline NSString *tgGroupDigits(NSString *digits, const int *groups, int groupCount, NSString *separator, BOOL parenthesiseFirst) {
	NSMutableString *result = [NSMutableString string];
	NSInteger position = 0;
	for (NSInteger i = 0; i < groupCount && position < digits.length; i++) {
		NSInteger length = (NSUInteger)groups[i];
		if (position + length > digits.length)
			length = digits.length - position;
		NSString *chunk = [digits substringWithRange:NSMakeRange(position, length)];
		if (i == 0 && parenthesiseFirst) {
			[result appendFormat:@"(%@", chunk];
			if (position + length < digits.length || length == (NSUInteger)groups[0])
				[result appendString:@")"];
		} else {
			if (result.length > 0)
				[result appendString:i == 1 ? @" " : separator];
			[result appendString:chunk];
		}
		position += length;
	}
	if (position < digits.length)
		[result appendFormat:@"%@%@", separator, [digits substringFromIndex:position]];
	return result;
}

static inline NSString *tgDigitsOf(NSString *string) {
	if (string.length == 0)
		return @"";
	NSMutableString *result = [NSMutableString stringWithCapacity:string.length];
	for (NSInteger i = 0; i < string.length; i++) {
		unichar c = [string characterAtIndex:i];
		if (c >= '0' && c <= '9')
			[result appendFormat:@"%C", c];
	}
	return result;
}

static inline NSString *tgNationalFromPhoneFormats(NSString *dialDigits, NSString *nationalDigits) {
	if (dialDigits.length == 0)
		return nil;
	TGPhoneFormat *formatter = [TGPhoneFormat instance];
	if (formatter == nil)
		return nil;

	NSString *full = [formatter format:[NSString stringWithFormat:@"+%@%@", dialDigits, nationalDigits]
						  implicitPlus:NO];
	if (![full hasPrefix:@"+"])
		return nil;

	NSString *body = [full substringFromIndex:1];
	NSInteger consumed = 0;
	NSInteger index = 0;
	while (index < body.length && consumed < dialDigits.length) {
		unichar c = [body characterAtIndex:index];
		if (c >= '0' && c <= '9')
			consumed++;
		index++;
	}
	if (consumed != dialDigits.length)
		return nil;

	NSString *rest = [[body substringFromIndex:index]
		stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -"]];
	if (![tgDigitsOf(rest) isEqualToString:nationalDigits])
		return nil;
	return rest;
}

static inline NSString *tgFormatNationalNumber(NSString *dialDigits, NSString *nationalDigits) {
	if (nationalDigits.length == 0)
		return @"";
	NSString *fromData = tgNationalFromPhoneFormats(dialDigits, nationalDigits);
	if (fromData.length != 0)
		return fromData;
	if ([dialDigits isEqualToString:@"1"]) {
		static const int groups[] = {3, 3, 4};
		NSMutableString *out = [NSMutableString string];
		NSInteger position = 0;
		for (NSInteger i = 0; i < 3 && position < nationalDigits.length; i++) {
			NSInteger length = (NSUInteger)groups[i];
			if (position + length > nationalDigits.length)
				length = nationalDigits.length - position;
			NSString *chunk = [nationalDigits substringWithRange:NSMakeRange(position, length)];
			if (i == 0) {
				[out appendFormat:@"(%@", chunk];
				if (length == 3)
					[out appendString:@")"];
			} else if (i == 1) {
				[out appendFormat:@" %@", chunk];
			} else {
				[out appendFormat:@"-%@", chunk];
			}
			position += length;
		}
		if (position < nationalDigits.length)
			[out appendFormat:@"-%@", [nationalDigits substringFromIndex:position]];
		return out;
	}
	if ([dialDigits isEqualToString:@"7"]) {
		static const int groups[] = {3, 3, 2, 2};
		return tgGroupDigits(nationalDigits, groups, 4, @"-", NO);
	}
	return nationalDigits;
}

@implementation TGLoginViewController (Chrome)

#pragma mark - chrome

- (NSString *)formattedPhoneForDigits:(NSString *)nationalDigits {
	return tgFormatNationalNumber([self digitsOnly:self.countryCodeField.text], nationalDigits);
}

- (void)updateTitleText {
	NSString *nationalDigits = [self digitsOnly:self.inputField.text];
	NSString *dialDigits = [self digitsOnly:self.countryCodeField.text];
	if (nationalDigits.length == 0 || dialDigits.length == 0) {
		self.title = TGL(@"Login.PhoneTitle", @"Your Phone");
		return;
	}
	self.title = [NSString stringWithFormat:@"+%@ %@", dialDigits, tgFormatNationalNumber(dialDigits, nationalDigits)];
}

- (void)reformatPhoneField {
	if (self.currentStep != TGLoginStepPhone)
		return;
	self.inputField.text = [self formattedPhoneForDigits:[self digitsOnly:self.inputField.text]];
	[self updateTitleText];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	self.title = TGL(@"Login.PhoneTitle", @"Your Phone");

	[self setupNavigationBar];
	[self setupUI];
	[self observeKeyboardFrame];
}

- (void)observeKeyboardFrame {
	__weak typeof(self) weakSelf = self;
	self.keyboardFrameObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIKeyboardWillChangeFrameNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGLoginViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					CGRect frame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
					CGFloat height = UIInterfaceOrientationIsLandscape(strongSelf.interfaceOrientation)
						? frame.size.width
						: frame.size.height;
					if (height <= 0 || height == strongSelf.keyboardHeight)
						return;
					strongSelf.keyboardHeight = height;
					[strongSelf layoutInterface];
				}];
}

- (UIButton *)loginToolbarButtonWithTitle:(NSString *)title
									plate:(NSString *)plateName
								  pressed:(NSString *)pressedName
							  leftCapHalf:(BOOL)leftCapHalf
								  leftCap:(int)leftCap
							 shadowColour:(UIColor *)shadowColour
							  paddingLeft:(CGFloat)paddingLeft
							 paddingRight:(CGFloat)paddingRight
								 minWidth:(CGFloat)minWidth
								   isBack:(BOOL)isBack {
	TGLoginToolbarButton *button = [TGLoginToolbarButton buttonWithType:UIButtonTypeCustom];
	button.backSemantics = isBack;
	button.exclusiveTouch = YES;
	button.adjustsImageWhenDisabled = NO;
	button.adjustsImageWhenHighlighted = NO;

	UIImage *raw = [UIImage imageNamed:plateName];
	UIImage *rawPressed = [UIImage imageNamed:pressedName];
	if (raw != nil) {
		int cap = leftCapHalf ? (int)(raw.size.width / 2) : leftCap;
		UIImage *stretched = isBack ? TGLocalizedDirectionalStretchableImage(raw, cap)
									: [raw stretchableImageWithLeftCapWidth:cap topCapHeight:0];
		[button setBackgroundImage:stretched forState:UIControlStateNormal];
	}
	if (rawPressed != nil) {
		int cap = leftCapHalf ? (int)(rawPressed.size.width / 2) : leftCap;
		UIImage *stretched = isBack ? TGLocalizedDirectionalStretchableImage(rawPressed, cap)
									: [rawPressed stretchableImageWithLeftCapWidth:cap topCapHeight:0];
		[button setBackgroundImage:stretched forState:UIControlStateHighlighted];
		[button setBackgroundImage:stretched forState:UIControlStateSelected];
		[button setBackgroundImage:stretched forState:UIControlStateHighlighted | UIControlStateSelected];
	}

	button.titleLabel.font = [UIFont boldSystemFontOfSize:12];
	button.titleLabel.shadowOffset = CGSizeMake(0, -1);
	button.titleLabel.backgroundColor = [UIColor clearColor];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[button setTitleShadowColor:shadowColour forState:UIControlStateNormal];

	CGFloat lift = isBack ? 0.5f : 1.0f;
	button.titleEdgeInsets = UIEdgeInsetsMake(-lift, paddingLeft, lift, paddingRight);
	[button setTitle:title forState:UIControlStateNormal];

	[self sizeLoginToolbarButton:button
					 paddingLeft:paddingLeft
					paddingRight:paddingRight
						minWidth:minWidth];

	return button;
}

- (void)sizeLoginToolbarButton:(UIButton *)button
				   paddingLeft:(CGFloat)paddingLeft
				  paddingRight:(CGFloat)paddingRight
					  minWidth:(CGFloat)minWidth {
	NSString *title = [button titleForState:UIControlStateNormal];
	CGSize textSize = title.length > 0 ? [title sizeWithFont:button.titleLabel.font] : CGSizeZero;
	CGFloat width = paddingLeft + paddingRight + ceilf(textSize.width);
	if (width < minWidth)
		width = minWidth;
	button.frame = CGRectMake(button.frame.origin.x, button.frame.origin.y, width, 30);
}

- (void)setupNavigationBar {
	UINavigationBar *bar = self.navigationController.navigationBar;
	if (bar == nil)
		return;

	bar.barStyle = UIBarStyleBlackOpaque;

	UIImage *header = [UIImage imageNamed:@"LoginHeader.png"];
	if (header != nil && [bar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)])
		[bar setBackgroundImage:header forBarMetrics:UIBarMetricsDefault];

	if ([bar respondsToSelector:@selector(setTitleTextAttributes:)]) {
		if ([bar respondsToSelector:@selector(setBarTintColor:)])
			bar.titleTextAttributes = @{NSForegroundColorAttributeName : [UIColor whiteColor]};
		else
			bar.titleTextAttributes = @{UITextAttributeTextColor : [UIColor whiteColor],
				UITextAttributeTextShadowColor : TGColourFromHex(0x25272b),
				UITextAttributeTextShadowOffset : [NSValue valueWithUIOffset:UIOffsetMake(0, 1)]};
	}

	self.nextButton = [self
		loginToolbarButtonWithTitle:TGL(@"Common.Next", @"Next")
							  plate:@"HeaderButton_Login_Blue.png"
							pressed:@"HeaderButton_Login_Blue_Pressed.png"
						leftCapHalf:YES
							leftCap:0
					   shadowColour:tgRGBA(0x042651, 0.3f)
						paddingLeft:7
					   paddingRight:7
						   minWidth:52
							 isBack:NO];
	[self.nextButton addTarget:self action:@selector(actionButtonTapped) forControlEvents:UIControlEventTouchUpInside];

	self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	self.spinner.frame = CGRectMake(floorf((self.nextButton.frame.size.width - self.spinner.frame.size.width) / 2),
		floorf((self.nextButton.frame.size.height - self.spinner.frame.size.height) / 2),
		self.spinner.frame.size.width, self.spinner.frame.size.height);
	self.spinner.hidesWhenStopped = YES;
	[self.nextButton addSubview:self.spinner];

	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.nextButton];

	[self installCancelButtonIfNeeded];
}

- (UIButton *)neutralLoginButtonWithTitle:(NSString *)title {
	return [self loginToolbarButtonWithTitle:title
									   plate:@"HeaderButton_Login.png"
									 pressed:@"HeaderButton_Login_Pressed.png"
								 leftCapHalf:NO
									 leftCap:11
								shadowColour:tgRGBA(0x07080a, 0.35f)
								 paddingLeft:7
								paddingRight:7
									minWidth:0
									  isBack:NO];
}

- (void)setLoginButton:(UIButton *)button title:(NSString *)title {
	[button setTitle:title forState:UIControlStateNormal];
	[self sizeLoginToolbarButton:button paddingLeft:7 paddingRight:7 minWidth:0];
}

- (void)installCancelButtonIfNeeded {
	if (!self.cancellable) {
		self.navigationItem.leftBarButtonItem = nil;
		return;
	}
	if (self.cancelButton == nil) {
		self.cancelButton = [self neutralLoginButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
		[self.cancelButton addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
	}
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.cancelButton];
}

- (void)cancelTapped {
	[self.inputField resignFirstResponder];
	[self setBusy:NO];
	void (^cancelled)(void) = self.onCancelled;
	if (cancelled)
		dispatch_async(dispatch_get_main_queue(), cancelled);
}

- (UILabel *)countdownStateLabelWithText:(NSString *)text {
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
	label.font = [UIFont systemFontOfSize:14];
	label.textColor = TGColourFromHex(0xc4c9d2);
	label.shadowColor = TGColourFromHex(0x25272b);
	label.shadowOffset = CGSizeMake(0, 1);
	label.textAlignment = NSTextAlignmentCenter;
	label.contentMode = UIViewContentModeCenter;
	label.lineBreakMode = NSLineBreakByWordWrapping;
	label.numberOfLines = 0;
	label.backgroundColor = [UIColor clearColor];
	label.text = text;
	label.hidden = YES;
	return label;
}

- (void)setupUI {
	[self buildBackgroundLayers];
	[self buildNoticeLabel];
	[self buildCountryButton];
	[self buildPlateImages];
	[self buildInputPlate];
	[self buildPhoneFields];
	[self buildLastNameRow];
	[self buildCountdownLabels];
	[self buildResendAndExtraButtons];
	[self buildShadeView];

	self.currentStep = TGLoginStepPhone;
	[self updateCountryNameForDialCode];
	[self layoutInterface];
	[self updateNextEnabled];

	dispatch_async(dispatch_get_main_queue(), ^{
		[self.inputField becomeFirstResponder];
	});

	[self prefillGuessedCountry];
}

- (void)buildBackgroundLayers {
	UIImage *linen = [UIImage imageNamed:@"DarkLinen.png"];
	if (linen != nil)
		self.view.backgroundColor = [UIColor colorWithPatternImage:linen];
	else
		self.view.backgroundColor = TGColourFromHex(0x1c1e22);

	UIImage *shadow = [UIImage imageNamed:@"LoginShadow.png"];
	if (shadow != nil) {
		UIImageView *shadowView = [[UIImageView alloc] initWithFrame:self.view.bounds];
		shadowView.image = shadow;
		shadowView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self.view addSubview:shadowView];
	}

	UIImage *headerShadow = [UIImage imageNamed:@"HeaderLoginShadow.png"];
	if (headerShadow != nil) {
		UIImageView *headerShadowView = [[UIImageView alloc] initWithImage:[headerShadow stretchableImageWithLeftCapWidth:0 topCapHeight:0]];
		headerShadowView.frame = CGRectMake(0, 0, self.view.bounds.size.width, headerShadow.size.height);
		headerShadowView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self.view addSubview:headerShadowView];
	}
}

- (void)buildNoticeLabel {
	self.noticeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.noticeLabel.font = [UIFont systemFontOfSize:14];
	self.noticeLabel.textColor = TGColourFromHex(0xc0c5cc);
	self.noticeLabel.shadowColor = TGColourFromHex(0x323c4a);
	self.noticeLabel.shadowOffset = CGSizeMake(0, 1);
	self.noticeLabel.backgroundColor = [UIColor clearColor];
	self.noticeLabel.lineBreakMode = NSLineBreakByWordWrapping;
	self.noticeLabel.textAlignment = NSTextAlignmentCenter;
	self.noticeLabel.contentMode = UIViewContentModeCenter;
	self.noticeLabel.numberOfLines = 0;
	self.noticeLabel.text = TGL(@"Login.PhoneAndCountryHelp", @"Please confirm your country code and enter your phone number.");
	[self.view addSubview:self.noticeLabel];
}

- (void)buildCountryButton {
	UIImage *rawCountryImage = [UIImage imageNamed:@"LoginCountry.png"];
	UIImage *rawCountryImageHighlighted = [UIImage imageNamed:@"LoginCountry_Highlighted.png"];

	CGFloat countryHeight = rawCountryImage != nil ? rawCountryImage.size.height : 55;
	self.countryButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.countryButton.frame = CGRectMake(0, 0, 290, countryHeight);
	self.countryButton.exclusiveTouch = YES;
	if (rawCountryImage != nil)
		[self.countryButton setBackgroundImage:[rawCountryImage stretchableImageWithLeftCapWidth:(int)(rawCountryImage.size.width - 16) topCapHeight:0] forState:UIControlStateNormal];
	if (rawCountryImageHighlighted != nil)
		[self.countryButton setBackgroundImage:[rawCountryImageHighlighted stretchableImageWithLeftCapWidth:(int)(rawCountryImageHighlighted.size.width - 16) topCapHeight:0] forState:UIControlStateHighlighted];
	self.countryButton.titleLabel.font = [UIFont boldSystemFontOfSize:16.5f];
	self.countryButton.titleLabel.textAlignment = NSTextAlignmentLeft;
	self.countryButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
	[self.countryButton setTitleColor:TGColourFromHex(0xf0f0f0) forState:UIControlStateNormal];
	[self.countryButton setTitleShadowColor:TGColourFromHex(0x17191d) forState:UIControlStateNormal];
	[self.countryButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
	[self.countryButton setTitleShadowColor:[UIColor clearColor] forState:UIControlStateHighlighted];
	self.countryButton.titleLabel.shadowOffset = CGSizeMake(0, 1);
	self.countryButton.titleEdgeInsets = UIEdgeInsetsMake(0, 14, 9, 14);
	[self.countryButton setTitle:[self currentCountryName] forState:UIControlStateNormal];
	[self.countryButton addTarget:self action:@selector(countryButtonTapped) forControlEvents:UIControlEventTouchUpInside];

	UIImage *arrowImage = TGLocalizedDirectionalImage([UIImage imageNamed:@"LoginCountryArrow.png"]);
	if (arrowImage != nil) {
		UIImageView *arrowView = [[UIImageView alloc] initWithImage:arrowImage highlightedImage:TGLocalizedDirectionalImage([UIImage imageNamed:@"LoginCountryArrow_Highlighted.png"])];
		arrowView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		arrowView.frame = CGRectMake(290 - arrowImage.size.width - 15, 16, arrowImage.size.width, arrowImage.size.height);
		[self.countryButton addSubview:arrowView];
	}
	[self.view addSubview:self.countryButton];
}

- (void)buildPlateImages {
	UIImage *rawInputImage = [UIImage imageNamed:@"LoginInput.png"];
	if (rawInputImage != nil)
		self.plateImage = [rawInputImage stretchableImageWithLeftCapWidth:(int)(rawInputImage.size.width / 2) topCapHeight:(int)(rawInputImage.size.height / 2)];

	UIImage *rawTopImage = [UIImage imageNamed:@"LoginInput_Top.png"];
	self.plateTopImage = rawTopImage != nil
		? [rawTopImage stretchableImageWithLeftCapWidth:(int)(rawTopImage.size.width / 2) topCapHeight:0]
		: self.plateImage;

	UIImage *rawBottomImage = [UIImage imageNamed:@"LoginInput_Bottom.png"];
	self.plateBottomImage = rawBottomImage != nil
		? [rawBottomImage stretchableImageWithLeftCapWidth:(int)(rawBottomImage.size.width / 2) topCapHeight:0]
		: self.plateImage;
}

- (void)buildInputPlate {
	self.inputBackgroundView = [[UIImageView alloc] initWithFrame:CGRectZero];
	self.inputBackgroundView.image = self.plateImage;
	[self.view addSubview:self.inputBackgroundView];

	UIImage *rawDivider = [UIImage imageNamed:@"LoginInputDivider.png"];
	self.inputDivider = [[UIImageView alloc] initWithFrame:CGRectMake(60, 1, 1, 48)];
	if (rawDivider != nil)
		self.inputDivider.image = [rawDivider stretchableImageWithLeftCapWidth:0 topCapHeight:4];
	[self.inputBackgroundView addSubview:self.inputDivider];

	self.inputBackgroundView.userInteractionEnabled = YES;
	[self.inputBackgroundView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(inputBackgroundTapped:)]];
}

- (void)buildPhoneFields {
	self.countryCodeField = [[UITextField alloc] initWithFrame:CGRectZero];
	self.countryCodeField.font = [UIFont boldSystemFontOfSize:18];
	self.countryCodeField.backgroundColor = TGColourFromHex(0xf5f5f5);
	self.countryCodeField.text = [self defaultDialCode];
	self.countryCodeField.textAlignment = NSTextAlignmentCenter;
	self.countryCodeField.keyboardType = UIKeyboardTypeNumberPad;
	self.countryCodeField.delegate = self;
	[self.countryCodeField addTarget:self action:@selector(countryCodeChanged) forControlEvents:UIControlEventEditingChanged];
	[self.countryCodeField addTarget:self action:@selector(phoneFieldsDidEndEditing) forControlEvents:UIControlEventEditingDidEnd];
	[self.view addSubview:self.countryCodeField];

	TGBackspaceTextField *phoneField = [[TGBackspaceTextField alloc] initWithFrame:CGRectZero];
	phoneField.backspaceDelegate = self;
	self.inputField = phoneField;
	self.inputField.font = [UIFont boldSystemFontOfSize:18];
	self.inputField.backgroundColor = TGColourFromHex(0xf5f5f5);
	self.inputField.placeholder = TGL(@"Login.PhonePlaceholder", @"Your phone number");
	self.inputField.keyboardType = UIKeyboardTypeNumberPad;
	self.inputField.delegate = self;
	self.inputField.returnKeyType = UIReturnKeyDone;
	self.inputField.autocorrectionType = UITextAutocorrectionTypeNo;
	self.inputField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	[self.inputField addTarget:self action:@selector(inputChanged) forControlEvents:UIControlEventEditingChanged];
	[self.inputField addTarget:self action:@selector(phoneFieldsDidEndEditing) forControlEvents:UIControlEventEditingDidEnd];
	[self.view addSubview:self.inputField];
}

- (void)buildLastNameRow {
	self.lastNameBackgroundView = [[UIImageView alloc] initWithFrame:CGRectZero];
	self.lastNameBackgroundView.image = self.plateBottomImage;
	self.lastNameBackgroundView.userInteractionEnabled = YES;
	self.lastNameBackgroundView.hidden = YES;
	[self.lastNameBackgroundView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(lastNameBackgroundTapped)]];
	[self.view addSubview:self.lastNameBackgroundView];

	self.lastNameField = [[UITextField alloc] initWithFrame:CGRectZero];
	self.lastNameField.font = [UIFont boldSystemFontOfSize:15.0f];
	self.lastNameField.backgroundColor = TGColourFromHex(0xf5f5f5);
	self.lastNameField.placeholder = TGL(@"Login.InfoLastNamePlaceholder", @"Last name");
	self.lastNameField.keyboardType = UIKeyboardTypeDefault;
	self.lastNameField.autocorrectionType = UITextAutocorrectionTypeNo;
	self.lastNameField.autocapitalizationType = UITextAutocapitalizationTypeWords;
	self.lastNameField.returnKeyType = UIReturnKeyDone;
	self.lastNameField.delegate = self;
	self.lastNameField.hidden = YES;
	[self.lastNameField addTarget:self action:@selector(inputChanged) forControlEvents:UIControlEventEditingChanged];
	[self.view addSubview:self.lastNameField];
}

- (void)buildCountdownLabels {
	self.timeoutLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.timeoutLabel.font = [UIFont systemFontOfSize:14];
	self.timeoutLabel.textColor = TGColourFromHex(0xc4c9d2);
	self.timeoutLabel.shadowColor = TGColourFromHex(0x25272b);
	self.timeoutLabel.shadowOffset = CGSizeMake(0, 1);
	self.timeoutLabel.textAlignment = NSTextAlignmentCenter;
	self.timeoutLabel.contentMode = UIViewContentModeCenter;
	self.timeoutLabel.lineBreakMode = NSLineBreakByWordWrapping;
	self.timeoutLabel.numberOfLines = 0;
	self.timeoutLabel.backgroundColor = [UIColor clearColor];
	self.timeoutLabel.hidden = YES;
	[self.view addSubview:self.timeoutLabel];

	self.requestingCallLabel = [self countdownStateLabelWithText:TGL(@"Login.CallRequestState2", @"Requesting a call from Telegram...")];
	[self.view addSubview:self.requestingCallLabel];

	self.callSentLabel = [self countdownStateLabelWithText:TGL(@"Login.CallRequestState3", @"Telegram dialed your number")];
	[self.view addSubview:self.callSentLabel];
}

- (void)buildResendAndExtraButtons {
	self.resendButton = [self
		loginToolbarButtonWithTitle:TGL(@"Login.SendCodeViaSms", @"Send the code as an SMS")
							  plate:@"HeaderButton_Login.png"
							pressed:@"HeaderButton_Login_Pressed.png"
						leftCapHalf:NO
							leftCap:11
					   shadowColour:tgRGBA(0x07080a, 0.35f)
						paddingLeft:7
					   paddingRight:7
						   minWidth:0
							 isBack:NO];
	[self.resendButton addTarget:self action:@selector(resendTapped) forControlEvents:UIControlEventTouchUpInside];
	self.resendButton.hidden = YES;
	[self.view addSubview:self.resendButton];

	self.extraButton = [self neutralLoginButtonWithTitle:TGL(@"Login.HaveNotReceivedCodeInternal", @"Didn't get the code?")];
	[self.extraButton addTarget:self action:@selector(extraTapped) forControlEvents:UIControlEventTouchUpInside];
	self.extraButton.hidden = YES;
	[self.view addSubview:self.extraButton];
}

- (void)buildShadeView {
	self.shadeView = [[UIView alloc] initWithFrame:self.view.bounds];
	self.shadeView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.shadeView.backgroundColor = [UIColor clearColor];
	self.shadeView.hidden = YES;
	[self.view addSubview:self.shadeView];
}

@end

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

@implementation TGLoginViewController (Layout)

#pragma mark - layout

- (CGFloat)plateWidthForCurrentStep {
	switch (self.currentStep) {
		case TGLoginStepCode:
			return self.codeIsText ? 240 : 80;
		case TGLoginStepEmailCode:
		case TGLoginStepRecoveryCode:
			return 80;
		default:
			return 200;
	}
}

- (void)restylePlaceholders {
	UIFont *fieldFont = [UIFont boldSystemFontOfSize:self.currentStep == TGLoginStepRegistration ? 15.0f : 18.0f];
	if (![self.inputField.font isEqual:fieldFont])
		self.inputField.font = fieldFont;

	if (self.currentStep == TGLoginStepPhone) {
		tgStylePlaceholder(self.inputField, [UIFont systemFontOfSize:17], TGColourFromHex(0x999999));
	} else if (self.currentStep == TGLoginStepRegistration) {
		tgStylePlaceholder(self.inputField, self.inputField.font, TGColourFromHex(0x999da4));
		tgStylePlaceholder(self.lastNameField, self.lastNameField.font, TGColourFromHex(0x999da4));
	} else {
		tgStylePlaceholder(self.inputField, [UIFont systemFontOfSize:18], TGColourFromHex(0xadb0b6));
	}
}

- (void)setNextButtonTitle:(NSString *)title {
	if ([[self.nextButton titleForState:UIControlStateNormal] isEqualToString:title])
		return;
	[self.nextButton setTitle:title forState:UIControlStateNormal];
	[self sizeLoginToolbarButton:self.nextButton
					 paddingLeft:7
					paddingRight:7
						minWidth:self.currentStep == TGLoginStepRegistration ? 51 : 52];
	self.spinner.frame = CGRectMake(floorf((self.nextButton.frame.size.width - self.spinner.frame.size.width) / 2),
		floorf((self.nextButton.frame.size.height - self.spinner.frame.size.height) / 2),
		self.spinner.frame.size.width, self.spinner.frame.size.height);
}

static const CGFloat kLoginStatusBarHeight = 20.0f;
static const CGFloat kLoginNavigationBarHeight = 44.0f;

static CGFloat TGLoginEstimatedKeyboardHeight(CGSize screenSize) {
	BOOL wide = screenSize.width >= 768.0f;
	BOOL portrait = screenSize.height >= screenSize.width;
	if (wide)
		return portrait ? 264.0f : 352.0f;
	return portrait ? 216.0f : 162.0f;
}

- (void)layoutInterface {
	CGSize screenSize = [UIScreen mainScreen].bounds.size;
	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
		CGFloat swap = screenSize.width;
		screenSize.width = screenSize.height;
		screenSize.height = swap;
	}
	CGFloat keyboard = self.keyboardHeight > 0 ? self.keyboardHeight
												: TGLoginEstimatedKeyboardHeight(screenSize);
	CGSize viewSize = CGSizeMake(screenSize.width,
		screenSize.height - kLoginStatusBarHeight - kLoginNavigationBarHeight - keyboard);

	[self setNextButtonTitle:self.currentStep == TGLoginStepRegistration ? TGL(@"Common.Done", @"Done") : TGL(@"Common.Next", @"Next")];
	[self restylePlaceholders];

	self.noticeLabel.hidden = self.currentStep == TGLoginStepRegistration;
	if (self.currentStep != TGLoginStepRegistration)
		self.inputBackgroundView.image = self.plateImage;

	if (self.currentStep != TGLoginStepRegistration) {
		self.lastNameBackgroundView.hidden = YES;
		self.lastNameField.hidden = YES;
	}

	if (self.currentStep == TGLoginStepRegistration) {
		[self layoutRegistrationStepForViewSize:viewSize];
		return;
	}

	self.inputBackgroundView.hidden = NO;
	self.inputField.hidden = NO;

	if (self.currentStep == TGLoginStepPhone)
		[self layoutPhoneRowForViewSize:viewSize];
	else
		[self layoutCentredPlateForViewSize:viewSize];

	[self layoutNoticeLabelForViewSize:viewSize];
	[self layoutCountdownRowForViewSize:viewSize];
}

- (void)layoutRegistrationStepForViewSize:(CGSize)viewSize {
	CGFloat width = 288;
	self.countryButton.hidden = YES;
	self.countryCodeField.hidden = YES;
	self.inputDivider.hidden = YES;
	self.inputBackgroundView.hidden = NO;
	self.inputField.hidden = NO;
	self.lastNameBackgroundView.hidden = NO;
	self.lastNameField.hidden = NO;

	self.inputBackgroundView.image = self.plateTopImage;
	self.lastNameBackgroundView.image = self.plateBottomImage;

	CGFloat retinaOffset = [UIScreen mainScreen].scale > 1.0f ? 0.5f : 0.0f;
	CGFloat top = (int)((viewSize.height - 68) / 2) - 7;
	self.inputBackgroundView.frame = CGRectMake((int)((viewSize.width - width) / 2), top, width, 43);
	self.inputField.frame = CGRectMake(self.inputBackgroundView.frame.origin.x + 15,
		self.inputBackgroundView.frame.origin.y + 11.0f + retinaOffset,
		width - 20, 22);
	self.inputField.textAlignment = NSTextAlignmentLeft;

	self.lastNameBackgroundView.frame = CGRectIntegral(CGRectMake(self.inputBackgroundView.frame.origin.x,
		self.inputBackgroundView.frame.origin.y + 43,
		width, 43));
	self.lastNameField.frame = CGRectMake(self.lastNameBackgroundView.frame.origin.x + 15,
		self.lastNameBackgroundView.frame.origin.y + 10.0f + retinaOffset,
		width - 20, 22);

	self.noticeLabel.hidden = YES;

	self.timeoutLabel.hidden = YES;
	self.requestingCallLabel.hidden = YES;
	self.callSentLabel.hidden = YES;
	self.resendButton.hidden = YES;
	self.extraButton.hidden = YES;
}

- (void)layoutPhoneRowForViewSize:(CGSize)viewSize {
	CGFloat width = 290;
	CGFloat retinaOffset = [UIScreen mainScreen].scale > 1.0f ? 0.5f : 0.0f;
	self.countryButton.hidden = NO;
	self.countryCodeField.hidden = NO;
	self.inputDivider.hidden = NO;

	self.countryButton.frame = CGRectMake((int)((viewSize.width - width) / 2),
		(int)((viewSize.height - 68) / 2) + 4.0f + retinaOffset,
		width, self.countryButton.frame.size.height);
	self.inputBackgroundView.frame = CGRectIntegral(CGRectMake((viewSize.width - width) / 2,
		self.countryButton.frame.origin.y + self.countryButton.frame.size.height + 7.0f + retinaOffset,
		width, 47));
	self.inputDivider.frame = CGRectMake(60, 1, 1, self.inputBackgroundView.frame.size.height + 1);
	self.countryCodeField.frame = CGRectMake(self.inputBackgroundView.frame.origin.x + 4, self.inputBackgroundView.frame.origin.y + 12, 54, 22);
	self.inputField.frame = CGRectMake(self.inputBackgroundView.frame.origin.x + 74, self.inputBackgroundView.frame.origin.y + 2,
		self.inputBackgroundView.frame.size.width - 74 - 14, 32);
	self.inputField.textAlignment = NSTextAlignmentLeft;
}

- (void)layoutCentredPlateForViewSize:(CGSize)viewSize {
	CGFloat width = [self plateWidthForCurrentStep];
	self.countryButton.hidden = YES;
	self.countryCodeField.hidden = YES;
	self.inputDivider.hidden = YES;

	self.inputBackgroundView.frame = CGRectIntegral(CGRectMake((viewSize.width - width) / 2,
		(viewSize.height - 26) / 2,
		width, 43));
	self.inputField.frame = CGRectMake(self.inputBackgroundView.frame.origin.x + 9,
		self.inputBackgroundView.frame.origin.y + 10,
		self.inputBackgroundView.frame.size.width - 20, 22);
	self.inputField.textAlignment = NSTextAlignmentCenter;
}

- (void)layoutNoticeLabelForViewSize:(CGSize)viewSize {
	CGSize noticeSize = [self.noticeLabel sizeThatFits:CGSizeMake(self.currentStep == TGLoginStepPhone ? 270 : 300, 1024)];
	CGFloat anchorY = self.currentStep == TGLoginStepPhone ? self.countryButton.frame.origin.y : self.inputBackgroundView.frame.origin.y;
	CGFloat spacing = self.currentStep == TGLoginStepPhone ? 16 : 14;
	self.noticeLabel.frame = CGRectIntegral(CGRectMake((viewSize.width - noticeSize.width) / 2,
		anchorY - spacing - noticeSize.height,
		noticeSize.width, noticeSize.height));
	self.noticeLabel.alpha = self.noticeLabel.frame.origin.y < 0 ? 0.0f : 1.0f;
}

- (void)layoutCountdownRowForViewSize:(CGSize)viewSize {
	CGFloat resendY = self.inputBackgroundView.frame.origin.y + self.inputBackgroundView.frame.size.height + 14;

	CGSize timeoutSize = [self.timeoutLabel sizeThatFits:CGSizeMake(300, 1024)];
	self.timeoutLabel.frame = CGRectIntegral(CGRectMake((viewSize.width - timeoutSize.width) / 2, resendY, timeoutSize.width, timeoutSize.height));

	CGSize requestingSize = [self.requestingCallLabel sizeThatFits:CGSizeMake(300, 1024)];
	self.requestingCallLabel.frame = CGRectIntegral(CGRectMake((viewSize.width - requestingSize.width) / 2, resendY, requestingSize.width, requestingSize.height));

	CGSize callSentSize = [self.callSentLabel sizeThatFits:CGSizeMake(300, 1024)];
	self.callSentLabel.frame = CGRectIntegral(CGRectMake((viewSize.width - callSentSize.width) / 2, resendY, callSentSize.width, callSentSize.height));

	self.resendButton.frame = CGRectMake((int)((viewSize.width - self.resendButton.frame.size.width) / 2), resendY,
		self.resendButton.frame.size.width, self.resendButton.frame.size.height);

	BOOL countdownStep = self.currentStep == TGLoginStepCode || self.currentStep == TGLoginStepEmailCode;

	BOOL callStateVisible = self.currentStep == TGLoginStepCode && self.callRequestState > 0 && self.resendSeconds <= 0;
	self.requestingCallLabel.hidden = !(callStateVisible && self.callRequestState == 1);
	self.callSentLabel.hidden = !(callStateVisible && self.callRequestState == 2);

	self.timeoutLabel.hidden = !countdownStep || (self.resendSeconds <= 0 && self.callRequestState == 0);
	self.resendButton.hidden = !countdownStep || self.resendSeconds > 0 || self.suppressResendButton;

	BOOL hasExtra = self.currentStep == TGLoginStepCode || self.currentStep == TGLoginStepPassword || self.currentStep == TGLoginStepNewPasswordHint;
	self.extraButton.hidden = !hasExtra;
	CGFloat extraY = resendY;
	if (self.currentStep == TGLoginStepCode)
		extraY += 38;
	self.extraButton.frame = CGRectMake((int)((viewSize.width - self.extraButton.frame.size.width) / 2), extraY,
		self.extraButton.frame.size.width, self.extraButton.frame.size.height);
}

@end

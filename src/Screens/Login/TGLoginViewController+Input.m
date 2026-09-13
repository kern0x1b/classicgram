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

@implementation TGLoginViewController (Input)

#pragma mark - input

- (void)inputBackgroundTapped:(UITapGestureRecognizer *)recognizer {
	if (recognizer.state != UIGestureRecognizerStateRecognized)
		return;

	if (!self.countryCodeField.hidden) {
		CGPoint location = [recognizer locationInView:self.inputBackgroundView];
		CGFloat countryRight = self.countryCodeField.frame.origin.x + self.countryCodeField.frame.size.width - self.inputBackgroundView.frame.origin.x;
		if (location.x < countryRight) {
			[self.countryCodeField becomeFirstResponder];
			return;
		}
	}

	[self.inputField becomeFirstResponder];
}

- (void)textFieldDidHitLastBackspace {
	if (self.currentStep == TGLoginStepPhone)
		[self.countryCodeField becomeFirstResponder];
}

- (BOOL)busy {
	return _busy;
}

- (void)setBusy:(BOOL)busy {
	_busy = busy;
	self.shadeView.hidden = !busy;
	[self updateNextEnabled];
	if (busy)
		[self.spinner startAnimating];
	else
		[self.spinner stopAnimating];
}

- (NSString *)trimmedInput {
	return [self.inputField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)digitsOnly:(NSString *)string {
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

- (BOOL)hasSubmittableInput {
	NSString *text = [self trimmedInput];
	if (self.currentStep == TGLoginStepPhone)
		return [self digitsOnly:text].length >= 4 && [self digitsOnly:self.countryCodeField.text].length >= 1;
	if (self.currentStep == TGLoginStepCode)
		return self.codeIsText ? text.length >= 2 : [self digitsOnly:text].length >= self.expectedCodeLength;
	if (self.currentStep == TGLoginStepRegistration)
		return text.length > 0;
	if (self.currentStep == TGLoginStepEmail)
		return [text rangeOfString:@"@"].location != NSNotFound && text.length >= 5;
	if (self.currentStep == TGLoginStepEmailCode)
		return text.length >= 4;
	if (self.currentStep == TGLoginStepRecoveryCode)
		return text.length >= 4;
	return text.length > 0;
}

- (void)updateNextEnabled {
	BOOL enabled = !self.busy;
	self.nextButton.enabled = enabled;
	self.nextButton.titleLabel.alpha = self.busy ? 0.0f : (enabled ? 1.0f : 0.6f);
}

- (void)shakeView:(UIView *)view {
	if (view == nil || view.hidden)
		return;

	CGRect originalFrame = view.frame;
	CGRect right = originalFrame;
	right.origin.x = originalFrame.origin.x + 4;
	CGRect left = originalFrame;
	left.origin.x = originalFrame.origin.x - 4;

	[UIView animateWithDuration:0.05 delay:0.0 options:UIViewAnimationOptionAutoreverse animations:^{
		view.frame = right;
	} completion:^(BOOL finished) {
		if (!finished) {
			view.frame = originalFrame;
			return;
		}
		[UIView animateWithDuration:0.05
			delay:0.0
			options:(UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse)
			animations:^{
				[UIView setAnimationRepeatCount:3];
				view.frame = left;
			} completion:^(__unused BOOL innerFinished) {
				view.frame = originalFrame;
			}];
	}];
}

- (void)shakeInputRow {
	[self shakeView:self.inputField];
	[self shakeView:self.inputBackgroundView];
	if (!self.countryCodeField.hidden)
		[self shakeView:self.countryCodeField];
	if (self.currentStep == TGLoginStepRegistration) {
		[self shakeView:self.lastNameField];
		[self shakeView:self.lastNameBackgroundView];
	}
}

- (void)inputChanged {
	[self updateNextEnabled];

	if (self.currentStep == TGLoginStepCode && !self.codeIsText && !self.busy) {
		if ([self digitsOnly:[self trimmedInput]].length >= self.expectedCodeLength)
			[self actionButtonTapped];
	}
}

- (void)countryCodeChanged {
	NSString *digits = [self digitsOnly:self.countryCodeField.text];
	if (digits.length > 4)
		digits = [digits substringToIndex:4];
	self.countryCodeField.text = [@"+" stringByAppendingString:digits];
	self.countryCodeEdited = YES;
	self.lastQueriedPhonePrefix = nil;
	[self updateCountryNameForDialCode];
	[self reformatPhoneField];
	[self updateNextEnabled];
}

- (void)actionButtonTapped {
	if (self.busy)
		return;

	NSString *text = [self trimmedInput];
	if (![self hasSubmittableInput]) {
		[self shakeInputRow];
		if (self.currentStep == TGLoginStepPhone && [self digitsOnly:self.countryCodeField.text].length < 1)
			[self.countryCodeField becomeFirstResponder];
		else
			[self.inputField becomeFirstResponder];
		return;
	}

	[self setBusy:YES];

	if (self.currentStep == TGLoginStepPhone) {
		[self submitPhoneNumber:text];
	} else if (self.currentStep == TGLoginStepCode) {
		[self submitCode:text];
	} else if (self.currentStep == TGLoginStepRegistration) {
		[self submitRegistrationFirstName:text];
	} else if (self.currentStep == TGLoginStepPassword) {
		[self submitPassword:text];
	} else if (self.currentStep == TGLoginStepEmail) {
		[self submitEmailAddress:text];
	} else if (self.currentStep == TGLoginStepEmailCode) {
		[self submitEmailCode:text];
	} else if (self.currentStep == TGLoginStepRecoveryCode) {
		[self submitRecoveryCode:text];
	} else if (self.currentStep == TGLoginStepNewPassword) {
		[self submitNewPassword:text];
	} else if (self.currentStep == TGLoginStepNewPasswordConfirm) {
		[self submitNewPasswordConfirm:text];
	} else if (self.currentStep == TGLoginStepNewPasswordHint) {
		[self submitNewPasswordHint:text];
	}
}

- (NSInteger)slotAlreadyHoldingPhoneDigits:(NSString *)digits {
	if (!digits.length)
		return -1;
	for (NSDictionary *account in [[TGAccountManager shared] accounts]) {
		NSString *known = account[@"phone"];
		if (![known isKindOfClass:[NSString class]])
			continue;
		if ([[self digitsOnly:known] isEqualToString:digits])
			return [account[@"slot"] integerValue];
	}
	return -1;
}

@end

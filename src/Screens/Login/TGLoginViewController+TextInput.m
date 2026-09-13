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

@implementation TGLoginViewController (TextInput)

#pragma mark - textinput

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
	if (self.busy)
		return NO;

	if (textField == self.countryCodeField) {
		NSString *result = [textField.text stringByReplacingCharactersInRange:range withString:string];
		return [self digitsOnly:result].length <= 4;
	}

	if (self.currentStep == TGLoginStepRegistration) {
		NSString *result = [textField.text stringByReplacingCharactersInRange:range withString:string];
		return result.length <= 30;
	}

	if (self.currentStep == TGLoginStepCode) {
		NSString *result = [textField.text stringByReplacingCharactersInRange:range withString:string];
		if (self.codeIsText)
			return result.length <= 64;
		return [self digitsOnly:result].length <= self.expectedCodeLength && [[self digitsOnly:string] length] == string.length;
	}

	if (self.currentStep == TGLoginStepEmailCode || self.currentStep == TGLoginStepRecoveryCode) {
		NSString *result = [textField.text stringByReplacingCharactersInRange:range withString:string];
		return result.length <= 12;
	}

	if (self.currentStep == TGLoginStepPhone) {
		[self applyPhoneFormattingInField:textField range:range replacement:string];
		return NO;
	}

	return YES;
}

- (void)applyPhoneFormattingInField:(UITextField *)textField range:(NSRange)range replacement:(NSString *)string {
	NSString *result = [textField.text stringByReplacingCharactersInRange:range withString:string];
	NSString *digits = [self digitsOnly:result];
	if (digits.length > 15)
		return;

	NSString *prefix = [textField.text substringToIndex:range.location];
	NSInteger digitsBeforeCaret = [self digitsOnly:prefix].length + [self digitsOnly:string].length;

	NSString *formatted = [self formattedPhoneForDigits:digits];
	textField.text = formatted;

	NSInteger caret = formatted.length;
	NSInteger seen = 0;
	for (NSInteger i = 0; i < formatted.length; i++) {
		if (seen == digitsBeforeCaret) {
			caret = i;
			break;
		}
		unichar c = [formatted characterAtIndex:i];
		if (c >= '0' && c <= '9')
			seen++;
	}
	if (seen == digitsBeforeCaret && caret == formatted.length)
		caret = formatted.length;

	UITextPosition *position = [textField positionFromPosition:textField.beginningOfDocument offset:(NSInteger)caret];
	if (position != nil)
		textField.selectedTextRange = [textField textRangeFromPosition:position toPosition:position];

	[self updateTitleText];
	[self inputChanged];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	if (textField == self.countryCodeField) {
		[self.inputField becomeFirstResponder];
		return NO;
	}
	if (self.currentStep == TGLoginStepRegistration && textField == self.inputField) {
		[self.lastNameField becomeFirstResponder];
		return NO;
	}
	[self actionButtonTapped];
	return YES;
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (!self.busy && ![self.inputField isFirstResponder] && ![self.countryCodeField isFirstResponder])
		[self.inputField becomeFirstResponder];
}

- (void)tearDownTextInput {
	if (self.keyboardFrameObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.keyboardFrameObserverToken];
	[_resendCountdown stop];
	_resendCountdown = nil;
	_currentActionSheet.delegate = nil;
	_lastNameField.delegate = nil;
	_inputField.delegate = nil;
	_countryCodeField.delegate = nil;
}

@end

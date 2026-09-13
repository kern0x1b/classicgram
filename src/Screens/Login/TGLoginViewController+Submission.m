#import "TGLoginViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGCountryPickerViewController.h"
#import "TGPhoneFormat.h"
#import "TGLoginService.h"
#import "TGActionSheet.h"
#import "TGQRImage.h"
#import "TGAccountManager.h"
#import "TGBackspaceTextField.h"
#import "TGLoginToolbarButton.h"
#import <QuartzCore/QuartzCore.h>
#import "TGLoginViewControllerInternal.h"

@implementation TGLoginViewController (Submission)

#pragma mark - submission

- (void)submitPhoneNumber:(NSString *)text {
	NSString *code = [self digitsOnly:self.countryCodeField.text];
	NSString *fullPhone = [NSString stringWithFormat:@"+%@%@", code, [self digitsOnly:text]];

	NSInteger existing = [self slotAlreadyHoldingPhoneDigits:[self digitsOnly:fullPhone]];
	if (existing >= 0) {
		[self setBusy:NO];
		self.slotToSwitchTo = existing;
		UIAlertView *alert = [[UIAlertView alloc]
				initWithTitle:nil
					  message:TGL(@"Login.PhoneNumberAlreadyAuthorized", @"This number is already on this device.")
					 delegate:self
			cancelButtonTitle:TGL(@"Common.OK", @"OK")
			otherButtonTitles:TGL(@"Login.PhoneNumberAlreadyAuthorizedSwitch", @"Switch"), nil];
		alert.tag = kLoginExistingAccountAlertTag;
		[alert show];
		return;
	}

	self.savedPhoneNumber = fullPhone;
	__weak TGLoginViewController *weakSelf = self;
	[TGLoginService startLoginWithPhoneNumber:fullPhone
							  isCurrentNumber:NO
								   completion:^(BOOL ok, NSInteger retryAfterSeconds) {
									   TGLoginViewController *strongSelf = weakSelf;
									   if (strongSelf == nil || ok)
										   return;
									   if (strongSelf.currentStep != TGLoginStepPhone)
										   return;
									   [strongSelf setBusy:NO];
									   [strongSelf shakeInputRow];
									   [strongSelf showLoginAlert:[strongSelf loginErrorMessage:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")
										   forRetryAfterSeconds:retryAfterSeconds]];
									   [strongSelf.inputField becomeFirstResponder];
								   }];
}

- (void)submitCode:(NSString *)text {
	NSString *code = self.codeIsText ? text : [self digitsOnly:text];
	__weak TGLoginViewController *weakSelf = self;
	[TGLoginService sendCode:code completion:^(BOOL ok, NSInteger retryAfterSeconds) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		[strongSelf setBusy:NO];
		if (!ok) {
			strongSelf.inputField.text = @"";
			[strongSelf updateNextEnabled];
			[strongSelf showLoginAlert:[strongSelf loginErrorMessage:TGL(@"Login.WrongCodeError", @"Wrong code, please try again.")
											 forRetryAfterSeconds:retryAfterSeconds]];
		}
	}];
}

- (void)submitRegistrationFirstName:(NSString *)text {
	NSString *lastName = [self.lastNameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	__weak TGLoginViewController *weakSelf = self;
	[TGLoginService registerWithFirstName:text lastName:lastName.length > 0 ? lastName : nil completion:^(BOOL ok) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		[strongSelf setBusy:NO];
		if (!ok)
			[strongSelf showLoginAlert:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")];
	}];
}

- (void)submitPassword:(NSString *)text {
	__weak TGLoginViewController *weakSelf = self;
	[TGLoginService sendPassword:text completion:^(BOOL ok, NSInteger retryAfterSeconds) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		[strongSelf setBusy:NO];
		if (!ok) {
			strongSelf.inputField.text = @"";
			[strongSelf updateNextEnabled];
			[strongSelf showLoginAlert:[strongSelf loginErrorMessage:TGL(@"TwoStepAuth.ThatPasswordIsWrong", @"That password is wrong.")
											 forRetryAfterSeconds:retryAfterSeconds]];
		}
	}];
}

- (void)submitEmailAddress:(NSString *)text {
	__weak TGLoginViewController *weakSelf = self;
	[TGLoginService setAuthenticationEmailAddress:text completion:^(NSString *pattern, NSInteger codeLength) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		[strongSelf setBusy:NO];
		if (pattern.length == 0) {
			[strongSelf showLoginAlert:TGL(@"Login.EmailAddressNotAcceptedMessage", @"This email address was not accepted.")];
			return;
		}
		[strongSelf showEmailCodeStepWithPattern:pattern];
	}];
}

- (void)submitEmailCode:(NSString *)text {
	__weak TGLoginViewController *weakSelf = self;
	[TGLoginService checkAuthenticationEmailCode:text completion:^(BOOL ok) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		[strongSelf setBusy:NO];
		if (!ok) {
			strongSelf.inputField.text = @"";
			[strongSelf updateNextEnabled];
			[strongSelf showLoginAlert:TGL(@"Login.InvalidCodeError", @"Invalid code, please try again.")];
		}
	}];
}

- (void)submitRecoveryCode:(NSString *)text {
	__weak TGLoginViewController *weakSelf = self;
	[TGLoginService checkAuthenticationPasswordRecoveryCode:text completion:^(BOOL ok) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		[strongSelf setBusy:NO];
		if (!ok) {
			strongSelf.inputField.text = @"";
			[strongSelf updateNextEnabled];
			[strongSelf showLoginAlert:TGL(@"Login.InvalidCodeError", @"Invalid code, please try again.")];
			return;
		}
		strongSelf.verifiedRecoveryCode = text;
		[strongSelf showNewPasswordStep];
	}];
}

- (void)submitNewPassword:(NSString *)text {
	self.pendingNewPassword = text;
	[self showNewPasswordConfirmStep];
}

- (void)submitNewPasswordConfirm:(NSString *)text {
	if (![text isEqualToString:self.pendingNewPassword]) {
		[self setBusy:NO];
		self.inputField.text = @"";
		[self updateNextEnabled];
		[self shakeInputRow];
		[self showLoginAlert:TGL(@"TwoStepAuth.SetupPasswordConfirmFailed", @"Passwords don't match. Please try again.")];
		return;
	}
	[self showNewPasswordHintStep];
}

- (void)submitNewPasswordHint:(NSString *)text {
	if (text.length > 0 && [text isEqualToString:self.pendingNewPassword]) {
		[self setBusy:NO];
		self.inputField.text = @"";
		[self updateNextEnabled];
		[self shakeInputRow];
		[self showLoginAlert:TGL(@"TwoStepAuth.TheHintCannotBeThePasswordItself", @"The hint cannot be the password itself.")];
		return;
	}
	[self finishNewPasswordRecoveryWithHint:text.length > 0 ? text : nil];
}

- (void)finishNewPasswordRecoveryWithHint:(NSString *)hint {
	__weak TGLoginViewController *weakSelf = self;
	NSString *password = self.pendingNewPassword;
	[TGLoginService recoverAuthenticationPasswordWithCode:self.verifiedRecoveryCode newPassword:password newHint:hint completion:^(BOOL ok) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		[strongSelf setBusy:NO];
		if (!ok) {
			[strongSelf showLoginAlert:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")];
			return;
		}
		strongSelf.pendingNewPassword = nil;
		strongSelf.verifiedRecoveryCode = nil;
	}];
}

- (NSString *)loginErrorMessage:(NSString *)genericMessage forRetryAfterSeconds:(NSInteger)retryAfterSeconds {
	if (retryAfterSeconds < 0)
		return genericMessage;
	return TGLPlural(@"Login.FloodWait", retryAfterSeconds,
		@"Please wait 1 second before trying again.",
		@"Please wait %@ seconds before trying again.");
}

- (void)showLoginAlert:(NSString *)message {
	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:@""
						 message:message
						delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

@end

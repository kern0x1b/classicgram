#import "TGLoginViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGCountryPickerViewController.h"
#import "TGPhoneFormat.h"
#import "TGLoginService.h"
#import "TGActionSheet.h"
#import "TGAccountManager.h"
#import "TGBackspaceTextField.h"
#import "TGLoginToolbarButton.h"
#import <QuartzCore/QuartzCore.h>
#import "TGLoginViewControllerInternal.h"

@implementation TGLoginViewController (Steps)

#pragma mark - steps

- (void)enterStep:(TGLoginStep)step title:(NSString *)title notice:(NSString *)notice {
	self.currentStep = step;
	self.title = title;
	self.noticeLabel.text = notice;
}

- (void)finishStepTransition {
	[self layoutInterface];
	[self updateNextEnabled];
}

- (void)finishStepTransitionFocusingInput {
	[self finishStepTransition];
	[self.inputField becomeFirstResponder];
}

- (void)showCodeStepWithPhoneNumber:(NSString *)phoneNumber {
	(void)self.view;
	[self setBusy:NO];
	self.suppressResendButton = NO;
	self.codeIsText = NO;
	self.codeIsPhrase = NO;
	self.expectedCodeLength = 5;
	[self enterStep:TGLoginStepCode
			  title:phoneNumber.length > 0 ? phoneNumber : (self.savedPhoneNumber.length > 0 ? self.savedPhoneNumber : TGL(@"Login.EnterCodeSMSTitle", @"Confirmation Code"))
			 notice:[NSString stringWithFormat:TGL(@"Login.EnterCodeSMSText", @"We've sent an SMS with an activation code to your phone %@."),
				phoneNumber.length > 0 ? phoneNumber : self.savedPhoneNumber]];

	self.inputField.text = @"";
	self.inputField.secureTextEntry = NO;
	self.inputField.placeholder = TGL(@"Login.Code", @"Code");
	self.inputField.keyboardType = UIKeyboardTypeNumberPad;
	self.inputField.autocapitalizationType = UITextAutocapitalizationTypeNone;

	[self setLoginButton:self.resendButton title:TGL(@"Login.SendCodeViaSms", @"Send the code as an SMS")];
	[self setLoginButton:self.extraButton title:TGL(@"Login.HaveNotReceivedCodeInternal", @"Didn't get the code?")];
	self.nextCodeTypeTitle = nil;
	self.nextCodeType = nil;

	[self installBackButton];
	[self startResendCountdown];
	[self finishStepTransitionFocusingInput];

	__weak TGLoginViewController *weakSelf = self;
	[TGLoginService authenticationCodeInfoWithCompletion:^(NSDictionary *info) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf.currentStep != TGLoginStepCode || info == nil)
			return;
		[strongSelf applyCodeInfo:info];
	}];
}

- (void)applyTextCodeType:(BOOL)isPhrase {
	self.codeIsText = YES;
	self.codeIsPhrase = isPhrase;

	self.inputField.keyboardType = UIKeyboardTypeDefault;
	self.inputField.autocorrectionType = UITextAutocorrectionTypeNo;
	self.inputField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	self.inputField.placeholder = isPhrase ? TGL(@"Login.EnterPhrasePlaceholder", @"Phrase") : TGL(@"Login.EnterWordPlaceholder", @"Word");
	if ([self.inputField isFirstResponder])
		[self.inputField reloadInputViews];

	NSString *format = isPhrase
		? TGL(@"Login.EnterPhraseText", @"We've sent you an SMS with a secret phrase to your phone %@.")
		: TGL(@"Login.EnterWordText", @"We've sent you an SMS with a secret word to your phone %@.");
	self.noticeLabel.text = [NSString stringWithFormat:format, self.savedPhoneNumber ?: @""];
}

- (void)applyCodeInfo:(NSDictionary *)info {
	NSString *type = [info objectForKey:@"type"];
	BOOL isWordCode = [type isKindOfClass:[NSString class]] && [type isEqualToString:@"authenticationCodeTypeSmsWord"];
	BOOL isPhraseCode = [type isKindOfClass:[NSString class]] && [type isEqualToString:@"authenticationCodeTypeSmsPhrase"];

	if (isWordCode || isPhraseCode) {
		[self applyTextCodeType:isPhraseCode];
	} else if (self.codeIsText) {
		self.codeIsText = NO;
		self.codeIsPhrase = NO;
		self.inputField.placeholder = TGL(@"Login.Code", @"Code");
		self.inputField.keyboardType = UIKeyboardTypeNumberPad;
		if ([self.inputField isFirstResponder])
			[self.inputField reloadInputViews];
	}

	NSNumber *length = [info objectForKey:@"length"];
	NSInteger reportedLength = [length isKindOfClass:[NSNumber class]] ? [length integerValue] : 0;
	self.expectedCodeLength = reportedLength > 0 ? reportedLength : 5;

	NSString *description = [info objectForKey:@"description"];
	if (!self.codeIsText && [description isKindOfClass:[NSString class]] && description.length > 0)
		self.noticeLabel.text = description;

	NSString *nextType = [info objectForKey:@"nextType"];
	self.nextCodeType = [nextType isKindOfClass:[NSString class]] ? nextType : nil;

	NSString *nextDescription = [info objectForKey:@"nextDescription"];
	if ([nextDescription isKindOfClass:[NSString class]] && nextDescription.length > 0) {
		self.nextCodeTypeTitle = nextDescription;
		[self setLoginButton:self.resendButton title:nextDescription];
	}

	NSNumber *timeout = [info objectForKey:@"timeout"];
	if ([timeout isKindOfClass:[NSNumber class]] && [timeout intValue] > 0) {
		[self stopResendCountdown];
		self.resendSeconds = [timeout integerValue];
		self.callRequestState = 0;
		self.timeoutLabel.alpha = 1.0f;
		[self startResendTimer];
	}

	[self updateResendTitle];
	[self layoutInterface];
}

- (void)showRegistrationStep {
	(void)self.view;
	[self setBusy:NO];
	[self stopResendCountdown];
	[self enterStep:TGLoginStepRegistration
			  title:TGL(@"Login.InfoTitle", @"Your Info")
			 notice:TGL(@"Login.InfoHelp", @"Enter your name and add a profile photo.")];

	self.inputField.text = @"";
	self.inputField.secureTextEntry = NO;
	self.inputField.font = [UIFont boldSystemFontOfSize:15.0f];
	self.inputField.placeholder = TGL(@"Login.InfoFirstNamePlaceholder", @"First name");
	self.inputField.keyboardType = UIKeyboardTypeDefault;
	self.inputField.autocapitalizationType = UITextAutocapitalizationTypeWords;
	self.inputField.returnKeyType = UIReturnKeyNext;
	self.lastNameField.text = @"";

	[self installBackButton];
	[self finishStepTransitionFocusingInput];

	__weak TGLoginViewController *weakSelf = self;
	[TGLoginService registrationTermsWithCompletion:^(NSDictionary *terms) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf.currentStep != TGLoginStepRegistration || terms == nil)
			return;
		[strongSelf applyRegistrationTerms:terms];
	}];
}

- (void)applyRegistrationTerms:(NSDictionary *)terms {
	NSString *text = [terms objectForKey:@"text"];
	if (![text isKindOfClass:[NSString class]])
		text = @"";
	self.termsText = text;

	NSNumber *minAge = [terms objectForKey:@"minUserAge"];
	self.termsMinUserAge = [minAge isKindOfClass:[NSNumber class]] ? [minAge integerValue] : 0;

	NSNumber *showPopup = [terms objectForKey:@"showPopup"];
	if (![showPopup isKindOfClass:[NSNumber class]] || ![showPopup boolValue])
		return;

	NSMutableString *message = [NSMutableString string];
	if (text.length > 0)
		[message appendString:text];
	if (self.termsMinUserAge > 0) {
		if (message.length > 0)
			[message appendString:@"\n\n"];
		[message appendFormat:TGL(@"Login.TermsOfServiceMinAgeFormat", @"You must be at least %d years old to use Telegram."), (int)self.termsMinUserAge];
	}
	if (message.length == 0)
		return;

	[self.inputField resignFirstResponder];
	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:TGL(@"Login.TermsOfServiceHeader", @"Terms of Service")
						 message:message
						delegate:self
			   cancelButtonTitle:TGL(@"Call.Decline", @"Decline")
			   otherButtonTitles:TGL(@"Call.Accept", @"Accept"), nil];
	alert.tag = kLoginAlertTerms;
	[alert show];
}

- (void)lastNameBackgroundTapped {
	[self.lastNameField becomeFirstResponder];
}

- (void)showPasswordStepWithHint:(NSString *)hint recoveryEmailPattern:(NSString *)recoveryEmailPattern {
	(void)self.view;
	[self setBusy:NO];
	self.passwordHint = hint;
	self.recoveryEmailPattern = recoveryEmailPattern;
	NSString *notice = TGL(@"LoginPassword.PasswordHelp", @"Two-Step verification enabled. Your account is protected with an additional password.");
	if (hint.length > 0)
		notice = [notice stringByAppendingFormat:@"\n\n%@ %@", TGL(@"LoginPassword.PasswordHint", @"Hint"), hint];
	[self enterStep:TGLoginStepPassword
			  title:TGL(@"TwoStepAuth.EnterPasswordTitle", @"Password")
			 notice:notice];
	[self setLoginButton:self.extraButton title:TGL(@"LoginPassword.ForgotPassword", @"Forgot password?")];

	self.inputField.text = @"";
	self.inputField.placeholder = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	self.inputField.secureTextEntry = YES;
	self.inputField.keyboardType = UIKeyboardTypeDefault;
	self.inputField.returnKeyType = UIReturnKeyDone;
	self.inputField.autocapitalizationType = UITextAutocapitalizationTypeNone;

	[self stopResendCountdown];
	[self installBackButton];
	[self finishStepTransitionFocusingInput];
}

- (void)showPhoneStep {
	(void)self.view;
	[self setBusy:NO];
	[self enterStep:TGLoginStepPhone
			  title:TGL(@"Login.PhoneTitle", @"Your Phone")
			 notice:TGL(@"Login.PhoneAndCountryHelp", @"Please confirm your country code and enter your phone number.")];

	self.inputField.text = @"";
	self.inputField.secureTextEntry = NO;
	self.inputField.font = [UIFont boldSystemFontOfSize:18];
	self.inputField.placeholder = TGL(@"Login.PhonePlaceholder", @"Your phone number");
	self.inputField.keyboardType = UIKeyboardTypeNumberPad;
	self.inputField.returnKeyType = UIReturnKeyDone;
	self.inputField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	self.codeIsText = NO;
	self.codeIsPhrase = NO;
	self.lastQueriedPhonePrefix = nil;

	[self stopResendCountdown];
	[self installCancelButtonIfNeeded];
	[self finishStepTransitionFocusingInput];
	[self prefillGuessedCountry];
}

- (BOOL)handleExistingAccountAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	if (alertView.tag != kLoginExistingAccountAlertTag)
		return NO;
	NSInteger slot = self.slotToSwitchTo;
	self.slotToSwitchTo = -1;
	if (buttonIndex != alertView.cancelButtonIndex && slot >= 0)
		dispatch_async(dispatch_get_main_queue(), ^{
			[[TGAccountManager shared] switchToSlotAbandoningAdd:slot];
		});
	return YES;
}

- (void)showEmailStep {
	(void)self.view;
	[self setBusy:NO];
	[self stopResendCountdown];
	[self enterStep:TGLoginStepEmail
			  title:TGL(@"CheckoutInfo.ReceiverInfoEmail", @"Email")
			 notice:TGL(@"Login.AddEmailText", @"Please enter your valid email address to protect your account.")];

	self.inputField.text = @"";
	self.inputField.secureTextEntry = NO;
	self.inputField.placeholder = TGL(@"CheckoutInfo.ReceiverInfoEmail", @"Email");
	self.inputField.keyboardType = UIKeyboardTypeEmailAddress;

	[self installBackButton];
	[self finishStepTransitionFocusingInput];
}

- (void)showEmailCodeStepWithPattern:(NSString *)pattern {
	(void)self.view;
	[self setBusy:NO];
	self.suppressResendButton = NO;
	self.emailPattern = pattern;
	[self enterStep:TGLoginStepEmailCode
			  title:TGL(@"Login.EnterCodeEmailTitle", @"Check Your Email")
			 notice:[NSString stringWithFormat:
						TGL(@"Login.EnterCodeEmailText",
							@"Please enter the code we have sent to your email %@."),
					pattern]];

	self.inputField.text = @"";
	self.inputField.secureTextEntry = NO;
	self.inputField.placeholder = TGL(@"Login.Code", @"Code");
	self.inputField.keyboardType = UIKeyboardTypeNumberPad;

	[self setLoginButton:self.resendButton title:TGL(@"Login.Email.ResetTitle", @"Reset email address")];
	[self installBackButton];
	[self finishStepTransitionFocusingInput];

	__weak TGLoginViewController *weakSelf = self;
	[TGLoginService authenticationEmailStateWithCompletion:^(NSDictionary *info) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf.currentStep != TGLoginStepEmailCode || info == nil)
			return;
		[strongSelf applyEmailState:info];
	}];
}

- (void)applyEmailState:(NSDictionary *)info {
	NSString *resetState = [info objectForKey:@"resetState"];
	if (![resetState isKindOfClass:[NSString class]])
		resetState = @"";

	if ([resetState isEqualToString:@"pending"]) {
		NSNumber *resetIn = [info objectForKey:@"resetIn"];
		[self stopResendCountdown];
		self.resendSeconds = [resetIn isKindOfClass:[NSNumber class]] ? [resetIn integerValue] : 0;
		if (self.resendSeconds > 0)
			[self startResendTimer];
	} else if ([resetState isEqualToString:@"available"]) {
		[self stopResendCountdown];
	} else {
		[self stopResendCountdown];
		self.suppressResendButton = YES;
	}

	[self updateResendTitle];
	[self layoutInterface];
}

- (void)showRecoveryCodeStep {
	(void)self.view;
	[self setBusy:NO];
	[self stopResendCountdown];
	NSString *notice = self.recoveryEmailPattern.length > 0
		? [NSString stringWithFormat:
			TGL(@"Login.RecoveryCodeNoticeWithEmail",
				@"We have sent a recovery code to %@."),
			self.recoveryEmailPattern]
		: TGL(@"Login.RecoveryCodeNotice", @"We have sent a recovery code to the email address you provided when setting up your password.");
	[self enterStep:TGLoginStepRecoveryCode
			  title:TGL(@"TwoStepAuth.RecoveryTitle", @"E-Mail Code")
			 notice:notice];

	self.inputField.text = @"";
	self.inputField.secureTextEntry = NO;
	self.inputField.placeholder = TGL(@"Login.Code", @"Code");
	self.inputField.keyboardType = UIKeyboardTypeNumberPad;

	[self installBackButton];
	[self finishStepTransitionFocusingInput];
}

- (void)showNewPasswordStep {
	(void)self.view;
	[self setBusy:NO];
	[self stopResendCountdown];
	[self enterStep:TGLoginStepNewPassword
			  title:TGL(@"TwoFactorSetup.PasswordRecovery.Title", @"New Password")
			 notice:TGL(@"TwoFactorSetup.PasswordRecovery.Text", @"You can now set a new password that will be used to log into your account.")];

	self.inputField.text = @"";
	self.inputField.secureTextEntry = YES;
	self.inputField.placeholder = TGL(@"TwoFactorSetup.PasswordRecovery.PlaceholderPassword", @"New password");
	self.inputField.keyboardType = UIKeyboardTypeDefault;

	[self installBackButton];
	[self finishStepTransitionFocusingInput];
}

- (void)showNewPasswordConfirmStep {
	(void)self.view;
	[self setBusy:NO];
	[self stopResendCountdown];
	[self enterStep:TGLoginStepNewPasswordConfirm
			  title:TGL(@"TwoFactorSetup.Password.PlaceholderConfirmPassword", @"Re-enter Password")
			 notice:TGL(@"TwoStepAuth.SetupPasswordConfirmPassword", @"Please re-enter your password:")];

	self.inputField.text = @"";
	self.inputField.secureTextEntry = YES;
	self.inputField.placeholder = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	self.inputField.keyboardType = UIKeyboardTypeDefault;

	[self installBackButton];
	[self finishStepTransitionFocusingInput];
}

- (void)showNewPasswordHintStep {
	(void)self.view;
	[self setBusy:NO];
	[self stopResendCountdown];
	[self enterStep:TGLoginStepNewPasswordHint
			  title:TGL(@"TwoStepAuth.HintPlaceholder", @"Hint")
			 notice:TGL(@"TwoStepAuth.AddHintDescription", @"A short reminder shown when the password is asked for. Anyone who sees your log-in screen sees the hint, so keep it vague.")];

	self.inputField.text = @"";
	self.inputField.secureTextEntry = NO;
	self.inputField.placeholder = TGL(@"TwoStepAuth.HintPlaceholder", @"Hint");
	self.inputField.keyboardType = UIKeyboardTypeDefault;

	[self setLoginButton:self.extraButton title:TGL(@"TwoStepAuth.SkipThisStep", @"Skip This Step")];
	[self installBackButton];
	[self finishStepTransitionFocusingInput];
}

- (void)extraTapped {
	if (self.busy)
		return;

	__weak TGLoginViewController *weakSelf = self;

	if (self.currentStep == TGLoginStepCode) {
		[TGLoginService reportAuthenticationCodeMissing:nil completion:^(BOOL ok) {
			TGLoginViewController *strongSelf = weakSelf;
			if (strongSelf == nil)
				return;
			[strongSelf showLoginAlert:ok ? TGL(@"Login.CodeMissingReportedMessage", @"Telegram has been told the code did not arrive. Please wait a little longer.")
								  : TGL(@"Login.CodeMissingReportFailedMessage", @"Could not report the missing code.")];
		}];
		return;
	}

	if (self.currentStep == TGLoginStepPassword) {
		[self setBusy:YES];
		[TGLoginService requestAuthenticationPasswordRecoveryWithCompletion:^(BOOL ok) {
			TGLoginViewController *strongSelf = weakSelf;
			if (strongSelf == nil)
				return;
			[strongSelf setBusy:NO];
			if (!ok) {
				[strongSelf showPasswordResetOptions];
				return;
			}
			[strongSelf showRecoveryCodeStep];
		}];
		return;
	}

	if (self.currentStep == TGLoginStepNewPasswordHint) {
		[self setBusy:YES];
		[self finishNewPasswordRecoveryWithHint:nil];
	}
}

- (void)showPasswordResetOptions {
	[self.inputField resignFirstResponder];

	NSArray *actions = @[ [[TGActionSheetAction alloc] initWithTitle:TGL(@"DeleteAccount.ConfirmationAlertDelete", @"Delete Account") action:@"delete" type:TGActionSheetActionTypeDestructive],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel] ];

	__weak TGLoginViewController *weakSelf = self;
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:TGL(@"LoginPassword.NoRecoveryEmailOptions", @"Since you didn't provide a recovery email when setting up your password, your remaining options are to remember your password or delete your account.")
						 actions:actions
					 actionBlock:^(__unused id target, NSString *action) {
						 TGLoginViewController *strongSelf = weakSelf;
						 if (strongSelf == nil)
							 return;
						 if ([action isEqualToString:@"delete"])
							 [strongSelf confirmAccountDeletion];
						 else
							 [strongSelf.inputField becomeFirstResponder];
					 }
						  target:self];
	self.currentActionSheet = sheet;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)confirmAccountDeletion {
	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:TGL(@"DeleteAccount.ConfirmationAlertDelete", @"Delete Account")
						 message:TGL(@"DeleteAccount.ConfirmationAlertText", @"All your chats, messages and contacts on Telegram will be lost. This cannot be undone.")
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"Common.Delete", @"Delete"), nil];
	alert.tag = kLoginAlertDeleteAccount;
	[alert show];
}

- (void)deleteAccountNow {
	[self setBusy:YES];
	__weak TGLoginViewController *weakSelf = self;
	[TGLoginService deleteAccountWithReason:@"Forgot password" password:nil completion:^(BOOL ok) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		[strongSelf setBusy:NO];
		if (ok)
			[strongSelf showPhoneStep];
		else
			[strongSelf showLoginAlert:TGL(@"DeleteAccount.CouldNotBeDeletedMessage", @"The account could not be deleted. Please try again later.")];
	}];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if ([self handleExistingAccountAlert:alertView buttonIndex:buttonIndex])
		return;

	if (alertView.tag == kLoginAlertTerms) {
		if (buttonIndex == alertView.cancelButtonIndex) {
			[self logOutAndReturnToPhoneStep];
			return;
		}
		if (self.currentStep == TGLoginStepRegistration)
			[self.inputField becomeFirstResponder];
		return;
	}

	if (alertView.tag == kLoginAlertDeleteAccount) {
		if (buttonIndex != alertView.cancelButtonIndex)
			[self deleteAccountNow];
		else
			[self.inputField becomeFirstResponder];
	}
}

@end

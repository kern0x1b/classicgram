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

@implementation TGLoginViewController (Navigation)

#pragma mark - navigation

- (void)installBackButton {
	if (self.backButton != nil) {
		[self.backButton setTitleShadowColor:self.currentStep == TGLoginStepRegistration ? tgRGBA(0x07080a, 0.35f) : tgRGBA(0x050608, 0.4f)
									forState:UIControlStateNormal];
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.backButton];
		return;
	}

	UIButton *backButton =
		[self loginToolbarButtonWithTitle:TGL(@"Common.Back", @"Back")
									plate:@"BackButton_Login.png"
								  pressed:@"BackButton_Login_Pressed.png"
							  leftCapHalf:NO
								  leftCap:15
							 shadowColour:tgRGBA(0x050608, 0.4f)
							  paddingLeft:15
							 paddingRight:9
								 minWidth:0
								   isBack:YES];
	[backButton addTarget:self action:@selector(backTapped) forControlEvents:UIControlEventTouchUpInside];
	if (self.currentStep == TGLoginStepRegistration)
		[backButton setTitleShadowColor:tgRGBA(0x07080a, 0.35f) forState:UIControlStateNormal];
	self.backButton = backButton;

	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
}

- (void)backTapped {
	if (self.busy)
		return;

	if (self.currentStep == TGLoginStepEmailCode) {
		[self showEmailStep];
		return;
	}

	if (self.currentStep == TGLoginStepNewPasswordHint) {
		[self showNewPasswordConfirmStep];
		return;
	}

	if (self.currentStep == TGLoginStepNewPasswordConfirm) {
		[self showNewPasswordStep];
		return;
	}

	if (self.currentStep == TGLoginStepNewPassword) {
		[self showRecoveryCodeStep];
		return;
	}

	if (self.currentStep == TGLoginStepRecoveryCode) {
		[self showPasswordStepWithHint:self.passwordHint recoveryEmailPattern:self.recoveryEmailPattern];
		return;
	}

	if (self.currentStep == TGLoginStepEmail) {
		[self showPhoneStep];
		return;
	}

	[self logOutAndReturnToPhoneStep];
}

- (void)logOutAndReturnToPhoneStep {
	__weak TGLoginViewController *weakSelf = self;
	[TGLoginService logOutWithCompletion:^(BOOL ok) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil || ok)
			return;
		[strongSelf showLoginAlert:TGL(@"Login.StartOverFailedMessage", @"Could not start over. Please try again.")];
	}];
	[self showPhoneStep];
}

- (void)startResendCountdown {
	[self startResendCountdownWithSeconds:60];
}

- (void)startResendCountdownWithSeconds:(NSInteger)seconds {
	[self stopResendCountdown];
	self.resendSeconds = seconds;
	self.callRequestState = 0;
	self.timeoutLabel.alpha = 1.0f;
	self.requestingCallLabel.alpha = 0.0f;
	self.callSentLabel.alpha = 0.0f;
	[self updateResendTitle];
	[self startResendTimer];
}

- (BOOL)nextCodeTypeIsCall {
	NSString *type = self.nextCodeType;
	if (![type isKindOfClass:[NSString class]])
		return NO;
	return [type isEqualToString:@"authenticationCodeTypeCall"]
		|| [type isEqualToString:@"authenticationCodeTypeFlashCall"]
		|| [type isEqualToString:@"authenticationCodeTypeMissedCall"];
}

- (void)beginSilentResend {
	__weak TGLoginViewController *weakSelf = self;
	[TGLoginService resendAuthenticationCodeWithFailureMessage:nil completion:^(NSDictionary *info, NSInteger retryAfterSeconds) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf.currentStep != TGLoginStepCode)
			return;
		if (info == nil) {
			[strongSelf showLoginAlert:[strongSelf loginErrorMessage:TGL(@"Login.ResendCodeFailedMessage", @"Telegram could not resend the code. Please try again.")
													  forRetryAfterSeconds:retryAfterSeconds]];
			if (retryAfterSeconds >= 0)
				[strongSelf startResendCountdownWithSeconds:retryAfterSeconds];
			return;
		}
		[strongSelf applyCodeInfo:info];
	}];
}

- (void)beginCallRequest {
	self.callRequestState = 1;
	self.requestingCallLabel.hidden = NO;
	self.requestingCallLabel.alpha = 0.0f;

	[UIView animateWithDuration:0.2 animations:^{
		self.timeoutLabel.alpha = 0.0f;
	}];
	[UIView animateWithDuration:0.2 delay:0.1 options:0 animations:^{
		self.requestingCallLabel.alpha = 1.0f;
	} completion:nil];

	__weak TGLoginViewController *weakSelf = self;
	[TGLoginService resendAuthenticationCodeWithFailureMessage:nil completion:^(NSDictionary *info, NSInteger retryAfterSeconds) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf.currentStep != TGLoginStepCode)
			return;
		if (info == nil) {
			[strongSelf failCallRequestWithRetryAfterSeconds:retryAfterSeconds];
			return;
		}
		[strongSelf applyCodeInfo:info];
		[strongSelf finishCallRequest];
	}];
}

- (void)failCallRequestWithRetryAfterSeconds:(NSInteger)retryAfterSeconds {
	if (self.currentStep != TGLoginStepCode || self.callRequestState != 1)
		return;

	self.callRequestState = 0;
	[UIView animateWithDuration:0.2 animations:^{
		self.requestingCallLabel.alpha = 0.0f;
	} completion:^(BOOL finished) {
		self.requestingCallLabel.hidden = YES;
	}];

	[self updateResendTitle];
	[self showLoginAlert:[self loginErrorMessage:TGL(@"Login.CallFailedMessage", @"Telegram could not call you. Please try again.")
							 forRetryAfterSeconds:retryAfterSeconds]];
}

- (void)finishCallRequest {
	if (self.currentStep != TGLoginStepCode || self.callRequestState != 1)
		return;

	self.callRequestState = 2;
	self.callSentLabel.hidden = NO;
	self.callSentLabel.alpha = 0.0f;

	[UIView animateWithDuration:0.2 animations:^{
		self.requestingCallLabel.alpha = 0.0f;
	}];
	[UIView animateWithDuration:0.2 delay:0.1 options:0 animations:^{
		self.callSentLabel.alpha = 1.0f;
	} completion:nil];

	[self layoutInterface];
}

- (void)startResendTimer {
	__weak TGLoginViewController *weakSelf = self;
	TGResendCountdown *countdown = [[TGResendCountdown alloc] init];
	countdown.onTick = ^(NSInteger secondsRemaining) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		strongSelf.resendSeconds = secondsRemaining;
		[strongSelf updateResendTitle];
	};
	countdown.onFinished = ^{
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		if (strongSelf.currentStep == TGLoginStepCode && strongSelf.callRequestState == 0 && !strongSelf.suppressResendButton) {
			if ([strongSelf nextCodeTypeIsCall])
				[strongSelf beginCallRequest];
			else
				[strongSelf beginSilentResend];
		}
	};
	self.resendCountdown = countdown;
	[countdown startWithSeconds:self.resendSeconds];
}

- (void)stopResendCountdown {
	[self.resendCountdown stop];
	self.resendCountdown = nil;
	self.resendSeconds = 0;
}

- (void)updateResendTitle {
	if (self.resendSeconds > 0) {
		NSString *format;
		if (self.currentStep == TGLoginStepEmailCode)
			format = TGL(@"Login.ResendEmailCountdownFormat", @"You will be able to reset your email address in %d:%02d");
		else if ([self nextCodeTypeIsCall])
			format = TGL(@"Login.ResendCallCountdownFormat", @"Telegram will call you in %d:%.2d");
		else
			format = TGL(@"Login.ResendCodeCountdownFormat", @"Telegram will send you a new code in %d:%02d");
		self.timeoutLabel.text = [NSString stringWithFormat:format,
			(int)self.resendSeconds / 60, (int)self.resendSeconds % 60];
		self.resendButton.enabled = NO;
	} else {
		self.resendButton.enabled = YES;
	}
	[self layoutInterface];
}

- (void)resendTapped {
	if (self.busy)
		return;

	__weak TGLoginViewController *weakSelf = self;

	if (self.resendSeconds > 0)
		return;

	if (self.currentStep == TGLoginStepEmailCode) {
		[self setBusy:YES];
		[TGLoginService resetAuthenticationEmailAddressWithCompletion:^(BOOL ok) {
			TGLoginViewController *strongSelf = weakSelf;
			if (strongSelf == nil)
				return;
			[strongSelf setBusy:NO];
			if (ok)
				[strongSelf showEmailStep];
			else
				[strongSelf showLoginAlert:TGL(@"Login.EmailResetFailedMessage", @"The email address could not be reset.")];
		}];
		return;
	}

	if (self.currentStep != TGLoginStepCode)
		return;

	[TGLoginService resendAuthenticationCodeWithFailureMessage:nil completion:^(NSDictionary *info, NSInteger retryAfterSeconds) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf.currentStep != TGLoginStepCode)
			return;
		if (info == nil) {
			[strongSelf showLoginAlert:[strongSelf loginErrorMessage:TGL(@"Login.ResendCodeFailedMessage", @"Telegram could not resend the code. Please try again.")
													  forRetryAfterSeconds:retryAfterSeconds]];
			if (retryAfterSeconds >= 0)
				[strongSelf startResendCountdownWithSeconds:retryAfterSeconds];
			return;
		}
		[strongSelf applyCodeInfo:info];
		[strongSelf startResendCountdown];
	}];
}

@end

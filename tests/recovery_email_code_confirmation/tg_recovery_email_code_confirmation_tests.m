#import "tg_recovery_email_code_confirmation_tests.h"
#import "../../src/Screens/Settings/TGRecoveryEmailCodeConfirmation.h"

TGTestOutcome TGRecoveryEmailCodeConfirmationTestNonDictionaryStateIsNotConfirmed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGRecoveryEmailCodeWasConfirmed((NSDictionary *)@"not a dictionary"),
			"a non-dictionary state (the genuine-error case) must never be read as a confirmed code");

	return outcome;
}

TGTestOutcome TGRecoveryEmailCodeConfirmationTestMissingPatternIsConfirmed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *state = @{ @"hasRecoveryEmail" : @YES };
	TGTestExpectTrue(&outcome, TGRecoveryEmailCodeWasConfirmed(state),
			"a state with no recoveryEmailPattern at all means TDLib's recovery_email_address_code_info is null, so the code was accepted");

	return outcome;
}

TGTestOutcome TGRecoveryEmailCodeConfirmationTestEmptyPatternIsConfirmed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *state = @{ @"recoveryEmailPattern" : @"" };
	TGTestExpectTrue(&outcome, TGRecoveryEmailCodeWasConfirmed(state),
			"an empty recoveryEmailPattern is TGPrivacyPasswordState's flattening of a null recovery_email_address_code_info, meaning confirmed");

	return outcome;
}

TGTestOutcome TGRecoveryEmailCodeConfirmationTestNonStringPatternIsConfirmed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *state = @{ @"recoveryEmailPattern" : [NSNull null] };
	TGTestExpectTrue(&outcome, TGRecoveryEmailCodeWasConfirmed(state),
			"a non-string recoveryEmailPattern must be treated the same as no pattern at all");

	return outcome;
}

TGTestOutcome TGRecoveryEmailCodeConfirmationTestNonEmptyPatternIsNotConfirmed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *state = @{ @"recoveryEmailPattern" : @"jo***@example.com" };
	TGTestExpectTrue(&outcome, !TGRecoveryEmailCodeWasConfirmed(state),
			"a still-populated recoveryEmailPattern means TDLib's PasswordState.recovery_email_address_code_info is still non-null, "
			"which per td_api.tl means the wrong or expired code was silently kept pending by account_confirmPasswordEmail, not accepted");

	return outcome;
}

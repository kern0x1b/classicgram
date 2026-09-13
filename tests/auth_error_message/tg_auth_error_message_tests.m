#import "tg_auth_error_message_tests.h"
#import "../../src/TDLibClient/TGAuthErrorMessage.h"

TGTestOutcome TGAuthErrorMessageTestNamesTheCodesAUserCanAct(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGAuthErrorMessage(@"PHONE_CODE_INVALID") isEqualToString:@"Invalid code, please try again."],
			"a wrong code says so in words the user can act on");
	TGTestExpectTrue(&outcome,
			[TGAuthErrorMessage(@"PHONE_CODE_EXPIRED")
					isEqualToString:@"That code has expired. Please request a new one."],
			"an expired code tells the user to ask for another");
	TGTestExpectTrue(&outcome,
			[TGAuthErrorMessage(@"PHONE_NUMBER_INVALID") isEqualToString:@"That phone number is not valid."],
			"a rejected number is named");
	TGTestExpectTrue(&outcome,
			[TGAuthErrorMessage(@"PASSWORD_HASH_INVALID") isEqualToString:@"That password is wrong."],
			"a wrong two-step password reads as a wrong password");
	TGTestExpectTrue(&outcome,
			[TGAuthErrorMessage(@"phone_code_invalid") isEqualToString:@"Invalid code, please try again."],
			"the mapping does not depend on the case the server used");

	return outcome;
}

TGTestOutcome TGAuthErrorMessageTestNeverShowsARawServerString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *generic = @"An error occurred, please try again later.";
	TGTestExpectTrue(&outcome,
			[TGAuthErrorMessage(@"Call to checkAuthenticationCode unexpected") isEqualToString:generic],
			"a TDLib internal complaint must never reach the user as itself");
	TGTestExpectTrue(&outcome, [TGAuthErrorMessage(@"AUTH_KEY_DUPLICATED") isEqualToString:generic],
			"an unmapped server code falls back to the generic message");
	TGTestExpectTrue(&outcome, [TGAuthErrorMessage(@"") isEqualToString:generic],
			"an empty message is still a readable alert");
	TGTestExpectTrue(&outcome, [TGAuthErrorMessage(nil) isEqualToString:generic],
			"a nil message must not crash the login screen");
	TGTestExpectTrue(&outcome, [TGAuthErrorMessage((NSString *)@[]) isEqualToString:generic],
			"a message of the wrong type off the wire is not printed");

	return outcome;
}

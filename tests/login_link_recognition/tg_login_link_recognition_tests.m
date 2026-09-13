#import "tg_login_link_recognition_tests.h"
#import "../../src/Screens/Settings/TGLoginLinkRecognition.h"

TGTestOutcome TGLoginLinkRecognitionTestNilTextIsNotALoginLink(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGTextIsLoginConfirmationLink(nil),
			"nil must never be treated as a login confirmation link");

	return outcome;
}

TGTestOutcome TGLoginLinkRecognitionTestEmptyTextIsNotALoginLink(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGTextIsLoginConfirmationLink(@""),
			"an empty string must never be treated as a login confirmation link");

	return outcome;
}

TGTestOutcome TGLoginLinkRecognitionTestExactTokenPrefixIsALoginLink(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGTextIsLoginConfirmationLink(@"tg://login?token=AbCdEf0123456789"),
			"the real tg://login?token= prefix that TDLib's confirm_qr_code_authentication requires must match");

	return outcome;
}

TGTestOutcome TGLoginLinkRecognitionTestUppercaseTokenPrefixIsALoginLink(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGTextIsLoginConfirmationLink(@"TG://LOGIN?TOKEN=AbCdEf0123456789"),
			"TDLib lowercases the whole link before comparing, so an uppercase scheme and query must still match");

	return outcome;
}

TGTestOutcome TGLoginLinkRecognitionTestMixedCaseTokenPrefixIsALoginLink(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGTextIsLoginConfirmationLink(@"Tg://Login?Token=AbCdEf0123456789"),
			"a mixed-case prefix must match, matching TDLib's case-insensitive comparison");

	return outcome;
}

TGTestOutcome TGLoginLinkRecognitionTestSmsAuthCodeDeepLinkIsNotALoginLink(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGTextIsLoginConfirmationLink(@"tg://login?code=123456"),
			"tg://login?code= is TDLib's unrelated SMS authentication code deep link, not a QR login token");

	return outcome;
}

TGTestOutcome TGLoginLinkRecognitionTestPlainLoginPrefixWithoutTokenIsNotALoginLink(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGTextIsLoginConfirmationLink(@"tg://login"),
			"the bare tg://login prefix with no ?token= must not be treated as a login confirmation link");

	return outcome;
}

TGTestOutcome TGLoginLinkRecognitionTestChatNamedLoginIsNotALoginLink(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGTextIsLoginConfirmationLink(@"https://t.me/login"),
			"a plain link to a chat/user/channel literally named login must not be treated as a login confirmation link");

	return outcome;
}

TGTestOutcome TGLoginLinkRecognitionTestUnrelatedTextIsNotALoginLink(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGTextIsLoginConfirmationLink(@"hello world"),
			"arbitrary scanned text unrelated to any tg:// link must not be treated as a login confirmation link");

	return outcome;
}

TGTestOutcome TGLoginLinkRecognitionTestLeadingWhitespaceIsNotALoginLink(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGTextIsLoginConfirmationLink(@" tg://login?token=AbCdEf0123456789"),
			"TDLib does not trim leading whitespace before its own prefix check, so this predicate must agree and reject it too");

	return outcome;
}

TGTestOutcome TGLoginLinkRecognitionTestTrailingWhitespaceStillMatchesPrefix(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGTextIsLoginConfirmationLink(@"tg://login?token=AbCdEf0123456789 "),
			"trailing whitespace sits after the prefix this predicate checks, so it must not change the prefix match");

	return outcome;
}

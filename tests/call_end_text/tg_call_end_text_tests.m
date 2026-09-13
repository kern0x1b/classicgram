#import "tg_call_end_text_tests.h"
#import "../../src/Screens/Calls/TGCallEndText.h"

TGTestOutcome TGCallEndTextTestNoAnswerReasonMapsToLocalizedNoAnswer(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGCallEndText(@"No answer", @"Call Failed");

	TGTestExpectTrue(&outcome, [result isEqualToString:@"No Answer"],
			"the backend's \"No answer\" reason must resolve to the localized No Answer status, not be shown raw");

	return outcome;
}

TGTestOutcome TGCallEndTextTestDeclinedReasonMapsToBusy(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGCallEndText(@"Declined", @"Call Failed");

	TGTestExpectTrue(&outcome, [result isEqualToString:@"Busy"],
			"a declined call must read Busy, the wording the call screen uses for a refused call");

	return outcome;
}

TGTestOutcome TGCallEndTextTestDisconnectedReasonMapsToCallFailed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGCallEndText(@"Disconnected", @"Call Ended");

	TGTestExpectTrue(&outcome, [result isEqualToString:@"Call Failed"],
			"a disconnect must read Call Failed rather than inheriting whichever fallback the caller passed");

	return outcome;
}

TGTestOutcome TGCallEndTextTestCallEndedReasonMapsToCallEnded(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGCallEndText(@"Call ended", @"Call Failed");

	TGTestExpectTrue(&outcome, [result isEqualToString:@"Call Ended"],
			"a normally ended call must read Call Ended, not the failure fallback");

	return outcome;
}

TGTestOutcome TGCallEndTextTestMovedToGroupCallReasonMapsToMovedToGroupCall(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGCallEndText(@"Moved to a group call", @"Call Ended");

	TGTestExpectTrue(&outcome, [result isEqualToString:@"Moved to a Group Call"],
			"a call upgraded into a group call must say so instead of reading as an ordinary ended call");

	return outcome;
}

TGTestOutcome TGCallEndTextTestEmptyAndNonStringReasonsUseFallback(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGCallEndText(nil, @"Call Failed") isEqualToString:@"Call Failed"],
			"no reason at all must fall back to the caller's status text");
	TGTestExpectTrue(&outcome, [TGCallEndText(@"", @"Call Failed") isEqualToString:@"Call Failed"],
			"an empty reason must fall back to the caller's status text");
	TGTestExpectTrue(&outcome, [TGCallEndText((NSString *)@42, @"Call Failed") isEqualToString:@"Call Failed"],
			"a non-string reason coming off the wire must fall back rather than being messaged as a string");

	return outcome;
}

TGTestOutcome TGCallEndTextTestUnrecognizedBackendMessageUsesFallbackNotItself(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGCallEndText(@"PARTICIPANT_VERSION_OUTDATED", @"Call Failed");

	TGTestExpectTrue(&outcome, [result isEqualToString:@"Call Failed"],
			"an unrecognized TDLib error message must never reach the user verbatim: callStateError stores the raw "
			"English error text as the end reason, so anything unmapped has to render as the localized fallback");

	return outcome;
}

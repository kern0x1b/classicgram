#import "tg_flood_wait_message_tests.h"
#import "../../src/TDLibClient/TGFloodWaitMessage.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFloodWaitMessageTestParsesRetryAfterSeconds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSInteger seconds = TGFloodWaitSecondsFromMessage(@"Too Many Requests: retry after 47");

	TGTestExpectTrue(&outcome, seconds == 47,
			"the seconds trailing 'retry after ' must be parsed out of the message");

	return outcome;
}

TGTestOutcome TGFloodWaitMessageTestMatchIsCaseInsensitive(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSInteger seconds = TGFloodWaitSecondsFromMessage(@"too many requests: RETRY AFTER 5");

	TGTestExpectTrue(&outcome, seconds == 5,
			"the 'retry after ' marker must be matched regardless of case");

	return outcome;
}

TGTestOutcome TGFloodWaitMessageTestNonFloodWaitMessageReturnsNegativeOne(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSInteger seconds = TGFloodWaitSecondsFromMessage(@"PHONE_CODE_INVALID");

	TGTestExpectTrue(&outcome, seconds == -1,
			"a message with no 'retry after ' marker must not be treated as a flood wait");

	return outcome;
}

TGTestOutcome TGFloodWaitMessageTestNilMessageReturnsNegativeOne(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSInteger seconds = TGFloodWaitSecondsFromMessage(nil);

	TGTestExpectTrue(&outcome, seconds == -1,
			"a nil message must not crash and must report no flood wait");

	return outcome;
}

TGTestOutcome TGFloodWaitMessageTestMissingDigitsAfterMarkerReturnsNegativeOne(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSInteger seconds = TGFloodWaitSecondsFromMessage(@"Too Many Requests: retry after later");

	TGTestExpectTrue(&outcome, seconds == -1,
			"a marker with no digits following it must not be treated as a flood wait");

	return outcome;
}

TGTestOutcome TGFloodWaitMessageTestZeroSecondsReturnsNegativeOne(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSInteger seconds = TGFloodWaitSecondsFromMessage(@"Too Many Requests: retry after 0");

	TGTestExpectTrue(&outcome, seconds == -1,
			"a non-positive wait must not be surfaced as an actionable flood wait");

	return outcome;
}

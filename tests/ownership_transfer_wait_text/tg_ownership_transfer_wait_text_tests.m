#import "tg_ownership_transfer_wait_text_tests.h"
#import "../../src/Screens/Groups/TGOwnershipTransferWaitText.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGOwnershipTransferRetryDurationTextTestZeroClampsToOneSecond(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGOwnershipTransferRetryDurationText(0) isEqualToString:@"1 second"],
			"a zero retry_after must clamp up to 1 second, not display 0 seconds");

	return outcome;
}

TGTestOutcome TGOwnershipTransferRetryDurationTextTestNegativeClampsToOneSecond(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGOwnershipTransferRetryDurationText(-5) isEqualToString:@"1 second"],
			"a negative retry_after must still clamp to 1 second, not crash or underflow");

	return outcome;
}

TGTestOutcome TGOwnershipTransferRetryDurationTextTestSubMinuteValue(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGOwnershipTransferRetryDurationText(45) isEqualToString:@"45 seconds"],
			"a sub-minute retry_after must be reported in seconds");

	return outcome;
}

TGTestOutcome TGOwnershipTransferRetryDurationTextTestExactlyOneMinuteBoundary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGOwnershipTransferRetryDurationText(60) isEqualToString:@"1 minute"],
			"exactly sixty seconds must format in minutes, crossing over from the seconds branch");

	return outcome;
}

TGTestOutcome TGOwnershipTransferRetryDurationTextTestExactlyOneHourBoundary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGOwnershipTransferRetryDurationText(3600) isEqualToString:@"1 hour"],
			"exactly one hour must format in hours, crossing over from the minutes branch");

	return outcome;
}

TGTestOutcome TGOwnershipTransferRetryDurationTextTestExactlyTwentyFourHourBoundary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGOwnershipTransferRetryDurationText(86400) isEqualToString:@"1 day"],
			"exactly twenty-four hours must format in days, crossing over from the hours branch");

	return outcome;
}

TGTestOutcome TGOwnershipTransferRetryDurationTextTestMultiDayValue(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGOwnershipTransferRetryDurationText(5 * 86400) isEqualToString:@"5 days"],
			"a multi-day retry_after, such as the 7-day password-freshness window, must report the correct whole number of days");

	return outcome;
}

#import "tg_topic_mute_text_tests.h"
#import "../../src/Screens/Chat/TGTopicMuteText.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGTopicMuteTextTestZeroSecondsIsEnabled(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGTopicMuteText(0) isEqualToString:@"Enabled"],
			"zero seconds until unmute must read as Enabled, not a zero-length mute");

	return outcome;
}

TGTestOutcome TGTopicMuteTextTestNegativeSecondsIsEnabled(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGTopicMuteText(-5) isEqualToString:@"Enabled"],
			"a negative seconds-until-unmute value must still read as Enabled, not crash or underflow");

	return outcome;
}

TGTestOutcome TGTopicMuteTextTestSubMinuteValueClampsToOneMinute(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGTopicMuteText(30) isEqualToString:@"Muted for 1 minute"],
			"a mute duration under one minute must clamp up to Muted for 1 minute, not display Muted for 0 minutes");

	return outcome;
}

TGTestOutcome TGTopicMuteTextTestExactlyOneHourBoundary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGTopicMuteText(3600) isEqualToString:@"Muted for 1 hour"],
			"exactly one hour must format in hours, crossing over from the minutes branch");

	return outcome;
}

TGTestOutcome TGTopicMuteTextTestExactlyTwentyFourHourBoundary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGTopicMuteText(86400) isEqualToString:@"Muted for 1 day"],
			"exactly twenty-four hours must format in days, crossing over from the hours branch");

	return outcome;
}

TGTestOutcome TGTopicMuteTextTestMultiDayValue(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGTopicMuteText(5 * 86400) isEqualToString:@"Muted for 5 days"],
			"a multi-day mute duration must report the correct whole number of days");

	return outcome;
}

TGTestOutcome TGTopicMuteTextTestHugeOverAYearValueIsMutedForever(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGTopicMuteText(2 * 366 * 24 * 3600) isEqualToString:@"Muted"],
			"a mute duration of a year or more must collapse to the plain Muted forever label");

	return outcome;
}

#import "tg_profile_auto_delete_subtitle_tests.h"
#import "../../src/Screens/Profile/TGProfileAutoDeleteSubtitle.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGProfileAutoDeleteSubtitleTestZeroIsOff(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGProfileAutoDeleteSubtitleForSeconds(0) isEqualToString:@"Off"],
			"a zero auto-delete value must display as Off");

	return outcome;
}

TGTestOutcome TGProfileAutoDeleteSubtitleTestNegativeIsOff(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGProfileAutoDeleteSubtitleForSeconds(-5) isEqualToString:@"Off"],
			"a negative auto-delete value must still display as Off, not crash or underflow");

	return outcome;
}

TGTestOutcome TGProfileAutoDeleteSubtitleTestExactlyOneDayPreset(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGProfileAutoDeleteSubtitleForSeconds(86400) isEqualToString:@"1 day"],
			"exactly the one-day preset must show the preset wording, not a generic day count");

	return outcome;
}

TGTestOutcome TGProfileAutoDeleteSubtitleTestExactlyOneWeekPreset(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGProfileAutoDeleteSubtitleForSeconds(604800) isEqualToString:@"1 week"],
			"exactly the one-week preset must show the preset wording, not a generic day count");

	return outcome;
}

TGTestOutcome TGProfileAutoDeleteSubtitleTestExactlyOneMonthPreset(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGProfileAutoDeleteSubtitleForSeconds(2592000) isEqualToString:@"1 month"],
			"exactly the one-month preset must show the preset wording, not a generic day count");

	return outcome;
}

TGTestOutcome TGProfileAutoDeleteSubtitleTestNonPresetThreeDaysShowsThreeDays(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGProfileAutoDeleteSubtitleForSeconds(3 * 86400) isEqualToString:@"3 days"],
			"a genuine 3-day custom timer must not be collapsed onto the nearest preset bucket");

	return outcome;
}

TGTestOutcome TGProfileAutoDeleteSubtitleTestNonPresetLongerThanAWeekShowsWeeks(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGProfileAutoDeleteSubtitleForSeconds(2 * 604800) isEqualToString:@"2 weeks"],
			"a duration longer than a week but not the one-month preset must not be rounded down to 1 week");

	return outcome;
}

TGTestOutcome TGProfileAutoDeleteSubtitleTestSecretChatSubMinuteValueShowsSeconds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGProfileAutoDeleteSubtitleForSeconds(45) isEqualToString:@"45 seconds"],
			"a secret chat's fine-grained sub-minute timer must not be misread as a day-count value");

	return outcome;
}

TGTestOutcome TGProfileAutoDeleteSubtitleTestSecretChatSubHourValueShowsMinutes(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGProfileAutoDeleteSubtitleForSeconds(90) isEqualToString:@"1 minute"],
			"a secret chat's sub-hour timer must be reported in minutes");

	return outcome;
}

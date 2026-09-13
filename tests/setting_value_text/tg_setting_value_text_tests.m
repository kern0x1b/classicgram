#import "tg_setting_value_text_tests.h"

#import "../../src/Utilities/TGSettingValueText.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGSettingValueTextTestAFailedFetchIsNotAnAnswer(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSettingValueText(NO, YES, @"Off") isEqualToString:@"Unavailable"],
			"a setting the app could not read must not be drawn as a value: the "
			"auto-delete row read \"Off\" for a failed fetch, which is a claim about "
			"whether messages are being deleted");
	TGTestExpectTrue(&outcome,
			[TGSettingValueText(YES, YES, @"1 week") isEqualToString:@"Unavailable"],
			"a failure outranks a value left over from an earlier read");

	return outcome;
}

TGTestOutcome TGSettingValueTextTestALoadedValueIsShown(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGSettingValueText(YES, NO, @"1 week") isEqualToString:@"1 week"],
			"a value that was read is shown as it is");
	TGTestExpectTrue(&outcome, [TGSettingValueText(YES, NO, @"Off") isEqualToString:@"Off"],
			"including Off, which is a real answer when it was really read");

	return outcome;
}

TGTestOutcome TGSettingValueTextTestAPendingFetchShowsDots(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGSettingValueText(NO, NO, @"Off") isEqualToString:@"..."],
			"a fetch still in flight shows neither an answer nor a failure");
	TGTestExpectTrue(&outcome, [TGSettingValueText(YES, NO, nil) isEqualToString:@""],
			"and a value that is not a string at all is empty rather than a crash");

	return outcome;
}

TGTestOutcome TGSettingValueTextTestACountIsNotZeroWhenUnread(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGSettingValueText(NO, YES, @"0") isEqualToString:@"Unavailable"],
			"the profile-photo row counted an empty answer as zero photos, which reads as "
			"the photos being gone rather than unread");
	TGTestExpectTrue(&outcome, [TGSettingValueText(YES, NO, @"0") isEqualToString:@"0"],
			"an account that really has no profile photos still says zero");

	return outcome;
}

#import "tg_member_picker_status_tests.h"

#import "../../src/Screens/Groups/TGMemberPickerStatusText.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGMemberPickerStatusTestAFailedSearchSaysSo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGMemberPickerStatusText(YES, 0) hasPrefix:@"Contacts could not be searched"],
			"a contact search that never reached the server must not tell someone adding "
			"members that nobody by that name exists");

	return outcome;
}

TGTestOutcome TGMemberPickerStatusTestNobodyMatchedSaysThat(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGMemberPickerStatusText(NO, 0)
					isEqualToString:@"No contact or Telegram user matches that name."],
			"a search that came back empty says so");

	return outcome;
}

TGTestOutcome TGMemberPickerStatusTestPeopleOnScreenSayNothing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGMemberPickerStatusText(NO, 4) isEqualToString:@""],
			"with people listed the status line is out of the way");
	TGTestExpectTrue(&outcome, [TGMemberPickerStatusText(YES, 4) isEqualToString:@""],
			"and a later failure does not cover the people already found");

	return outcome;
}

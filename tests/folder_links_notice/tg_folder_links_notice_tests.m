#import "tg_folder_links_notice_tests.h"

#import "../../src/Screens/Settings/TGFolderLinksNotice.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGFolderLinksNoticeTestAFailedLoadSaysSo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGFolderLinksNoticeText(YES, 0)
					isEqualToString:@"The links for this folder could not be loaded."],
			"a folder whose links could not be loaded must say so, rather than showing the "
			"empty row that reads as the folder having no link yet - and inviting a second one");

	return outcome;
}

TGTestOutcome TGFolderLinksNoticeTestASuccessfulLoadSaysNothing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGFolderLinksNoticeText(NO, 0) isEqualToString:@""],
			"a folder that really has no links says nothing here");

	return outcome;
}

TGTestOutcome TGFolderLinksNoticeTestLinksAlreadyKnownStaySilent(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGFolderLinksNoticeText(YES, 2) isEqualToString:@""],
			"a refresh that failed behind links already on screen leaves them alone");

	return outcome;
}

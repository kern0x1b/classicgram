#import "tg_folder_chat_count_tests.h"
#import "../../src/Screens/Settings/TGFolderChatCount.h"

TGTestOutcome TGFolderChatCountTestAZeroBeforeTheListsAreLoadedIsNotKept(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGFolderChatCountIsTrustworthy(0, NO) == NO,
			"TDLib counts a folder's chats from the loaded lists, so a zero before they are loaded "
			"says nothing and must not be shown");
	TGTestExpectTrue(&outcome, TGFolderChatCountIsTrustworthy(0, YES) == YES,
			"a zero once the lists are loaded is a real answer: the folder is empty");
	TGTestExpectTrue(&outcome, TGFolderChatCountIsTrustworthy(3, NO) == YES,
			"a count found early can only grow, so it is worth showing while the rest loads");
	TGTestExpectTrue(&outcome, TGFolderChatCountIsTrustworthy(3, YES) == YES,
			"and it stays worth showing afterwards");

	return outcome;
}

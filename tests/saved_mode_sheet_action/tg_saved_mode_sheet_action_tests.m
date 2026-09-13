#import "tg_saved_mode_sheet_action_tests.h"
#import "../../src/Screens/Chat/TGSavedModeSheetAction.h"

TGTestOutcome TGSavedModeSheetActionTestEachButtonMapsToItsAction(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGSavedModeSheetActionForIndex(0, 3) == TGSavedModeSheetActionViewAsChats,
			"the first button must stay View as Chats");
	TGTestExpectTrue(&outcome, TGSavedModeSheetActionForIndex(1, 3) == TGSavedModeSheetActionViewAsMessages,
			"the second button must stay View as Messages");
	TGTestExpectTrue(&outcome, TGSavedModeSheetActionForIndex(2, 3) == TGSavedModeSheetActionMessageTags,
			"the third button must open the message tags");

	return outcome;
}

TGTestOutcome TGSavedModeSheetActionTestCancelAndOutOfRangeDoNothing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGSavedModeSheetActionForIndex(3, 3) == TGSavedModeSheetActionNone,
			"the cancel button must do nothing");
	TGTestExpectTrue(&outcome, TGSavedModeSheetActionForIndex(-1, 3) == TGSavedModeSheetActionNone,
			"a dismissed sheet must do nothing");
	TGTestExpectTrue(&outcome, TGSavedModeSheetActionForIndex(2, 2) == TGSavedModeSheetActionNone,
			"an index that is the cancel button must do nothing whatever it would otherwise mean");
	TGTestExpectTrue(&outcome, TGSavedModeSheetActionForIndex(7, 3) == TGSavedModeSheetActionNone,
			"an index past the last button must do nothing");

	return outcome;
}

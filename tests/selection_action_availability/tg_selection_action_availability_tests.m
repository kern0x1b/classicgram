#import "tg_selection_action_availability_tests.h"
#import "../../src/Screens/Chat/TGSelectionActionAvailability.h"

TGTestOutcome TGSelectionActionAvailabilityTestProtectedContentDisablesEveryWayOut(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGSelectionActionIsAvailable(YES, NO, YES, NO),
			"an unprotected chat with something selected offers the action");
	TGTestExpectTrue(&outcome, !TGSelectionActionIsAvailable(YES, YES, YES, NO),
			"a chat with protected content offers none of them");
	TGTestExpectTrue(&outcome, !TGSelectionActionIsAvailable(YES, NO, NO, NO),
			"nothing selected, nothing to do");
	TGTestExpectTrue(&outcome, !TGSelectionActionIsAvailable(YES, NO, YES, YES),
			"a selection holding one message that forbids it is enough to stop the action");
	TGTestExpectTrue(&outcome, !TGSelectionActionIsAvailable(NO, NO, YES, NO),
			"before the chat's protection is known the action stays off, where Save and Copy "
			"used to read the not-yet-loaded flag as permission");

	return outcome;
}

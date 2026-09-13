#import "tg_list_status_tests.h"
#import "../../src/Utilities/TGListLoadFailure.h"

TGTestOutcome TGListStatusTestAFailureIsNotAnEmptyList(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGListStatusOfList(NO, NO, 0) == TGListStatusLoading,
		"a list that has not answered yet is loading, not empty");
	TGTestExpectTrue(&outcome, TGListStatusOfList(YES, NO, 0) == TGListStatusEmpty,
		"a list that answered with nothing is empty");
	TGTestExpectTrue(&outcome, TGListStatusOfList(YES, YES, 0) == TGListStatusFailed,
		"a list whose request failed says so rather than claiming there is nothing");
	TGTestExpectTrue(&outcome, TGListStatusOfList(NO, YES, 0) == TGListStatusFailed,
		"a failure outranks a load that never finished");
	TGTestExpectTrue(&outcome, TGListStatusOfList(YES, YES, 3) == TGListStatusRows,
		"rows already on screen outrank a later failure, so a refresh that fails does not "
		"replace what the reader can see with a notice");
	TGTestExpectTrue(&outcome, TGListStatusOfList(NO, NO, 3) == TGListStatusRows,
		"and rows outrank a still-running load for the same reason");

	return outcome;
}

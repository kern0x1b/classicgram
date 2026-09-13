#import "tg_list_load_failure_tests.h"
#import "../../src/Utilities/TGListLoadFailure.h"

TGTestOutcome TGListLoadFailureTestAListSaysSoOnlyWhenItHasNothingToShow(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGListShowsLoadFailureNotice(YES, 0),
			"a list that asked and got nothing back says the load failed");
	TGTestExpectTrue(&outcome, !TGListShowsLoadFailureNotice(NO, 0),
			"a list that is genuinely empty keeps its own empty wording");
	TGTestExpectTrue(&outcome, !TGListShowsLoadFailureNotice(YES, 40),
			"a later page failing does not take back the rows already on screen");
	TGTestExpectTrue(&outcome, !TGListShowsLoadFailureNotice(NO, 40),
			"a list with rows and no failure says nothing at all");

	return outcome;
}

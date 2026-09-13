#import "tg_blocked_list_paging_tests.h"
#import "../../src/Screens/Settings/TGBlockedListPaging.h"

TGTestOutcome TGBlockedListPagingTestAShortPageEndsTheList(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGBlockedListIsExhausted(0, 100, 0, 0) == YES,
			"an empty first page must end the list");
	TGTestExpectTrue(&outcome, TGBlockedListIsExhausted(37, 100, 37, 0) == YES,
			"a page shorter than the page size must end the list even with no total");
	TGTestExpectTrue(&outcome, TGBlockedListIsExhausted(100, 0, 100, 500) == YES,
			"a page size of zero must end the list rather than ask forever");

	return outcome;
}

TGTestOutcome TGBlockedListPagingTestAFullPageKeepsGoingUntilTheTotalIsReached(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGBlockedListIsExhausted(100, 100, 100, 0) == NO,
			"a full page with no total reported must leave the list open");
	TGTestExpectTrue(&outcome, TGBlockedListIsExhausted(100, 100, 100, 250) == NO,
			"a full page short of the total must leave the list open");
	TGTestExpectTrue(&outcome, TGBlockedListIsExhausted(100, 100, 250, 250) == YES,
			"reaching the total must end the list");
	TGTestExpectTrue(&outcome, TGBlockedListIsExhausted(100, 100, 300, 250) == YES,
			"passing the total must end the list");

	return outcome;
}

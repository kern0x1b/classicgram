#import "tg_story_paging_tests.h"
#import "../../src/Screens/Stories/TGStoryPaging.h"

TGTestOutcome TGStoryPagingTestReportsMoreWhileTheServerTotalIsNotReached(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGStoryPageHasMore(0, 30, 91) == YES,
			"a first page of 30 out of 91 must leave more to load");
	TGTestExpectTrue(&outcome, TGStoryPageHasMore(60, 30, 91) == YES,
			"90 of 91 loaded must still leave more to load");
	TGTestExpectTrue(&outcome, TGStoryPageHasMore(61, 30, 91) == NO,
			"reaching the total exactly must end the paging");
	TGTestExpectTrue(&outcome, TGStoryPageHasMore(90, 30, 91) == NO,
			"a total the loaded rows already passed must end the paging");

	return outcome;
}

TGTestOutcome TGStoryPagingTestStopsOnAnEmptyPageOrAnUnknownTotal(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGStoryPageHasMore(30, 0, 91) == NO,
			"a page that came back empty must end the paging whatever the total says");
	TGTestExpectTrue(&outcome, TGStoryPageHasMore(0, 30, 0) == NO,
			"a total of zero must end the paging rather than ask for another page forever");
	TGTestExpectTrue(&outcome, TGStoryPageHasMore(0, 30, -1) == NO,
			"a negative total must end the paging, not be compared as a large unsigned value");

	return outcome;
}

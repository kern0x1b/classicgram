#import "tg_grouped_metrics_tests.h"
#import "../../src/Theme/TGGroupedMetrics.h"

TGTestOutcome TGGroupedMetricsTestHeaderAndCommentFollowTheOriginal(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGGroupedHeaderHeight(@"PROFILE") == 46,
		"a titled section header is 46 points, as the original draws it");
	TGTestExpectTrue(&outcome, TGGroupedHeaderHeight(@"") == 8,
		"a section with no title is the original's 8 point gap, not a title's worth of space");
	TGTestExpectTrue(&outcome, TGGroupedHeaderHeight(nil) == 8,
		"no title at all is the same gap");

	TGTestExpectTrue(&outcome, TGGroupedCommentHeight(34) == 48,
		"a footer comment is its text plus the original's 7 points above and below");
	TGTestExpectTrue(&outcome, TGGroupedCommentHeight(0) == 0,
		"a footer with no text takes no space");

	return outcome;
}

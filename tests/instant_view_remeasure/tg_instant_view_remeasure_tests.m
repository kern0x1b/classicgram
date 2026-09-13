#import "tg_instant_view_remeasure_tests.h"
#import "../../src/Screens/Media/TGInstantViewRemeasure.h"

TGTestOutcome TGInstantViewRemeasureTestOnlyWhenTheWidthActuallyChanged(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGInstantViewNeedsRemeasure(1024, 768, 12) == YES,
		"a rotation changes the width, so the article has to be measured again");
	TGTestExpectTrue(&outcome, TGInstantViewNeedsRemeasure(768, 768, 12) == NO,
		"a layout pass at the same width must not start the work again");
	TGTestExpectTrue(&outcome, TGInstantViewNeedsRemeasure(768.2f, 768, 12) == NO,
		"a sub-pixel difference is not a rotation");
	TGTestExpectTrue(&outcome, TGInstantViewNeedsRemeasure(1024, 768, 0) == NO,
		"an article with no blocks has nothing to measure");
	TGTestExpectTrue(&outcome, TGInstantViewNeedsRemeasure(0, 768, 12) == NO,
		"a view that has not been laid out yet reports no width, which is not a change");

	return outcome;
}

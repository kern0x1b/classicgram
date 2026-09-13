#import "tg_mirrored_rect_tests.h"
#import "../../src/Utilities/TGMirroredRect.h"

TGTestOutcome TGMirroredRectTestALeftToRightRowIsLeftAlone(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGRect badge = CGRectMake(265, 29, 27, 21);
	CGRect kept = TGMirroredRectInContainer(badge, 320, NO);
	TGTestExpectTrue(&outcome, CGRectEqualToRect(kept, badge),
			"a row in a left-to-right language keeps every frame exactly as it was laid out");

	return outcome;
}

TGTestOutcome TGMirroredRectTestARightToLeftRowIsMirroredAboutTheContainer(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGRect badge = CGRectMake(265, 29, 27, 21);
	CGRect mirrored = TGMirroredRectInContainer(badge, 320, YES);
	TGTestExpectTrue(&outcome, mirrored.origin.x == 320 - 265 - 27,
			"the right edge becomes the same distance from the left edge");
	TGTestExpectTrue(&outcome, mirrored.origin.y == badge.origin.y &&
			mirrored.size.width == badge.size.width && mirrored.size.height == badge.size.height,
			"mirroring moves a frame across, it does not resize or raise it");

	CGRect mirroredTwice = TGMirroredRectInContainer(mirrored, 320, YES);
	TGTestExpectTrue(&outcome, CGRectEqualToRect(mirroredTwice, badge),
			"mirroring twice returns the original frame, which is what makes the rule safe to apply "
			"once per frame");

	CGRect flush = TGMirroredRectInContainer(CGRectMake(0, 0, 320, 44), 320, YES);
	TGTestExpectTrue(&outcome, flush.origin.x == 0,
			"a frame that fills the width stays where it is");

	CGRect wider = TGMirroredRectInContainer(CGRectMake(10, 0, 400, 44), 320, YES);
	TGTestExpectTrue(&outcome, wider.origin.x == -90,
			"a frame wider than the container keeps its overhang on the other side rather than "
			"being clamped, which is what the layouts that rely on overhang expect");

	return outcome;
}

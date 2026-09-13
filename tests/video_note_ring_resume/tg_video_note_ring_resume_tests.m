#import "tg_video_note_ring_resume_tests.h"
#import "../../src/Screens/Chat/TGVideoNoteRingResume.h"
#import <math.h>

TGTestOutcome TGVideoNoteRingResumeTestFreshStartAnimatesFullRange(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGVideoNoteRingResumeAnimation resume = TGVideoNoteRingResumeAnimationForPosition(0, 10, 1.0f);

	TGTestExpectEqualDouble(&outcome, resume.fromFraction, 0.0, 0.0001,
			"a fresh start must animate the ring's full 0 to 1 range");
	TGTestExpectEqualDouble(&outcome, resume.duration, 10.0, 0.0001,
			"a fresh start's duration must be the whole note length at the given rate");

	return outcome;
}

TGTestOutcome TGVideoNoteRingResumeTestHalfwayAtSameRateResumesFromHalf(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGVideoNoteRingResumeAnimation resume = TGVideoNoteRingResumeAnimationForPosition(5, 10, 1.0f);

	TGTestExpectEqualDouble(&outcome, resume.fromFraction, 0.5, 0.0001,
			"resuming halfway through must start the ring's strokeEnd at 0.5, not 0");
	TGTestExpectEqualDouble(&outcome, resume.duration, 5.0, 0.0001,
			"resuming halfway through must animate only the remaining half of the note length");

	return outcome;
}

TGTestOutcome TGVideoNoteRingResumeTestMidPlayRateChangeUsesRemainingTimeAtNewRate(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGVideoNoteRingResumeAnimation resume = TGVideoNoteRingResumeAnimationForPosition(4, 12, 2.0f);

	TGTestExpectEqualDouble(&outcome, resume.fromFraction, 4.0 / 12.0, 0.0001,
			"a mid-play rate change must resume from the note's actual elapsed fraction");
	TGTestExpectEqualDouble(&outcome, resume.duration, 4.0, 0.0001,
			"a mid-play rate change must animate the remaining 8s of note at the new 2x rate, so 4s");

	return outcome;
}

TGTestOutcome TGVideoNoteRingResumeTestRateBelowFloorIsClampedToHalfSpeed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGVideoNoteRingResumeAnimation resume = TGVideoNoteRingResumeAnimationForPosition(0, 10, 0.3f);

	TGTestExpectEqualDouble(&outcome, resume.duration, 20.0, 0.0001,
			"a rate below the existing 0.5x floor must still be clamped to 0.5x, matching startVideoNoteRing");

	return outcome;
}

TGTestOutcome TGVideoNoteRingResumeTestElapsedPastTotalClampsToComplete(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGVideoNoteRingResumeAnimation resume = TGVideoNoteRingResumeAnimationForPosition(15, 10, 1.0f);

	TGTestExpectEqualDouble(&outcome, resume.fromFraction, 1.0, 0.0001,
			"an elapsed time past the note's length must clamp the fraction to 1.0, not overshoot");
	TGTestExpectEqualDouble(&outcome, resume.duration, 0.0, 0.0001,
			"an already-complete note must animate for zero further seconds");

	return outcome;
}

TGTestOutcome TGVideoNoteRingResumeTestNegativeOrNanElapsedTreatedAsZero(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGVideoNoteRingResumeAnimation negative = TGVideoNoteRingResumeAnimationForPosition(-3, 10, 1.0f);
	TGTestExpectEqualDouble(&outcome, negative.fromFraction, 0.0, 0.0001,
			"a negative elapsed time must be treated as the very start of the note");

	TGVideoNoteRingResumeAnimation nan = TGVideoNoteRingResumeAnimationForPosition(NAN, 10, 1.0f);
	TGTestExpectEqualDouble(&outcome, nan.fromFraction, 0.0, 0.0001,
			"a NaN elapsed time (no current item yet) must be treated as the very start of the note");

	return outcome;
}

TGTestOutcome TGVideoNoteRingResumeTestNonPositiveTotalLengthReturnsZero(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGVideoNoteRingResumeAnimation resume = TGVideoNoteRingResumeAnimationForPosition(1, 0, 1.0f);

	TGTestExpectEqualDouble(&outcome, resume.fromFraction, 0.0, 0.0001,
			"a non-positive total length must not divide by zero");
	TGTestExpectEqualDouble(&outcome, resume.duration, 0.0, 0.0001,
			"a non-positive total length must yield a zero-length animation");

	return outcome;
}

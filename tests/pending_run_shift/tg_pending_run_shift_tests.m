#import "tg_pending_run_shift_tests.h"
#import "../../src/Screens/Chat/TGPendingRunShift.h"

static void TGPendingRunShiftExpectKept(TGTestOutcome *outcome, NSValue *result,
	NSUInteger expectedLocation, NSUInteger expectedLength, const char *description) {
	TGTestExpectTrue(outcome, result != nil, description);
	if (!result)
		return;
	NSRange range = [result rangeValue];
	TGTestExpectEqualInteger(outcome, range.location, expectedLocation, description);
	TGTestExpectEqualInteger(outcome, range.length, expectedLength, description);
}

TGTestOutcome TGPendingRunShiftTestEditEntirelyBeforeRunShiftsOffsetOnly(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSValue *result = TGPendingRunRangeAfterEdit(NSMakeRange(10, 5), NSMakeRange(0, 3), 2);

	TGPendingRunShiftExpectKept(&outcome, result, 9, 5,
			"an edit entirely before the run must only shift its offset by the length delta");

	return outcome;
}

TGTestOutcome TGPendingRunShiftTestEditTouchingRunStartCountsAsBefore(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSValue *result = TGPendingRunRangeAfterEdit(NSMakeRange(10, 5), NSMakeRange(5, 5), 8);

	TGPendingRunShiftExpectKept(&outcome, result, 13, 5,
			"an edit that ends exactly where the run starts must be treated as before it");

	return outcome;
}

TGTestOutcome TGPendingRunShiftTestEditEntirelyAfterRunIsUnchanged(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSValue *result = TGPendingRunRangeAfterEdit(NSMakeRange(0, 5), NSMakeRange(10, 3), 1);

	TGPendingRunShiftExpectKept(&outcome, result, 0, 5,
			"an edit entirely after the run must leave it untouched");

	return outcome;
}

TGTestOutcome TGPendingRunShiftTestEditTouchingRunEndCountsAsAfter(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSValue *result = TGPendingRunRangeAfterEdit(NSMakeRange(0, 5), NSMakeRange(5, 0), 4);

	TGPendingRunShiftExpectKept(&outcome, result, 0, 5,
			"an insertion exactly at the run's end must be treated as after it");

	return outcome;
}

TGTestOutcome TGPendingRunShiftTestInsertionInsideRunGrowsItInPlace(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSValue *result = TGPendingRunRangeAfterEdit(NSMakeRange(5, 10), NSMakeRange(8, 0), 3);

	TGPendingRunShiftExpectKept(&outcome, result, 5, 13,
			"an insertion strictly inside the run must grow the run by the inserted length");

	return outcome;
}

TGTestOutcome TGPendingRunShiftTestDeletionInsideRunShrinksItInPlace(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSValue *result = TGPendingRunRangeAfterEdit(NSMakeRange(5, 10), NSMakeRange(7, 4), 0);

	TGPendingRunShiftExpectKept(&outcome, result, 5, 6,
			"a deletion strictly inside the run must shrink the run by the deleted length");

	return outcome;
}

TGTestOutcome TGPendingRunShiftTestRetypingExactRunContentsKeepsItAtNewLength(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSValue *result = TGPendingRunRangeAfterEdit(NSMakeRange(5, 10), NSMakeRange(5, 10), 7);

	TGPendingRunShiftExpectKept(&outcome, result, 5, 7,
			"selecting and retyping exactly the run's own text must resize it, not drop it");

	return outcome;
}

TGTestOutcome TGPendingRunShiftTestFullyDeletingRunContentsDropsIt(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSValue *result = TGPendingRunRangeAfterEdit(NSMakeRange(5, 10), NSMakeRange(5, 10), 0);

	TGTestExpectTrue(&outcome, result == nil,
			"deleting the entirety of the run's own text must drop the now-empty run");

	return outcome;
}

TGTestOutcome TGPendingRunShiftTestEditCrossingRunStartBoundaryIsDropped(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSValue *result = TGPendingRunRangeAfterEdit(NSMakeRange(5, 10), NSMakeRange(3, 4), 1);

	TGTestExpectTrue(&outcome, result == nil,
			"an edit that starts before the run but ends inside it has an ambiguous resulting shape and must be dropped");

	return outcome;
}

TGTestOutcome TGPendingRunShiftTestEditCrossingRunEndBoundaryIsDropped(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSValue *result = TGPendingRunRangeAfterEdit(NSMakeRange(5, 10), NSMakeRange(12, 5), 1);

	TGTestExpectTrue(&outcome, result == nil,
			"an edit that starts inside the run but extends past its end has an ambiguous resulting shape and must be dropped");

	return outcome;
}

TGTestOutcome TGPendingRunShiftTestEditSpanningPastBothBoundariesIsDropped(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSValue *result = TGPendingRunRangeAfterEdit(NSMakeRange(5, 10), NSMakeRange(0, 20), 1);

	TGTestExpectTrue(&outcome, result == nil,
			"an edit that swallows the run entirely and extends past both of its boundaries must be dropped");

	return outcome;
}

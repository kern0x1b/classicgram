#import "tg_cache_trim_tests.h"
#import "../../src/Utilities/TGCacheTrim.h"

static NSArray *TGOrderOfLength(NSUInteger length) {
	NSMutableArray *order = [NSMutableArray arrayWithCapacity:length];
	for (NSUInteger i = 0; i < length; i++)
		[order addObject:@(i)];
	return order;
}

TGTestOutcome TGCacheTrimTestNothingGoesUntilTheCacheIsFull(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGCacheTrimKeys(TGOrderOfLength(0), 200, 150).count == 0,
			"an empty cache drops nothing");
	TGTestExpectTrue(&outcome, TGCacheTrimKeys(TGOrderOfLength(200), 200, 150).count == 0,
			"a cache exactly at the limit drops nothing");
	TGTestExpectTrue(&outcome, TGCacheTrimKeys(nil, 200, 150).count == 0,
			"no order to work from means nothing is dropped");

	return outcome;
}

TGTestOutcome TGCacheTrimTestTheOldestRowsGoFirst(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *dropped = TGCacheTrimKeys(TGOrderOfLength(201), 200, 150);
	TGTestExpectTrue(&outcome, dropped.count == 51,
			"one row past the limit leaves the newest hundred and fifty");
	TGTestExpectTrue(&outcome, [dropped.firstObject isEqual:@(0)],
			"the oldest row goes first");
	TGTestExpectTrue(&outcome, [dropped.lastObject isEqual:@(50)],
			"the newest rows are kept, so the reader scrolling back finds them measured");

	TGTestExpectTrue(&outcome, TGCacheTrimKeys(TGOrderOfLength(400), 200, 150).count == 250,
			"a cache well past the limit comes back to the keep mark in one pass");
	TGTestExpectTrue(&outcome, TGCacheTrimKeys(TGOrderOfLength(201), 200, 500).count == 0,
			"a keep mark above the cache size drops nothing rather than going negative");

	return outcome;
}

#import "tg_flatten_history_tests.h"
#import "../../src/Wire/Flatten/TGFlattenHistory.h"
#import <Foundation/Foundation.h>

static NSDictionary *TGFHMessage(int64_t messageId, NSString *marker) {
	return @{@"id" : @(messageId), @"marker" : marker};
}

TGTestOutcome TGFlattenHistoryTestMergeRawMessagesDedupsOverlappingIdsKeepingFirstArrayVersion(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *first = @[ TGFHMessage(30, @"first-30"), TGFHMessage(10, @"first-10") ];
	NSArray *second = @[ TGFHMessage(20, @"second-20"), TGFHMessage(10, @"second-10") ];

	NSArray *merged = TGMergeRawMessages(first, second);

	TGTestExpectEqualInteger(&outcome, merged.count, 3,
			"merging two arrays sharing one id must produce exactly the union of distinct ids");

	NSDictionary *keptId10 = nil;
	for (NSDictionary *m in merged)
		if ([m[@"id"] longLongValue] == 10)
			keptId10 = m;

	TGTestExpectTrue(&outcome, keptId10 != nil, "the shared id 10 must still be present after the merge");
	TGTestExpectTrue(&outcome, [keptId10[@"marker"] isEqualToString:@"first-10"],
			"when the same id appears in both arrays, the version from the first array must win, not the second");

	TGTestExpectEqualLongLong(&outcome, [merged[0][@"id"] longLongValue], 30,
			"the merged result must be sorted with the highest id first");
	TGTestExpectEqualLongLong(&outcome, [merged[1][@"id"] longLongValue], 20,
			"the merged result must be sorted descending by id");
	TGTestExpectEqualLongLong(&outcome, [merged[2][@"id"] longLongValue], 10,
			"the merged result must place the lowest id last");

	return outcome;
}

TGTestOutcome TGFlattenHistoryTestMergeRawMessagesUnionsNonOverlappingIds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *first = @[ TGFHMessage(5, @"a"), TGFHMessage(1, @"b") ];
	NSArray *second = @[ TGFHMessage(3, @"c"), TGFHMessage(2, @"d") ];

	NSArray *merged = TGMergeRawMessages(first, second);

	TGTestExpectEqualInteger(&outcome, merged.count, 4,
			"merging two arrays with no shared ids must keep every message from both");
	TGTestExpectEqualLongLong(&outcome, [merged[0][@"id"] longLongValue], 5,
			"the merged non-overlapping result must be sorted descending by id, highest first");
	TGTestExpectEqualLongLong(&outcome, [merged[1][@"id"] longLongValue], 3,
			"the merged non-overlapping result must be fully sorted, not just per-source-array sorted");
	TGTestExpectEqualLongLong(&outcome, [merged[2][@"id"] longLongValue], 2,
			"the merged non-overlapping result must be fully sorted, not just per-source-array sorted");
	TGTestExpectEqualLongLong(&outcome, [merged[3][@"id"] longLongValue], 1,
			"the lowest id across both arrays must end up last");

	return outcome;
}

TGTestOutcome TGFlattenHistoryTestMergeRawMessagesHandlesOneEmptyArray(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *first = @[ TGFHMessage(2, @"a"), TGFHMessage(1, @"b") ];
	NSArray *second = @[];

	NSArray *merged = TGMergeRawMessages(first, second);

	TGTestExpectEqualInteger(&outcome, merged.count, 2,
			"merging against an empty second array must yield the first array's messages unchanged in count");
	TGTestExpectEqualLongLong(&outcome, [merged[0][@"id"] longLongValue], 2,
			"merging against an empty array must still sort the surviving messages descending by id");
	TGTestExpectEqualLongLong(&outcome, [merged[1][@"id"] longLongValue], 1,
			"merging against an empty array must still sort the surviving messages descending by id");

	NSArray *mergedReversed = TGMergeRawMessages(second, first);

	TGTestExpectEqualInteger(&outcome, mergedReversed.count, 2,
			"merging an empty first array against a populated second array must yield the second array's messages");

	return outcome;
}

TGTestOutcome TGFlattenHistoryTestMergeRawMessagesHandlesBothEmptyArrays(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *merged = TGMergeRawMessages(@[], @[]);

	TGTestExpectTrue(&outcome, merged != nil, "merging two empty arrays must return an array, not nil");
	TGTestExpectEqualInteger(&outcome, merged.count, 0, "merging two empty arrays must return an empty array");

	return outcome;
}

TGTestOutcome TGFlattenHistoryTestOldestFirstReversesWithoutLimit(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *newestFirst = @[ TGFHMessage(30, @"a"), TGFHMessage(20, @"b"), TGFHMessage(10, @"c") ];

	NSArray *oldestFirst = TGHistoryOldestFirst(newestFirst, 0);

	TGTestExpectEqualInteger(&outcome, oldestFirst.count, 3,
			"a limit of zero must mean no boundary limiting, only reversal");
	TGTestExpectEqualLongLong(&outcome, [oldestFirst[0][@"id"] longLongValue], 10,
			"with no limit, the oldest message must come first after reversal");
	TGTestExpectEqualLongLong(&outcome, [oldestFirst[2][@"id"] longLongValue], 30,
			"with no limit, the newest message must come last after reversal");

	return outcome;
}

TGTestOutcome TGFlattenHistoryTestOldestFirstLeavesArrayUnderLimitAlone(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *newestFirst = @[ TGFHMessage(30, @"a"), TGFHMessage(20, @"b"), TGFHMessage(10, @"c") ];

	NSArray *oldestFirst = TGHistoryOldestFirst(newestFirst, 10);

	TGTestExpectEqualInteger(&outcome, oldestFirst.count, 3,
			"a limit larger than the array must not drop any messages");
	TGTestExpectEqualLongLong(&outcome, [oldestFirst[0][@"id"] longLongValue], 10,
			"a limit larger than the array must still reverse to oldest-first order");

	return outcome;
}

TGTestOutcome TGFlattenHistoryTestOldestFirstAtExactlyTheLimit(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *newestFirst = @[ TGFHMessage(30, @"a"), TGFHMessage(20, @"b"), TGFHMessage(10, @"c") ];

	NSArray *oldestFirst = TGHistoryOldestFirst(newestFirst, 3);

	TGTestExpectEqualInteger(&outcome, oldestFirst.count, 3,
			"a limit exactly equal to the array's count must keep every message, not drop the boundary one");
	TGTestExpectEqualLongLong(&outcome, [oldestFirst[0][@"id"] longLongValue], 10,
			"at exactly the limit, the oldest message must still be first after reversal");
	TGTestExpectEqualLongLong(&outcome, [oldestFirst[2][@"id"] longLongValue], 30,
			"at exactly the limit, the newest message must still be last after reversal");

	return outcome;
}

TGTestOutcome TGFlattenHistoryTestOldestFirstPastTheLimit(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *newestFirst = @[ TGFHMessage(50, @"a"), TGFHMessage(40, @"b"), TGFHMessage(30, @"c"),
		TGFHMessage(20, @"d"), TGFHMessage(10, @"e") ];

	NSArray *oldestFirst = TGHistoryOldestFirst(newestFirst, 2);

	TGTestExpectEqualInteger(&outcome, oldestFirst.count, 2,
			"a limit smaller than the array must slice down to that many messages before reversing");
	TGTestExpectEqualLongLong(&outcome, [oldestFirst[0][@"id"] longLongValue], 40,
			"slicing keeps the first `limit` newest-first entries, so after reversal the second-newest message must be first");
	TGTestExpectEqualLongLong(&outcome, [oldestFirst[1][@"id"] longLongValue], 50,
			"slicing keeps the first `limit` newest-first entries, so after reversal the newest message must be last");

	NSArray *oldestFirstOne = TGHistoryOldestFirst(newestFirst, 1);

	TGTestExpectEqualInteger(&outcome, oldestFirstOne.count, 1,
			"a limit of one must slice down to a single, newest message");
	TGTestExpectEqualLongLong(&outcome, [oldestFirstOne[0][@"id"] longLongValue], 50,
			"a limit of one keeps only the newest message from a newest-first array");

	return outcome;
}

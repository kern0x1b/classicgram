#import "tg_booster_page_merge_tests.h"
#import "../../src/Screens/Profile/TGBoosterPageMerge.h"

TGTestOutcome TGBoosterPageMergeTestAppendsTheNextPage(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *first = @[ @{ @"id" : @"a" }, @{ @"id" : @"b" } ];
	NSArray *second = @[ @{ @"id" : @"c" }, @{ @"id" : @"d" } ];
	NSArray *merged = TGBoostersWithPageAppended(first, second);

	TGTestExpectTrue(&outcome, merged.count == 4,
			"the second page joins the first");
	TGTestExpectTrue(&outcome,
			[merged[0][@"id"] isEqualToString:@"a"] && [merged[3][@"id"] isEqualToString:@"d"],
			"the pages keep the order the server sent them in");

	NSArray *overlapping = @[ @{ @"id" : @"b" }, @{ @"id" : @"e" } ];
	NSArray *deduped = TGBoostersWithPageAppended(first, overlapping);
	TGTestExpectTrue(&outcome, deduped.count == 3,
			"a page that repeats a booster adds only what is new");
	TGTestExpectTrue(&outcome, [deduped[2][@"id"] isEqualToString:@"e"],
			"the new booster lands at the end");

	NSArray *unkeyed = @[ @{ @"count" : @2 } ];
	TGTestExpectTrue(&outcome, TGBoostersWithPageAppended(first, unkeyed).count == 3,
			"a booster the server sent without an id is kept rather than dropped");

	return outcome;
}

TGTestOutcome TGBoosterPageMergeTestRefusesPagesThatAddNothing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *first = @[ @{ @"id" : @"a" } ];

	TGTestExpectTrue(&outcome, TGBoostersWithPageAppended(first, @[]) == nil,
			"an empty page means the list has reached its end");
	TGTestExpectTrue(&outcome, TGBoostersWithPageAppended(first, nil) == nil,
			"so does a missing page");
	TGTestExpectTrue(&outcome, TGBoostersWithPageAppended(first, @[ @{ @"id" : @"a" } ]) == nil,
			"a page that only repeats what is shown means the same");
	TGTestExpectTrue(&outcome,
			TGBoostersWithPageAppended(nil, @[ @{ @"id" : @"a" } ]).count == 1,
			"the first page is accepted into an empty list");

	return outcome;
}

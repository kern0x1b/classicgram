#import "tg_owned_set_page_merge_tests.h"
#import "../../src/Screens/Stickers/TGOwnedSetPageMerge.h"

TGTestOutcome TGOwnedSetPageMergeTestAppendsAndDeduplicates(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *first = @[ @{ @"id" : @1101, @"title" : @"Cats" },
		@{ @"id" : @1102, @"title" : @"Dogs" } ];
	NSArray *second = @[ @{ @"id" : @1103, @"title" : @"Birds" } ];
	NSArray *merged = TGOwnedSetsWithPageAppended(first, second);

	TGTestExpectTrue(&outcome, merged.count == 3,
			"the next page of owned sets is appended to the ones already listed");
	TGTestExpectTrue(&outcome, [merged[2][@"title"] isEqualToString:@"Birds"],
			"the newly loaded set lands at the end, in server order");
	TGTestExpectTrue(&outcome,
			TGOwnedSetsWithPageAppended(first, @[ @{ @"id" : @1102, @"title" : @"Dogs" } ]) == nil,
			"a page that only repeats the cursor set ends the paging");
	TGTestExpectTrue(&outcome, TGOwnedSetsWithPageAppended(first, @[]) == nil,
			"so does an empty page");
	TGTestExpectTrue(&outcome, TGOwnedSetsWithPageAppended(nil, second).count == 1,
			"the first page is accepted into an empty list");
	TGTestExpectTrue(&outcome,
			TGOwnedSetsWithPageAppended(first, @[ @{ @"id" : @"1101" } ]) == nil,
			"an id that arrives as a string still matches the set already held");

	return outcome;
}

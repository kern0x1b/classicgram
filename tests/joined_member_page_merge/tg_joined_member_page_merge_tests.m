#import "tg_joined_member_page_merge_tests.h"
#import "../../src/Screens/Profile/TGJoinedMemberPageMerge.h"

TGTestOutcome TGJoinedMemberPageMergeTestAppendsAndDeduplicates(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *first = @[ @{ @"userId" : @11, @"date" : @100 },
		@{ @"userId" : @12, @"date" : @90 } ];
	NSArray *second = @[ @{ @"userId" : @13, @"date" : @80 } ];
	NSArray *merged = TGJoinedMembersWithPageAppended(first, second);

	TGTestExpectTrue(&outcome, merged.count == 3,
			"the next page of joins is appended to the ones already shown");
	TGTestExpectTrue(&outcome, [merged[2][@"userId"] integerValue] == 13,
			"the newly joined member lands at the end, in server order");
	TGTestExpectTrue(&outcome,
			TGJoinedMembersWithPageAppended(first, @[ @{ @"userId" : @12, @"date" : @90 } ]) == nil,
			"a page that only repeats the cursor member ends the paging");
	TGTestExpectTrue(&outcome, TGJoinedMembersWithPageAppended(first, @[]) == nil,
			"so does an empty page");
	TGTestExpectTrue(&outcome,
			TGJoinedMembersWithPageAppended(nil, second).count == 1,
			"the first page is accepted into an empty list");

	return outcome;
}

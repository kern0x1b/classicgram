#import "tg_chat_history_merge_tests.h"
#import "../../src/Screens/Chat/TGChatHistoryMerge.h"

static NSDictionary *TGMergeTestMessage(long long identifier) {
	return @{ @"id" : @(identifier) };
}

TGTestOutcome TGChatHistoryMergeTestPrependsOlderInOrder(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *existing = @[ TGMergeTestMessage(50), TGMergeTestMessage(60) ];
	NSArray *incoming = @[ TGMergeTestMessage(40), TGMergeTestMessage(20), TGMergeTestMessage(30) ];
	NSArray *merged = TGHistoryWithOlderPagePrepended(existing, incoming, 50);

	TGTestExpectTrue(&outcome, merged.count == 5,
			"a page of three older messages joins the two already shown");
	TGTestExpectTrue(&outcome,
			[merged[0][@"id"] longLongValue] == 20 &&
			[merged[1][@"id"] longLongValue] == 30 &&
			[merged[2][@"id"] longLongValue] == 40,
			"the older page arrives oldest first, whatever order the server sent");
	TGTestExpectTrue(&outcome,
			[merged[3][@"id"] longLongValue] == 50 && [merged[4][@"id"] longLongValue] == 60,
			"the messages already on screen keep their order at the end");

	NSArray *withDuplicate = @[ TGMergeTestMessage(45), TGMergeTestMessage(50) ];
	NSArray *deduped = TGHistoryWithOlderPagePrepended(existing, withDuplicate, 50);
	TGTestExpectTrue(&outcome, deduped.count == 3,
			"a page that repeats the anchor adds only what is new");
	TGTestExpectTrue(&outcome, [deduped[0][@"id"] longLongValue] == 45,
			"the one new message lands before the window");

	return outcome;
}

TGTestOutcome TGChatHistoryMergeTestRefusesPagesThatAddNothing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *existing = @[ TGMergeTestMessage(10), TGMergeTestMessage(11) ];

	TGTestExpectTrue(&outcome, TGHistoryWithOlderPagePrepended(existing, @[], 10) == nil,
			"an empty page means the chat has no older messages left");
	TGTestExpectTrue(&outcome,
			TGHistoryWithOlderPagePrepended(existing, @[ TGMergeTestMessage(10) ], 10) == nil,
			"a page holding only the anchor means the same");
	TGTestExpectTrue(&outcome,
			TGHistoryWithOlderPagePrepended(existing, @[ TGMergeTestMessage(99) ], 10) == nil,
			"a page of newer messages is not mistaken for older history");
	TGTestExpectTrue(&outcome,
			TGHistoryWithOlderPagePrepended(existing, @[ @"not a message" ], 10) == nil,
			"a malformed entry is dropped rather than prepended");
	TGTestExpectTrue(&outcome,
			TGHistoryWithOlderPagePrepended(nil, @[ TGMergeTestMessage(5) ], 0).count == 1,
			"an empty window accepts the first page it is given");

	return outcome;
}

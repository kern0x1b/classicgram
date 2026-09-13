#import "tg_chat_positions_tests.h"

#import "../../src/TDLibClient/TGChatPositions.h"

#import <Foundation/Foundation.h>

static NSDictionary *TGTestPosition(NSString *listType, id order, BOOL pinned) {
	return @{
		@"list" : @{@"@type" : listType},
		@"order" : order,
		@"is_pinned" : @(pinned),
	};
}

TGTestOutcome TGChatPositionsTestOrderArrivesAsAString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *positions = @[ TGTestPosition(@"chatListMain", @"7743600000000000000", NO) ];

	TGTestExpectTrue(&outcome, TGMainListOrder(positions) == 7743600000000000000LL,
			"a chat's order is an int64 and TDLib sends it as a string, so reading it as a "
			"number alone would sort the whole chat list by zero");

	NSArray *asNumber = @[ TGTestPosition(@"chatListMain", @(1234567890123LL), NO) ];
	TGTestExpectTrue(&outcome, TGMainListOrder(asNumber) == 1234567890123LL,
			"and a number is read just as well");

	return outcome;
}

TGTestOutcome TGChatPositionsTestEachListHasItsOwnOrder(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *positions = @[
		TGTestPosition(@"chatListArchive", @"99", NO),
		TGTestPosition(@"chatListMain", @"5000", NO),
	];

	TGTestExpectTrue(&outcome, TGMainListOrder(positions) == 5000,
			"the main list takes its own position");
	TGTestExpectTrue(&outcome, TGArchiveOrder(positions) == 99,
			"and the archive takes its own");
	TGTestExpectTrue(&outcome, TGOrderInList(positions, @"chatListFolder") == 0,
			"a list the chat is not in has no order to give");

	return outcome;
}

TGTestOutcome TGChatPositionsTestPinnedIsReadPerList(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *positions = @[
		TGTestPosition(@"chatListMain", @"5000", NO),
		TGTestPosition(@"chatListArchive", @"99", YES),
	];

	TGTestExpectTrue(&outcome, !TGPinnedInMain(positions),
			"a chat pinned in the archive is not pinned in the main list");
	TGTestExpectTrue(&outcome, TGPinnedInArchive(positions),
			"and the archive's own pin is read from the archive's position");

	return outcome;
}

TGTestOutcome TGChatPositionsTestAChatOutOfAListHasNoOrder(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGMainListOrder(@[]) == 0,
			"a chat with no positions at all is in no list");
	TGTestExpectTrue(&outcome, !TGPinnedInMain(@[]),
			"and is pinned nowhere");

	return outcome;
}

TGTestOutcome TGChatPositionsTestMalformedPositionsAreIgnored(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *positions = @[
		@"not a position",
		@{@"list" : @"not a list", @"order" : @"5"},
		TGTestPosition(@"chatListMain", @"42", NO),
	];

	TGTestExpectTrue(&outcome, TGMainListOrder(positions) == 42,
			"a malformed entry is stepped over rather than taken for the answer");
	TGTestExpectTrue(&outcome, TGMainListOrder(nil) == 0,
			"and no positions at all raises nothing");

	return outcome;
}

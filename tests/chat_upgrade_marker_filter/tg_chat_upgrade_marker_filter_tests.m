#import "tg_chat_upgrade_marker_filter_tests.h"
#import "../../src/Screens/Chat/TGChatUpgradeMarkerFilter.h"

TGTestOutcome TGChatUpgradeMarkerFilterTestUpgradeToIsAMarker(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{@"kind" : @"messageChatUpgradeTo", @"id" : @123};
	TGTestExpectTrue(&outcome, TGMessageIsChatUpgradeMarker(message),
			"the basic-group-to-supergroup migration marker must be recognised");

	return outcome;
}

TGTestOutcome TGChatUpgradeMarkerFilterTestUpgradeFromIsAMarker(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{@"kind" : @"messageChatUpgradeFrom", @"id" : @456};
	TGTestExpectTrue(&outcome, TGMessageIsChatUpgradeMarker(message),
			"the new supergroup's migrated-from marker must be recognised");

	return outcome;
}

TGTestOutcome TGChatUpgradeMarkerFilterTestOrdinaryMessageIsNotAMarker(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{@"kind" : @"messageText", @"id" : @789};
	TGTestExpectTrue(&outcome, !TGMessageIsChatUpgradeMarker(message),
			"an ordinary text message must not be treated as a migration marker");

	return outcome;
}

TGTestOutcome TGChatUpgradeMarkerFilterTestNilMessageIsNotAMarker(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGMessageIsChatUpgradeMarker(nil),
			"a nil message (a pure delete notification) must not be treated as a migration marker");

	return outcome;
}

TGTestOutcome TGChatUpgradeMarkerFilterTestArrayWithoutMarkersIsUnchanged(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *messages = @[
		@{@"kind" : @"messageText", @"id" : @1},
		@{@"kind" : @"messagePhoto", @"id" : @2},
	];
	NSArray *filtered = TGMessagesWithChatUpgradeMarkersRemoved(messages);
	TGTestExpectTrue(&outcome, filtered.count == 2,
			"a history page with no migration marker must keep every message");
	TGTestExpectTrue(&outcome, filtered == messages,
			"a history page with no migration marker should not need a copy");

	return outcome;
}

TGTestOutcome TGChatUpgradeMarkerFilterTestArrayDropsUpgradeMarkersOnly(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *messages = @[
		@{@"kind" : @"messageText", @"id" : @1},
		@{@"kind" : @"messageChatUpgradeFrom", @"id" : @2},
		@{@"kind" : @"messageText", @"id" : @3},
		@{@"kind" : @"messageChatUpgradeTo", @"id" : @4},
	];
	NSArray *filtered = TGMessagesWithChatUpgradeMarkersRemoved(messages);
	TGTestExpectTrue(&outcome, filtered.count == 2,
			"both migration markers must be dropped from the displayed history");
	TGTestExpectTrue(&outcome, [filtered[0][@"id"] isEqual:@1] && [filtered[1][@"id"] isEqual:@3],
			"the surviving ordinary messages must keep their original order");

	return outcome;
}

TGTestOutcome TGChatUpgradeMarkerFilterTestEmptyArrayIsUnchanged(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *messages = @[];
	NSArray *filtered = TGMessagesWithChatUpgradeMarkersRemoved(messages);
	TGTestExpectTrue(&outcome, filtered.count == 0,
			"an empty history page must stay empty");

	return outcome;
}

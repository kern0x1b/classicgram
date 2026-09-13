#import "tg_chat_swipe_actions_tests.h"
#import "../../src/Screens/ChatList/TGChatSwipeActions.h"

TGTestOutcome TGChatSwipeActionsTestARowOffersMuteArchiveAndDelete(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *loud = @{ @"id" : @(4242) };
	NSArray *kinds = TGChatSwipeActionKinds(loud, NO, NO, NO);
	TGTestExpectTrue(&outcome, kinds.count == 3 &&
			[kinds[0] isEqualToString:@"mute"] &&
			[kinds[1] isEqualToString:@"archive"] &&
			[kinds[2] isEqualToString:@"delete"],
			"an ordinary row offers mute, archive and delete, in that order");

	NSDictionary *quiet = @{ @"id" : @(4242), @"isMuted" : @YES };
	TGTestExpectTrue(&outcome,
			[TGChatSwipeActionKinds(quiet, NO, NO, NO)[0] isEqualToString:@"unmute"],
			"a muted row offers to unmute instead");

	TGTestExpectTrue(&outcome,
			[TGChatSwipeActionKinds(loud, NO, NO, YES)[1] isEqualToString:@"unarchive"],
			"the archived list offers to bring a chat back rather than archive it again");

	return outcome;
}

TGTestOutcome TGChatSwipeActionsTestRowsThatOfferNothing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *chat = @{ @"id" : @(4242) };
	TGTestExpectTrue(&outcome, TGChatSwipeActionKinds(chat, YES, NO, NO) == nil,
			"a search result is not a row you can swipe: the actions belong to the list it came from");
	TGTestExpectTrue(&outcome, TGChatSwipeActionKinds(chat, NO, YES, NO) == nil,
			"while picking several chats a swipe would fight the selection");
	TGTestExpectTrue(&outcome, TGChatSwipeActionKinds(@{ @"id" : @(0) }, NO, NO, NO) == nil,
			"a row with no chat behind it - a header or a placeholder - offers nothing");
	TGTestExpectTrue(&outcome, TGChatSwipeActionKinds(nil, NO, NO, NO) == nil,
			"and neither does no row at all");

	return outcome;
}

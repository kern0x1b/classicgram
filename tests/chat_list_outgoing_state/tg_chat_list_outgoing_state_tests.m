#import "tg_chat_list_outgoing_state_tests.h"
#import "../../src/Wire/Flatten/TGChatListOutgoingState.h"

TGTestOutcome TGChatListOutgoingStateTestASentMessageShowsItsTick(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *state = TGChatListOutgoingState(@{@"is_outgoing" : @YES}, YES);

	TGTestExpectTrue(&outcome, [state[@"outgoing"] boolValue],
		"a message the server has accepted is drawn with its tick");
	TGTestExpectTrue(&outcome, ![state[@"pending"] boolValue] && ![state[@"failed"] boolValue],
		"a sent message is neither on its way nor failed");

	NSDictionary *inChannel = TGChatListOutgoingState(@{@"is_outgoing" : @YES}, NO);
	TGTestExpectTrue(&outcome, ![inChannel[@"outgoing"] boolValue],
		"a channel post and a saved message have no reader, so no tick is drawn");

	NSDictionary *incoming = TGChatListOutgoingState(@{@"is_outgoing" : @NO}, YES);
	TGTestExpectTrue(&outcome, ![incoming[@"outgoing"] boolValue],
		"someone else's message is not marked as ours");

	NSDictionary *missing = TGChatListOutgoingState(nil, YES);
	TGTestExpectTrue(&outcome, ![missing[@"outgoing"] boolValue] && ![missing[@"pending"] boolValue] && ![missing[@"failed"] boolValue],
		"a chat with no last message reports nothing rather than crashing");

	return outcome;
}

TGTestOutcome TGChatListOutgoingStateTestAMessageOnItsWayIsPendingNotSent(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *state = TGChatListOutgoingState(@{@"is_outgoing" : @YES,
		@"sending_state" : @{@"@type" : @"messageSendingStatePending"}},
		YES);

	TGTestExpectTrue(&outcome, [state[@"pending"] boolValue],
		"a message still on its way shows the pending indicator");
	TGTestExpectTrue(&outcome, ![state[@"outgoing"] boolValue],
		"it must not also claim to be delivered");
	TGTestExpectTrue(&outcome, ![state[@"failed"] boolValue], "and it has not failed");

	NSDictionary *theirs = TGChatListOutgoingState(@{@"is_outgoing" : @NO,
		@"sending_state" : @{@"@type" : @"messageSendingStatePending"}},
		YES);
	TGTestExpectTrue(&outcome, ![theirs[@"pending"] boolValue],
		"a sending state on a message that is not ours changes nothing");

	return outcome;
}

TGTestOutcome TGChatListOutgoingStateTestAFailedMessageIsFailedOnly(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *state = TGChatListOutgoingState(@{@"is_outgoing" : @YES,
		@"sending_state" : @{@"@type" : @"messageSendingStateFailed", @"can_retry" : @YES}},
		YES);

	TGTestExpectTrue(&outcome, [state[@"failed"] boolValue],
		"a message the server refused is reported as failed, which is what puts the badge in the row");
	TGTestExpectTrue(&outcome, ![state[@"pending"] boolValue],
		"a failed message is not still on its way");
	TGTestExpectTrue(&outcome, ![state[@"outgoing"] boolValue],
		"and it is certainly not delivered");

	NSDictionary *unknownState = TGChatListOutgoingState(@{@"is_outgoing" : @YES,
		@"sending_state" : @{@"@type" : @"messageSendingStateSomethingNew"}},
		YES);
	TGTestExpectTrue(&outcome, [unknownState[@"pending"] boolValue] && ![unknownState[@"failed"] boolValue],
		"a sending state this build does not know is treated as still on its way, not as a failure");

	return outcome;
}

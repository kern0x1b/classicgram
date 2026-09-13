#import "TGChatListOutgoingState.h"

NSDictionary *TGChatListOutgoingState(NSDictionary *lastMessage, BOOL hasReader) {
	NSDictionary *message = [lastMessage isKindOfClass:[NSDictionary class]] ? lastMessage : nil;
	NSDictionary *sendingState = [message[@"sending_state"] isKindOfClass:[NSDictionary class]]
		? message[@"sending_state"]
		: nil;
	NSString *sendingStateType = [sendingState[@"@type"] isKindOfClass:[NSString class]]
		? sendingState[@"@type"]
		: @"";
	BOOL isOutgoing = [message[@"is_outgoing"] boolValue];
	BOOL failed = isOutgoing && [sendingStateType isEqualToString:@"messageSendingStateFailed"];
	BOOL pending = isOutgoing && !failed && sendingState != nil;

	return @{
		@"outgoing" : @(isOutgoing && hasReader && sendingState == nil),
		@"pending" : @(pending),
		@"failed" : @(failed),
	};
}

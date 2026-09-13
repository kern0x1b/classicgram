#import "TGChatUpgradeMarkerFilter.h"

BOOL TGMessageIsChatUpgradeMarker(NSDictionary *message) {
	NSString *kind = message[@"kind"];
	return [kind isEqualToString:@"messageChatUpgradeTo"] ||
		[kind isEqualToString:@"messageChatUpgradeFrom"];
}

NSArray *TGMessagesWithChatUpgradeMarkersRemoved(NSArray *messages) {
	if (!messages.count)
		return messages;

	BOOL anyMarker = NO;
	for (NSDictionary *message in messages) {
		if (TGMessageIsChatUpgradeMarker(message)) {
			anyMarker = YES;
			break;
		}
	}
	if (!anyMarker)
		return messages;

	NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:messages.count];
	for (NSDictionary *message in messages)
		if (!TGMessageIsChatUpgradeMarker(message))
			[filtered addObject:message];
	return filtered;
}

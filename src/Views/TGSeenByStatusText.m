#import "TGSeenByStatusText.h"
#import "TGLocalization.h"

NSString *TGSeenByStatusText(NSString *unavailableReason) {
	if ([unavailableReason isEqualToString:@"tooOld"])
		return TGL(@"Chat.SeenByTooOld",
			@"The list of viewers is no longer available for old messages");
	if ([unavailableReason isEqualToString:@"chatTooBig"])
		return TGL(@"Chat.SeenByChatTooBig", @"The list of viewers isn't available in large groups");
	if ([unavailableReason isKindOfClass:[NSString class]] && unavailableReason.length > 0)
		return TGL(@"Chat.SeenByUnavailable", @"The list of viewers isn't available");
	return TGL(@"Conversation.ContextMenuNoViews", @"Nobody Viewed");
}

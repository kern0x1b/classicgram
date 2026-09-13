#import "TGChatListPreviewAuthor.h"

NSString *TGChatListPreviewWithAuthor(NSString *text, BOOL isGroup, BOOL isOutgoing,
	BOOL isChannelPost, NSString *authorName, NSString *youText) {
	NSString *preview = [text isKindOfClass:[NSString class]] ? text : @"";
	if (!isGroup || isChannelPost)
		return preview;

	NSString *who = isOutgoing ? youText : authorName;
	if (![who isKindOfClass:[NSString class]] || who.length == 0)
		return preview;
	return [NSString stringWithFormat:@"%@: %@", who, preview];
}

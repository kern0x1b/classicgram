#import "TGMessageReply.h"

NSDictionary *TGReplyToDictionary(int64_t replyToId, NSString *quoteText, NSArray *quoteWireEntities,
	NSInteger quotePosition) {
	if (replyToId == 0)
		return nil;
	NSMutableDictionary *replyTo = [@{
		@"@type" : @"inputMessageReplyToMessage",
		@"message_id" : @(replyToId),
	} mutableCopy];
	if (![quoteText isKindOfClass:[NSString class]] || quoteText.length == 0)
		return replyTo;
	NSMutableDictionary *text = [@{@"@type" : @"formattedText", @"text" : quoteText} mutableCopy];
	if ([quoteWireEntities isKindOfClass:[NSArray class]] && [quoteWireEntities count] > 0)
		text[@"entities"] = quoteWireEntities;
	replyTo[@"quote"] = @{@"@type" : @"inputTextQuote",
		@"text" : text,
		@"position" : @((int32_t)quotePosition)};
	return replyTo;
}

#import "TGQuickReplyTrigger.h"

static BOOL TGQuickReplyNameCharacter(unichar c) {
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
		(c >= '0' && c <= '9') || c == '_';
}

NSRange TGQuickReplyTriggerRangeInText(NSString *text, NSUInteger caret) {
	if (![text isKindOfClass:NSString.class] || !text.length)
		return NSMakeRange(NSNotFound, 0);
	if ([text characterAtIndex:0] != '/')
		return NSMakeRange(NSNotFound, 0);
	NSUInteger end = 1;
	while (end < text.length && TGQuickReplyNameCharacter([text characterAtIndex:end]))
		end++;
	if (end < text.length)
		return NSMakeRange(NSNotFound, 0);
	if (caret == 0 || caret > end)
		return NSMakeRange(NSNotFound, 0);
	return NSMakeRange(0, end);
}

NSArray *TGQuickReplyMatches(NSArray *shortcuts, NSString *query) {
	if (![shortcuts isKindOfClass:NSArray.class])
		return @[];
	NSString *needle = [query isKindOfClass:NSString.class] ? query : @"";
	NSMutableArray *matches = [NSMutableArray array];
	for (id entry in shortcuts) {
		if (![entry isKindOfClass:NSDictionary.class])
			continue;
		NSString *name = ((NSDictionary *)entry)[@"name"];
		if (![name isKindOfClass:NSString.class] || !name.length)
			continue;
		if (!needle.length) {
			[matches addObject:entry];
			continue;
		}
		if (name.length < needle.length)
			continue;
		NSRange prefix = NSMakeRange(0, needle.length);
		if ([[name substringWithRange:prefix] caseInsensitiveCompare:needle] == NSOrderedSame)
			[matches addObject:entry];
	}
	return matches;
}

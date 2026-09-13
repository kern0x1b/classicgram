#import "TGMentionTrigger.h"

static BOOL TGMentionCharIsWordChar(unichar c) {
	if (c == '_')
		return YES;
	return [[NSCharacterSet alphanumericCharacterSet] characterIsMember:c];
}

NSRange TGMentionTriggerRangeInText(NSString *text, NSUInteger caret) {
	NSInteger length = text.length;
	if (caret > length)
		caret = length;

	NSCharacterSet *space = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSInteger cursor = caret;
	while (cursor > 0) {
		unichar c = [text characterAtIndex:cursor - 1];
		if (c == '@') {
			NSInteger atIndex = cursor - 1;
			if (atIndex > 0) {
				unichar before = [text characterAtIndex:atIndex - 1];
				if (![space characterIsMember:before])
					return NSMakeRange(NSNotFound, 0);
			}
			return NSMakeRange(atIndex, caret - atIndex);
		}
		if (!TGMentionCharIsWordChar(c))
			return NSMakeRange(NSNotFound, 0);
		cursor--;
	}
	return NSMakeRange(NSNotFound, 0);
}

NSRange TGInlineBotUsernameRangeInText(NSString *text) {
	NSInteger length = text.length;
	if (length < 2 || [text characterAtIndex:0] != '@')
		return NSMakeRange(NSNotFound, 0);

	NSInteger end = 1;
	while (end < length && TGMentionCharIsWordChar([text characterAtIndex:end]))
		end++;
	if (end == 1)
		return NSMakeRange(NSNotFound, 0);

	return NSMakeRange(1, end - 1);
}

NSRange TGInlineBotQueryRangeInText(NSString *text, NSUInteger caret) {
	NSInteger length = text.length;
	if (caret > length)
		caret = length;

	NSRange usernameRange = TGInlineBotUsernameRangeInText(text);
	if (usernameRange.location == NSNotFound)
		return NSMakeRange(NSNotFound, 0);

	NSInteger usernameEnd = NSMaxRange(usernameRange);
	if (usernameEnd >= length || [text characterAtIndex:usernameEnd] != ' ')
		return NSMakeRange(NSNotFound, 0);

	NSInteger queryStart = usernameEnd + 1;
	NSRange searchRange = NSMakeRange(queryStart, length - queryStart);
	NSRange newline = [text rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]
											 options:0
											   range:searchRange];
	NSInteger queryEnd = (newline.location == NSNotFound) ? length : newline.location;

	if (caret < queryStart || caret > queryEnd)
		return NSMakeRange(NSNotFound, 0);

	return NSMakeRange(queryStart, queryEnd - queryStart);
}

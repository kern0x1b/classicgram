#import "TGProxyLinkInText.h"

NSString *TGProxyLinkInText(NSString *text) {
	if (![text isKindOfClass:[NSString class]])
		return nil;
	NSString *trimmed = [text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (trimmed.length < 8 || trimmed.length > 2048)
		return nil;
	NSArray *needles = [NSArray arrayWithObjects:@"tg://proxy", @"tg://socks",
		@"t.me/proxy", @"t.me/socks", @"telegram.me/proxy", @"telegram.me/socks", nil];
	NSCharacterSet *labelChars = [NSCharacterSet characterSetWithCharactersInString:
			@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"];
	for (NSString *needle in needles) {
		NSUInteger searchFrom = 0;
		while (searchFrom < trimmed.length) {
			NSRange searchRange = NSMakeRange(searchFrom, trimmed.length - searchFrom);
			NSRange range = [trimmed rangeOfString:needle options:NSCaseInsensitiveSearch range:searchRange];
			if (range.location == NSNotFound)
				break;
			if (range.location > 0 &&
					[labelChars characterIsMember:[trimmed characterAtIndex:range.location - 1]]) {
				searchFrom = range.location + 1;
				continue;
			}
			NSString *tail = [trimmed substringFromIndex:range.location];
			NSRange space = [tail rangeOfCharacterFromSet:
					[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if (space.location != NSNotFound)
				tail = [tail substringToIndex:space.location];
			return tail;
		}
	}
	return nil;
}

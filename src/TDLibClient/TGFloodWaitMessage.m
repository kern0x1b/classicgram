#import "TGFloodWaitMessage.h"

NSInteger TGFloodWaitSecondsFromMessage(NSString *message) {
	if (![message isKindOfClass:NSString.class])
		return -1;
	NSRange range = [message rangeOfString:@"retry after " options:NSCaseInsensitiveSearch];
	if (range.location == NSNotFound)
		return -1;
	NSString *tail = [message substringFromIndex:range.location + range.length];
	NSScanner *scanner = [NSScanner scannerWithString:tail];
	NSInteger seconds = 0;
	if (![scanner scanInteger:&seconds])
		return -1;
	return seconds > 0 ? seconds : -1;
}

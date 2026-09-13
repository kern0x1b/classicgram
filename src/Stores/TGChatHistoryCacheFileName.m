#import "TGChatHistoryCacheFileName.h"

NSString *TGChatHistoryCacheFileName(NSString *accountScope) {
	if (![accountScope isKindOfClass:[NSString class]] || !accountScope.length)
		return @"chat-history.plist";

	NSMutableString *safe = [NSMutableString stringWithCapacity:accountScope.length];
	NSCharacterSet *allowed = [NSCharacterSet alphanumericCharacterSet];
	for (NSUInteger index = 0; index < accountScope.length; index++) {
		unichar character = [accountScope characterAtIndex:index];
		[safe appendString:[allowed characterIsMember:character]
				? [NSString stringWithCharacters:&character length:1]
				: @"-"];
	}
	return [NSString stringWithFormat:@"chat-history-%@.plist", safe];
}

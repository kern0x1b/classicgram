#import "TGInternalLinkUsername.h"

NSString *TGUsernameInInternalPublicChatLink(NSString *url) {
	if (![url isKindOfClass:[NSString class]])
		return nil;
	NSString *prefix = @"tg://resolve?domain=";
	if (![url hasPrefix:prefix])
		return nil;
	NSString *rest = [url substringFromIndex:prefix.length];
	NSRange separator = [rest rangeOfString:@"&"];
	if (separator.location != NSNotFound)
		rest = [rest substringToIndex:separator.location];
	return rest.length ? rest : nil;
}

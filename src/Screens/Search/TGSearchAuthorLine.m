#import "TGSearchAuthorLine.h"

BOOL TGSearchResultShowsAuthorLine(NSString *chatTitle, NSString *senderName, BOOL outgoing, BOOL scopedToOneChat) {
	if (scopedToOneChat)
		return NO;
	if (outgoing)
		return YES;
	if (![senderName isKindOfClass:[NSString class]] || !senderName.length)
		return NO;
	if (![chatTitle isKindOfClass:[NSString class]] || !chatTitle.length)
		return NO;
	return ![senderName isEqualToString:chatTitle];
}

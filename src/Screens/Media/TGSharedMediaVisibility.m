#import "TGSharedMediaVisibility.h"

#import "TGDisappearingMedia.h"

BOOL TGSharedMediaShowsContent(NSDictionary *content) {
	if (![content isKindOfClass:[NSDictionary class]])
		return NO;
	return !TGMediaContentDisappears(content);
}

BOOL TGSharedMediaShowsMessage(NSDictionary *message) {
	if (![message isKindOfClass:[NSDictionary class]])
		return NO;
	if (![message[@"content"] isKindOfClass:[NSDictionary class]])
		return NO;
	return !TGMessageDisappears(message);
}

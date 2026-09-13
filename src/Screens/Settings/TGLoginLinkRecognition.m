#import "TGLoginLinkRecognition.h"

BOOL TGTextIsLoginConfirmationLink(NSString *text) {
	static NSString *const kLoginTokenPrefix = @"tg://login?token=";

	if (![text isKindOfClass:[NSString class]] || text.length < kLoginTokenPrefix.length)
		return NO;

	NSString *head = [text substringToIndex:kLoginTokenPrefix.length];
	return [head caseInsensitiveCompare:kLoginTokenPrefix] == NSOrderedSame;
}

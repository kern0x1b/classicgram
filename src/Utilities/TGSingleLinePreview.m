#import "TGSingleLinePreview.h"

NSString *TGSingleLinePreviewText(NSString *text) {
	if (![text isKindOfClass:[NSString class]] || !text.length)
		return text;

	NSCharacterSet *breaks = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSMutableString *out = [NSMutableString stringWithCapacity:text.length];
	BOOL pendingSpace = NO;
	NSUInteger length = text.length;
	for (NSUInteger index = 0; index < length; index++) {
		unichar unit = [text characterAtIndex:index];
		if ([breaks characterIsMember:unit]) {
			pendingSpace = out.length > 0;
			continue;
		}
		if (pendingSpace) {
			[out appendString:@" "];
			pendingSpace = NO;
		}
		[out appendFormat:@"%C", unit];
	}
	return [out copy];
}

#import "TGClockMarker.h"

static BOOL TGClockMarkerMatches(NSString *text, NSString *symbol) {
	if (![symbol isKindOfClass:[NSString class]] || !symbol.length)
		return NO;
	if (text.length <= symbol.length)
		return NO;
	NSString *tail = [text substringFromIndex:text.length - symbol.length];
	return [tail caseInsensitiveCompare:symbol] == NSOrderedSame;
}

NSString *TGClockMarkerInTime(NSString *text, NSString *amSymbol, NSString *pmSymbol) {
	if (![text isKindOfClass:[NSString class]] || !text.length)
		return nil;
	if (TGClockMarkerMatches(text, amSymbol))
		return amSymbol;
	if (TGClockMarkerMatches(text, pmSymbol))
		return pmSymbol;
	return nil;
}

NSString *TGTimeWithoutClockMarker(NSString *text, NSString *marker) {
	if (![text isKindOfClass:[NSString class]] || !marker.length)
		return text;
	if (text.length <= marker.length)
		return text;
	NSString *head = [text substringToIndex:text.length - marker.length];
	return [head stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceCharacterSet]];
}

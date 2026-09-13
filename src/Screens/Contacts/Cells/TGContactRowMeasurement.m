#import "TGContactRowMeasurement.h"

BOOL TGContactRowMeasurementIsFresh(NSString *cachedText,
	CGFloat cachedFontSize,
	CGFloat cachedHeight,
	CGFloat cachedLimit,
	NSString *text,
	CGFloat fontSize,
	CGFloat height,
	CGFloat limit) {
	if (cachedFontSize != fontSize || cachedHeight != height || cachedLimit != limit)
		return NO;
	if (cachedText == text)
		return YES;
	if (!cachedText || !text)
		return NO;
	return [cachedText isEqualToString:text];
}

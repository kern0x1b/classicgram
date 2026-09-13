#import "TGWebBrowserExceptionURL.h"

NSString *TGWebBrowserNormalizeExceptionURL(NSString *entered) {
	if (![entered isKindOfClass:[NSString class]])
		return @"";
	NSString *trimmed = [entered stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!trimmed.length)
		return @"";
	NSString *lower = trimmed.lowercaseString;
	if ([lower hasPrefix:@"http://"] || [lower hasPrefix:@"https://"])
		return trimmed;
	return [@"https://" stringByAppendingString:trimmed];
}

#import "TGTranslationLanguageCode.h"

static NSDictionary *TGTranslationLanguageCodeOverrides(void) {
	return @{
		@"nb" : @"no",
		@"nn" : @"no",
		@"fil" : @"tl",
		@"haw" : @"haw",
		@"ceb" : @"ceb",
		@"hmn" : @"hmn",
	};
}

NSString *TGTranslationLanguageCodeForLocaleIdentifier(NSString *localeIdentifier) {
	if (![localeIdentifier isKindOfClass:[NSString class]] || !localeIdentifier.length)
		return @"en";

	NSString *primary = localeIdentifier;
	NSRange dash = [localeIdentifier rangeOfString:@"-"];
	if (dash.location != NSNotFound)
		primary = [localeIdentifier substringToIndex:dash.location];

	NSString *lowered = primary.lowercaseString;
	NSString *mapped = TGTranslationLanguageCodeOverrides()[lowered];
	if (mapped.length)
		return mapped;

	if (lowered.length >= 2)
		return [lowered substringToIndex:2];

	return @"en";
}

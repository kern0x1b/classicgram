#import "TGStringTruncation.h"

NSString *TGSafeSubstringToIndex(NSString *string, NSUInteger index) {
	if (![string isKindOfClass:[NSString class]])
		return string;
	if (index >= string.length)
		return string;
	NSRange sequence = [string rangeOfComposedCharacterSequenceAtIndex:index];
	NSUInteger safeIndex = sequence.location == index ? index : sequence.location;
	return [string substringToIndex:safeIndex];
}

NSString *TGSafeSubstringFromIndex(NSString *string, NSUInteger index) {
	if (![string isKindOfClass:[NSString class]])
		return string;
	if (index == 0)
		return string;
	if (index >= string.length)
		return @"";
	NSRange sequence = [string rangeOfComposedCharacterSequenceAtIndex:index];
	NSUInteger safeIndex = sequence.location == index ? index : NSMaxRange(sequence);
	if (safeIndex >= string.length)
		return @"";
	return [string substringFromIndex:safeIndex];
}

NSString *TGSafeFirstCharacter(NSString *string) {
	if (![string isKindOfClass:[NSString class]] || !string.length)
		return @"";
	NSRange first = [string rangeOfComposedCharacterSequenceAtIndex:0];
	return [string substringWithRange:first];
}

static NSString *TGStringWithFirstCharacter(NSString *string, BOOL uppercased) {
	if (![string isKindOfClass:[NSString class]] || !string.length)
		return string;
	NSRange first = [string rangeOfComposedCharacterSequenceAtIndex:0];
	NSString *head = [string substringWithRange:first];
	head = uppercased ? [head uppercaseString] : [head lowercaseString];
	return [head stringByAppendingString:[string substringFromIndex:NSMaxRange(first)]];
}

NSString *TGStringWithFirstCharacterUppercased(NSString *string) {
	return TGStringWithFirstCharacter(string, YES);
}

NSString *TGStringWithFirstCharacterLowercased(NSString *string) {
	return TGStringWithFirstCharacter(string, NO);
}

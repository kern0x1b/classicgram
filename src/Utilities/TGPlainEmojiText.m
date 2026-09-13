#import "TGPlainEmojiText.h"

static BOOL TGEmojiModifierIsInvisibleOnThisSystem(uint32_t codePoint) {
	if (codePoint == 0xFE0E || codePoint == 0xFE0F || codePoint == 0x200D)
		return YES;
	if (codePoint >= 0x1F3FB && codePoint <= 0x1F3FF)
		return YES;
	if (codePoint >= 0xE0020 && codePoint <= 0xE007F)
		return YES;
	return NO;
}

NSString *TGTextWithoutInvisibleEmojiModifiers(NSString *text) {
	if (![text isKindOfClass:[NSString class]] || !text.length)
		return text;

	NSMutableString *kept = nil;
	NSUInteger length = text.length;
	NSUInteger index = 0;
	while (index < length) {
		unichar unit = [text characterAtIndex:index];
		uint32_t codePoint = unit;
		NSUInteger unitCount = 1;
		if (CFStringIsSurrogateHighCharacter(unit) && index + 1 < length) {
			unichar low = [text characterAtIndex:index + 1];
			if (CFStringIsSurrogateLowCharacter(low)) {
				codePoint = (uint32_t)CFStringGetLongCharacterForSurrogatePair(unit, low);
				unitCount = 2;
			}
		}
		if (TGEmojiModifierIsInvisibleOnThisSystem(codePoint)) {
			if (!kept)
				kept = [[text substringToIndex:index] mutableCopy];
		} else if (kept) {
			[kept appendString:[text substringWithRange:NSMakeRange(index, unitCount)]];
		}
		index += unitCount;
	}
	return kept ? [kept copy] : text;
}

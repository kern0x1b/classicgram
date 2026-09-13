#import "TGTextSelectionWordRange.h"

NSRange TGTextSelectionWordRangeInText(NSString *text, NSUInteger index) {
	NSInteger length = text.length;
	if (!length)
		return NSMakeRange(0, 0);
	if (index >= (NSUInteger)length)
		index = length - 1;

	NSRange charRange = [text rangeOfComposedCharacterSequenceAtIndex:index];

	NSCharacterSet *word = [NSCharacterSet alphanumericCharacterSet];
	BOOL onWord = [word characterIsMember:[text characterAtIndex:charRange.location]];

	NSInteger start = charRange.location;
	NSInteger end = charRange.location + charRange.length;
	if (onWord) {
		while (start > 0) {
			NSRange previous = [text rangeOfComposedCharacterSequenceAtIndex:start - 1];
			if (![word characterIsMember:[text characterAtIndex:previous.location]])
				break;
			start = previous.location;
		}
		while (end < length) {
			NSRange next = [text rangeOfComposedCharacterSequenceAtIndex:end];
			if (![word characterIsMember:[text characterAtIndex:next.location]])
				break;
			end = next.location + next.length;
		}
	}
	return NSMakeRange(start, end - start);
}

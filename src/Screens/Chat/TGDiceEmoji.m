#import "TGDiceEmoji.h"

BOOL TGComposerTextIsSendableDiceEmoji(NSString *text) {
	static NSSet *diceEmoji;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		diceEmoji = [NSSet setWithObjects:
			@"\U0001F3B2",
			@"\U0001F3AF",
			@"\U0001F3C0",
			@"\U000026BD",
			@"\U000026BD\U0000FE0F",
			@"\U0001F3B0",
			@"\U0001F3B3", nil];
	});
	return [text isKindOfClass:[NSString class]] && [diceEmoji containsObject:text];
}

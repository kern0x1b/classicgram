#import "tg_plain_emoji_text_tests.h"
#import "../../src/Utilities/TGPlainEmojiText.h"

TGTestOutcome TGPlainEmojiTextTestDropsWhatTheSystemCannotDraw(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *withSkinTone = @"Ivan \U0001F476\U0001F3FB";
	TGTestExpectTrue(&outcome,
			[TGTextWithoutInvisibleEmojiModifiers(withSkinTone) isEqualToString:@"Ivan \U0001F476"],
			"a skin-tone modifier is dropped, since iOS 6 draws it as an empty box");

	NSString *withSelector = @"❤️";
	TGTestExpectTrue(&outcome,
			[TGTextWithoutInvisibleEmojiModifiers(withSelector) isEqualToString:@"❤"],
			"a variation selector is dropped and the heart itself is kept");

	NSString *family = @"\U0001F468‍\U0001F469‍\U0001F467";
	TGTestExpectTrue(&outcome,
			[TGTextWithoutInvisibleEmojiModifiers(family) isEqualToString:@"\U0001F468\U0001F469\U0001F467"],
			"the joiners in a sequence go, the people in it stay");

	TGTestExpectTrue(&outcome,
			[TGTextWithoutInvisibleEmojiModifiers(@"Alexander") isEqualToString:@"Alexander"],
			"plain text comes back as the same string");
	TGTestExpectTrue(&outcome, [TGTextWithoutInvisibleEmojiModifiers(@"") isEqualToString:@""],
			"an empty name stays empty");
	TGTestExpectTrue(&outcome, TGTextWithoutInvisibleEmojiModifiers(nil) == nil,
			"a missing name stays missing");
	TGTestExpectTrue(&outcome,
			[TGTextWithoutInvisibleEmojiModifiers(@"\U0001F476") isEqualToString:@"\U0001F476"],
			"an emoji with nothing attached to it is untouched");

	return outcome;
}

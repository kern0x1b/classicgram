#import "tg_sticker_tab_title_tests.h"

#import "../../src/Views/TGStickerTabTitle.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGStickerTabTitleTestShortTitleIsLeftAlone(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGStickerTabTitle(@"Fav") isEqualToString:@"Fav"],
			"a title already three units long keeps the case the panel gave it");

	return outcome;
}

TGTestOutcome TGStickerTabTitleTestLongAsciiTitleIsCutAndUppercased(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGStickerTabTitle(@"Recent") isEqualToString:@"REC"],
			"a longer title is cut to three characters and shown in capitals");

	return outcome;
}

TGTestOutcome TGStickerTabTitleTestEmojiTitleKeepsWholeGlyphs(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *smile = [[NSString alloc] initWithUTF8String:"\xF0\x9F\x98\x80"];
	NSString *title = [smile stringByAppendingString:@"Cats"];
	NSString *result = TGStickerTabTitle(title);

	TGTestExpectTrue(&outcome, [result isEqualToString:[smile stringByAppendingString:@"C"]],
			"a set whose title starts with an emoji keeps the whole emoji and the letter after it");
	TGTestExpectTrue(&outcome, result.length == 3,
			"the cut still uses the three units the tab was measured for");

	return outcome;
}

TGTestOutcome TGStickerTabTitleTestEmojiOnlyTitleIsNeverHalfAGlyph(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *smile = [[NSString alloc] initWithUTF8String:"\xF0\x9F\x98\x80"];
	NSString *title = [smile stringByAppendingString:smile];
	NSString *result = TGStickerTabTitle(title);

	TGTestExpectTrue(&outcome, [result isEqualToString:smile],
			"two emoji are four units, so the three-unit cut drops the second one whole "
			"rather than leaving half a surrogate pair on the tab");
	TGTestExpectTrue(&outcome, result.length == 2,
			"nothing unpaired survives the cut");

	return outcome;
}

TGTestOutcome TGStickerTabTitleTestMissingTitleIsEmpty(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGStickerTabTitle(nil) isEqualToString:@""],
			"a set with no title at all gives an empty tab rather than raising");

	return outcome;
}

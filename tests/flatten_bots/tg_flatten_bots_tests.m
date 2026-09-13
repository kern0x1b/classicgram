#import "tg_flatten_bots_tests.h"
#import "../../src/Wire/Flatten/TGFlattenBots.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenBotsTestFileIdOfPhotoLastSizeWinsOverLargerEarlierSize(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *photo = @{
		@"sizes" : @[
			@{@"type" : @"y", @"width" : @1280, @"height" : @960,
				@"photo" : @{@"@type" : @"file", @"id" : @999}},
			@{@"type" : @"m", @"width" : @320, @"height" : @240,
				@"photo" : @{@"@type" : @"file", @"id" : @111}},
		],
	};

	NSNumber *fileId = TGBFileIdOfPhoto(photo);

	TGTestExpectTrue(&outcome, fileId != nil,
			"a photo with multiple sizes must resolve to a file id, not nil");
	TGTestExpectEqualLongLong(&outcome, [fileId longLongValue], 111,
			"the scan must keep whichever size entry came last in the array, even though an earlier entry describes a physically larger size - this is a last-wins scan, not a largest-wins one");

	return outcome;
}

TGTestOutcome TGFlattenBotsTestFileIdOfPhotoSingleSize(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *photo = @{
		@"sizes" : @[
			@{@"type" : @"x", @"photo" : @{@"@type" : @"file", @"id" : @555}},
		],
	};

	NSNumber *fileId = TGBFileIdOfPhoto(photo);

	TGTestExpectTrue(&outcome, fileId != nil,
			"a photo with a single size must resolve to that size's file id");
	TGTestExpectEqualLongLong(&outcome, [fileId longLongValue], 555,
			"the single size's own file id must round-trip unchanged");

	return outcome;
}

TGTestOutcome TGFlattenBotsTestFileIdOfPhotoEmptyOrMissingSizesReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGBFileIdOfPhoto(@{@"sizes" : @[]}) == nil,
			"a photo with an empty sizes array must resolve to nil, not crash");
	TGTestExpectTrue(&outcome, TGBFileIdOfPhoto(@{}) == nil,
			"a photo dictionary with no sizes key at all must resolve to nil");
	TGTestExpectTrue(&outcome, TGBFileIdOfPhoto(nil) == nil,
			"a nil photo must resolve to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenBotsTestMarkupComposesFromRealisticPayload(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *inlineMarkup = @{
		@"@type" : @"replyMarkupInlineKeyboard",
		@"rows" : @[
			@[@{@"text" : @"Open", @"type" : @{@"@type" : @"inlineKeyboardButtonTypeUrl", @"url" : @"https://example.com"}}],
		],
	};
	NSDictionary *messageWithSnakeCaseKey = @{
		@"@type" : @"message",
		@"reply_markup" : inlineMarkup,
	};
	NSDictionary *messageWithCamelCaseKey = @{
		@"@type" : @"message",
		@"replyMarkup" : inlineMarkup,
	};

	TGTestExpectTrue(&outcome, [TGBMarkup(messageWithSnakeCaseKey) isEqual:inlineMarkup],
			"a message with a snake_case reply_markup key must resolve to that markup dictionary");
	TGTestExpectTrue(&outcome, [TGBMarkup(messageWithCamelCaseKey) isEqual:inlineMarkup],
			"a message with only the camelCase replyMarkup key must fall back to it");

	return outcome;
}

TGTestOutcome TGFlattenBotsTestMarkupReturnsNilForNonDictionaryOrMissingKeys(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGBMarkup(nil) == nil,
			"a nil message must resolve to nil markup, not crash");
	TGTestExpectTrue(&outcome, TGBMarkup((NSDictionary *)@"not a dictionary") == nil,
			"a non-dictionary message must resolve to nil markup, not crash");
	TGTestExpectTrue(&outcome, TGBMarkup(@{@"@type" : @"message"}) == nil,
			"a message with neither reply_markup nor replyMarkup must resolve to nil markup");

	return outcome;
}

TGTestOutcome TGFlattenBotsTestFileIdOfThumbnailPresentAndAbsent(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *withThumbnail = @{
		@"thumbnail" : @{@"@type" : @"thumbnail",
			@"file" : @{@"@type" : @"file", @"id" : @42}},
	};

	NSNumber *fileId = TGBFileIdOfThumbnail(withThumbnail);
	TGTestExpectTrue(&outcome, fileId != nil,
			"an owner with a well-formed thumbnail must resolve to a file id");
	TGTestExpectEqualLongLong(&outcome, [fileId longLongValue], 42,
			"the thumbnail's file id must round-trip unchanged");

	TGTestExpectTrue(&outcome, TGBFileIdOfThumbnail(@{}) == nil,
			"an owner with no thumbnail key must resolve to nil");
	TGTestExpectTrue(&outcome, TGBFileIdOfThumbnail(@{@"thumbnail" : @{}}) == nil,
			"a thumbnail with no file key must resolve to nil");
	TGTestExpectTrue(&outcome, TGBFileIdOfThumbnail(nil) == nil,
			"a nil owner must resolve to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenBotsTestFileIdOfDocumentPresentAndAbsent(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *withDocument = @{
		@"document" : @{@"@type" : @"file", @"id" : @77},
	};

	NSNumber *fileId = TGBFileIdOfDocument(withDocument, @"document");
	TGTestExpectTrue(&outcome, fileId != nil,
			"an owner with a well-formed document file must resolve to a file id");
	TGTestExpectEqualLongLong(&outcome, [fileId longLongValue], 77,
			"the document's file id must round-trip unchanged");

	TGTestExpectTrue(&outcome, TGBFileIdOfDocument(@{}, @"document") == nil,
			"an owner missing the given key must resolve to nil");
	TGTestExpectTrue(&outcome, TGBFileIdOfDocument(withDocument, @"sticker") == nil,
			"looking up the wrong key must resolve to nil even though the owner has a document under another key");
	TGTestExpectTrue(&outcome, TGBFileIdOfDocument(nil, @"document") == nil,
			"a nil owner must resolve to nil, not crash");

	return outcome;
}

#import "tg_flatten_stickers_tests.h"
#import "../../src/Wire/Flatten/TGFlattenStickers.h"
#import <Foundation/Foundation.h>

static NSDictionary *TGFlattenStickersTestBuildSticker(NSInteger fileId) {
	return @{
		@"@type" : @"sticker",
		@"set_id" : @10,
		@"emoji" : @"\U0001F600",
		@"width" : @512,
		@"height" : @512,
		@"format" : @{@"@type" : @"stickerFormatWebp"},
		@"full_type" : @{@"@type" : @"stickerFullTypeRegular"},
		@"sticker" : @{
			@"@type" : @"file",
			@"id" : @(fileId),
			@"remote" : @{@"unique_id" : [NSString stringWithFormat:@"AAAA%ld", (long)fileId]},
		},
	};
}

TGTestOutcome TGFlattenStickersTestFlattensWebpFormat(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"sticker",
		@"set_id" : @10,
		@"emoji" : @"\U0001F600",
		@"width" : @512,
		@"height" : @512,
		@"format" : @{@"@type" : @"stickerFormatWebp"},
		@"full_type" : @{@"@type" : @"stickerFullTypeRegular"},
		@"sticker" : @{@"@type" : @"file", @"id" : @501, @"remote" : @{@"unique_id" : @"AAAA501"}},
		@"thumbnail" : @{
			@"@type" : @"thumbnail",
			@"file" : @{@"@type" : @"file", @"id" : @601, @"remote" : @{@"unique_id" : @"AAAA601"}},
		},
	};

	NSDictionary *flat = TGFlattenSticker(raw);

	TGTestExpectTrue(&outcome, flat != nil,
			"a well-formed webp sticker must flatten to a dictionary, not nil");
	TGTestExpectEqualLongLong(&outcome, [flat[@"fileId"] longLongValue], 501,
			"a sticker's fileId must round-trip");
	TGTestExpectEqualLongLong(&outcome, [flat[@"setId"] longLongValue], 10,
			"a sticker's setId must round-trip");
	TGTestExpectTrue(&outcome, [flat[@"uniqueId"] isEqualToString:@"AAAA501"],
			"a sticker's uniqueId must come from sticker.remote.unique_id");
	TGTestExpectTrue(&outcome, [flat[@"thumbUniqueId"] isEqualToString:@"AAAA601"],
			"a sticker's thumbUniqueId must come from thumbnail.file.remote.unique_id");
	TGTestExpectTrue(&outcome, ![flat[@"isAnimated"] boolValue],
			"a stickerFormatWebp sticker must not be flagged isAnimated");
	TGTestExpectTrue(&outcome, ![flat[@"isVideo"] boolValue],
			"a stickerFormatWebp sticker must not be flagged isVideo");
	TGTestExpectEqualDouble(&outcome, [flat[@"width"] doubleValue], 512.0, 0.0001,
			"a sticker's width must round-trip");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestFlattensAnimatedFormat(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"sticker",
		@"format" : @{@"@type" : @"stickerFormatTgs"},
		@"sticker" : @{@"@type" : @"file", @"id" : @502},
	};

	NSDictionary *flat = TGFlattenSticker(raw);

	TGTestExpectTrue(&outcome, [flat[@"isAnimated"] boolValue],
			"a stickerFormatTgs sticker must be flagged isAnimated");
	TGTestExpectTrue(&outcome, ![flat[@"isVideo"] boolValue],
			"a stickerFormatTgs sticker must not be flagged isVideo");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestFlattensVideoFormat(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"sticker",
		@"format" : @{@"@type" : @"stickerFormatWebm"},
		@"sticker" : @{@"@type" : @"file", @"id" : @503},
	};

	NSDictionary *flat = TGFlattenSticker(raw);

	TGTestExpectTrue(&outcome, ![flat[@"isAnimated"] boolValue],
			"a stickerFormatWebm sticker must not be flagged isAnimated");
	TGTestExpectTrue(&outcome, [flat[@"isVideo"] boolValue],
			"a stickerFormatWebm sticker must be flagged isVideo");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestCustomEmojiIdPresent(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"sticker",
		@"full_type" : @{@"@type" : @"stickerFullTypeCustomEmoji", @"custom_emoji_id" : @12345},
		@"sticker" : @{@"@type" : @"file", @"id" : @504},
	};

	NSDictionary *flat = TGFlattenSticker(raw);

	TGTestExpectEqualLongLong(&outcome, [flat[@"customEmojiId"] longLongValue], 12345,
			"a stickerFullTypeCustomEmoji sticker must expose its custom_emoji_id");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestCustomEmojiIdAbsent(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"sticker",
		@"full_type" : @{@"@type" : @"stickerFullTypeRegular"},
		@"sticker" : @{@"@type" : @"file", @"id" : @505},
	};

	NSDictionary *flat = TGFlattenSticker(raw);

	TGTestExpectEqualLongLong(&outcome, [flat[@"customEmojiId"] longLongValue], 0,
			"a non custom-emoji sticker must default customEmojiId to zero");

	NSDictionary *noFullType = @{
		@"@type" : @"sticker",
		@"sticker" : @{@"@type" : @"file", @"id" : @506},
	};
	TGTestExpectEqualLongLong(&outcome, [TGFlattenSticker(noFullType)[@"customEmojiId"] longLongValue], 0,
			"a sticker with no full_type at all must default customEmojiId to zero, not crash");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestMissingFileIdReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGFlattenSticker(nil) == nil,
			"a nil raw sticker must flatten to nil, not crash");
	TGTestExpectTrue(&outcome, TGFlattenSticker(@{}) == nil,
			"a sticker dictionary with no sticker.id must flatten to nil");
	TGTestExpectTrue(&outcome, TGFlattenSticker(@{@"sticker" : @{@"id" : @"not-a-number"}}) == nil,
			"a sticker whose file id is not a number must flatten to nil");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestThumbnailDefaultsToZeroWhenMissing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"sticker",
		@"sticker" : @{@"@type" : @"file", @"id" : @507},
	};

	NSDictionary *flat = TGFlattenSticker(raw);

	TGTestExpectEqualLongLong(&outcome, [flat[@"thumbId"] longLongValue], 0,
			"a sticker with no thumbnail must default thumbId to zero");
	TGTestExpectTrue(&outcome, [flat[@"thumbUniqueId"] isEqualToString:@""],
			"a sticker with no thumbnail must default thumbUniqueId to an empty string");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestSetFlattensRealisticPayload(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"stickerSet",
		@"id" : @77,
		@"title" : @"Cool Set",
		@"name" : @"cool_set",
		@"size" : @3,
		@"is_installed" : @YES,
		@"is_archived" : @NO,
		@"is_official" : @YES,
		@"is_viewed" : @NO,
		@"is_owned" : @NO,
		@"sticker_type" : @{@"@type" : @"stickerTypeRegular"},
		@"thumbnail" : @{
			@"@type" : @"thumbnail",
			@"file" : @{@"@type" : @"file", @"id" : @900, @"remote" : @{@"unique_id" : @"AAAA900"}},
		},
		@"stickers" : @[
			TGFlattenStickersTestBuildSticker(1),
			TGFlattenStickersTestBuildSticker(2),
		],
		@"covers" : @[
			TGFlattenStickersTestBuildSticker(1),
		],
	};

	NSDictionary *flat = TGFlattenStickerSet(raw);

	TGTestExpectTrue(&outcome, flat != nil,
			"a well-formed sticker set must flatten to a dictionary, not nil");
	TGTestExpectEqualLongLong(&outcome, [flat[@"id"] longLongValue], 77,
			"a sticker set's id must round-trip");
	TGTestExpectTrue(&outcome, [flat[@"title"] isEqualToString:@"Cool Set"],
			"a sticker set's title must round-trip");
	TGTestExpectTrue(&outcome, [flat[@"name"] isEqualToString:@"cool_set"],
			"a sticker set's name must round-trip");
	TGTestExpectEqualLongLong(&outcome, [flat[@"count"] longLongValue], 3,
			"a sticker set's count must come from its size field when present");
	TGTestExpectTrue(&outcome, [flat[@"installed"] boolValue],
			"is_installed must round-trip into installed");
	TGTestExpectTrue(&outcome, ![flat[@"archived"] boolValue],
			"is_archived must round-trip into archived");
	TGTestExpectTrue(&outcome, ![flat[@"isEmoji"] boolValue],
			"a stickerTypeRegular set must not be flagged isEmoji");
	TGTestExpectEqualLongLong(&outcome, [flat[@"thumbId"] longLongValue], 900,
			"a sticker set's thumbId must come from thumbnail.file.id");
	TGTestExpectEqualInteger(&outcome, [flat[@"stickers"] count], 2,
			"a sticker set's stickers array must be fully flattened");
	TGTestExpectEqualInteger(&outcome, [flat[@"covers"] count], 1,
			"a sticker set with a non-empty covers array must use it as-is, not fall back to stickers");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestSetMissingIdReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGFlattenStickerSet(nil) == nil,
			"a nil raw sticker set must flatten to nil, not crash");
	TGTestExpectTrue(&outcome, TGFlattenStickerSet(@{@"title" : @"Untitled"}) == nil,
			"a sticker set with no id must flatten to nil");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestSetCoversFallBackToStickersWhenEmpty(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"stickerSet",
		@"id" : @78,
		@"stickers" : @[
			TGFlattenStickersTestBuildSticker(11),
			TGFlattenStickersTestBuildSticker(12),
		],
		@"covers" : @[],
	};

	NSDictionary *flat = TGFlattenStickerSet(raw);
	NSArray *stickers = flat[@"stickers"];
	NSArray *covers = flat[@"covers"];

	TGTestExpectEqualInteger(&outcome, covers.count, stickers.count,
			"an empty covers array must fall back to the set's own stickers array");
	TGTestExpectEqualLongLong(&outcome, [covers[0][@"fileId"] longLongValue], 11,
			"the fallback covers array must carry the same entries as stickers, in order");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestSetCountFallsBackToStickersCountWhenSizeMissing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"stickerSet",
		@"id" : @79,
		@"stickers" : @[
			TGFlattenStickersTestBuildSticker(21),
			TGFlattenStickersTestBuildSticker(22),
			TGFlattenStickersTestBuildSticker(23),
		],
	};

	NSDictionary *flat = TGFlattenStickerSet(raw);

	TGTestExpectEqualLongLong(&outcome, [flat[@"count"] longLongValue], 3,
			"a sticker set with no size field must fall back its count to stickers.count");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestSetIsEmojiTrueForCustomEmojiType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"stickerSet",
		@"id" : @80,
		@"sticker_type" : @{@"@type" : @"stickerTypeCustomEmoji"},
	};

	NSDictionary *flat = TGFlattenStickerSet(raw);

	TGTestExpectTrue(&outcome, [flat[@"isEmoji"] boolValue],
			"a stickerTypeCustomEmoji set must be flagged isEmoji");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestSetIsMaskTrueForMaskType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"stickerSet",
		@"id" : @81,
		@"sticker_type" : @{@"@type" : @"stickerTypeMask"},
	};

	NSDictionary *flat = TGFlattenStickerSet(raw);

	TGTestExpectTrue(&outcome, [flat[@"isMask"] boolValue],
			"a stickerTypeMask set must be flagged isMask");
	TGTestExpectTrue(&outcome, ![flat[@"isEmoji"] boolValue],
			"a stickerTypeMask set must not be flagged isEmoji");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestSetIsMaskFalseForRegularType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"stickerSet",
		@"id" : @82,
		@"sticker_type" : @{@"@type" : @"stickerTypeRegular"},
	};

	NSDictionary *flat = TGFlattenStickerSet(raw);

	TGTestExpectTrue(&outcome, ![flat[@"isMask"] boolValue],
			"a stickerTypeRegular set must not be flagged isMask");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestIsFlattenableRecognizesValidAndInvalid(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGIsFlattenableSticker(TGFlattenStickersTestBuildSticker(1)),
			"a sticker with a numeric file id must be flattenable");
	TGTestExpectTrue(&outcome, !TGIsFlattenableSticker(@{@"sticker" : @{@"id" : @"not-a-number"}}),
			"a sticker whose file id is a string must not be flattenable");
	TGTestExpectTrue(&outcome, !TGIsFlattenableSticker(@{}),
			"a sticker dictionary with no sticker key must not be flattenable");
	TGTestExpectTrue(&outcome, !TGIsFlattenableSticker(nil),
			"a nil object must not be flattenable, not crash");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestRangeAtStart(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *list = @[
		TGFlattenStickersTestBuildSticker(1),
		TGFlattenStickersTestBuildSticker(2),
		TGFlattenStickersTestBuildSticker(3),
		TGFlattenStickersTestBuildSticker(4),
		TGFlattenStickersTestBuildSticker(5),
	];

	NSArray *page = TGFlattenStickerRange(list, 0, 2);

	TGTestExpectEqualInteger(&outcome, page.count, 2,
			"a window at the start of the stream must return exactly length items");
	TGTestExpectEqualLongLong(&outcome, [page[0][@"fileId"] longLongValue], 1,
			"the first item of a start window must be the first flattenable entry");
	TGTestExpectEqualLongLong(&outcome, [page[1][@"fileId"] longLongValue], 2,
			"the second item of a start window must be the second flattenable entry");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestRangeAtMiddle(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *list = @[
		TGFlattenStickersTestBuildSticker(1),
		TGFlattenStickersTestBuildSticker(2),
		TGFlattenStickersTestBuildSticker(3),
		TGFlattenStickersTestBuildSticker(4),
		TGFlattenStickersTestBuildSticker(5),
	];

	NSArray *page = TGFlattenStickerRange(list, 2, 2);

	TGTestExpectEqualInteger(&outcome, page.count, 2,
			"a window in the middle of the stream must return exactly length items");
	TGTestExpectEqualLongLong(&outcome, [page[0][@"fileId"] longLongValue], 3,
			"a middle window must start at the item located at its offset");
	TGTestExpectEqualLongLong(&outcome, [page[1][@"fileId"] longLongValue], 4,
			"a middle window's second item must follow the first");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestRangeAtEnd(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *list = @[
		TGFlattenStickersTestBuildSticker(1),
		TGFlattenStickersTestBuildSticker(2),
		TGFlattenStickersTestBuildSticker(3),
		TGFlattenStickersTestBuildSticker(4),
		TGFlattenStickersTestBuildSticker(5),
	];

	NSArray *page = TGFlattenStickerRange(list, 3, 2);

	TGTestExpectEqualInteger(&outcome, page.count, 2,
			"a window that ends exactly at the last item must still return its full length");
	TGTestExpectEqualLongLong(&outcome, [page[0][@"fileId"] longLongValue], 4,
			"the second-to-last item must open a window that reaches the end");
	TGTestExpectEqualLongLong(&outcome, [page[1][@"fileId"] longLongValue], 5,
			"the last item must close a window that reaches the end");

	NSArray *overrunPage = TGFlattenStickerRange(list, 4, 10);
	TGTestExpectEqualInteger(&outcome, overrunPage.count, 1,
			"a window whose requested length overruns the stream must be truncated to what remains");
	TGTestExpectEqualLongLong(&outcome, [overrunPage[0][@"fileId"] longLongValue], 5,
			"a truncated end window must still return the correct remaining item");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestRangePastTheEnd(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *list = @[
		TGFlattenStickersTestBuildSticker(1),
		TGFlattenStickersTestBuildSticker(2),
		TGFlattenStickersTestBuildSticker(3),
	];

	NSArray *exactlyPastEnd = TGFlattenStickerRange(list, 3, 2);
	TGTestExpectEqualInteger(&outcome, exactlyPastEnd.count, 0,
			"a window whose offset equals the stream length must return an empty array");

	NSArray *wellPastEnd = TGFlattenStickerRange(list, 100, 5);
	TGTestExpectEqualInteger(&outcome, wellPastEnd.count, 0,
			"a window whose offset is far past the stream length must return an empty array, not crash");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestRangeSkipsNonFlattenableEntriesInterspersed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *list = @[
		TGFlattenStickersTestBuildSticker(1),
		@{@"foo" : @"bar"},
		TGFlattenStickersTestBuildSticker(2),
		@"garbage",
		TGFlattenStickersTestBuildSticker(3),
		@{@"sticker" : @{@"id" : @"not-a-number"}},
		TGFlattenStickersTestBuildSticker(4),
		TGFlattenStickersTestBuildSticker(5),
	];

	NSArray *page = TGFlattenStickerRange(list, 0, 100);

	TGTestExpectEqualInteger(&outcome, page.count, 5,
			"non-flattenable entries interspersed in the stream must not appear in the window");
	TGTestExpectEqualLongLong(&outcome, [page[0][@"fileId"] longLongValue], 1,
			"the window's ordering must follow the filtered stream, not the raw list");
	TGTestExpectEqualLongLong(&outcome, [page[2][@"fileId"] longLongValue], 3,
			"an invalid entry must not consume a slot in the pagination index");
	TGTestExpectEqualLongLong(&outcome, [page[4][@"fileId"] longLongValue], 5,
			"the last valid entry must still land at its correct filtered position");

	NSArray *middlePage = TGFlattenStickerRange(list, 2, 2);
	TGTestExpectEqualLongLong(&outcome, [middlePage[0][@"fileId"] longLongValue], 3,
			"a windowed offset counted over the filtered stream must skip invalid entries correctly");
	TGTestExpectEqualLongLong(&outcome, [middlePage[1][@"fileId"] longLongValue], 4,
			"a windowed offset's second item must be the next valid entry after the first");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestRangeEmptyStreamReturnsEmptyArray(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualInteger(&outcome, TGFlattenStickerRange(nil, 0, 5).count, 0,
			"a nil stream must produce an empty range, not crash");
	TGTestExpectEqualInteger(&outcome, TGFlattenStickerRange(@[], 0, 5).count, 0,
			"an empty stream must produce an empty range");
	TGTestExpectEqualInteger(&outcome, TGFlattenStickers(nil).count, 0,
			"a nil list must flatten to an empty stickers array, not crash");
	TGTestExpectEqualInteger(&outcome, TGFlattenStickers(@[]).count, 0,
			"an empty list must flatten to an empty stickers array");

	return outcome;
}

TGTestOutcome TGFlattenStickersTestCountSkipsInvalidEntries(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *list = @[
		TGFlattenStickersTestBuildSticker(1),
		@{@"foo" : @"bar"},
		TGFlattenStickersTestBuildSticker(2),
		@"garbage",
	];

	TGTestExpectEqualInteger(&outcome, TGCountFlattenableStickers(list), 2,
			"invalid entries interspersed in the stream must not be counted as flattenable");
	TGTestExpectEqualInteger(&outcome, TGCountFlattenableStickers(nil), 0,
			"a nil stream must count as zero flattenable stickers, not crash");
	TGTestExpectEqualInteger(&outcome, TGCountFlattenableStickers(@[]), 0,
			"an empty stream must count as zero flattenable stickers");

	return outcome;
}

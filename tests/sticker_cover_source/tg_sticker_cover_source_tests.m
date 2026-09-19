#import "tg_sticker_cover_source_tests.h"

#import "../../src/Screens/Stickers/TGStickerCoverSource.h"

#import <Foundation/Foundation.h>

static NSDictionary *TGStickerCoverSourceTestStill(long long fileId) {
	return @{ @"fileId" : @(fileId),
		@"uniqueId" : @"still-unique",
		@"isAnimated" : @NO,
		@"isVideo" : @NO,
		@"thumbId" : @(fileId + 1000),
		@"thumbUniqueId" : @"still-thumb-unique" };
}

static NSDictionary *TGStickerCoverSourceTestVideo(long long fileId, long long thumbId) {
	return @{ @"fileId" : @(fileId),
		@"uniqueId" : @"video-unique",
		@"isAnimated" : @NO,
		@"isVideo" : @YES,
		@"thumbId" : @(thumbId),
		@"thumbUniqueId" : thumbId > 0 ? @"video-thumb-unique" : @"" };
}

TGTestOutcome TGStickerCoverSourceTestStillStickerUsesItsOwnFile(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGStickerCoverSource *source =
		[TGStickerCoverSource sourceForSticker:TGStickerCoverSourceTestStill(7)];
	TGTestExpectEqualInteger(&outcome, source.kind, TGStickerCoverKindSticker,
			"a still sticker is drawn from its own WebP, as it always was");
	TGTestExpectEqualLongLong(&outcome, source.fileId, 7,
			"and from its own file id, not its thumbnail's");

	TGStickerCoverSource *empty = [TGStickerCoverSource sourceForSticker:nil];
	TGTestExpectEqualInteger(&outcome, empty.kind, TGStickerCoverKindNone,
			"nothing at all names no source");

	return outcome;
}

TGTestOutcome TGStickerCoverSourceTestAnimatedAndVideoUseTheirThumbnail(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGStickerCoverSource *video =
		[TGStickerCoverSource sourceForSticker:TGStickerCoverSourceTestVideo(11, 12)];
	TGTestExpectEqualInteger(&outcome, video.kind, TGStickerCoverKindThumbnail,
			"a video sticker is drawn from its thumbnail; the whole pack used to be grey "
			"outlines because the webm itself was never decoded for a tile");
	TGTestExpectEqualLongLong(&outcome, video.fileId, 12,
			"the thumbnail's file id is the one to fetch");
	TGTestExpectTrue(&outcome, [video.uniqueId isEqualToString:@"video-thumb-unique"],
			"and the thumbnail's unique id is what the thumbnail cache is keyed by");

	NSMutableDictionary *animated =
		[TGStickerCoverSourceTestVideo(13, 14) mutableCopy];
	animated[@"isVideo"] = @NO;
	animated[@"isAnimated"] = @YES;
	TGTestExpectEqualInteger(&outcome,
			[TGStickerCoverSource sourceForSticker:animated].kind, TGStickerCoverKindThumbnail,
			"a tgs sticker takes the same path");

	TGStickerCoverSource *none =
		[TGStickerCoverSource sourceForSticker:TGStickerCoverSourceTestVideo(15, 0)];
	TGTestExpectEqualInteger(&outcome, none.kind, TGStickerCoverKindNone,
			"a video sticker with no thumbnail names no source, so the outline stays");

	return outcome;
}

TGTestOutcome TGStickerCoverSourceTestSetPrefersAStillCover(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *set = @{ @"thumbId" : @90,
		@"thumbUniqueId" : @"set-thumb-unique",
		@"covers" : @[ TGStickerCoverSourceTestVideo(21, 22), TGStickerCoverSourceTestStill(23) ] };
	TGStickerCoverSource *source = [TGStickerCoverSource sourceForSet:set];
	TGTestExpectEqualInteger(&outcome, source.kind, TGStickerCoverKindSticker,
			"a set with a still cover draws that cover");
	TGTestExpectEqualLongLong(&outcome, source.fileId, 23,
			"even when the still one is not the first cover");

	return outcome;
}

TGTestOutcome TGStickerCoverSourceTestSetFallsBackToThumbnails(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *own = @{ @"thumbId" : @90,
		@"thumbUniqueId" : @"set-thumb-unique",
		@"covers" : @[ TGStickerCoverSourceTestVideo(21, 22) ] };
	TGStickerCoverSource *source = [TGStickerCoverSource sourceForSet:own];
	TGTestExpectEqualInteger(&outcome, source.kind, TGStickerCoverKindThumbnail,
			"a set of video stickers draws a thumbnail rather than the initials avatar");
	TGTestExpectEqualLongLong(&outcome, source.fileId, 90,
			"the set's own thumbnail wins over its covers'");

	NSDictionary *borrowed = @{ @"thumbId" : @0,
		@"thumbUniqueId" : @"",
		@"covers" : @[ TGStickerCoverSourceTestVideo(21, 22) ] };
	TGStickerCoverSource *fallback = [TGStickerCoverSource sourceForSet:borrowed];
	TGTestExpectEqualLongLong(&outcome, fallback.fileId, 22,
			"a set with no thumbnail of its own borrows its first cover's");

	NSDictionary *bare = @{ @"thumbId" : @0, @"thumbUniqueId" : @"", @"covers" : @[] };
	TGTestExpectEqualInteger(&outcome, [TGStickerCoverSource sourceForSet:bare].kind,
			TGStickerCoverKindNone,
			"a set with nothing to draw names no source");

	return outcome;
}

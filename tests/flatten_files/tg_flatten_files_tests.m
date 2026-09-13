#import "tg_flatten_files_tests.h"
#import "../../src/Wire/Flatten/TGFlattenFiles.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenFilesTestBase64DecodeValidInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *decoded = TGFilesDataFromBase64(@"SGVsbG8=");
	NSData *expected = [@"Hello" dataUsingEncoding:NSUTF8StringEncoding];

	TGTestExpectTrue(&outcome, [decoded isEqualToData:expected],
			"a well-formed base64 string with trailing '=' padding must decode to its exact original bytes");

	NSData *unpadded = TGFilesDataFromBase64(@"TWFu");
	NSData *expectedUnpadded = [@"Man" dataUsingEncoding:NSUTF8StringEncoding];
	TGTestExpectTrue(&outcome, [unpadded isEqualToData:expectedUnpadded],
			"a padding-free base64 string must decode to its exact original bytes");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestBase64DecodeEmptyInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGFilesDataFromBase64(@"") == nil,
			"an empty string must decode to nil, not an empty NSData or a crash - this matches TGScBase64Decode's "
			"convention and differs from TGMCBase64, which returns an empty NSData for empty input instead of nil");
	TGTestExpectTrue(&outcome, TGFilesDataFromBase64(nil) == nil,
			"a nil value must decode to nil, not crash");
	TGTestExpectTrue(&outcome, TGFilesDataFromBase64(@42) == nil,
			"a non-string value must decode to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestBase64DecodeMalformedInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGFilesDataFromBase64(@"!!!@@@") == nil,
			"a string with no valid base64 characters at all must decode to nil, again matching "
			"TGScBase64Decode rather than TGMCBase64's empty-NSData behavior for the same input");

	NSData *decoded = TGFilesDataFromBase64(@"SGVs bG8=");
	NSData *expected = [@"Hello" dataUsingEncoding:NSUTF8StringEncoding];
	TGTestExpectTrue(&outcome, [decoded isEqualToData:expected],
			"stray non-alphabet characters embedded in an otherwise valid string must be skipped, not corrupt the result");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestFileInfoComposesRealisticPayload(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *file = @{
		@"id" : @5,
		@"size" : @1024,
		@"expected_size" : @2048,
		@"local" : @{
			@"path" : @"/tmp/foo.jpg",
			@"downloaded_size" : @512,
			@"downloaded_prefix_size" : @256,
			@"download_offset" : @0,
			@"can_be_downloaded" : @YES,
			@"can_be_deleted" : @NO,
			@"is_downloading_active" : @YES,
			@"is_downloading_completed" : @NO,
		},
		@"remote" : @{
			@"id" : @"remote123",
			@"unique_id" : @"AABBCC",
			@"is_uploading_active" : @NO,
			@"is_uploading_completed" : @YES,
			@"uploaded_size" : @1024,
		},
	};

	NSDictionary *flat = TGFileInfo(file);

	TGTestExpectTrue(&outcome, flat != nil, "a well-formed file object must compose to a dictionary, not nil");
	TGTestExpectEqualInteger(&outcome, [flat[@"id"] integerValue], 5, "id must round-trip verbatim");
	TGTestExpectEqualInteger(&outcome, [flat[@"size"] integerValue], 1024, "size must round-trip verbatim");
	TGTestExpectEqualInteger(&outcome, [flat[@"expectedSize"] integerValue], 2048,
			"expectedSize must come from expected_size when present");
	TGTestExpectTrue(&outcome, [flat[@"path"] isEqualToString:@"/tmp/foo.jpg"],
			"path must come from local.path");
	TGTestExpectEqualInteger(&outcome, [flat[@"downloadedSize"] integerValue], 512,
			"downloadedSize must come from local.downloaded_size");
	TGTestExpectEqualInteger(&outcome, [flat[@"prefixSize"] integerValue], 256,
			"prefixSize must come from local.downloaded_prefix_size");
	TGTestExpectTrue(&outcome, [flat[@"canBeDownloaded"] boolValue],
			"canBeDownloaded must come from local.can_be_downloaded");
	TGTestExpectTrue(&outcome, ![flat[@"canBeDeleted"] boolValue],
			"canBeDeleted must come from local.can_be_deleted");
	TGTestExpectTrue(&outcome, [flat[@"isDownloading"] boolValue],
			"isDownloading must come from local.is_downloading_active");
	TGTestExpectTrue(&outcome, ![flat[@"isDownloaded"] boolValue],
			"isDownloaded must come from local.is_downloading_completed");
	TGTestExpectTrue(&outcome, ![flat[@"isUploading"] boolValue],
			"isUploading must come from remote.is_uploading_active");
	TGTestExpectTrue(&outcome, [flat[@"isUploaded"] boolValue],
			"isUploaded must come from remote.is_uploading_completed");
	TGTestExpectEqualInteger(&outcome, [flat[@"uploadedSize"] integerValue], 1024,
			"uploadedSize must come from remote.uploaded_size");
	TGTestExpectTrue(&outcome, [flat[@"remoteId"] isEqualToString:@"remote123"],
			"remoteId must come from remote.id");
	TGTestExpectTrue(&outcome, [flat[@"uniqueId"] isEqualToString:@"AABBCC"],
			"uniqueId must come from remote.unique_id");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestFileInfoFillsDefaultsForMissingFields(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *file = @{@"id" : @7};
	NSDictionary *flat = TGFileInfo(file);

	TGTestExpectTrue(&outcome, flat != nil,
			"a file object with only an id must still compose to a dictionary, not nil");
	TGTestExpectEqualInteger(&outcome, [flat[@"size"] integerValue], 0,
			"size must default to 0 when absent");
	TGTestExpectEqualInteger(&outcome, [flat[@"expectedSize"] integerValue], 0,
			"expectedSize must default to 0 when both expected_size and size are absent");
	TGTestExpectTrue(&outcome, [flat[@"path"] isEqualToString:@""],
			"path must default to an empty string when local is absent, not nil");
	TGTestExpectEqualInteger(&outcome, [flat[@"downloadedSize"] integerValue], 0,
			"downloadedSize must default to 0 when local is absent");
	TGTestExpectTrue(&outcome, ![flat[@"canBeDownloaded"] boolValue],
			"canBeDownloaded must default to NO when local is absent");
	TGTestExpectTrue(&outcome, ![flat[@"isUploaded"] boolValue],
			"isUploaded must default to NO when remote is absent");
	TGTestExpectTrue(&outcome, [flat[@"remoteId"] isEqualToString:@""],
			"remoteId must default to an empty string when remote is absent, not nil");
	TGTestExpectTrue(&outcome, [flat[@"uniqueId"] isEqualToString:@""],
			"uniqueId must default to an empty string when remote is absent, not nil");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestFileInfoReturnsNilForInvalidInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGFileInfo(nil) == nil, "a nil file object must compose to nil, not crash");
	TGTestExpectTrue(&outcome, TGFileInfo((NSDictionary *)@"not a dictionary") == nil,
			"a non-dictionary file object must compose to nil, not crash");
	TGTestExpectTrue(&outcome, TGFileInfo(@{@"size" : @10}) == nil,
			"a dictionary with no id must compose to nil, since id is the one field the caller cannot fabricate");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestFileOfMessageContentForDocument(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *content = @{
		@"@type" : @"messageDocument",
		@"document" : @{
			@"document" : @{@"id" : @10},
			@"file_name" : @"report.pdf",
		},
	};

	NSDictionary *media = TGFileOfMessageContent(content, 0);

	TGTestExpectTrue(&outcome, media != nil, "messageDocument content with a document file must compose, not nil");
	TGTestExpectEqualInteger(&outcome, [media[@"file"][@"id"] integerValue], 10,
			"messageDocument's file must be the inner document.document object");
	TGTestExpectTrue(&outcome, [media[@"name"] isEqualToString:@"report.pdf"],
			"messageDocument's name must come from document.file_name");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestFileOfMessageContentForVideo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *content = @{
		@"@type" : @"messageVideo",
		@"video" : @{
			@"video" : @{@"id" : @11},
			@"file_name" : @"clip.mp4",
		},
	};

	NSDictionary *media = TGFileOfMessageContent(content, 0);

	TGTestExpectTrue(&outcome, media != nil, "messageVideo content with a video file must compose, not nil");
	TGTestExpectEqualInteger(&outcome, [media[@"file"][@"id"] integerValue], 11,
			"messageVideo's file must be the inner video.video object");
	TGTestExpectTrue(&outcome, [media[@"name"] isEqualToString:@"clip.mp4"],
			"messageVideo's name must come from video.file_name");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestFileOfMessageContentForPhotoPicksLastSize(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *content = @{
		@"@type" : @"messagePhoto",
		@"photo" : @{
			@"sizes" : @[
				@{@"photo" : @{@"id" : @1}},
				@{@"photo" : @{@"id" : @2}},
			],
		},
	};

	NSDictionary *media = TGFileOfMessageContent(content, 0);

	TGTestExpectTrue(&outcome, media != nil, "messagePhoto content with sizes must compose, not nil");
	TGTestExpectEqualInteger(&outcome, [media[@"file"][@"id"] integerValue], 2,
			"messagePhoto must pick the last entry in photo.sizes, matching TDLib's largest-last convention");
	TGTestExpectTrue(&outcome, [media[@"name"] isEqualToString:@""],
			"messagePhoto has no file name of its own, so name must be empty");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestFileOfMessageContentForLivePhotoPrefersMatchingVideoFile(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *content = @{
		@"@type" : @"messagePhoto",
		@"photo" : @{
			@"sizes" : @[
				@{@"photo" : @{@"id" : @1}},
				@{@"photo" : @{@"id" : @2}},
			],
		},
		@"video" : @{
			@"video" : @{@"id" : @99},
			@"file_name" : @"livephoto.mov",
		},
	};

	NSDictionary *stillMedia = TGFileOfMessageContent(content, 0);
	TGTestExpectTrue(&outcome, stillMedia != nil, "a live photo with no preferred file id must still compose, not nil");
	TGTestExpectEqualInteger(&outcome, [stillMedia[@"file"][@"id"] integerValue], 2,
			"with no preferred file id, a live photo must default to the still photo's last size, same as an ordinary photo");

	NSDictionary *videoMedia = TGFileOfMessageContent(content, 99);
	TGTestExpectTrue(&outcome, videoMedia != nil,
			"a live photo whose preferred file id matches the live-video component must still compose, not nil");
	TGTestExpectEqualInteger(&outcome, [videoMedia[@"file"][@"id"] integerValue], 99,
			"a download-manager entry whose file_id is the live-video component (not the still photo) must resolve "
			"to that video's own file object, not silently fall back to the unrelated still photo");
	TGTestExpectTrue(&outcome, [videoMedia[@"name"] isEqualToString:@"livephoto.mov"],
			"the live-video branch's name must come from video.file_name, matching the messageVideo convention");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestFileOfMessageContentForVoiceNote(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *content = @{
		@"@type" : @"messageVoiceNote",
		@"voice_note" : @{@"voice" : @{@"id" : @20}},
	};

	NSDictionary *media = TGFileOfMessageContent(content, 0);

	TGTestExpectTrue(&outcome, media != nil, "messageVoiceNote content with a voice file must compose, not nil");
	TGTestExpectEqualInteger(&outcome, [media[@"file"][@"id"] integerValue], 20,
			"messageVoiceNote's file must be the inner voice_note.voice object");
	TGTestExpectTrue(&outcome, [media[@"name"] isEqualToString:@""],
			"messageVoiceNote has no file name of its own, so name must be empty");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestFileOfMessageContentFallsBackToNilForUnhandledKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGFileOfMessageContent(@{@"@type" : @"messageText"}, 0) == nil,
			"a content kind with no file at all, like messageText, must compose to nil, not crash");
	TGTestExpectTrue(&outcome, TGFileOfMessageContent(nil, 0) == nil,
			"a nil content object must compose to nil, not crash");
	TGTestExpectTrue(&outcome, TGFileOfMessageContent(@{@"@type" : @"messageDocument"}, 0) == nil,
			"a recognised kind with no document payload at all must still compose to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestBestPhotoSizeInSizesForWidthScalePicksSmallestSizeAtOrAboveWanted(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *sizes = @[
		@{@"photo" : @{@"id" : @1}, @"width" : @100, @"height" : @100, @"type" : @"s"},
		@{@"photo" : @{@"id" : @2}, @"width" : @320, @"height" : @320, @"type" : @"m"},
		@{@"photo" : @{@"id" : @3}, @"width" : @800, @"height" : @800, @"type" : @"x"},
	];

	NSDictionary *chosen = TGBestPhotoSizeInSizesForWidthScale(sizes, 300, 1);

	TGTestExpectTrue(&outcome, chosen != nil, "a non-empty sizes array must produce a chosen size, not nil");
	TGTestExpectEqualInteger(&outcome, [chosen[@"fileId"] integerValue], 2,
			"the smallest size whose width is still >= the wanted width (300) must be chosen over both the "
			"too-small 100-wide entry and the needlessly large 800-wide entry");
	TGTestExpectEqualInteger(&outcome, [chosen[@"width"] integerValue], 320,
			"the chosen size's width must be the raw width of the picked entry");
	TGTestExpectTrue(&outcome, [chosen[@"type"] isEqualToString:@"m"],
			"the chosen size's type must be the raw type of the picked entry");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestBestPhotoSizeInSizesForWidthScaleFallsBackToLargestWhenNoneAreBigEnough(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *sizes = @[
		@{@"photo" : @{@"id" : @1}, @"width" : @100, @"height" : @100, @"type" : @"s"},
		@{@"photo" : @{@"id" : @2}, @"width" : @320, @"height" : @320, @"type" : @"m"},
	];

	NSDictionary *chosen = TGBestPhotoSizeInSizesForWidthScale(sizes, 2000, 2);

	TGTestExpectTrue(&outcome, chosen != nil,
			"even when no size reaches the wanted width, the largest available size must still be returned");
	TGTestExpectEqualInteger(&outcome, [chosen[@"fileId"] integerValue], 2,
			"the largest size (320 wide) must be the fallback when the wanted width (4000 at scale 2) exceeds everything");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestBestPhotoSizeInSizesForWidthScaleHandlesEmptyArray(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGBestPhotoSizeInSizesForWidthScale(@[], 300, 1) == nil,
			"an empty sizes array must produce nil, not crash");
	TGTestExpectTrue(&outcome, TGBestPhotoSizeInSizesForWidthScale(nil, 300, 1) == nil,
			"a nil sizes value must produce nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestBestPhotoSizeInSizesForWidthScaleHandlesSingleEntry(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *sizes = @[@{@"photo" : @{@"id" : @9}, @"width" : @480, @"height" : @480, @"type" : @"y"}];

	NSDictionary *smallWanted = TGBestPhotoSizeInSizesForWidthScale(sizes, 100, 1);
	NSDictionary *largeWanted = TGBestPhotoSizeInSizesForWidthScale(sizes, 5000, 1);

	TGTestExpectTrue(&outcome, smallWanted != nil && largeWanted != nil,
			"a single-entry sizes array must always produce that one entry, regardless of the wanted width");
	TGTestExpectEqualInteger(&outcome, [smallWanted[@"fileId"] integerValue], 9,
			"the single entry must be chosen when the wanted width is well below it");
	TGTestExpectEqualInteger(&outcome, [largeWanted[@"fileId"] integerValue], 9,
			"the single entry must also be the fallback when the wanted width is well above it");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestDecodableThumbnailAcceptsJpegAndPng(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *jpeg = @{
		@"format" : @{@"@type" : @"thumbnailFormatJpeg"},
		@"file" : @{@"id" : @30},
		@"width" : @90,
		@"height" : @90,
	};
	NSDictionary *png = @{
		@"format" : @{@"@type" : @"thumbnailFormatPng"},
		@"file" : @{@"id" : @31},
		@"width" : @90,
		@"height" : @90,
	};

	NSDictionary *jpegFlat = TGDecodableThumbnail(jpeg);
	NSDictionary *pngFlat = TGDecodableThumbnail(png);

	TGTestExpectTrue(&outcome, jpegFlat != nil, "a thumbnailFormatJpeg thumbnail must be decodable");
	TGTestExpectEqualInteger(&outcome, [jpegFlat[@"fileId"] integerValue], 30,
			"the decodable jpeg thumbnail's fileId must come from file.id");
	TGTestExpectTrue(&outcome, [jpegFlat[@"type"] isEqualToString:@"thumbnailFormatJpeg"],
			"the decodable jpeg thumbnail's type must be the raw format type name");
	TGTestExpectTrue(&outcome, pngFlat != nil, "a thumbnailFormatPng thumbnail must also be decodable");
	TGTestExpectEqualInteger(&outcome, [pngFlat[@"fileId"] integerValue], 31,
			"the decodable png thumbnail's fileId must come from file.id");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestDecodableThumbnailRejectsUnsupportedFormat(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *webp = @{
		@"format" : @{@"@type" : @"thumbnailFormatWebp"},
		@"file" : @{@"id" : @32},
	};

	TGTestExpectTrue(&outcome, TGDecodableThumbnail(webp) == nil,
			"a thumbnail whose format isn't jpeg or png must not be reported as decodable, since the client "
			"cannot render it directly");

	return outcome;
}

TGTestOutcome TGFlattenFilesTestDecodableThumbnailReturnsNilForMissingFile(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *noFile = @{@"format" : @{@"@type" : @"thumbnailFormatJpeg"}};

	TGTestExpectTrue(&outcome, TGDecodableThumbnail(noFile) == nil,
			"a thumbnail with a supported format but no file object must compose to nil, not crash");
	TGTestExpectTrue(&outcome, TGDecodableThumbnail(nil) == nil,
			"a nil thumbnail must compose to nil, not crash");
	TGTestExpectTrue(&outcome, TGDecodableThumbnail((NSDictionary *)@"not a dictionary") == nil,
			"a non-dictionary thumbnail must compose to nil, not crash");

	return outcome;
}

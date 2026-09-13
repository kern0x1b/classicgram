#import "tg_flatten_gifs_tests.h"
#import "../../src/Wire/Flatten/TGFlattenGifs.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenGifsTestWebmFormatSuppressesThumbId(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *animation = @{
		@"animation" : @{
			@"id" : @1001,
			@"remote" : @{@"unique_id" : @"AAABBB"},
		},
		@"thumbnail" : @{
			@"file" : @{
				@"id" : @2002,
				@"remote" : @{@"unique_id" : @"CCCDDD"},
			},
			@"format" : @{@"@type" : @"thumbnailFormatWebm"},
		},
		@"width" : @480,
		@"height" : @360,
		@"duration" : @3,
		@"mime_type" : @"video/webm",
		@"file_name" : @"funny.webm",
	};

	NSDictionary *flat = TGFlattenAnimation(animation);

	TGTestExpectTrue(&outcome, flat != nil,
			"a well-formed animation with a webm thumbnail must still flatten to a dictionary");
	TGTestExpectEqualInteger(&outcome, [flat[@"thumbId"] integerValue], 0,
			"a webm thumbnail format must suppress the thumbnail file id to 0");
	TGTestExpectTrue(&outcome, [flat[@"thumbUniqueId"] isEqualToString:@"CCCDDD"],
			"suppressing the numeric thumbnail id must not erase the thumbnail's own unique id");
	TGTestExpectTrue(&outcome, [flat[@"thumbIsVideo"] boolValue],
			"thumbnailFormatWebm must be reported as a video-format thumbnail");

	return outcome;
}

TGTestOutcome TGFlattenGifsTestTgsFormatSuppressesThumbId(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *animation = @{
		@"animation" : @{
			@"id" : @1001,
			@"remote" : @{@"unique_id" : @"AAABBB"},
		},
		@"thumbnail" : @{
			@"file" : @{
				@"id" : @2002,
				@"remote" : @{@"unique_id" : @"CCCDDD"},
			},
			@"format" : @{@"@type" : @"thumbnailFormatTgs"},
		},
		@"width" : @512,
		@"height" : @512,
		@"duration" : @2,
		@"mime_type" : @"application/x-tgsticker",
		@"file_name" : @"sticker.tgs",
	};

	NSDictionary *flat = TGFlattenAnimation(animation);

	TGTestExpectTrue(&outcome, flat != nil,
			"a well-formed animation with a tgs thumbnail must still flatten to a dictionary");
	TGTestExpectEqualInteger(&outcome, [flat[@"thumbId"] integerValue], 0,
			"a tgs thumbnail format must suppress the thumbnail file id to 0");
	TGTestExpectTrue(&outcome, [flat[@"thumbUniqueId"] isEqualToString:@"CCCDDD"],
			"suppressing the numeric thumbnail id must not erase the thumbnail's own unique id");
	TGTestExpectTrue(&outcome, ![flat[@"thumbIsVideo"] boolValue],
			"thumbnailFormatTgs must not be reported as a video-format thumbnail");

	return outcome;
}

TGTestOutcome TGFlattenGifsTestMpeg4FormatKeepsThumbIdAndReportsVideo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *animation = @{
		@"animation" : @{
			@"id" : @1001,
			@"remote" : @{@"unique_id" : @"AAABBB"},
		},
		@"thumbnail" : @{
			@"file" : @{
				@"id" : @2002,
				@"remote" : @{@"unique_id" : @"CCCDDD"},
			},
			@"format" : @{@"@type" : @"thumbnailFormatMpeg4"},
		},
		@"width" : @640,
		@"height" : @480,
		@"duration" : @5,
		@"mime_type" : @"video/mp4",
		@"file_name" : @"clip.mp4",
	};

	NSDictionary *flat = TGFlattenAnimation(animation);

	TGTestExpectTrue(&outcome, flat != nil,
			"a well-formed animation with an mpeg4 thumbnail must flatten to a dictionary");
	TGTestExpectEqualInteger(&outcome, [flat[@"thumbId"] integerValue], 2002,
			"an mpeg4 thumbnail format must not suppress the thumbnail file id, unlike webm and tgs");
	TGTestExpectTrue(&outcome, [flat[@"thumbIsVideo"] boolValue],
			"thumbnailFormatMpeg4 must be reported as a video-format thumbnail");

	return outcome;
}

TGTestOutcome TGFlattenGifsTestMissingThumbnailYieldsEmptyThumbFields(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *animation = @{
		@"animation" : @{
			@"id" : @1001,
			@"remote" : @{@"unique_id" : @"AAABBB"},
		},
		@"width" : @480,
		@"height" : @360,
		@"duration" : @3,
		@"mime_type" : @"video/mp4",
		@"file_name" : @"funny.mp4",
	};

	NSDictionary *flat = TGFlattenAnimation(animation);

	TGTestExpectTrue(&outcome, flat != nil,
			"an animation with no thumbnail at all must still flatten to a dictionary");
	TGTestExpectEqualInteger(&outcome, [flat[@"thumbId"] integerValue], 0,
			"a missing thumbnail must default the thumbnail file id to 0");
	TGTestExpectTrue(&outcome, [flat[@"thumbUniqueId"] isEqualToString:@""],
			"a missing thumbnail must default the thumbnail unique id to an empty string, not nil");
	TGTestExpectTrue(&outcome, ![flat[@"thumbIsVideo"] boolValue],
			"a missing thumbnail must not be reported as a video-format thumbnail");
	TGTestExpectEqualInteger(&outcome, [flat[@"fileId"] integerValue], 1001,
			"a missing thumbnail must not prevent the main file id from being flattened");

	return outcome;
}

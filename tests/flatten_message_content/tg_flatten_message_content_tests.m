#import "tg_flatten_message_content_tests.h"
#import "../../src/Wire/Flatten/TGFlattenMessageContent.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenMessageContentTestMediaInfoForPhoto(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"content" : @{
			@"@type" : @"messagePhoto",
			@"photo" : @{
				@"sizes" : @[
					@{@"width" : @90, @"height" : @90,
						@"photo" : @{@"id" : @111, @"size" : @2000}},
					@{@"width" : @1280, @"height" : @720,
						@"photo" : @{@"id" : @222, @"size" : @50000}},
				],
			},
			@"caption" : @{@"text" : @"a photo"},
			@"has_spoiler" : @YES,
		},
	};

	NSDictionary *info = TGMCMediaInfo(message);

	TGTestExpectTrue(&outcome, [info[@"kind"] isEqualToString:@"messagePhoto"],
			"messagePhoto must report its own content kind");
	TGTestExpectEqualInteger(&outcome, [info[@"width"] integerValue], 1280,
			"messagePhoto must take width from the largest size, the last entry in sizes");
	TGTestExpectEqualInteger(&outcome, [info[@"height"] integerValue], 720,
			"messagePhoto must take height from the largest size, the last entry in sizes");
	TGTestExpectEqualInteger(&outcome, [info[@"thumbId"] integerValue], 111,
			"messagePhoto must take thumbId from the smallest size, the first entry in sizes");
	TGTestExpectEqualInteger(&outcome, [info[@"fileId"] integerValue], 222,
			"messagePhoto must take fileId from the largest size's photo file");
	TGTestExpectEqualInteger(&outcome, [info[@"size"] integerValue], 50000,
			"messagePhoto must take size from the largest size's photo file");
	TGTestExpectTrue(&outcome, [info[@"caption"] isEqualToString:@"a photo"],
			"messagePhoto must flatten the caption text");
	TGTestExpectTrue(&outcome, [info[@"hasSpoiler"] boolValue],
			"messagePhoto must carry through has_spoiler");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestMediaInfoForVideo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"content" : @{
			@"@type" : @"messageVideo",
			@"video" : @{
				@"video" : @{@"id" : @501, @"size" : @123456},
				@"width" : @640,
				@"height" : @480,
				@"duration" : @30,
				@"file_name" : @"clip.mp4",
				@"mime_type" : @"video/mp4",
				@"thumbnail" : @{@"file" : @{@"id" : @777}},
			},
			@"caption" : @{@"text" : @"a video"},
			@"has_spoiler" : @NO,
		},
	};

	NSDictionary *info = TGMCMediaInfo(message);

	TGTestExpectEqualInteger(&outcome, [info[@"fileId"] integerValue], 501,
			"messageVideo must take fileId from video.video.id");
	TGTestExpectEqualInteger(&outcome, [info[@"size"] integerValue], 123456,
			"messageVideo must take size from video.video.size");
	TGTestExpectEqualInteger(&outcome, [info[@"width"] integerValue], 640,
			"messageVideo must take width from the shared media fields");
	TGTestExpectEqualInteger(&outcome, [info[@"height"] integerValue], 480,
			"messageVideo must take height from the shared media fields");
	TGTestExpectEqualInteger(&outcome, [info[@"duration"] integerValue], 30,
			"messageVideo must take duration from the shared media fields");
	TGTestExpectTrue(&outcome, [info[@"fileName"] isEqualToString:@"clip.mp4"],
			"messageVideo must take fileName from the shared media fields");
	TGTestExpectTrue(&outcome, [info[@"mimeType"] isEqualToString:@"video/mp4"],
			"messageVideo must take mimeType from the shared media fields");
	TGTestExpectEqualInteger(&outcome, [info[@"thumbId"] integerValue], 777,
			"messageVideo must fall back to the generic thumbnail.file.id since it does not set thumbId itself");
	TGTestExpectTrue(&outcome, ![info[@"hasSpoiler"] boolValue],
			"messageVideo with has_spoiler false must not report a spoiler");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestMediaInfoForAnimation(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"content" : @{
			@"@type" : @"messageAnimation",
			@"animation" : @{
				@"animation" : @{@"id" : @601, @"size" : @98765},
				@"width" : @480,
				@"height" : @480,
				@"duration" : @5,
				@"file_name" : @"loop.gif",
				@"mime_type" : @"image/gif",
			},
		},
	};

	NSDictionary *info = TGMCMediaInfo(message);

	TGTestExpectEqualInteger(&outcome, [info[@"fileId"] integerValue], 601,
			"messageAnimation must take fileId from animation.animation.id");
	TGTestExpectEqualInteger(&outcome, [info[@"size"] integerValue], 98765,
			"messageAnimation must take size from animation.animation.size");
	TGTestExpectEqualInteger(&outcome, [info[@"width"] integerValue], 480,
			"messageAnimation must take width from the shared media fields");
	TGTestExpectEqualInteger(&outcome, [info[@"duration"] integerValue], 5,
			"messageAnimation must take duration from the shared media fields");
	TGTestExpectTrue(&outcome, [info[@"fileName"] isEqualToString:@"loop.gif"],
			"messageAnimation must take fileName from the shared media fields");
	TGTestExpectTrue(&outcome, [info[@"mimeType"] isEqualToString:@"image/gif"],
			"messageAnimation must take mimeType from the shared media fields");
	TGTestExpectEqualInteger(&outcome, [info[@"thumbId"] integerValue], 0,
			"messageAnimation with no thumbnail must default thumbId to zero");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestMediaInfoForDocument(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"content" : @{
			@"@type" : @"messageDocument",
			@"document" : @{
				@"document" : @{@"id" : @701, @"size" : @4096},
				@"file_name" : @"report.pdf",
				@"mime_type" : @"application/pdf",
			},
			@"caption" : @{@"text" : @"a doc"},
		},
	};

	NSDictionary *info = TGMCMediaInfo(message);

	TGTestExpectEqualInteger(&outcome, [info[@"fileId"] integerValue], 701,
			"messageDocument must take fileId from document.document.id");
	TGTestExpectEqualInteger(&outcome, [info[@"size"] integerValue], 4096,
			"messageDocument must take size from document.document.size");
	TGTestExpectTrue(&outcome, [info[@"fileName"] isEqualToString:@"report.pdf"],
			"messageDocument must take fileName from the shared media fields");
	TGTestExpectTrue(&outcome, [info[@"mimeType"] isEqualToString:@"application/pdf"],
			"messageDocument must take mimeType from the shared media fields");
	TGTestExpectTrue(&outcome, [info[@"caption"] isEqualToString:@"a doc"],
			"messageDocument must flatten the caption text");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestMediaInfoForAudio(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"content" : @{
			@"@type" : @"messageAudio",
			@"audio" : @{
				@"audio" : @{@"id" : @801, @"size" : @55555},
				@"duration" : @180,
				@"title" : @"Song Title",
				@"performer" : @"Artist Name",
				@"album_cover_thumbnail" : @{@"file" : @{@"id" : @999}},
			},
		},
	};

	NSDictionary *info = TGMCMediaInfo(message);

	TGTestExpectEqualInteger(&outcome, [info[@"fileId"] integerValue], 801,
			"messageAudio must take fileId from audio.audio.id");
	TGTestExpectEqualInteger(&outcome, [info[@"size"] integerValue], 55555,
			"messageAudio must take size from audio.audio.size");
	TGTestExpectEqualInteger(&outcome, [info[@"duration"] integerValue], 180,
			"messageAudio must take duration from the shared media fields");
	TGTestExpectTrue(&outcome, [info[@"title"] isEqualToString:@"Song Title"],
			"messageAudio must set title from audio.title");
	TGTestExpectTrue(&outcome, [info[@"performer"] isEqualToString:@"Artist Name"],
			"messageAudio must set performer from audio.performer");
	TGTestExpectEqualInteger(&outcome, [info[@"thumbId"] integerValue], 999,
			"messageAudio must take thumbId from its own album_cover_thumbnail, set before the generic fallback runs");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestMediaInfoForVoiceNote(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"content" : @{
			@"@type" : @"messageVoiceNote",
			@"voice_note" : @{
				@"voice" : @{@"id" : @901, @"size" : @2222},
				@"duration" : @12,
				@"waveform" : @"Zm9v",
			},
		},
	};

	NSDictionary *info = TGMCMediaInfo(message);

	unsigned char expectedWaveformBytes[3] = {'f', 'o', 'o'};
	NSData *expectedWaveform = [NSData dataWithBytes:expectedWaveformBytes length:3];

	TGTestExpectEqualInteger(&outcome, [info[@"fileId"] integerValue], 901,
			"messageVoiceNote must take fileId from voice_note.voice.id");
	TGTestExpectEqualInteger(&outcome, [info[@"size"] integerValue], 2222,
			"messageVoiceNote must take size from voice_note.voice.size");
	TGTestExpectEqualInteger(&outcome, [info[@"duration"] integerValue], 12,
			"messageVoiceNote must take duration from the shared media fields");
	TGTestExpectTrue(&outcome, [info[@"waveform"] isEqualToData:expectedWaveform],
			"messageVoiceNote must decode its base64 waveform through the same base64 decoder");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestMediaInfoForVideoNote(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"content" : @{
			@"@type" : @"messageVideoNote",
			@"video_note" : @{
				@"video" : @{@"id" : @1001, @"size" : @3333},
				@"length" : @240,
				@"duration" : @9,
			},
		},
	};

	NSDictionary *info = TGMCMediaInfo(message);

	TGTestExpectEqualInteger(&outcome, [info[@"fileId"] integerValue], 1001,
			"messageVideoNote must take fileId from video_note.video.id");
	TGTestExpectEqualInteger(&outcome, [info[@"size"] integerValue], 3333,
			"messageVideoNote must take size from video_note.video.size");
	TGTestExpectEqualInteger(&outcome, [info[@"width"] integerValue], 240,
			"messageVideoNote must set both width and height from its own length field");
	TGTestExpectEqualInteger(&outcome, [info[@"height"] integerValue], 240,
			"messageVideoNote must set both width and height from its own length field");
	TGTestExpectEqualInteger(&outcome, [info[@"duration"] integerValue], 9,
			"messageVideoNote must take duration from the shared media fields");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestMediaInfoForSticker(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"content" : @{
			@"@type" : @"messageSticker",
			@"sticker" : @{
				@"sticker" : @{@"id" : @1101, @"size" : @4444},
				@"emoji" : @"\U0001F600",
				@"width" : @512,
				@"height" : @512,
			},
		},
	};

	NSDictionary *info = TGMCMediaInfo(message);

	TGTestExpectEqualInteger(&outcome, [info[@"fileId"] integerValue], 1101,
			"messageSticker must take fileId from sticker.sticker.id");
	TGTestExpectEqualInteger(&outcome, [info[@"size"] integerValue], 4444,
			"messageSticker must take size from sticker.sticker.size");
	TGTestExpectTrue(&outcome, [info[@"title"] isEqualToString:@"\U0001F600"],
			"messageSticker must set title from its own emoji field");
	TGTestExpectEqualInteger(&outcome, [info[@"width"] integerValue], 512,
			"messageSticker must take width from the shared media fields since it does not set width itself");
	TGTestExpectEqualInteger(&outcome, [info[@"height"] integerValue], 512,
			"messageSticker must take height from the shared media fields since it does not set height itself");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestMediaInfoForAnimatedEmoji(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"content" : @{
			@"@type" : @"messageAnimatedEmoji",
			@"emoji" : @"\U0001F389",
			@"animated_emoji" : @{
				@"sticker" : @{
					@"sticker" : @{@"id" : @1201, @"size" : @5555},
					@"emoji" : @"\U0001F600",
					@"width" : @256,
					@"height" : @256,
				},
			},
		},
	};

	NSDictionary *info = TGMCMediaInfo(message);

	TGTestExpectEqualInteger(&outcome, [info[@"fileId"] integerValue], 1201,
			"messageAnimatedEmoji must reach into animated_emoji.sticker.sticker.id, one level deeper than messageSticker");
	TGTestExpectEqualInteger(&outcome, [info[@"size"] integerValue], 5555,
			"messageAnimatedEmoji must take size from animated_emoji.sticker.sticker.size");
	TGTestExpectTrue(&outcome, [info[@"title"] isEqualToString:@"\U0001F389"],
			"messageAnimatedEmoji must set title from the message's own top-level emoji field, not the nested sticker's own emoji tag");
	TGTestExpectEqualInteger(&outcome, [info[@"width"] integerValue], 256,
			"messageAnimatedEmoji must take width from the shared media fields");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestMediaInfoReturnsNilForUnsupportedKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"text" : @"hi"},
		},
	};

	TGTestExpectTrue(&outcome, TGMCMediaInfo(message) == nil,
			"a content kind with no media mapping, such as messageText, must produce nil, not a half-filled dictionary");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestMediaInfoReturnsNilForEmptyContent(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGMCMediaInfo(@{@"content" : @{}}) == nil,
			"an empty content dictionary must produce nil, not crash or fabricate a kind");
	TGTestExpectTrue(&outcome, TGMCMediaInfo(nil) == nil,
			"a nil message must produce nil, not crash");
	TGTestExpectTrue(&outcome, TGMCMediaInfo(@{}) == nil,
			"a message with no content key at all must produce nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestFlattenEntitiesMapsVariousKindsAndSkipsMalformed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *raw = @[
		@{@"offset" : @0, @"length" : @4,
			@"type" : @{@"@type" : @"textEntityTypeBold"}},
		@{@"offset" : @5, @"length" : @3,
			@"type" : @{@"@type" : @"textEntityTypeTextUrl", @"url" : @"https://example.com"}},
		@{@"offset" : @9, @"length" : @6,
			@"type" : @{@"@type" : @"textEntityTypeMentionName", @"user_id" : @12345}},
		@{@"offset" : @16, @"length" : @10,
			@"type" : @{@"@type" : @"textEntityTypePreCode", @"language" : @"swift"}},
		@{@"offset" : @26, @"length" : @2,
			@"type" : @{@"@type" : @"textEntityTypeCustomEmoji", @"custom_emoji_id" : @"5368324170671202286"}},
		@{@"offset" : @30, @"length" : @2},
		@"not a dictionary entity",
	];

	NSArray *flat = TGMCFlattenEntities(raw);

	TGTestExpectEqualInteger(&outcome, (NSInteger)flat.count, 5,
			"an entity missing its type and a non-dictionary entry must both be dropped, leaving only the 5 well-formed entities");

	NSDictionary *bold = flat[0];
	TGTestExpectTrue(&outcome, [bold[@"kind"] isEqualToString:@"Bold"],
			"textEntityTypeBold must flatten to kind Bold with the textEntityType prefix stripped");
	TGTestExpectEqualInteger(&outcome, [bold[@"offset"] integerValue], 0,
			"the bold entity's offset must round-trip verbatim");
	TGTestExpectEqualInteger(&outcome, [bold[@"length"] integerValue], 4,
			"the bold entity's length must round-trip verbatim");
	TGTestExpectTrue(&outcome, [bold[@"url"] isEqualToString:@""],
			"the bold entity has no url, so it must default to an empty string, not nil or a crash");

	NSDictionary *textUrl = flat[1];
	TGTestExpectTrue(&outcome, [textUrl[@"kind"] isEqualToString:@"TextUrl"],
			"textEntityTypeTextUrl must flatten to kind TextUrl");
	TGTestExpectTrue(&outcome, [textUrl[@"url"] isEqualToString:@"https://example.com"],
			"the text-url entity's url must round-trip verbatim");

	NSDictionary *mention = flat[2];
	TGTestExpectTrue(&outcome, [mention[@"kind"] isEqualToString:@"MentionName"],
			"textEntityTypeMentionName must flatten to kind MentionName");
	TGTestExpectEqualInteger(&outcome, [mention[@"userId"] integerValue], 12345,
			"the mention entity's userId must round-trip from type.user_id");

	NSDictionary *preCode = flat[3];
	TGTestExpectTrue(&outcome, [preCode[@"kind"] isEqualToString:@"PreCode"],
			"textEntityTypePreCode must flatten to kind PreCode");
	TGTestExpectTrue(&outcome, [preCode[@"language"] isEqualToString:@"swift"],
			"the pre-code entity's language must round-trip from type.language");

	NSDictionary *customEmoji = flat[4];
	TGTestExpectTrue(&outcome, [customEmoji[@"kind"] isEqualToString:@"CustomEmoji"],
			"textEntityTypeCustomEmoji must flatten to kind CustomEmoji");
	TGTestExpectTrue(&outcome,
			[customEmoji[@"customEmojiId"] isKindOfClass:NSNumber.class] &&
				[customEmoji[@"customEmojiId"] longLongValue] == 5368324170671202286LL,
			"the custom-emoji id is serialized by TDLib as a JSON string and must be read back as its exact int64 value, not truncated or defaulted to zero");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestEntityKindStripsPrefixAndPassesThroughOthers(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGMCEntityKind(@"textEntityTypeBold") isEqualToString:@"Bold"],
			"a name with the textEntityType prefix must have exactly that prefix stripped");
	TGTestExpectTrue(&outcome, [TGMCEntityKind(@"textEntityTypeItalic") isEqualToString:@"Italic"],
			"stripping must work for any suffix, not just one hardcoded kind");
	TGTestExpectTrue(&outcome, [TGMCEntityKind(@"customKind") isEqualToString:@"customKind"],
			"a name without the textEntityType prefix must pass through unchanged");
	TGTestExpectTrue(&outcome, [TGMCEntityKind(@"") isEqualToString:@""],
			"an empty name must pass through as an empty string");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestEntityKindFallsBackForNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGMCEntityKind(nil) isEqualToString:@""],
			"a nil type name must flatten to an empty string, not crash");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestSelfDestructImmediateSentinel(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *destruct = TGMCSelfDestruct(kSelfDestructViewOnce);

	TGTestExpectTrue(&outcome, [destruct[@"@type"] isEqualToString:@"messageSelfDestructTypeImmediately"],
			"the view-once sentinel must produce the immediately-typed self-destruct dict, not a timer");
	TGTestExpectTrue(&outcome, destruct[@"self_destruct_time"] == nil,
			"the immediately-typed self-destruct dict must not carry a self_destruct_time key");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestSelfDestructZeroAndNegativeReturnNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGMCSelfDestruct(0) == nil,
			"zero seconds must produce nil, meaning no self-destruct at all");
	TGTestExpectTrue(&outcome, TGMCSelfDestruct(-2) == nil,
			"a negative value other than the view-once sentinel must also produce nil, not a timer with a negative time");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestSelfDestructPositiveSecondsReturnsTimer(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *oneSecond = TGMCSelfDestruct(1);
	NSDictionary *anHour = TGMCSelfDestruct(3600);

	TGTestExpectTrue(&outcome, [oneSecond[@"@type"] isEqualToString:@"messageSelfDestructTypeTimer"],
			"the smallest positive value, 1 second, must already cross into the timer type");
	TGTestExpectEqualInteger(&outcome, [oneSecond[@"self_destruct_time"] integerValue], 1,
			"the timer dict's self_destruct_time must round-trip the requested seconds verbatim");
	TGTestExpectTrue(&outcome, [anHour[@"@type"] isEqualToString:@"messageSelfDestructTypeTimer"],
			"a larger positive value must also produce the timer type");
	TGTestExpectEqualInteger(&outcome, [anHour[@"self_destruct_time"] integerValue], 3600,
			"the timer dict's self_destruct_time must round-trip a larger value verbatim");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestBase64DecodesValidInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	unsigned char expectedBytes[3] = {'f', 'o', 'o'};
	NSData *expected = [NSData dataWithBytes:expectedBytes length:3];

	TGTestExpectTrue(&outcome, [TGMCBase64(@"Zm9v") isEqualToData:expected],
			"a plain, unpadded base64 string must decode to its exact original bytes");

	unsigned char expectedUrlSafeBytes[3] = {0xFB, 0xFF, 0xBE};
	NSData *expectedUrlSafe = [NSData dataWithBytes:expectedUrlSafeBytes length:3];

	TGTestExpectTrue(&outcome, [TGMCBase64(@"-_--") isEqualToData:expectedUrlSafe],
			"the URL-safe alphabet characters - and _ must decode the same as their + and / counterparts");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestBase64DecodesEmptyInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGMCBase64(@"") == nil,
			"an empty string must decode to nil, matching the shared TGBase64Decode convention");
	TGTestExpectTrue(&outcome, TGMCBase64(nil) == nil,
			"a nil value must decode to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestBase64DecodesInputNeedingPadding(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	unsigned char expectedBytes[5] = {'H', 'e', 'l', 'l', 'o'};
	NSData *expected = [NSData dataWithBytes:expectedBytes length:5];

	TGTestExpectTrue(&outcome, [TGMCBase64(@"SGVsbG8=") isEqualToData:expected],
			"a base64 string with a trailing = padding character must decode to the same bytes as if the padding were absent");

	return outcome;
}

TGTestOutcome TGFlattenMessageContentTestBase64SkipsInvalidCharacters(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	unsigned char expectedBytes[5] = {'H', 'e', 'l', 'l', 'o'};
	NSData *expected = [NSData dataWithBytes:expectedBytes length:5];

	TGTestExpectTrue(&outcome, [TGMCBase64(@"SGVs!!!bG8=") isEqualToData:expected],
			"characters outside the base64 alphabet must simply be skipped rather than aborting the decode or corrupting later bytes");

	return outcome;
}

#import "tg_flatten_search_tests.h"
#import "../../src/Wire/Flatten/TGFlattenSearch.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenSearchTestTextForContentPrefersMessageText(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *content = @{
		@"@type" : @"messagePhoto",
		@"text" : @{@"@type" : @"formattedText", @"text" : @"hello world"},
	};

	TGTestExpectTrue(&outcome, [TGSearchTextForContent(content) isEqualToString:@"hello world"],
			"a content dict carrying a formattedText 'text' must return that text verbatim, regardless of its @type");

	return outcome;
}

TGTestOutcome TGFlattenSearchTestTextForContentPrefersNonEmptyCaption(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *content = @{
		@"@type" : @"messagePhoto",
		@"caption" : @{@"@type" : @"formattedText", @"text" : @"a caption"},
	};

	TGTestExpectTrue(&outcome, [TGSearchTextForContent(content) isEqualToString:@"a caption"],
			"a non-empty caption must take priority over the type-specific fallback text");

	return outcome;
}

TGTestOutcome TGFlattenSearchTestTextForContentIgnoresEmptyCaption(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *content = @{
		@"@type" : @"messagePhoto",
		@"caption" : @{@"@type" : @"formattedText", @"text" : @""},
	};

	TGTestExpectTrue(&outcome, [TGSearchTextForContent(content) isEqualToString:@"Photo"],
			"an empty caption must not suppress the type-specific fallback text");

	return outcome;
}

TGTestOutcome TGFlattenSearchTestTextForContentCoversMediaKindsWithoutCaption(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent(@{@"@type" : @"messagePhoto"}) isEqualToString:@"Photo"],
			"messagePhoto with no text or caption must fall back to 'Photo'");
	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent(@{@"@type" : @"messageVideo"}) isEqualToString:@"Video"],
			"messageVideo with no text or caption must fall back to 'Video'");
	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent(@{@"@type" : @"messageVideoNote"}) isEqualToString:@"Video Message"],
			"messageVideoNote with no text or caption must fall back to 'Video Message'");
	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent(@{@"@type" : @"messageVoiceNote"}) isEqualToString:@"Voice message"],
			"messageVoiceNote with no text or caption must fall back to 'Voice message'");
	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent(@{@"@type" : @"messageAnimation"}) isEqualToString:@"GIF"],
			"messageAnimation with no text or caption must fall back to 'GIF'");
	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent(@{@"@type" : @"messageSticker"}) isEqualToString:@"Sticker"],
			"messageSticker with no text or caption must fall back to 'Sticker'");
	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent(@{@"@type" : @"messageLocation"}) isEqualToString:@"Location"],
			"messageLocation with no text or caption must fall back to 'Location'");
	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent(@{@"@type" : @"messageLiveLocation"}) isEqualToString:@"Live location"],
			"messageLiveLocation with no text or caption must fall back to 'Live location'");
	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent(@{@"@type" : @"messageContact"}) isEqualToString:@"Contact"],
			"messageContact with no text or caption must fall back to 'Contact'");
	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent(@{@"@type" : @"messagePoll"}) isEqualToString:@"Poll"],
			"messagePoll with no text or caption must fall back to 'Poll'");
	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent(@{@"@type" : @"messageCall"}) isEqualToString:@"Call"],
			"messageCall with no text or caption must fall back to 'Call'");

	return outcome;
}

TGTestOutcome TGFlattenSearchTestTextForContentDocumentUsesFileNameOrFallback(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *named = @{
		@"@type" : @"messageDocument",
		@"document" : @{@"@type" : @"document", @"file_name" : @"report.pdf"},
	};
	NSDictionary *unnamed = @{
		@"@type" : @"messageDocument",
		@"document" : @{@"@type" : @"document", @"file_name" : @""},
	};

	TGTestExpectTrue(&outcome, [TGSearchTextForContent(named) isEqualToString:@"report.pdf"],
			"messageDocument with a non-empty file_name must return that file name");
	TGTestExpectTrue(&outcome, [TGSearchTextForContent(unnamed) isEqualToString:@"File"],
			"messageDocument with an empty file_name must fall back to 'File'");

	return outcome;
}

TGTestOutcome TGFlattenSearchTestTextForContentAudioUsesTitleOrFallback(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *titled = @{
		@"@type" : @"messageAudio",
		@"audio" : @{@"@type" : @"audio", @"title" : @"Song Name"},
	};
	NSDictionary *untitled = @{
		@"@type" : @"messageAudio",
		@"audio" : @{@"@type" : @"audio", @"title" : @""},
	};

	TGTestExpectTrue(&outcome, [TGSearchTextForContent(titled) isEqualToString:@"Song Name"],
			"messageAudio with a non-empty title must return that title");
	TGTestExpectTrue(&outcome, [TGSearchTextForContent(untitled) isEqualToString:@"Audio"],
			"messageAudio with an empty title must fall back to 'Audio'");

	return outcome;
}

TGTestOutcome TGFlattenSearchTestTextForContentFallsBackForUnknownKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *content = @{@"@type" : @"messageSomethingTelegramAddedLater"};

	TGTestExpectTrue(&outcome, [TGSearchTextForContent(content) isEqualToString:@""],
			"a content @type this build has never heard of flattens to an empty string rather "
			"than crashing or inventing a name for it");
	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent(@{@"@type" : @"messageUnsupported"})
					rangeOfString:@"not supported"].location != NSNotFound,
			"a message TDLib itself calls unsupported says so in the row, where the search "
			"result used to be a blank line");

	return outcome;
}

TGTestOutcome TGFlattenSearchTestTextForContentFallsBackForNonDictionaryInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGSearchTextForContent(nil) isEqualToString:@""],
			"a nil content must flatten to an empty string, not crash");
	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent((NSDictionary *)@"not a dictionary") isEqualToString:@""],
			"a non-dictionary content must flatten to an empty string, not crash");

	return outcome;
}

TGTestOutcome TGFlattenSearchTestPhotoIdForContentMessagePhotoReturnsLargestSize(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *content = @{
		@"@type" : @"messagePhoto",
		@"photo" : @{
			@"sizes" : @[
				@{@"photo" : @{@"id" : @101}},
				@{@"photo" : @{@"id" : @202}},
			],
		},
	};

	NSNumber *photoId = TGSearchPhotoIdForContent(content);

	TGTestExpectTrue(&outcome, photoId != nil,
			"messagePhoto with non-empty sizes must resolve a photo id, not nil");
	TGTestExpectEqualLongLong(&outcome, [photoId longLongValue], 202,
			"messagePhoto must pick the last (largest) size's photo id, not the first");

	return outcome;
}

TGTestOutcome TGFlattenSearchTestPhotoIdForContentMessagePhotoReturnsNilWhenNoSizes(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *content = @{
		@"@type" : @"messagePhoto",
		@"photo" : @{@"sizes" : @[]},
	};

	TGTestExpectTrue(&outcome, TGSearchPhotoIdForContent(content) == nil,
			"messagePhoto with an empty sizes array must resolve to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenSearchTestPhotoIdForContentThumbnailKinds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *video = @{
		@"@type" : @"messageVideo",
		@"video" : @{@"thumbnail" : @{@"file" : @{@"id" : @11}}},
	};
	NSDictionary *videoNote = @{
		@"@type" : @"messageVideoNote",
		@"video_note" : @{@"thumbnail" : @{@"file" : @{@"id" : @12}}},
	};
	NSDictionary *animation = @{
		@"@type" : @"messageAnimation",
		@"animation" : @{@"thumbnail" : @{@"file" : @{@"id" : @13}}},
	};
	NSDictionary *document = @{
		@"@type" : @"messageDocument",
		@"document" : @{@"thumbnail" : @{@"file" : @{@"id" : @14}}},
	};
	NSDictionary *sticker = @{
		@"@type" : @"messageSticker",
		@"sticker" : @{@"thumbnail" : @{@"file" : @{@"id" : @15}}},
	};

	TGTestExpectEqualLongLong(&outcome, [TGSearchPhotoIdForContent(video) longLongValue], 11,
			"messageVideo must resolve its photo id from video.thumbnail.file.id");
	TGTestExpectEqualLongLong(&outcome, [TGSearchPhotoIdForContent(videoNote) longLongValue], 12,
			"messageVideoNote must resolve its photo id from video_note.thumbnail.file.id");
	TGTestExpectEqualLongLong(&outcome, [TGSearchPhotoIdForContent(animation) longLongValue], 13,
			"messageAnimation must resolve its photo id from animation.thumbnail.file.id");
	TGTestExpectEqualLongLong(&outcome, [TGSearchPhotoIdForContent(document) longLongValue], 14,
			"messageDocument must resolve its photo id from document.thumbnail.file.id");
	TGTestExpectEqualLongLong(&outcome, [TGSearchPhotoIdForContent(sticker) longLongValue], 15,
			"messageSticker must resolve its photo id from sticker.thumbnail.file.id");

	return outcome;
}

TGTestOutcome TGFlattenSearchTestPhotoIdForContentReturnsNilWhenThumbnailMissing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *noThumbnail = @{
		@"@type" : @"messageVideo",
		@"video" : @{@"duration" : @5},
	};
	NSDictionary *noMedia = @{
		@"@type" : @"messageVideo",
	};

	TGTestExpectTrue(&outcome, TGSearchPhotoIdForContent(noThumbnail) == nil,
			"a video with no thumbnail dict must resolve to nil, not crash");
	TGTestExpectTrue(&outcome, TGSearchPhotoIdForContent(noMedia) == nil,
			"a video content with no video dict at all must resolve to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenSearchTestPhotoIdForContentReturnsNilForKindWithoutPhotoKey(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *content = @{
		@"@type" : @"messageVoiceNote",
		@"voice_note" : @{@"thumbnail" : @{@"file" : @{@"id" : @99}}},
	};

	TGTestExpectTrue(&outcome, TGSearchPhotoIdForContent(content) == nil,
			"messageVoiceNote has no photo-bearing key in the dispatcher, so it must resolve to nil even with a thumbnail present");

	return outcome;
}

TGTestOutcome TGFlattenSearchTestPhotoIdForContentReturnsNilForNonDictionaryInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGSearchPhotoIdForContent(nil) == nil,
			"a nil content must resolve to nil, not crash");
	TGTestExpectTrue(&outcome, TGSearchPhotoIdForContent((NSDictionary *)@42) == nil,
			"a non-dictionary content must resolve to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenSearchTestRowsNameTheKindsTheyCannotQuote(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent(@{@"@type" : @"messageChecklist"})
					isEqualToString:@"Checklist"],
			"a checklist names itself in a search row, where the row used to be blank");
	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent(@{@"@type" : @"messagePaidMedia"})
					isEqualToString:@"Paid media"],
			"and so does a paid post");
	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent(@{@"@type" : @"messageExpiredPhoto"})
					isEqualToString:@"Photo has expired"],
			"and an expired photo");
	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent(@{@"@type" : @"messageGroupCall", @"was_missed" : @NO})
					isEqualToString:@"Incoming Group Call"],
			"and a group call, in the words the chat uses for it");

	NSDictionary *secretPhoto = @{@"@type" : @"messagePhoto", @"is_secret" : @YES,
		@"caption" : @{@"text" : @"the words meant to be seen once"}};
	TGTestExpectTrue(&outcome,
			[TGSearchTextForContent(secretPhoto) isEqualToString:@"Disappearing Photo"],
			"a disappearing photo names itself in search too, rather than handing its caption "
			"to a list of results anyone can scroll");

	return outcome;
}

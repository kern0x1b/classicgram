#import "tg_media_preview_name_tests.h"
#import "../../src/Wire/Flatten/TGMediaPreviewName.h"

TGTestOutcome TGMediaPreviewNameTestARowNamesTheFileItIsAbout(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *document = @{@"@type" : @"messageDocument",
		@"document" : @{@"file_name" : @"Legacy Archive iOS 3-15.zip"}};
	TGTestExpectTrue(&outcome,
			[TGMediaPreviewName(document) isEqualToString:@"Legacy Archive iOS 3-15.zip"],
			"a document is named by its file, not by the word document");
	TGTestExpectTrue(&outcome, TGMediaPreviewName(@{@"@type" : @"messageDocument",
			@"document" : @{@"file_name" : @""}}) == nil,
			"a document with no file name leaves the caller to say what it is");
	TGTestExpectTrue(&outcome, TGMediaPreviewName(@{@"@type" : @"messageDocument"}) == nil,
			"a document with no document at all is not a crash");

	NSDictionary *track = @{@"@type" : @"messageAudio",
		@"audio" : @{@"title" : @"Blue in Green", @"performer" : @"Miles Davis"}};
	TGTestExpectTrue(&outcome, [TGMediaPreviewName(track) isEqualToString:@"Blue in Green — Miles Davis"],
			"a track reads title then performer, the order the modern client uses");
	TGTestExpectTrue(&outcome, [TGMediaPreviewName(@{@"@type" : @"messageAudio",
			@"audio" : @{@"title" : @"Blue in Green"}}) isEqualToString:@"Blue in Green"],
			"a title on its own carries no dash");
	TGTestExpectTrue(&outcome, [TGMediaPreviewName(@{@"@type" : @"messageAudio",
			@"audio" : @{@"performer" : @"Miles Davis"}}) isEqualToString:@"Miles Davis"],
			"a performer on its own is better than nothing");
	TGTestExpectTrue(&outcome, [TGMediaPreviewName(@{@"@type" : @"messageAudio",
			@"audio" : @{@"file_name" : @"track01.mp3"}}) isEqualToString:@"track01.mp3"],
			"an untagged track falls back to its file name");

	TGTestExpectTrue(&outcome, TGMediaPreviewName(@{@"@type" : @"messagePhoto"}) == nil,
			"a photo has no name to show");
	TGTestExpectTrue(&outcome, TGMediaPreviewName(nil) == nil, "no content is no name");
	TGTestExpectTrue(&outcome, TGMediaPreviewName(@{@"@type" : @"messageAudio",
			@"audio" : @{@"title" : @42}}) == nil,
			"a title that is not a string is not read as one");

	return outcome;
}

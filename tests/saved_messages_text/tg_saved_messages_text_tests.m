#import "tg_saved_messages_text_tests.h"
#import "../../src/Screens/Chat/TGSavedMessagesText.h"

TGTestOutcome TGSavedMessagesTextTestFilterForEachScope(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGSavedFilterForScope(0) == nil,
			"the chats scope searches everything, so it must send no filter at all");
	TGTestExpectTrue(&outcome,
			[TGSavedFilterForScope(1) isEqualToString:@"searchMessagesFilterPhotoAndVideo"],
			"the media scope must name the schema's own photo-and-video filter");
	TGTestExpectTrue(&outcome,
			[TGSavedFilterForScope(2) isEqualToString:@"searchMessagesFilterDocument"],
			"the files scope maps to the document filter");
	TGTestExpectTrue(&outcome,
			[TGSavedFilterForScope(3) isEqualToString:@"searchMessagesFilterAudio"],
			"the music scope maps to the audio filter, not the voice-note one");
	TGTestExpectTrue(&outcome,
			[TGSavedFilterForScope(4) isEqualToString:@"searchMessagesFilterUrl"],
			"the links scope maps to the url filter");
	TGTestExpectTrue(&outcome, TGSavedFilterForScope(5) == nil,
			"a scope index the scope bar cannot produce must fall back to no filter rather than a wrong one");
	TGTestExpectTrue(&outcome, TGSavedFilterForScope(-1) == nil,
			"a negative scope must not index past the switch");

	return outcome;
}

TGTestOutcome TGSavedMessagesTextTestEmptyStateDiffersPerScope(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSMutableSet *titles = [NSMutableSet set];
	NSMutableSet *texts = [NSMutableSet set];
	for (NSInteger scope = 0; scope <= 4; scope++) {
		NSString *title = TGSavedEmptyTitleForScope(scope);
		NSString *text = TGSavedEmptyTextForScope(scope);
		TGTestExpectTrue(&outcome, title.length > 0 && text.length > 0,
				"every scope needs its own empty-state title and body, or the placeholder reads as a bug");
		[titles addObject:title];
		[texts addObject:text];
	}
	TGTestExpectEqualInteger(&outcome, (NSInteger)titles.count, 5,
			"the five scopes must not share an empty-state title: a copy-paste would tell the user the wrong "
			"thing is missing");
	TGTestExpectEqualInteger(&outcome, (NSInteger)texts.count, 5,
			"nor an empty-state body");
	TGTestExpectTrue(&outcome,
			[TGSavedEmptyTitleForScope(9) isEqualToString:TGSavedEmptyTitleForScope(0)],
			"an out-of-range scope falls back to the generic empty state");

	return outcome;
}

TGTestOutcome TGSavedMessagesTextTestKindLabelCoversEveryMediaKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *kinds = @[ @"messagePhoto", @"messageVideo", @"messageVideoNote", @"messageVoiceNote",
		@"messageAudio", @"messageDocument", @"messageAnimation", @"messageSticker" ];
	NSMutableSet *labels = [NSMutableSet set];
	for (NSString *kind in kinds) {
		NSString *label = TGSavedKindLabel(kind);
		TGTestExpectTrue(&outcome, label.length > 0,
				"each media kind a saved message can hold needs a label, or its row shows a bare timestamp");
		[labels addObject:label];
	}
	TGTestExpectTrue(&outcome, labels.count >= 7,
			"the labels must be nearly all distinct: a photo and a video reading the same would make the row "
			"useless");

	return outcome;
}

TGTestOutcome TGSavedMessagesTextTestKindLabelIsEmptyForAnythingElse(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGSavedKindLabel(@"messageText") isEqualToString:@""],
			"a text message needs no kind label: its own text is shown instead");
	TGTestExpectTrue(&outcome, [TGSavedKindLabel(@"messageSomethingNewerTdlibAdded") isEqualToString:@""],
			"an unknown kind must produce no label rather than a placeholder");
	TGTestExpectTrue(&outcome, [TGSavedKindLabel(nil) isEqualToString:@""],
			"a nil kind must answer empty rather than crash");
	TGTestExpectTrue(&outcome, [TGSavedKindLabel((NSString *)@42) isEqualToString:@""],
			"a non-string kind coming off the wire must answer empty rather than be messaged as a string");

	return outcome;
}

TGTestOutcome TGSavedMessagesTextTestShortTextTruncatesAtTheLimit(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSavedShortText(@{@"text" : @"0123456789"}, 10) isEqualToString:@"0123456789"],
			"text of exactly the limit is not truncated");
	TGTestExpectTrue(&outcome,
			[TGSavedShortText(@{@"text" : @"01234567890"}, 10) isEqualToString:@"0123456789…"],
			"one character past the limit trips truncation and appends the ellipsis character, not three dots");

	NSString *emoji = TGSavedShortText(@{@"text" : @"aaaaaaaaa\U0001F642bb"}, 10);
	TGTestExpectTrue(&outcome, [emoji hasSuffix:@"…"],
			"truncation goes through the surrogate-safe substring, so an emoji straddling the limit is not cut "
			"in half");

	return outcome;
}

TGTestOutcome TGSavedMessagesTextTestShortTextFallsBackToTheMediaLabel(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *fallback = TGSavedShortText(@{}, 24);
	TGTestExpectTrue(&outcome, fallback.length > 0,
			"a message with no text still needs a row line: the media label stands in");
	TGTestExpectTrue(&outcome,
			[TGSavedShortText(@{@"text" : @""}, 24) isEqualToString:fallback],
			"an empty string is treated as no text at all");
	TGTestExpectTrue(&outcome,
			[TGSavedShortText(@{@"text" : @42}, 24) isEqualToString:fallback],
			"a non-string text off the wire falls back rather than crashing");

	return outcome;
}

TGTestOutcome TGSavedMessagesTextTestTopicKindIsAlwaysAString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGSavedTopicKind(@{@"kind" : @"myNotes"}) isEqualToString:@"myNotes"],
			"a real kind passes through");
	TGTestExpectTrue(&outcome, [TGSavedTopicKind(@{}) isEqualToString:@""],
			"a topic with no kind yields an empty string, which the callers compare against safely");
	TGTestExpectTrue(&outcome, [TGSavedTopicKind(@{@"kind" : @7}) isEqualToString:@""],
			"a non-string kind yields an empty string rather than a number pretending to be one");

	return outcome;
}

TGTestOutcome TGSavedMessagesTextTestKindLabelFallsThroughToTheSharedTable(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGSavedKindLabel(@"messagePhoto") isEqualToString:@"Photo"],
			"the kinds this screen knows itself are unchanged");
	TGTestExpectTrue(&outcome,
			[TGSavedKindLabel(@"messageChecklist") isEqualToString:@"Checklist"],
			"a checklist is named by the shared table rather than labelled Media");
	TGTestExpectTrue(&outcome,
			[TGSavedKindLabel(@"messagePoll") isEqualToString:@"Poll"],
			"and so is a poll");
	TGTestExpectTrue(&outcome,
			[TGSavedKindLabel(@"messageSomethingTelegramAddedLater") isEqualToString:@""],
			"a kind nothing knows still answers an empty string, which the row turns into "
			"its own Media wording");
	TGTestExpectTrue(&outcome, [TGSavedKindLabel(nil) isEqualToString:@""],
			"and so does no kind at all");

	return outcome;
}

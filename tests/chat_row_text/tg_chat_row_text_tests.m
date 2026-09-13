#import "tg_chat_row_text_tests.h"
#import "../../src/Screens/Chat/TGChatRowText.h"

TGTestOutcome TGChatRowTextTestPinnedDescriptorPrefersTheContentKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGPinnedDescriptor(@{@"kind" : @"messagePhoto", @"text" : @"ignore me"})
					isEqualToString:@"a photo"],
			"a pinned photo is announced by its kind: the caption must not be quoted instead");
	TGTestExpectTrue(&outcome,
			[TGPinnedDescriptor(@{@"kind" : @"messageVoiceNote"}) isEqualToString:@"a voice message"],
			"each media kind gets its own descriptor");

	return outcome;
}

TGTestOutcome TGChatRowTextTestPinnedDescriptorQuotesAndFlattensTheBody(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGPinnedDescriptor(@{@"kind" : @"messageText", @"text" : @"hi"}) isEqualToString:@"\"hi\""],
			"a pinned text message is quoted");
	TGTestExpectTrue(&outcome,
			[TGPinnedDescriptor(@{@"kind" : @"messageText", @"text" : @"one\ntwo"})
					isEqualToString:@"\"one two\""],
			"the banner is one line, so newlines in the pinned body must become spaces");
	TGTestExpectTrue(&outcome,
			[TGPinnedDescriptor(@{@"kind" : @"messageText", @"text" : @"  padded  "})
					isEqualToString:@"\"padded\""],
			"surrounding whitespace must be trimmed before quoting, or the quotes look misplaced");

	return outcome;
}

TGTestOutcome TGChatRowTextTestPinnedDescriptorTruncatesALongBody(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGPinnedDescriptor(@{@"kind" : @"messageText", @"text" : @"01234567890123"})
					isEqualToString:@"\"01234567890123\""],
			"a body of exactly fourteen characters is not truncated");
	TGTestExpectTrue(&outcome,
			[TGPinnedDescriptor(@{@"kind" : @"messageText", @"text" : @"012345678901234"})
					isEqualToString:@"\"01234567890123...\""],
			"a fifteenth character trips the truncation and the ellipsis is appended inside the quotes");

	NSString *emoji = TGPinnedDescriptor(@{@"kind" : @"messageText",
		@"text" : @"aaaaaaaaaaaaa\U0001F642bbb"});
	TGTestExpectTrue(&outcome, [emoji hasSuffix:@"...\""],
			"truncation must go through the surrogate-safe substring: cutting an emoji in half would produce "
			"a broken code unit in the banner");

	return outcome;
}

TGTestOutcome TGChatRowTextTestPinnedDescriptorFallsBackForAnEmptyBody(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGPinnedDescriptor(@{@"kind" : @"messageText", @"text" : @"   "})
					isEqualToString:@"a message"],
			"a whitespace-only body leaves nothing to quote, so the generic wording is used");
	TGTestExpectTrue(&outcome, [TGPinnedDescriptor(@{}) isEqualToString:@"a message"],
			"an unknown kind with no text falls back rather than quoting an empty string");
	TGTestExpectTrue(&outcome, [TGPinnedDescriptor(nil) isEqualToString:@"a message"],
			"a missing target must not crash the banner");

	return outcome;
}

TGTestOutcome TGChatRowTextTestFileStatusKindOrdersPlayingOverEverything(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *downloading = @{@"active" : @YES, @"local" : @NO};

	TGTestExpectEqualInteger(&outcome,
			TGFileStatusKindForState(downloading, YES, YES), TGFileStatusKindPause,
			"a playing file shows pause even while its download is still active");
	TGTestExpectEqualInteger(&outcome,
			TGFileStatusKindForState(downloading, YES, NO), TGFileStatusKindProgress,
			"an active download that is not playing shows progress, not the play glyph");
	TGTestExpectEqualInteger(&outcome,
			TGFileStatusKindForState(@{@"active" : @YES, @"local" : @YES}, NO, NO),
			TGFileStatusKindFile,
			"a file already local is not showing progress even if a stale active flag says otherwise");

	return outcome;
}

TGTestOutcome TGChatRowTextTestFileStatusKindDistinguishesLocalFromDownloadable(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualInteger(&outcome,
			TGFileStatusKindForState(@{@"local" : @YES}, YES, NO), TGFileStatusKindPlay,
			"a playable local file offers play");
	TGTestExpectEqualInteger(&outcome,
			TGFileStatusKindForState(@{@"local" : @YES}, NO, NO), TGFileStatusKindFile,
			"a local file that cannot be played shows the file glyph");
	TGTestExpectEqualInteger(&outcome,
			TGFileStatusKindForState(@{@"local" : @NO}, NO, NO), TGFileStatusKindDownload,
			"a file not on disk and not downloading offers download");
	TGTestExpectEqualInteger(&outcome,
			TGFileStatusKindForState(@{}, NO, NO), TGFileStatusKindDownload,
			"an empty state means nothing is known to be local, so download is the safe glyph");

	return outcome;
}

TGTestOutcome TGChatRowTextTestClockTextPadsSecondsAndClampsNegative(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGClockText(0) isEqualToString:@"0:00"],
			"zero reads 0:00");
	TGTestExpectTrue(&outcome, [TGClockText(9) isEqualToString:@"0:09"],
			"seconds are zero-padded");
	TGTestExpectTrue(&outcome, [TGClockText(605) isEqualToString:@"10:05"],
			"minutes are not padded, matching the duration labels the chat rows draw");
	TGTestExpectTrue(&outcome, [TGClockText(-30) isEqualToString:@"0:00"],
			"a negative duration clamps rather than printing a negative clock");

	return outcome;
}

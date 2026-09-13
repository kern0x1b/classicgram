#import "tg_mention_trigger_tests.h"
#import "../../src/Utilities/TGMentionTrigger.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGMentionTriggerTestAtStartOfTextIsATrigger(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSRange range = TGMentionTriggerRangeInText(@"@abc", 4);

	TGTestExpectTrue(&outcome, NSEqualRanges(range, NSMakeRange(0, 4)),
			"an at sign at the very start of the text followed by word characters up to the caret must trigger over the whole span");

	return outcome;
}

TGTestOutcome TGMentionTriggerTestAfterWhitespaceIsATrigger(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSRange range = TGMentionTriggerRangeInText(@" @abc", 5);

	TGTestExpectTrue(&outcome, NSEqualRanges(range, NSMakeRange(1, 4)),
			"an at sign preceded by whitespace must trigger over the at sign and the word up to the caret");

	return outcome;
}

TGTestOutcome TGMentionTriggerTestBareAtSignIsATriggerWithEmptyQuery(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSRange range = TGMentionTriggerRangeInText(@"@", 1);

	TGTestExpectTrue(&outcome, NSEqualRanges(range, NSMakeRange(0, 1)),
			"a bare at sign with the caret right after it must trigger with an empty query");

	return outcome;
}

TGTestOutcome TGMentionTriggerTestAtSignGluedToPrecedingWordIsNotATrigger(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSRange range = TGMentionTriggerRangeInText(@"foo@bar", 7);

	TGTestExpectTrue(&outcome, range.location == NSNotFound,
			"an at sign glued to a preceding word character, like an email address, must not trigger");

	return outcome;
}

TGTestOutcome TGMentionTriggerTestSpaceAfterAtSignEndsTheTrigger(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSRange range = TGMentionTriggerRangeInText(@"@abc ", 5);

	TGTestExpectTrue(&outcome, range.location == NSNotFound,
			"once a space has been typed after the mention word the trigger must no longer be active");

	return outcome;
}

TGTestOutcome TGMentionTriggerTestPunctuationAfterAtSignEndsTheTrigger(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSRange range = TGMentionTriggerRangeInText(@"@ab.cd", 6);

	TGTestExpectTrue(&outcome, range.location == NSNotFound,
			"punctuation between the at sign and the caret must not be treated as part of the mention word");

	return outcome;
}

TGTestOutcome TGMentionTriggerTestNoAtSignIsNotATrigger(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSRange range = TGMentionTriggerRangeInText(@"hello world", 11);

	TGTestExpectTrue(&outcome, range.location == NSNotFound,
			"text with no at sign before the caret must never trigger");

	return outcome;
}

TGTestOutcome TGMentionTriggerTestCaretMidwordNarrowsTheQueryToTheCaret(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSRange range = TGMentionTriggerRangeInText(@"@abcdef", 4);

	TGTestExpectTrue(&outcome, NSEqualRanges(range, NSMakeRange(0, 4)),
			"the trigger span must stop at the caret even when the mention word continues past it");

	return outcome;
}

TGTestOutcome TGMentionTriggerTestCaretPastEndOfTextClampsToTextLength(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSRange range = TGMentionTriggerRangeInText(@"@abc", 999);

	TGTestExpectTrue(&outcome, NSEqualRanges(range, NSMakeRange(0, 4)),
			"a caret location past the end of the text must be clamped to the text length rather than reading out of bounds");

	return outcome;
}

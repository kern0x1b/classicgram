#import "tg_text_selection_word_range_tests.h"
#import "../../src/Utilities/TGTextSelectionWordRange.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGTextSelectionWordRangeTestPlainAsciiWordExpandsToWholeWord(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSRange range = TGTextSelectionWordRangeInText(@"hello world", 2);

	TGTestExpectTrue(&outcome, NSEqualRanges(range, NSMakeRange(0, 5)),
			"an index inside a plain ascii word must expand to the whole word");

	return outcome;
}

TGTestOutcome TGTextSelectionWordRangeTestIndexOnHighSurrogateReturnsWholePair(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	unichar chars[] = {'a', 'b', 0xD83D, 0xDE00, 'c', 'd'};
	NSString *text = [NSString stringWithCharacters:chars length:6];

	NSRange range = TGTextSelectionWordRangeInText(text, 2);

	TGTestExpectTrue(&outcome, NSEqualRanges(range, NSMakeRange(2, 2)),
			"an index on the high half of a surrogate pair must return the whole two-unit pair, never a lone unit");

	return outcome;
}

TGTestOutcome TGTextSelectionWordRangeTestIndexOnLowSurrogateReturnsWholePair(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	unichar chars[] = {'a', 'b', 0xD83D, 0xDE00, 'c', 'd'};
	NSString *text = [NSString stringWithCharacters:chars length:6];

	NSRange range = TGTextSelectionWordRangeInText(text, 3);

	TGTestExpectTrue(&outcome, NSEqualRanges(range, NSMakeRange(2, 2)),
			"an index on the low half of a surrogate pair must snap to the whole pair rather than splitting it");

	return outcome;
}

TGTestOutcome TGTextSelectionWordRangeTestWordAfterEmojiDoesNotMergeAcrossIt(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	unichar chars[] = {'a', 'b', 0xD83D, 0xDE00, 'c', 'd'};
	NSString *text = [NSString stringWithCharacters:chars length:6];

	NSRange range = TGTextSelectionWordRangeInText(text, 4);

	TGTestExpectTrue(&outcome, NSEqualRanges(range, NSMakeRange(4, 2)),
			"a word that starts right after a surrogate pair must expand on its own, not merge across the emoji");

	return outcome;
}

TGTestOutcome TGTextSelectionWordRangeTestIndexPastEndOfTextClampsToLastCharacter(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSRange range = TGTextSelectionWordRangeInText(@"hi", 999);

	TGTestExpectTrue(&outcome, NSEqualRanges(range, NSMakeRange(0, 2)),
			"an index past the end of the text must clamp to the last character rather than reading out of bounds");

	return outcome;
}

TGTestOutcome TGTextSelectionWordRangeTestEmptyTextReturnsZeroRange(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSRange range = TGTextSelectionWordRangeInText(@"", 0);

	TGTestExpectTrue(&outcome, NSEqualRanges(range, NSMakeRange(0, 0)),
			"empty text must return a zero range rather than crashing");

	return outcome;
}

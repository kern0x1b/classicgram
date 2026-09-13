#import "tg_single_line_preview_tests.h"
#import "../../src/Utilities/TGSingleLinePreview.h"

TGTestOutcome TGSingleLinePreviewTestFlattensWhatAListRowShows(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSingleLinePreviewText(@"first line\nsecond line") isEqualToString:@"first line second line"],
			"a message written on two lines previews as one");
	TGTestExpectTrue(&outcome,
			[TGSingleLinePreviewText(@"link\n\n\nmore") isEqualToString:@"link more"],
			"a run of blank lines collapses to a single space");
	TGTestExpectTrue(&outcome,
			[TGSingleLinePreviewText(@"  padded  \n ") isEqualToString:@"padded"],
			"leading and trailing space go, so the row never starts with a gap");
	TGTestExpectTrue(&outcome,
			[TGSingleLinePreviewText(@"one\ttwo") isEqualToString:@"one two"],
			"a tab counts as a break too");
	TGTestExpectTrue(&outcome, [TGSingleLinePreviewText(@"\n\n") isEqualToString:@""],
			"a message of nothing but newlines previews as nothing");
	TGTestExpectTrue(&outcome,
			[TGSingleLinePreviewText(@"plain text") isEqualToString:@"plain text"],
			"text that is already one line is unchanged");
	TGTestExpectTrue(&outcome, TGSingleLinePreviewText(nil) == nil,
			"no text stays no text");

	return outcome;
}

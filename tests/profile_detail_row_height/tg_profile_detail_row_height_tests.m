#import "tg_profile_detail_row_height_tests.h"
#import "../../src/Screens/Profile/TGProfileDetailRowHeight.h"

static UIFont *TGProfileDetailTestFont(void) {
	return [UIFont boldSystemFontOfSize:15];
}

TGTestOutcome TGProfileDetailRowHeightTestOneLineValueKeepsTheStandardRow(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGFloat height = TGProfileDetailRowHeightForValue(@"+48 123 456 789",
			TGProfileDetailTestFont(), 300);

	TGTestExpectTrue(&outcome, height == 44,
			"a value that fits on one line leaves the row at the standard 44 points");
	TGTestExpectTrue(&outcome, TGProfileDetailRowHeightForValue(@"", TGProfileDetailTestFont(), 300) == 44,
			"an empty value is still a 44 point row");
	TGTestExpectTrue(&outcome, TGProfileDetailRowHeightForValue(nil, TGProfileDetailTestFont(), 300) == 44,
			"a missing value is a 44 point row rather than a crash");

	return outcome;
}

TGTestOutcome TGProfileDetailRowHeightTestALongValueGrowsTheRow(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *bio = @"Sometimes I write long lines about nothing in particular, "
		"just to see how the profile screen copes with a bio that will not fit on one line.";
	CGFloat narrow = TGProfileDetailRowHeightForValue(bio, TGProfileDetailTestFont(), 300);
	CGFloat wide = TGProfileDetailRowHeightForValue(bio, TGProfileDetailTestFont(), 700);

	TGTestExpectTrue(&outcome, narrow > 44,
			"a value that wraps must make the row taller than the standard one");
	TGTestExpectTrue(&outcome, wide < narrow,
			"the same value in a wider table needs fewer lines, so a shorter row");
	TGTestExpectTrue(&outcome,
			narrow == TGProfileDetailValueHeight(bio, TGProfileDetailTestFont(), 300) + 22,
			"the row is the measured value plus the padding above and below it");

	return outcome;
}

TGTestOutcome TGProfileDetailRowHeightTestNarrowTablesKeepAUsableValueColumn(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGProfileDetailValueWidthForContentWidth(300) == 210,
			"the value column is what is left after the label column and the right margin");
	TGTestExpectTrue(&outcome, TGProfileDetailValueWidthForContentWidth(100) == 40,
			"a table too narrow for the arithmetic still leaves a 40 point column");
	TGTestExpectTrue(&outcome, TGProfileDetailValueWidthForContentWidth(0) == 40,
			"a width of zero, which is what a table reports before it is laid out, gives the same floor");

	return outcome;
}

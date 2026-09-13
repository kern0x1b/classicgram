#import "tg_grouped_caption_tests.h"

#import "../../src/Theme/TGGroupedCaption.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGGroupedCaptionTestASectionWithNoFooterKeepsItsGap(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGGroupedFooterHeight(nil, 0) == 1,
			"a section with nothing to say still keeps the hair of space that holds the "
			"next group off it");
	TGTestExpectTrue(&outcome, TGGroupedFooterHeight(@"", 0) == 1,
			"and an empty caption is the same as none");
	TGTestExpectTrue(&outcome, TGGroupedFooterHeight(@"Only shown to contacts.", 0) == 1,
			"a caption the theme measured as nothing cannot collapse the gap either");

	return outcome;
}

TGTestOutcome TGGroupedCaptionTestAFooterIsAsTallAsItsText(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGGroupedFooterHeight(@"Only shown to contacts.", 34) == 34,
			"a caption is given the height the theme measured for it");

	return outcome;
}

TGTestOutcome TGGroupedCaptionTestARowReadsAsTheOriginalDid(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	UIFont *title = TGGroupedRowTitleFont();
	UIFont *value = TGGroupedRowValueFont();

	TGTestExpectTrue(&outcome, title.pointSize == 17.0f && title.isBold,
			"a grouped row's title is bold 17, which is what the 2013 rows were; regular 17 is "
			"the iOS 7 look this app is not");
	TGTestExpectTrue(&outcome, value.pointSize == 16.0f && !value.isBold,
			"and the value on its right is regular 16, not the 15 one screen had chosen");

	return outcome;
}

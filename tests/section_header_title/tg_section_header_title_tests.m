#import "tg_section_header_title_tests.h"

#import "../../src/Theme/TGSectionHeaderTitle.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGSectionHeaderTitleTestAnEmptySectionHasNoHeader(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGSectionHeaderTitle(@"OPEN IN-APP", 0) == nil,
			"a section with no rows draws no header, where the screen used to show a "
			"heading over nothing");
	TGTestExpectTrue(&outcome, TGSectionHeaderTitle(@"OPEN IN-APP", -1) == nil,
			"and a count that cannot be right is treated as empty");

	return outcome;
}

TGTestOutcome TGSectionHeaderTitleTestASectionWithRowsKeepsIts(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSectionHeaderTitle(@"OPEN IN-APP", 1) isEqualToString:@"OPEN IN-APP"],
			"one row is enough to keep the heading");

	return outcome;
}

TGTestOutcome TGSectionHeaderTitleTestMissingTitleIsHandled(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGSectionHeaderTitle(nil, 3) == nil,
			"a section with no title of its own still has none");

	return outcome;
}

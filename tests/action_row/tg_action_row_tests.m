#import "tg_action_row_tests.h"

#import "../../src/Theme/TGGroupedCaption.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGActionRowTestTheRowIsTheHeightOfThePlate(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGActionRowHeight() == 45.0f,
			"the row a plate stands in is the 45pt of the original, not the 44pt of an "
			"ordinary row");
	TGTestExpectTrue(&outcome, TGActionRowButtonFrame(320).size.height == TGActionRowHeight(),
			"and the plate fills that row from top to bottom");

	return outcome;
}

TGTestOutcome TGActionRowTestTheButtonFillsTheRow(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGRect frame = TGActionRowButtonFrame(320);

	TGTestExpectTrue(&outcome, frame.origin.x == 9.0f,
			"the plate is inset by the 9pt of the original");
	TGTestExpectTrue(&outcome, frame.size.width == 302.0f,
			"and is inset by the same on the other side, whatever the screen is wide");
	TGTestExpectTrue(&outcome, TGActionRowButtonFrame(768).size.width == 750.0f,
			"the inset is the same on the wider screen, which is what a hard-coded width "
			"would get wrong");

	return outcome;
}

TGTestOutcome TGActionRowTestTheRowIsAskedOnce(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGActionRowButtonFrame(0).size.width == 0.0f,
			"a cell that has not been laid out yet gives the plate no width rather than a "
			"negative one");

	return outcome;
}

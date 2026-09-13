#import "tg_row_colours_tests.h"

#import "../../src/Theme/TGRowColours.h"

#import <Foundation/Foundation.h>

static void TGRowColoursComponents(UIColor *colour, int *red, int *green, int *blue) {
	CGFloat r = 0, g = 0, b = 0, a = 0;
	[colour getRed:&r green:&g blue:&b alpha:&a];
	*red = (int)(r * 255.0f + 0.5f);
	*green = (int)(g * 255.0f + 0.5f);
	*blue = (int)(b * 255.0f + 0.5f);
}

TGTestOutcome TGRowColoursTestTheValueOnTheRightOfARow(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	int red = 0, green = 0, blue = 0;
	TGRowColoursComponents(TGSettingsValueColour(), &red, &green, &blue);

	TGTestExpectTrue(&outcome, red == 0x35 && green == 0x65 && blue == 0x96,
			"the value on the right of a settings row is the 0x356596 of the original, which "
			"sixteen screens used to write out for themselves");

	return outcome;
}

TGTestOutcome TGRowColoursTestAnEmptyListSaysSoInOneColour(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	int red = 0, green = 0, blue = 0;
	TGRowColoursComponents(TGEmptyStateColour(), &red, &green, &blue);

	TGTestExpectTrue(&outcome, red == 0x86 && green == 0x94 && blue == 0xa4,
			"the line a list shows when it holds nothing is one colour across the app");

	return outcome;
}

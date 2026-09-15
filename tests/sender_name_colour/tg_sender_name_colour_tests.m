#import "tg_sender_name_colour_tests.h"
#import "../../src/Views/TGSenderNameColour.h"

TGTestOutcome TGSenderNameColourTestTheColourEachSenderKeeps(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGSenderNameRgbForId(0) == 0xee4928,
		"the first sender takes the first colour of the 2013 palette");
	TGTestExpectTrue(&outcome, TGSenderNameRgbForId(7) == 0xeb7002,
		"the eighth takes the last of the eight");
	TGTestExpectTrue(&outcome, TGSenderNameRgbForId(8) == TGSenderNameRgbForId(0),
		"the palette wraps, so every ninth sender repeats the first colour");
	TGTestExpectTrue(&outcome, TGSenderNameRgbForId(-3) == TGSenderNameRgbForId(3),
		"a negative id picks the same colour as its positive twin");
	TGTestExpectTrue(&outcome, TGSenderNameRgbForId(12345) == TGSenderNameRgbForId(12345),
		"the same sender keeps the same colour between calls");

	return outcome;
}

TGTestOutcome TGSenderNameColourTestAChosenColourWins(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGSenderNameRgb(@(0x123456), 3) == 0x123456,
		"a sender who chose a name colour is drawn in it, not in the palette colour");
	TGTestExpectTrue(&outcome, TGSenderNameRgb(nil, 3) == TGSenderNameRgbForId(3),
		"a sender with no chosen colour keeps the palette colour");
	TGTestExpectTrue(&outcome, TGSenderNameRgb((NSNumber *)[NSNull null], 5)
			== TGSenderNameRgbForId(5),
		"a missing colour that arrived as null is not mistaken for a chosen one");

	return outcome;
}

#import "tg_clock_marker_tests.h"

#import "../../src/Utilities/TGClockMarker.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGClockMarkerTestEnglishMarkerIsFound(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGClockMarkerInTime(@"3:04 PM", @"AM", @"PM") isEqualToString:@"PM"],
			"an afternoon time gives the pm symbol");
	TGTestExpectTrue(&outcome,
			[TGClockMarkerInTime(@"11:59 AM", @"AM", @"PM") isEqualToString:@"AM"],
			"a morning time gives the am symbol");

	return outcome;
}

TGTestOutcome TGClockMarkerTestLowercaseMarkerIsFound(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGClockMarkerInTime(@"3:04 pm", @"am", @"pm") isEqualToString:@"pm"],
			"a locale whose symbols are lowercase is matched too");

	return outcome;
}

TGTestOutcome TGClockMarkerTestLocalisedMarkerIsFound(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *morning = [[NSString alloc] initWithUTF8String:"\xE4\xB8\x8A\xE5\x8D\x88"];
	NSString *evening = [[NSString alloc] initWithUTF8String:"\xE4\xB8\x8B\xE5\x8D\x88"];
	NSString *time = [@"3:04 " stringByAppendingString:evening];

	TGTestExpectTrue(&outcome,
			[TGClockMarkerInTime(time, morning, evening) isEqualToString:evening],
			"a marker that is neither two letters nor ascii is still the marker, where "
			"a hard-coded \" PM\" test would have left it drawn in the wrong font");
	TGTestExpectTrue(&outcome,
			[TGTimeWithoutClockMarker(time, evening) isEqualToString:@"3:04"],
			"and it comes off the time the same way");

	return outcome;
}

TGTestOutcome TGClockMarkerTestTwentyFourHourTimeHasNoMarker(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGClockMarkerInTime(@"15:04", @"AM", @"PM") == nil,
			"a 24-hour time has no marker to take off");
	TGTestExpectTrue(&outcome, TGClockMarkerInTime(@"15:04", @"", @"") == nil,
			"and neither has one whose locale reports no symbols at all");

	return outcome;
}

TGTestOutcome TGClockMarkerTestBodyKeepsTheTimeAndDropsTheSpace(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGTimeWithoutClockMarker(@"3:04 PM", @"PM") isEqualToString:@"3:04"],
			"the clock text keeps its digits and loses the space the marker sat behind");
	TGTestExpectTrue(&outcome,
			[TGTimeWithoutClockMarker(@"3:04", nil) isEqualToString:@"3:04"],
			"a time with no marker is left exactly as it came");

	return outcome;
}

TGTestOutcome TGClockMarkerTestMissingInputIsHandled(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGClockMarkerInTime(nil, @"AM", @"PM") == nil,
			"a label with no text has no marker");
	TGTestExpectTrue(&outcome, TGClockMarkerInTime(@"PM", @"AM", @"PM") == nil,
			"a string that is only the marker is not a time and is left alone");
	TGTestExpectTrue(&outcome, TGTimeWithoutClockMarker(nil, @"PM") == nil,
			"and nothing is cut off a missing string");

	return outcome;
}

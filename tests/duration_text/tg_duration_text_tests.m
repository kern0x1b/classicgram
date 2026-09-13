#import "tg_duration_text_tests.h"
#import "../../src/Utilities/TGDurationText.h"

TGTestOutcome TGDurationTextTestAnHourLongMediaReadsAsHours(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGDurationText(0) isEqualToString:@"0:00"],
		"a zero length is a clock reading zero, not an empty string");
	TGTestExpectTrue(&outcome, [TGDurationText(-5) isEqualToString:@"0:00"],
		"a negative length cannot show a minus sign in a media badge");
	TGTestExpectTrue(&outcome, [TGDurationText(9) isEqualToString:@"0:09"],
		"seconds under ten keep their leading zero");
	TGTestExpectTrue(&outcome, [TGDurationText(261) isEqualToString:@"4:21"],
		"a few minutes read as minutes and seconds");
	TGTestExpectTrue(&outcome, [TGDurationText(3599) isEqualToString:@"59:59"],
		"the last second below an hour is still minutes and seconds");
	TGTestExpectTrue(&outcome, [TGDurationText(3600) isEqualToString:@"1:00:00"],
		"an hour turns the clock into hours, where the old code said 60:00");
	TGTestExpectTrue(&outcome, [TGDurationText(5412) isEqualToString:@"1:30:12"],
		"an hour and a half podcast reads as 1:30:12, not 90:12");
	TGTestExpectTrue(&outcome, [TGDurationText(36000) isEqualToString:@"10:00:00"],
		"ten hours keeps two-digit minutes and seconds and an unpadded hour");

	return outcome;
}

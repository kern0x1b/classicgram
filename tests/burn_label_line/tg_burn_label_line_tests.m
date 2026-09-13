#import "tg_burn_label_line_tests.h"
#import "../../src/Screens/Chat/TGBurnLabelLine.h"

TGTestOutcome TGBurnLabelLineTestOutgoingWithTimerShowsTimerNotOpenedOnce(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGBurnLabelLineForKind(@"messagePhoto", YES, 30);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"Photo, 30s after opening"],
			"a sender's own outgoing photo with a chosen self-destruct timer must show the real timer duration, not the opened-once fallback");

	return outcome;
}

TGTestOutcome TGBurnLabelLineTestOutgoingWithoutTimerShowsCanBeOpenedOnce(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGBurnLabelLineForKind(@"messagePhoto", YES, 0);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"Photo, can be opened once"],
			"an outgoing photo with no timer set must keep the can-be-opened-once label");

	return outcome;
}

TGTestOutcome TGBurnLabelLineTestIncomingWithTimerShowsTimer(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGBurnLabelLineForKind(@"messagePhoto", NO, 10);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"Photo, 10s after opening"],
			"an incoming photo with a timer must show the timer duration");

	return outcome;
}

TGTestOutcome TGBurnLabelLineTestIncomingWithoutTimerShowsTapToOpenOnce(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGBurnLabelLineForKind(@"messagePhoto", NO, 0);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"Photo, tap to open once"],
			"an incoming photo with no timer must keep the tap-to-open-once label");

	return outcome;
}

TGTestOutcome TGBurnLabelLineTestVideoKindUsesVideoNoun(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGBurnLabelLineForKind(@"messageVideo", YES, 3);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"Video, 3s after opening"],
			"a video message must use the Video noun rather than the default Photo noun");

	return outcome;
}

TGTestOutcome TGBurnLabelLineTestVideoNoteKindUsesVideoMessageNoun(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGBurnLabelLineForKind(@"messageVideoNote", NO, 0);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"Video Message, tap to open once"],
			"a video note must use the Video Message noun rather than the default Photo noun");

	return outcome;
}

TGTestOutcome TGBurnLabelLineTestUnknownKindFallsBackToPhotoNoun(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGBurnLabelLineForKind(@"", YES, 0);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"Photo, can be opened once"],
			"an unrecognized kind must fall back to the Photo noun rather than crash or produce a blank label");

	return outcome;
}

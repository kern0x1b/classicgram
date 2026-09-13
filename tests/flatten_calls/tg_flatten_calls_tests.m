#import "tg_flatten_calls_tests.h"
#import "../../src/Wire/Flatten/TGFlattenCalls.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenCallsTestMapsEcho(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGCallsProblemType(@"echo") isEqualToString:@"callProblemEcho"],
			"the echo problem key must map to callProblemEcho");

	return outcome;
}

TGTestOutcome TGFlattenCallsTestMapsNoise(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGCallsProblemType(@"noise") isEqualToString:@"callProblemNoise"],
			"the noise problem key must map to callProblemNoise");

	return outcome;
}

TGTestOutcome TGFlattenCallsTestMapsInterruptions(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGCallsProblemType(@"interruptions") isEqualToString:@"callProblemInterruptions"],
			"the interruptions problem key must map to callProblemInterruptions");

	return outcome;
}

TGTestOutcome TGFlattenCallsTestMapsDistortedSpeech(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGCallsProblemType(@"distortedSpeech") isEqualToString:@"callProblemDistortedSpeech"],
			"the distortedSpeech problem key must map to callProblemDistortedSpeech");

	return outcome;
}

TGTestOutcome TGFlattenCallsTestMapsSilentLocal(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGCallsProblemType(@"silentLocal") isEqualToString:@"callProblemSilentLocal"],
			"the silentLocal problem key must map to callProblemSilentLocal");

	return outcome;
}

TGTestOutcome TGFlattenCallsTestMapsSilentRemote(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGCallsProblemType(@"silentRemote") isEqualToString:@"callProblemSilentRemote"],
			"the silentRemote problem key must map to callProblemSilentRemote");

	return outcome;
}

TGTestOutcome TGFlattenCallsTestMapsDropped(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGCallsProblemType(@"dropped") isEqualToString:@"callProblemDropped"],
			"the dropped problem key must map to callProblemDropped");

	return outcome;
}

TGTestOutcome TGFlattenCallsTestMapsDistortedVideo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGCallsProblemType(@"distortedVideo") isEqualToString:@"callProblemDistortedVideo"],
			"the distortedVideo problem key must map to callProblemDistortedVideo");

	return outcome;
}

TGTestOutcome TGFlattenCallsTestMapsPixelatedVideo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGCallsProblemType(@"pixelatedVideo") isEqualToString:@"callProblemPixelatedVideo"],
			"the pixelatedVideo problem key must map to callProblemPixelatedVideo");

	return outcome;
}

TGTestOutcome TGFlattenCallsTestUnknownKeyReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGCallsProblemType(@"somethingMadeUp") == nil,
			"a problem key with no entry in the lookup table must return nil, not crash or fabricate one");

	return outcome;
}

TGTestOutcome TGFlattenCallsTestNilArgumentReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGCallsProblemType(nil) == nil,
			"a nil problem name must return nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenCallsTestWrongTypeArgumentReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGCallsProblemType((NSString *)@42) == nil,
			"a non-string value passed where a problem name is expected must return nil, not crash");

	return outcome;
}

#import "tg_call_peer_state_tests.h"

#import "../../src/Screens/Calls/TGCallPeerStateText.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGCallPeerStateTestWhatTheOtherSideTurnedOff(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGCallPeerStateSuffix(NO, NO, YES) == nil,
			"a call where the other side has turned nothing off says nothing extra");
	TGTestExpectTrue(&outcome, TGCallPeerStateSuffix(YES, NO, NO).length > 0,
			"a muted microphone is worth saying on an audio call, which is the whole point: the "
			"app knew and never told anyone");
	TGTestExpectTrue(&outcome, TGCallPeerStateSuffix(NO, YES, NO) == nil,
			"a paused camera says nothing on a call with no video in it");
	TGTestExpectTrue(&outcome, TGCallPeerStateSuffix(NO, YES, YES).length > 0,
			"and on a video call it does");
	TGTestExpectTrue(&outcome,
			![TGCallPeerStateSuffix(YES, YES, YES) isEqualToString:TGCallPeerStateSuffix(YES, NO, YES)],
			"both off reads differently from the microphone alone");

	return outcome;
}

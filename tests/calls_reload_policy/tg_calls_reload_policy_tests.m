#import "tg_calls_reload_policy_tests.h"
#import "../../src/Screens/Calls/TGCallsReloadPolicy.h"

TGTestOutcome TGCallsReloadPolicyTestTheListRetriesWhenALoadNeverCameBack(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGCallsShouldReloadOnAppear(NO, 0, NO, 0),
			"a screen that has never loaded asks for its calls");
	TGTestExpectTrue(&outcome, !TGCallsShouldReloadOnAppear(YES, 1.0, NO, 0),
			"a request still in flight is left alone");
	TGTestExpectTrue(&outcome, TGCallsShouldReloadOnAppear(YES, TGCallsLoadStallSeconds, NO, 0),
			"a request that never came back is abandoned and the list asks again, rather than "
			"leaving the screen blank until the five-minute request deadline");
	TGTestExpectTrue(&outcome, TGCallsShouldReloadOnAppear(YES, 600.0, YES, 600.0),
			"that holds for a screen that once had rows too");
	TGTestExpectTrue(&outcome, !TGCallsShouldReloadOnAppear(NO, 0, YES, 1.0),
			"rows fetched a moment ago are not fetched again on every tab switch");
	TGTestExpectTrue(&outcome, TGCallsShouldReloadOnAppear(NO, 0, YES, TGCallsFreshSeconds + 0.1),
			"rows older than the freshness window are refetched when the screen comes back");
	TGTestExpectTrue(&outcome, TGCallsShouldReloadOnAppear(NO, 0, NO, 3600.0),
			"a failed load leaves the screen unloaded, so the next appearance retries at once");

	return outcome;
}

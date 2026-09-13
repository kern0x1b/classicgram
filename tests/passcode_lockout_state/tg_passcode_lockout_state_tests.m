#import "tg_passcode_lockout_state_tests.h"
#import "../../src/Storage/TGPasscodeLockoutState.h"

TGTestOutcome TGPasscodeLockoutStateTestBelowThresholdNeverLocksOut(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSTimeInterval remaining = TGPasscodeLockoutRemainingSeconds(TGPasscodeLockoutThreshold - 1,
		1000.0, 1000.0, 0.0, 0.0);
	TGTestExpectEqualDouble(&outcome, remaining, 0.0, 0.001,
			"one attempt short of the threshold must never lock the passcode screen out");

	return outcome;
}

TGTestOutcome TGPasscodeLockoutStateTestAtThresholdLocksOutForFullDuration(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSTimeInterval remaining = TGPasscodeLockoutRemainingSeconds(TGPasscodeLockoutThreshold,
		1000.0, 1000.0, 0.0, 0.0);
	TGTestExpectEqualDouble(&outcome, remaining, TGPasscodeLockoutDuration, 0.001,
			"the attempt that reaches the threshold must lock out for the full duration immediately");

	return outcome;
}

TGTestOutcome TGPasscodeLockoutStateTestPastThresholdLocksOutForFullDuration(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSTimeInterval remaining = TGPasscodeLockoutRemainingSeconds(TGPasscodeLockoutThreshold + 5,
		1000.0, 1000.0, 0.0, 0.0);
	TGTestExpectEqualDouble(&outcome, remaining, TGPasscodeLockoutDuration, 0.001,
			"attempts beyond the threshold must still lock out, matching TDLib-adjacent client behaviour");

	return outcome;
}

TGTestOutcome TGPasscodeLockoutStateTestRemainingCountsDownToZero(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSTimeInterval remaining = TGPasscodeLockoutRemainingSeconds(TGPasscodeLockoutThreshold,
		1000.0, 1000.0 + TGPasscodeLockoutDuration / 2.0, 0.0, 0.0);
	TGTestExpectEqualDouble(&outcome, remaining, TGPasscodeLockoutDuration / 2.0, 0.001,
			"halfway through the lockout window exactly half the duration must remain");

	return outcome;
}

TGTestOutcome TGPasscodeLockoutStateTestExpiresExactlyAtDuration(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSTimeInterval remaining = TGPasscodeLockoutRemainingSeconds(TGPasscodeLockoutThreshold,
		1000.0, 1000.0 + TGPasscodeLockoutDuration, 0.0, 0.0);
	TGTestExpectEqualDouble(&outcome, remaining, 0.0, 0.001,
			"the lockout must have fully expired the instant its duration has elapsed");

	return outcome;
}

TGTestOutcome TGPasscodeLockoutStateTestNeverGoesNegative(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSTimeInterval remaining = TGPasscodeLockoutRemainingSeconds(TGPasscodeLockoutThreshold,
		1000.0, 1000.0 + TGPasscodeLockoutDuration * 10.0, 0.0, 0.0);
	TGTestExpectTrue(&outcome, remaining == 0.0,
			"a long-expired lockout must clamp to zero, never go negative");

	return outcome;
}

TGTestOutcome TGPasscodeLockoutStateTestClockRunningBackwardsStillLocksOut(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSTimeInterval remaining = TGPasscodeLockoutRemainingSeconds(TGPasscodeLockoutThreshold,
		1000.0, 500.0, 0.0, 0.0);
	TGTestExpectTrue(&outcome, remaining >= TGPasscodeLockoutDuration,
			"a clock that appears to have moved backwards must never shorten the lockout");

	return outcome;
}

TGTestOutcome TGPasscodeLockoutStateTestForwardWallClockJumpCannotShortenLockout(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSTimeInterval remaining = TGPasscodeLockoutRemainingSeconds(TGPasscodeLockoutThreshold,
		1000.0, 1000.0 + TGPasscodeLockoutDuration + 1.0, 5000.0, 5005.0);
	TGTestExpectEqualDouble(&outcome, remaining, TGPasscodeLockoutDuration - 5.0, 0.001,
			"pushing the wall clock forward past the lockout window must not shorten it when the monotonic clock disagrees");

	return outcome;
}

TGTestOutcome TGPasscodeLockoutStateTestRebootFallsBackToWallClock(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSTimeInterval remaining = TGPasscodeLockoutRemainingSeconds(TGPasscodeLockoutThreshold,
		1000.0, 1000.0 + TGPasscodeLockoutDuration + 10.0, 5000.0, 10.0);
	TGTestExpectEqualDouble(&outcome, remaining, 0.0, 0.001,
			"a device reboot resets the monotonic clock, so the lockout must fall back to the wall clock instead of sticking forever");

	return outcome;
}

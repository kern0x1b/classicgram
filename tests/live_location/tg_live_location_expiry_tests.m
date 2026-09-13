#import "tg_live_location_expiry_tests.h"
#import "../../src/Screens/Chat/TGLiveLocationExpiry.h"

TGTestOutcome TGLiveLocationExpiryTestZeroPeriodNeverExpires(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGLiveLocationHasExpired(0, 1000.0, 100000.0),
			"a live_period of zero means the message never carries a countdown, so it must never read as expired");

	return outcome;
}

TGTestOutcome TGLiveLocationExpiryTestNegativePeriodNeverExpires(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGLiveLocationHasExpired(-60, 1000.0, 100000.0),
			"a negative live_period must not be treated as already expired");

	return outcome;
}

TGTestOutcome TGLiveLocationExpiryTestBeforeEndIsNotExpired(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGLiveLocationHasExpired(900, 1900.0, 1899.0),
			"one second before the expires_in deadline must not yet read as expired");

	return outcome;
}

TGTestOutcome TGLiveLocationExpiryTestExactlyAtEndIsExpired(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGLiveLocationHasExpired(900, 1900.0, 1900.0),
			"the exact instant the expires_in deadline is reached must already read as expired");

	return outcome;
}

TGTestOutcome TGLiveLocationExpiryTestLongAfterEndIsExpired(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGLiveLocationHasExpired(900, 1900.0, 50000.0),
			"a now far past the expires_in deadline must read as expired");

	return outcome;
}

TGTestOutcome TGLiveLocationExpiryTestZeroExpiresAtIsAlreadyExpired(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGLiveLocationHasExpired(900, 0, 1.0),
			"an expires_in of zero means TDLib already reports the location as unable to update, so it must read as expired regardless of now");

	return outcome;
}

TGTestOutcome TGLiveLocationExpiryTestIgnoresDeviceClockDrift(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGLiveLocationHasExpired(900, 10.0, 5.0),
			"expiry must be judged purely from the captured expires_in deadline, never from an absolute send date compared against a drifted device clock");
	TGTestExpectTrue(&outcome, TGLiveLocationHasExpired(900, 10.0, 15.0),
			"once now passes the captured expires_in deadline the location must read as expired even when both values sit far from any real message send date");

	return outcome;
}

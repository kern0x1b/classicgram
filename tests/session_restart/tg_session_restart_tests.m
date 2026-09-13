#import "tg_session_restart_tests.h"
#import "../../src/TDLibClient/TGClientSessionRestart.h"

TGTestOutcome TGSessionRestartTestRestartsTheCacheLessBackgroundSession(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			TGSessionNeedsRestartForDiskCaches(YES, YES, NO, YES, NO) == YES,
			"a running session opened without its databases must reopen once the caches are wanted");

	return outcome;
}

TGTestOutcome TGSessionRestartTestLeavesEveryOtherSessionAlone(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			TGSessionNeedsRestartForDiskCaches(YES, YES, YES, YES, NO) == NO,
			"a session that already opened its databases must not be reopened");
	TGTestExpectTrue(&outcome,
			TGSessionNeedsRestartForDiskCaches(YES, YES, NO, NO, NO) == NO,
			"a session still meant to run without databases must be left as it is");
	TGTestExpectTrue(&outcome,
			TGSessionNeedsRestartForDiskCaches(YES, YES, NO, YES, YES) == NO,
			"a call in progress outranks the databases, since reopening would drop it");
	TGTestExpectTrue(&outcome,
			TGSessionNeedsRestartForDiskCaches(NO, YES, NO, YES, NO) == NO,
			"a client that is not running has nothing to reopen");
	TGTestExpectTrue(&outcome,
			TGSessionNeedsRestartForDiskCaches(YES, NO, NO, YES, NO) == NO,
			"a client whose parameters have not gone out yet will send the right ones itself");

	return outcome;
}

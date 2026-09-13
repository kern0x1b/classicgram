#import "tg_test_dc_tests.h"

#import "../../src/TDLibClient/TGTestDCMode.h"

TGTestOutcome TGTestDCTestReadsTheFlag(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGTestDCWanted(@"1", NO, NO),
		"the environment variable puts a shell-launched build on the test servers");
	TGTestExpectTrue(&outcome, !TGTestDCWanted(@"0", YES, YES),
		"an explicit zero wins over both the stored setting and the marker file");
	TGTestExpectTrue(&outcome, TGTestDCWanted(nil, NO, YES),
		"a marker file is enough, which is how a device with no shell environment switches over");
	TGTestExpectTrue(&outcome, TGTestDCWanted(nil, YES, NO),
		"the stored setting still works, which is what the debug harness writes");
	TGTestExpectTrue(&outcome, !TGTestDCWanted(nil, NO, NO),
		"a plain build talks to the production servers, which is the only safe default");
	TGTestExpectTrue(&outcome, !TGTestDCWanted(@"", NO, NO),
		"an empty variable is no answer at all");

	return outcome;
}

TGTestOutcome TGTestDCTestKeepsTheRealAccountSeparate(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *production = @"slot0";
	NSString *test = TGTestDCScopeForScope(production);

	TGTestExpectTrue(&outcome, ![test isEqualToString:production],
		"the test session gets its own scope, so switching never opens the real database");
	TGTestExpectTrue(&outcome, [test hasSuffix:production],
		"the scope keeps the account slot it came from, so several slots stay distinguishable");
	TGTestExpectTrue(&outcome,
		![TGTestDCScopeForScope(@"slot1") isEqualToString:test],
		"two slots do not collapse into one test scope");
	TGTestExpectTrue(&outcome, TGTestDCScopeForScope(nil).length > 0,
		"a missing scope still produces a usable directory name rather than nil");

	return outcome;
}

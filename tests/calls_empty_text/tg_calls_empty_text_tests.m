#import "tg_calls_empty_text_tests.h"

#import "../../src/Screens/Calls/TGCallsEmptyText.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGCallsEmptyTextTestAFailedHistorySaysSo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGCallsEmptyText(YES, YES, NO, 0) isEqualToString:@"Your call history could not be loaded."],
			"a call history that could not be loaded must say so, where before the tab was "
			"blank: no rows, no placeholder and no reason");
	TGTestExpectTrue(&outcome,
			[TGCallsEmptyText(YES, YES, YES, 0) isEqualToString:@"Your call history could not be loaded."],
			"and the missed-calls filter fails the same way");

	return outcome;
}

TGTestOutcome TGCallsEmptyTextTestAnEmptyHistoryNamesItsFilter(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGCallsEmptyText(YES, NO, NO, 0) isEqualToString:@"No recent calls"],
			"an account with no calls says that");
	TGTestExpectTrue(&outcome, [TGCallsEmptyText(YES, NO, YES, 0) isEqualToString:@"No missed calls"],
			"and the missed filter says its own");

	return outcome;
}

TGTestOutcome TGCallsEmptyTextTestNothingIsSaidWhileLoading(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGCallsEmptyText(NO, NO, NO, 0) isEqualToString:@""],
			"a list still being fetched must not claim the account has no calls");

	return outcome;
}

TGTestOutcome TGCallsEmptyTextTestCallsOnScreenSayNothing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGCallsEmptyText(YES, NO, NO, 4) isEqualToString:@""],
			"with calls listed the placeholder stays out of the way");
	TGTestExpectTrue(&outcome, [TGCallsEmptyText(YES, YES, NO, 4) isEqualToString:@""],
			"and a later page that fails does not cover the calls already listed");

	return outcome;
}

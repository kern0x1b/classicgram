#import "tg_scheduled_footer_tests.h"

#import "../../src/Screens/Chat/TGScheduledFooterText.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGScheduledFooterTestAFailedLoadIsNotAnEmptyList(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *failed = TGScheduledFooterText(YES, YES, 0, NO);
	NSString *empty = TGScheduledFooterText(YES, NO, 0, NO);

	TGTestExpectTrue(&outcome, ![failed isEqualToString:empty],
			"a list that could not be loaded says so; it used to claim nothing was waiting to "
			"be sent, which is a different fact");
	TGTestExpectTrue(&outcome, [TGScheduledFooterText(YES, YES, 0, YES) isEqualToString:failed],
			"and it says the same whether the screen is reminders or scheduled messages, since "
			"the failure is not about either");

	return outcome;
}

TGTestOutcome TGScheduledFooterTestTheOrdinaryStates(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *loading = TGScheduledFooterText(NO, NO, 0, NO);
	NSString *reminders = TGScheduledFooterText(YES, NO, 0, YES);
	NSString *messages = TGScheduledFooterText(YES, NO, 0, NO);
	NSString *withRows = TGScheduledFooterText(YES, NO, 3, NO);

	TGTestExpectTrue(&outcome, loading.length && ![loading isEqualToString:messages],
			"a list still loading says neither that it is empty nor that it failed");
	TGTestExpectTrue(&outcome, ![reminders isEqualToString:messages],
			"an empty reminders screen and an empty scheduled screen each say their own thing");
	TGTestExpectTrue(&outcome, ![withRows isEqualToString:messages],
			"and a list with rows explains what tapping one does instead");

	return outcome;
}

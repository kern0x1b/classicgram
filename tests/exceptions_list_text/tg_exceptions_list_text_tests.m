#import "tg_exceptions_list_text_tests.h"

#import "../../src/Screens/Settings/TGExceptionsListText.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGExceptionsListTextTestNoExceptionsIsNotAFailure(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *empty = TGExceptionsListText(YES, NO);
	NSString *failed = TGExceptionsListText(YES, YES);
	NSString *loading = TGExceptionsListText(NO, NO);

	TGTestExpectTrue(&outcome, ![empty isEqualToString:failed],
			"a list of notification exceptions that could not be read no longer says the account "
			"has none, which also drove the counts beside every scope");
	TGTestExpectTrue(&outcome, ![loading isEqualToString:failed] && loading.length,
			"and a list still arriving says neither");

	return outcome;
}

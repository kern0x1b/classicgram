#import "tg_list_state_text_tests.h"

#import "../../src/Utilities/TGListStateText.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGListStateTextTestTheOrderOfTheThreeStates(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *loading = @"loading";
	NSString *failed = @"failed";
	NSString *empty = @"empty";

	TGTestExpectTrue(&outcome,
			[TGListStateText(NO, NO, loading, failed, empty) isEqualToString:loading],
			"a list that has not arrived is loading");
	TGTestExpectTrue(&outcome,
			[TGListStateText(NO, YES, loading, failed, empty) isEqualToString:loading],
			"a failure carried before the list has arrived still reads as loading, since the "
			"screen has not finished asking");
	TGTestExpectTrue(&outcome,
			[TGListStateText(YES, YES, loading, failed, empty) isEqualToString:failed],
			"a list that arrived as a failure says so");
	TGTestExpectTrue(&outcome,
			[TGListStateText(YES, NO, loading, failed, empty) isEqualToString:empty],
			"and only a list that arrived without failing may say it is empty - the whole point "
			"of the four rounds that built this");

	return outcome;
}

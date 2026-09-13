#import "tg_count_after_read_tests.h"

#import "../../src/Utilities/TGCountAfterRead.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGCountAfterReadTestAFailureDoesNotZeroACount(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGCountAfterRead(7, 0, YES) == 7,
			"a count that could not be read keeps what it was; zeroing it hid the join-request "
			"row from the admin of a group that had requests waiting");
	TGTestExpectTrue(&outcome, TGCountAfterRead(7, 0, NO) == 0,
			"a count read as zero really is zero");
	TGTestExpectTrue(&outcome, TGCountAfterRead(0, 3, NO) == 3,
			"and a count read as three is three");
	TGTestExpectTrue(&outcome, TGCountAfterRead(2, -1, NO) == 0,
			"a count that arrives negative is treated as none rather than drawn as -1");

	return outcome;
}

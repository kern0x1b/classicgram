#import "tg_archived_count_tests.h"

#import "../../src/Screens/Stickers/TGArchivedCount.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGArchivedCountTestTheRowAgreesWithTheList(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGArchivedCount(3, 1, 20) == 1,
			"a page that came back short is the whole list, so the row says what the screen "
			"behind it will show - the row said 3 and the screen listed 1");
	TGTestExpectTrue(&outcome, TGArchivedCount(0, 4, 20) == 4,
			"a server that reports no total at all is answered with what arrived");
	TGTestExpectTrue(&outcome, TGArchivedCount(57, 20, 20) == 57,
			"a full page means there is more behind it, and then the server's total is the "
			"honest number");
	TGTestExpectTrue(&outcome, TGArchivedCount(2, 20, 20) == 20,
			"a total smaller than what arrived is not believed");
	TGTestExpectTrue(&outcome, TGArchivedCount(9, 0, 20) == 0,
			"and nothing on the page means nothing to show, whatever the total claims");

	return outcome;
}

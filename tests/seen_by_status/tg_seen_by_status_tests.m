#import "tg_seen_by_status_tests.h"
#import "../../src/Views/TGSeenByStatusText.h"

TGTestOutcome TGSeenByStatusTestNamesEveryReasonTheClientReports(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGSeenByStatusText(nil) isEqualToString:@"Nobody Viewed"],
		"no reason at all means the server answered with an empty list");
	TGTestExpectTrue(&outcome, [TGSeenByStatusText(@"") isEqualToString:@"Nobody Viewed"],
		"an empty reason is the same as none");
	TGTestExpectTrue(&outcome,
		[TGSeenByStatusText(@"tooOld") rangeOfString:@"old messages"].location != NSNotFound,
		"a message too old to tell says so");
	TGTestExpectTrue(&outcome,
		[TGSeenByStatusText(@"chatTooBig") rangeOfString:@"large groups"].location != NSNotFound,
		"a group too big to tell says so");
	for (NSString *reason in @[ @"hiddenParticipants", @"incoming", @"unavailable", @"anything else" ])
		TGTestExpectTrue(&outcome,
			[TGSeenByStatusText(reason) isEqualToString:@"The list of viewers isn't available"],
			"every other reason falls back to the generic sentence rather than showing the code");

	return outcome;
}

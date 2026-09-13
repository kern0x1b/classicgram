#import "tg_request_expiry_tests.h"
#import "../../src/TDLibClient/TGRequestExpiry.h"

TGTestOutcome TGRequestExpiryTestAnAnswerThatNeverCameIsGivenUpOn(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *pending = @{
		@"r1" : @{@"deadline" : @(100.0)},
		@"r2" : @{@"deadline" : @(300.0)},
		@"r3" : @{@"deadline" : @(200.0)},
	};

	NSArray *expired = TGExpiredRequestKeys(pending, 200.0);
	TGTestExpectTrue(&outcome, expired.count == 2, "only the requests whose deadline has passed are given up on");
	TGTestExpectTrue(&outcome, [expired containsObject:@"r1"], "a request long past its deadline expires");
	TGTestExpectTrue(&outcome, [expired containsObject:@"r3"], "a deadline exactly now has passed");
	TGTestExpectTrue(&outcome, ![expired containsObject:@"r2"],
			"a request still inside its deadline is left waiting");

	TGTestExpectTrue(&outcome, TGExpiredRequestKeys(pending, 0.0).count == 0,
			"nothing expires before any deadline is due");
	TGTestExpectTrue(&outcome, TGExpiredRequestKeys(pending, 1000.0).count == 3,
			"long enough after, every unanswered request is given up on");
	TGTestExpectTrue(&outcome, TGExpiredRequestKeys(@{}, 1000.0).count == 0,
			"nothing pending is nothing to expire");
	TGTestExpectTrue(&outcome, TGExpiredRequestKeys(nil, 1000.0).count == 0,
			"no dictionary at all is not a crash");

	NSDictionary *malformed = @{
		@"r1" : @{@"block" : @"not a deadline"},
		@"r2" : @"not an entry",
		@"r3" : @{@"deadline" : @"soon"},
	};
	TGTestExpectTrue(&outcome, TGExpiredRequestKeys(malformed, 0.0).count == 3,
			"an entry with no usable deadline is expired rather than waited on forever, so its "
			"caller is told the answer is not coming");

	return outcome;
}

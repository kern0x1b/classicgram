#import "tg_paid_reactors_tests.h"
#import "../../src/Utilities/TGPaidReactors.h"

static NSDictionary *TGPaidReactorsTestReactor(NSString *name, NSInteger stars, BOOL anonymous) {
	return @{
		@"senderId" : @(anonymous ? 0 : 42),
		@"name" : name,
		@"stars" : @(stars),
		@"isAnonymous" : @(anonymous),
	};
}

TGTestOutcome TGPaidReactorsTestWhoLeadsTheBoard(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *ranked = TGPaidReactorsRanked(@[
		TGPaidReactorsTestReactor(@"Ada", 5, NO),
		TGPaidReactorsTestReactor(@"Grace", 40, NO),
		TGPaidReactorsTestReactor(@"Alan", 12, NO),
	]);
	TGTestExpectEqualInteger(&outcome, (NSInteger)ranked.count, 3, "everyone who paid is listed");
	TGTestExpectTrue(&outcome, [ranked[0][@"name"] isEqualToString:@"Grace"],
		"the biggest spender leads the board");
	TGTestExpectTrue(&outcome, [ranked[2][@"name"] isEqualToString:@"Ada"],
		"the smallest one closes it");

	NSArray *tied = TGPaidReactorsRanked(@[
		TGPaidReactorsTestReactor(@"Anonymous", 10, YES),
		TGPaidReactorsTestReactor(@"Ada", 10, NO),
	]);
	TGTestExpectTrue(&outcome, [tied[0][@"name"] isEqualToString:@"Ada"],
		"a named reactor is placed ahead of an anonymous one on the same amount");

	NSArray *cleaned = TGPaidReactorsRanked(@[
		TGPaidReactorsTestReactor(@"Ada", 0, NO),
		@"not a reactor",
		TGPaidReactorsTestReactor(@"Grace", 3, NO),
	]);
	TGTestExpectEqualInteger(&outcome, (NSInteger)cleaned.count, 1,
		"nothing that paid nothing, and nothing malformed, reaches the board");

	TGTestExpectEqualInteger(&outcome, (NSInteger)TGPaidReactorsRanked(nil).count, 0,
		"no reactions at all is an empty board, not a crash");

	return outcome;
}

TGTestOutcome TGPaidReactorsTestWhatTheBoardAddsUpTo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *reactors = @[
		TGPaidReactorsTestReactor(@"Ada", 5, NO),
		TGPaidReactorsTestReactor(@"Grace", 40, NO),
	];
	TGTestExpectEqualInteger(&outcome, (NSInteger)TGPaidReactorsTotalStars(reactors), 45,
		"the total is what the board paid between them");
	TGTestExpectEqualInteger(&outcome, (NSInteger)TGPaidReactorsTotalStars(nil), 0,
		"an absent board is worth nothing");

	TGTestExpectTrue(&outcome, [TGPaidReactorsStarText(7) isEqualToString:@"7 ⭐"],
		"an amount reads as a number beside a star");
	TGTestExpectTrue(&outcome, [TGPaidReactorsStarText(0) isEqualToString:@""],
		"nothing paid says nothing at all");

	return outcome;
}

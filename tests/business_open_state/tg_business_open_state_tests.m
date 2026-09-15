#import "tg_business_open_state_tests.h"
#import "../../src/Utilities/TGBusinessOpenState.h"

static NSArray *TGBusinessTestDays(void) {
	NSMutableArray *days = [NSMutableArray array];
	for (NSInteger i = 0; i < 7; i++)
		[days addObject:@{@"open" : @NO, @"startMinute" : @(0), @"endMinute" : @(0)}];
	days[0] = @{@"open" : @YES, @"startMinute" : @(9 * 60), @"endMinute" : @(18 * 60)};
	days[1] = @{@"open" : @YES, @"startMinute" : @(0), @"endMinute" : @(24 * 60)};
	days[2] = @{@"open" : @YES, @"startMinute" : @(10 * 60 + 30), @"endMinute" : @(10 * 60)};
	return days;
}

TGTestOutcome TGBusinessOpenStateTestWhenAPlaceIsOpen(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;
	NSArray *days = TGBusinessTestDays();

	TGTestExpectTrue(&outcome, TGBusinessIsOpenAt(days, 0, 9 * 60),
		"the minute it opens counts as open");
	TGTestExpectTrue(&outcome, TGBusinessIsOpenAt(days, 0, 17 * 60 + 59),
		"a minute before closing is still open");
	TGTestExpectTrue(&outcome, !TGBusinessIsOpenAt(days, 0, 18 * 60),
		"the closing minute is already shut");
	TGTestExpectTrue(&outcome, !TGBusinessIsOpenAt(days, 0, 8 * 60 + 59),
		"a minute early is not open yet");
	TGTestExpectTrue(&outcome, !TGBusinessIsOpenAt(days, 3, 12 * 60),
		"a day marked closed is closed all day");
	TGTestExpectTrue(&outcome, TGBusinessIsOpenAt(days, 1, 3 * 60),
		"a day that runs the full 24 hours is open at night");
	TGTestExpectTrue(&outcome, !TGBusinessIsOpenAt(days, 2, 10 * 60 + 45),
		"an interval that ends before it starts is not treated as open");
	TGTestExpectTrue(&outcome, !TGBusinessIsOpenAt(nil, 0, 12 * 60),
		"no schedule at all is never open");
	TGTestExpectTrue(&outcome, !TGBusinessIsOpenAt(days, 9, 12 * 60),
		"a weekday outside the week is not open");

	return outcome;
}

TGTestOutcome TGBusinessOpenStateTestWhatTheDayReads(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;
	NSArray *days = TGBusinessTestDays();

	TGTestExpectTrue(&outcome,
		[TGBusinessDayIntervalText(days, 0) isEqualToString:@"09:00 - 18:00"],
		"an ordinary day reads as its two clock times");
	TGTestExpectTrue(&outcome, [TGBusinessDayIntervalText(days, 1) isEqualToString:@""],
		"a day open around the clock has no interval to show");
	TGTestExpectTrue(&outcome, TGBusinessDayIntervalText(days, 3) == nil,
		"a closed day reads as nothing at all");
	TGTestExpectTrue(&outcome, TGBusinessDayIntervalText(days, 2) == nil,
		"so does a day whose interval makes no sense");

	return outcome;
}

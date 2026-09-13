#import "tg_live_location_rehydration_tests.h"
#import "../../src/Screens/Chat/TGLiveLocationRehydration.h"

TGTestOutcome TGLiveLocationRehydrationTestOwnActiveShareIsFound(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *messages = @[
		@{ @"id" : @1001, @"kind" : @"messageLiveLocation", @"outgoing" : @YES,
			@"livePeriod" : @900, @"liveExpiresAt" : @2000.0, @"date" : @1000.0 },
	];
	int64_t found = TGOwnActiveLiveLocationMessageId(messages, 1500.0);
	TGTestExpectEqualLongLong(&outcome, found, 1001,
			"reopening a chat with a still-active own live-location share must rehydrate its message id so Stop Sharing becomes available again");

	return outcome;
}

TGTestOutcome TGLiveLocationRehydrationTestIncomingLiveLocationIsIgnored(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *messages = @[
		@{ @"id" : @1001, @"kind" : @"messageLiveLocation", @"outgoing" : @NO,
			@"livePeriod" : @900, @"liveExpiresAt" : @2000.0, @"date" : @1000.0 },
	];
	int64_t found = TGOwnActiveLiveLocationMessageId(messages, 1500.0);
	TGTestExpectEqualLongLong(&outcome, found, 0,
			"a live location shared by someone else in the chat must never be picked up as the device's own tracked share");

	return outcome;
}

TGTestOutcome TGLiveLocationRehydrationTestOwnExpiredShareIsIgnored(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *messages = @[
		@{ @"id" : @1001, @"kind" : @"messageLiveLocation", @"outgoing" : @YES,
			@"livePeriod" : @900, @"liveExpiresAt" : @2000.0, @"date" : @1000.0 },
	];
	int64_t found = TGOwnActiveLiveLocationMessageId(messages, 3000.0);
	TGTestExpectEqualLongLong(&outcome, found, 0,
			"a share whose expires_in deadline already passed must not be rehydrated as if it were still active");

	return outcome;
}

TGTestOutcome TGLiveLocationRehydrationTestNoLiveLocationMessagesReturnsZero(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *messages = @[
		@{ @"id" : @1001, @"kind" : @"messageText", @"outgoing" : @YES },
	];
	int64_t found = TGOwnActiveLiveLocationMessageId(messages, 1500.0);
	TGTestExpectEqualLongLong(&outcome, found, 0,
			"an ordinary chat history with no live location content must not report any share as active");

	return outcome;
}

TGTestOutcome TGLiveLocationRehydrationTestOwnStaticLocationIsIgnored(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *messages = @[
		@{ @"id" : @1001, @"kind" : @"messageLocation", @"outgoing" : @YES,
			@"livePeriod" : @0, @"liveExpiresAt" : @0.0, @"date" : @1000.0 },
	];
	int64_t found = TGOwnActiveLiveLocationMessageId(messages, 1500.0);
	TGTestExpectEqualLongLong(&outcome, found, 0,
			"a one-shot static location message must never be treated as a live-location share to rehydrate");

	return outcome;
}

TGTestOutcome TGLiveLocationRehydrationTestMultipleOwnSharesPicksTheMostRecent(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *messages = @[
		@{ @"id" : @1001, @"kind" : @"messageLiveLocation", @"outgoing" : @YES,
			@"livePeriod" : @900, @"liveExpiresAt" : @5000.0, @"date" : @1000.0 },
		@{ @"id" : @1002, @"kind" : @"messageLiveLocation", @"outgoing" : @YES,
			@"livePeriod" : @900, @"liveExpiresAt" : @6000.0, @"date" : @2000.0 },
	];
	int64_t found = TGOwnActiveLiveLocationMessageId(messages, 1500.0);
	TGTestExpectEqualLongLong(&outcome, found, 1002,
			"if more than one own active live-location message is ever found the most recently sent one must win");

	return outcome;
}

TGTestOutcome TGLiveLocationRehydrationTestNonDictionaryEntriesDoNotCrash(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *messages = @[
		@"not a message dictionary",
		@{ @"id" : @1001, @"kind" : @"messageLiveLocation", @"outgoing" : @YES,
			@"livePeriod" : @900, @"liveExpiresAt" : @2000.0, @"date" : @1000.0 },
	];
	int64_t found = TGOwnActiveLiveLocationMessageId(messages, 1500.0);
	TGTestExpectEqualLongLong(&outcome, found, 1001,
			"a malformed entry in the message list must be skipped rather than crashing the rehydration scan");

	return outcome;
}

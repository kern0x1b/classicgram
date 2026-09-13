#import "tg_poll_update_merge_tests.h"

#import "../../src/Wire/Flatten/TGFlattenMessage.h"
#import "../../src/Wire/Flatten/TGPollUpdateMerge.h"

#import <Foundation/Foundation.h>

static NSDictionary *TGTestPollMessage(long long messageId, long long pollId, NSInteger total) {
	return @{
		@"id" : @(messageId),
		@"pollId" : @(pollId),
		@"pollTotal" : @(total),
		@"pollQuestion" : @"Tea or coffee?",
	};
}

TGTestOutcome TGPollUpdateMergeTestVotesReachTheMessageThatShowsThePoll(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *messages = @[ TGTestPollMessage(11, 700, 3) ];
	NSIndexSet *changed = nil;
	NSArray *merged = TGMessagesWithUpdatedPoll(messages,
			@{@"pollId" : @700, @"pollTotal" : @9, @"pollClosed" : @YES}, &changed);

	TGTestExpectTrue(&outcome, [changed containsIndex:0] && changed.count == 1,
			"the one message showing that poll is the one row that changed");
	TGTestExpectTrue(&outcome, [merged[0][@"pollTotal"] integerValue] == 9,
			"the new vote count reaches the message, where before the bubble kept the count "
			"it was drawn with until the chat was reloaded");
	TGTestExpectTrue(&outcome, [merged[0][@"pollClosed"] boolValue],
			"and so does the poll being closed");
	TGTestExpectTrue(&outcome, [merged[0][@"pollQuestion"] isEqualToString:@"Tea or coffee?"],
			"fields the update does not carry are left as they were");
	TGTestExpectTrue(&outcome, [merged[0][@"id"] longLongValue] == 11,
			"and the message keeps its own identity");

	return outcome;
}

TGTestOutcome TGPollUpdateMergeTestOtherMessagesAreLeftAlone(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *messages = @[
		@{@"id" : @9, @"text" : @"hello"},
		TGTestPollMessage(11, 700, 3),
		TGTestPollMessage(12, 701, 4),
	];
	NSIndexSet *changed = nil;
	NSArray *merged = TGMessagesWithUpdatedPoll(messages, @{@"pollId" : @701, @"pollTotal" : @5},
			&changed);

	TGTestExpectTrue(&outcome, changed.count == 1 && [changed containsIndex:2],
			"only the message showing the poll that changed is touched");
	TGTestExpectTrue(&outcome, [merged[1][@"pollTotal"] integerValue] == 3,
			"the other poll keeps its own count");
	TGTestExpectTrue(&outcome, merged[0] == messages[0],
			"a message with no poll at all is the same object it was");

	return outcome;
}

TGTestOutcome TGPollUpdateMergeTestTheSamePollTwiceChangesNothing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *messages = @[ TGTestPollMessage(11, 700, 3) ];
	NSIndexSet *changed = nil;
	NSArray *merged = TGMessagesWithUpdatedPoll(messages, @{@"pollId" : @700, @"pollTotal" : @3},
			&changed);

	TGTestExpectTrue(&outcome, changed.count == 0,
			"an update that says what the message already says reloads no rows");
	TGTestExpectTrue(&outcome, merged == messages,
			"and hands back the list it was given");

	return outcome;
}

TGTestOutcome TGPollUpdateMergeTestAPollWithNoIdIsIgnored(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *messages = @[ TGTestPollMessage(11, 700, 3) ];
	NSIndexSet *changed = nil;
	NSArray *merged = TGMessagesWithUpdatedPoll(messages, @{@"pollTotal" : @9}, &changed);

	TGTestExpectTrue(&outcome, changed.count == 0 && merged == messages,
			"an update with no poll id must not be spread across every poll on screen");

	return outcome;
}

TGTestOutcome TGPollUpdateMergeTestMissingInputIsHandled(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSIndexSet *changed = nil;
	TGTestExpectTrue(&outcome, TGMessagesWithUpdatedPoll(nil, @{@"pollId" : @700}, &changed) == nil,
			"no messages means nothing to merge into");
	TGTestExpectTrue(&outcome, changed.count == 0, "and nothing to reload");
	TGTestExpectTrue(&outcome,
			TGMessagesWithUpdatedPoll(@[], (id)@"not a poll", &changed).count == 0,
			"and a malformed update raises nothing");

	return outcome;
}

TGTestOutcome TGPollUpdateMergeTestFlattenedPollCarriesItsId(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *poll = @{
		@"id" : @"5307654321098765432",
		@"question" : @{@"text" : @"Tea or coffee?"},
		@"total_voter_count" : @7,
		@"is_closed" : @NO,
		@"options" : @[ @{@"id" : @0, @"text" : @{@"text" : @"Tea"}, @"voter_count" : @4} ],
	};
	NSDictionary *fields = TGFlattenPollFields(poll, nil);

	TGTestExpectTrue(&outcome, [fields[@"pollId"] longLongValue] == 5307654321098765432LL,
			"a poll id arrives from TDLib as a string and must survive as a number, "
			"or an update could never be matched to the message showing it");
	TGTestExpectTrue(&outcome, [fields[@"pollTotal"] integerValue] == 7,
			"the vote count comes across");
	TGTestExpectTrue(&outcome, [fields[@"pollQuestion"] isEqualToString:@"Tea or coffee?"],
			"and so does the question");
	TGTestExpectTrue(&outcome, [fields[@"pollOptions"] count] == 1,
			"and the options");
	TGTestExpectTrue(&outcome, [TGFlattenPollFields(nil, nil) count] == 0,
			"a message with no poll gives no poll fields");

	return outcome;
}

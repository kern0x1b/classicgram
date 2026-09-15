#import "tg_quick_reply_trigger_tests.h"
#import "../../src/Utilities/TGQuickReplyTrigger.h"

TGTestOutcome TGQuickReplyTriggerTestWhenTheSlashCounts(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSRange r = TGQuickReplyTriggerRangeInText(@"/hi", 3);
	TGTestExpectTrue(&outcome, r.location == 0 && r.length == 3,
		"a slash word being typed is the trigger, slash included");
	r = TGQuickReplyTriggerRangeInText(@"/", 1);
	TGTestExpectTrue(&outcome, r.location == 0 && r.length == 1,
		"a bare slash already offers every reply");
	TGTestExpectTrue(&outcome,
		TGQuickReplyTriggerRangeInText(@"/hi there", 3).location == NSNotFound,
		"once the message carries on past the word it is an ordinary message");
	TGTestExpectTrue(&outcome,
		TGQuickReplyTriggerRangeInText(@"hello /hi", 9).location == NSNotFound,
		"a slash in the middle of a sentence is not a shortcut");
	TGTestExpectTrue(&outcome, TGQuickReplyTriggerRangeInText(@"/hi", 0).location == NSNotFound,
		"a caret parked before the slash is not inside the word");
	TGTestExpectTrue(&outcome, TGQuickReplyTriggerRangeInText(@"", 0).location == NSNotFound,
		"an empty composer has no trigger");
	TGTestExpectTrue(&outcome, TGQuickReplyTriggerRangeInText(nil, 0).location == NSNotFound,
		"and neither does no text at all");

	return outcome;
}

TGTestOutcome TGQuickReplyTriggerTestWhichRepliesMatch(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;
	NSArray *shortcuts = @[
		@{@"id" : @(1), @"name" : @"hello"},
		@{@"id" : @(2), @"name" : @"Help"},
		@{@"id" : @(3), @"name" : @"bye"},
		@{@"id" : @(4)},
	];

	TGTestExpectEqualInteger(&outcome, TGQuickReplyMatches(shortcuts, @"").count, 3,
		"an empty query offers every named reply and skips a nameless one");
	NSArray *he = TGQuickReplyMatches(shortcuts, @"he");
	TGTestExpectEqualInteger(&outcome, he.count, 2,
		"a prefix narrows the list");
	TGTestExpectTrue(&outcome, [he.firstObject[@"name"] isEqualToString:@"hello"],
		"and keeps the order the shortcuts came in");
	TGTestExpectEqualInteger(&outcome, TGQuickReplyMatches(shortcuts, @"HEL").count, 2,
		"matching ignores case, the way typing does");
	TGTestExpectEqualInteger(&outcome, TGQuickReplyMatches(shortcuts, @"hello there").count, 0,
		"a query longer than the name matches nothing");
	TGTestExpectEqualInteger(&outcome, TGQuickReplyMatches(nil, @"he").count, 0,
		"no shortcuts means no matches");

	return outcome;
}

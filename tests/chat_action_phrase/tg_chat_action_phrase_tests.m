#import "tg_chat_action_phrase_tests.h"
#import "../../src/Utilities/TGChatActionPhraseComposer.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGChatActionPhraseTestEmptyPhrasesReturnsEmptyString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGComposeChatActionDisplayPhrase(@[], @[]);

	TGTestExpectTrue(&outcome, [result isEqualToString:@""],
			"an empty phrases array must compose to an empty string, not a stray format artifact");

	return outcome;
}

TGTestOutcome TGChatActionPhraseTestSingleSenderNamesTheVerb(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGComposeChatActionDisplayPhrase(@[@"Alice"], @[@"typing..."]);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"Alice is typing..."],
			"a single sender must be named directly against their own verb");

	return outcome;
}

TGTestOutcome TGChatActionPhraseTestTwoSendersSameKindNamesBoth(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGComposeChatActionDisplayPhrase(@[@"Alice", @"Bob"], @[@"typing...", @"typing..."]);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"Alice and Bob are typing..."],
			"two senders performing the same action must both be named alongside that action's own verb");

	return outcome;
}

TGTestOutcome TGChatActionPhraseTestTwoSendersMixedKindFallsBackToGenericVerb(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGComposeChatActionDisplayPhrase(@[@"Alice", @"Bob"],
		@[@"typing...", @"recording audio..."]);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"Alice and Bob are typing..."],
			"two senders performing different actions must still be named, but collapse to the generic typing verb rather than misreport either sender's real action");

	return outcome;
}

TGTestOutcome TGChatActionPhraseTestThreeOrMoreSendersSameKindNamesFirstAndCountsOthers(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGComposeChatActionDisplayPhrase(@[@"Alice", @"Bob"],
		@[@"typing...", @"typing...", @"typing..."]);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"Alice and 2 others are typing..."],
			"three or more senders sharing an action must name only the first and count the rest as others");

	return outcome;
}

TGTestOutcome TGChatActionPhraseTestThreeOrMoreSendersMixedKindFallsBackToGenericVerb(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGComposeChatActionDisplayPhrase(@[@"Alice", @"Bob"],
		@[@"typing...", @"recording audio...", @"sending a photo..."]);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"Alice and 2 others are typing..."],
			"three or more senders performing different actions must collapse to the generic typing verb, not the first sender's specific action");

	return outcome;
}

TGTestOutcome TGChatActionPhraseTestMissingSecondDisplayNameDoesNotCrash(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGComposeChatActionDisplayPhrase(@[@"Alice"], @[@"typing...", @"typing..."]);

	TGTestExpectTrue(&outcome, result.length > 0,
			"a two-sender phrase composed with only one resolved display name must degrade gracefully, not crash");

	return outcome;
}

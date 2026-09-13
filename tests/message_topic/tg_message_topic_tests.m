#import "tg_message_topic_tests.h"
#import "../../src/TDLibClient/TGMessageTopic.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGMessageTopicTestZeroThreadIdReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGMessageTopicDictionary(0, NO) == nil,
			"a zero thread id in a non-forum chat must not produce a topic wrapper");
	TGTestExpectTrue(&outcome, TGMessageTopicDictionary(0, YES) == nil,
			"a zero thread id in a forum chat must not produce a topic wrapper");

	return outcome;
}

TGTestOutcome TGMessageTopicTestNonForumChatWrapsAsMessageTopicThread(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	long long messageThreadId = 524288000000LL;
	NSDictionary *topic = TGMessageTopicDictionary(messageThreadId, NO);

	TGTestExpectTrue(&outcome, [topic[@"@type"] isEqualToString:@"messageTopicThread"],
			"a discussion/comment thread must be wrapped as messageTopicThread, not messageTopicForum");
	TGTestExpectTrue(&outcome, topic[@"forum_topic_id"] == nil,
			"a messageTopicThread wrapper must not also carry a forum_topic_id field");
	TGTestExpectEqualLongLong(&outcome, [topic[@"message_thread_id"] longLongValue], messageThreadId,
			"the message_thread_id must be carried through unchanged");

	return outcome;
}

TGTestOutcome TGMessageTopicTestForumChatWrapsAsMessageTopicForum(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	long long forumTopicId = 500LL;
	NSDictionary *topic = TGMessageTopicDictionary(forumTopicId, YES);

	TGTestExpectTrue(&outcome, [topic[@"@type"] isEqualToString:@"messageTopicForum"],
			"a real forum topic must still be wrapped as messageTopicForum");
	TGTestExpectTrue(&outcome, topic[@"message_thread_id"] == nil,
			"a messageTopicForum wrapper must not also carry a message_thread_id field");
	TGTestExpectEqualLongLong(&outcome, [topic[@"forum_topic_id"] longLongValue], forumTopicId,
			"the forum_topic_id must be carried through unchanged");

	return outcome;
}

TGTestOutcome TGMessageTopicTestThreadIdPassesThroughFullPrecisionForMessageThread(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	long long messageThreadId = 524288000000LL;
	NSDictionary *topic = TGMessageTopicDictionary(messageThreadId, NO);

	TGTestExpectTrue(&outcome, messageThreadId > INT32_MAX,
			"this test value must exceed int32 range to actually exercise truncation");
	TGTestExpectEqualLongLong(&outcome, [topic[@"message_thread_id"] longLongValue], messageThreadId,
			"a message_thread_id beyond int32 range must not be truncated when sending into a comment thread");

	return outcome;
}

TGTestOutcome TGMessageTopicTestForumTopicIdTruncatesTo32Bits(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	long long forumTopicIdJustBelowInt32Max = (long long)INT32_MAX - 1;
	NSDictionary *topic = TGMessageTopicDictionary(forumTopicIdJustBelowInt32Max, YES);

	TGTestExpectEqualLongLong(&outcome, [topic[@"forum_topic_id"] longLongValue], forumTopicIdJustBelowInt32Max,
			"a genuine forum topic id, which is always a 32-bit server id, must round-trip exactly");

	return outcome;
}

TGTestOutcome TGTopicDictionaryTestSavedTopicTakesPriority(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	long long savedTopicId = 42LL;
	NSDictionary *topic = TGTopicDictionary(0, 0, savedTopicId, NO);

	TGTestExpectTrue(&outcome, [topic[@"@type"] isEqualToString:@"messageTopicSavedMessages"],
			"a saved-messages topic id must resolve to messageTopicSavedMessages even with no thread id");
	TGTestExpectEqualLongLong(&outcome, [topic[@"saved_messages_topic_id"] longLongValue], savedTopicId,
			"the saved_messages_topic_id must be carried through unchanged");

	return outcome;
}

TGTestOutcome TGTopicDictionaryTestDirectMessagesTopicTakesPriority(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	long long directMessagesTopicId = 7LL;
	NSDictionary *topic = TGTopicDictionary(0, directMessagesTopicId, 0, NO);

	TGTestExpectTrue(&outcome, [topic[@"@type"] isEqualToString:@"messageTopicDirectMessages"],
			"a direct-messages topic id must resolve to messageTopicDirectMessages even with no thread id");
	TGTestExpectEqualLongLong(&outcome, [topic[@"direct_messages_chat_topic_id"] longLongValue],
			directMessagesTopicId, "the direct_messages_chat_topic_id must be carried through unchanged");

	return outcome;
}

TGTestOutcome TGTopicDictionaryTestDirectMessagesTopicOutranksSavedTopic(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *topic = TGTopicDictionary(0, 7LL, 42LL, NO);

	TGTestExpectTrue(&outcome, [topic[@"@type"] isEqualToString:@"messageTopicDirectMessages"],
			"when both a direct-messages topic and a saved topic id are set, direct messages must win");

	return outcome;
}

TGTestOutcome TGTopicDictionaryTestForumThreadFallsBackToMessageTopicForum(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	long long forumTopicId = 500LL;
	NSDictionary *topic = TGTopicDictionary(forumTopicId, 0, 0, YES);

	TGTestExpectTrue(&outcome, [topic[@"@type"] isEqualToString:@"messageTopicForum"],
			"with no saved/direct-messages topic set, a forum chat's thread id must resolve to messageTopicForum");

	return outcome;
}

TGTestOutcome TGTopicDictionaryTestNonForumThreadFallsBackToMessageTopicThread(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	long long messageThreadId = 524288000000LL;
	NSDictionary *topic = TGTopicDictionary(messageThreadId, 0, 0, NO);

	TGTestExpectTrue(&outcome, [topic[@"@type"] isEqualToString:@"messageTopicThread"],
			"with no saved/direct-messages topic set, a non-forum chat's thread id must resolve to messageTopicThread, not messageTopicForum");
	TGTestExpectEqualLongLong(&outcome, [topic[@"message_thread_id"] longLongValue], messageThreadId,
			"the message_thread_id must not be truncated when falling back to messageTopicThread");

	return outcome;
}

TGTestOutcome TGTopicDictionaryTestNoTopicAtAllReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGTopicDictionary(0, 0, 0, NO) == nil,
			"with no thread id, saved topic, or direct-messages topic, no topic scope must be sent at all");
	TGTestExpectTrue(&outcome, TGTopicDictionary(0, 0, 0, YES) == nil,
			"with no thread id, saved topic, or direct-messages topic, no topic scope must be sent at all, even in a forum chat");

	return outcome;
}

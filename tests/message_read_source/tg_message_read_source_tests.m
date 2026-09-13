#import "tg_message_read_source_tests.h"
#import "../../src/TDLibClient/TGMessageReadSource.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGMessageReadSourceTestViewingThreadReturnsThread(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGMessageReadSource(YES, NO) isEqualToString:@"thread"],
			"viewing a comment/discussion thread in a non-forum chat must mark messages read with "
			"the thread-scoped source so TDLib propagates the read pointer to the reply-count machinery");

	return outcome;
}

TGTestOutcome TGMessageReadSourceTestViewingForumTopicReturnsForumTopic(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGMessageReadSource(YES, YES) isEqualToString:@"forum_topic"],
			"viewing a forum topic must mark messages read with the forum-topic-scoped source so "
			"TDLib's ForumTopicManager clears that topic's own unread counter, not the unrelated "
			"comment-thread reply-info machinery");

	return outcome;
}

TGTestOutcome TGMessageReadSourceTestNotViewingThreadReturnsHistory(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGMessageReadSource(NO, NO) isEqualToString:@"history"],
			"an ordinary chat view must keep using the plain chat-history read source");

	return outcome;
}

TGTestOutcome TGMessageReadSourceTestNotViewingThreadInForumChatReturnsHistory(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGMessageReadSource(NO, YES) isEqualToString:@"history"],
			"the forum flag must only matter while actually viewing a thread/topic, never override "
			"the plain chat-history source on its own");

	return outcome;
}

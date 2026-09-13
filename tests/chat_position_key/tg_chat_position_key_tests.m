#import "tg_chat_position_key_tests.h"
#import "../../src/Screens/Chat/TGChatPositionKey.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGChatPositionKeyTestSameChatDifferentThreadsProduceDifferentKeys(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *groupKey = TGChatPositionKey(1001, 0);
	NSString *threadKey = TGChatPositionKey(1001, 555);

	TGTestExpectTrue(&outcome, ![groupKey isEqualToString:threadKey],
			"a discussion group's own scroll position and a comment thread inside it "
			"share the same chat id, so the key must also fold in the thread id to stay separate");

	return outcome;
}

TGTestOutcome TGChatPositionKeyTestSameChatAndThreadProduceTheSameKey(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *first = TGChatPositionKey(1001, 555);
	NSString *second = TGChatPositionKey(1001, 555);

	TGTestExpectTrue(&outcome, [first isEqualToString:second],
			"the same chat and thread must always produce the same storage key");

	return outcome;
}

TGTestOutcome TGChatPositionKeyTestZeroThreadKeyDiffersFromNonzeroThreadKey(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *keyForTwoDifferentThreadsInDifferentChats = TGChatPositionKey(2002, 1001);
	NSString *keyForTheChatItself = TGChatPositionKey(1001, 2002);

	TGTestExpectTrue(&outcome, ![keyForTwoDifferentThreadsInDifferentChats isEqualToString:keyForTheChatItself],
			"swapping which id is the chat id and which is the thread id must not collide, "
			"so two visits to different posts' threads on the same group cannot stomp on each other either");

	return outcome;
}

#import "TGMessageTopic.h"

NSDictionary *TGMessageTopicDictionary(int64_t threadId, BOOL chatIsForum) {
	if (threadId == 0)
		return nil;
	if (chatIsForum)
		return @{@"@type" : @"messageTopicForum",
			@"forum_topic_id" : @((int32_t)threadId)};
	return @{@"@type" : @"messageTopicThread",
		@"message_thread_id" : @(threadId)};
}

NSDictionary *TGTopicDictionary(int64_t threadId, int64_t directMessagesTopicId, int64_t savedTopicId,
	BOOL chatIsForum) {
	if (directMessagesTopicId != 0)
		return @{@"@type" : @"messageTopicDirectMessages",
			@"direct_messages_chat_topic_id" : @(directMessagesTopicId)};
	if (savedTopicId != 0)
		return @{@"@type" : @"messageTopicSavedMessages",
			@"saved_messages_topic_id" : @(savedTopicId)};
	return TGMessageTopicDictionary(threadId, chatIsForum);
}

#import <Foundation/Foundation.h>

NSDictionary *TGMessageTopicDictionary(int64_t threadId, BOOL chatIsForum);
NSDictionary *TGTopicDictionary(int64_t threadId, int64_t directMessagesTopicId, int64_t savedTopicId,
	BOOL chatIsForum);

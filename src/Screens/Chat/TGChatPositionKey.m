#import "TGChatPositionKey.h"

NSString *TGChatPositionKey(int64_t chatId, int64_t threadId) {
	return [NSString stringWithFormat:@"%lld:%lld", chatId, threadId];
}

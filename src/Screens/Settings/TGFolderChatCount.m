#import "TGFolderChatCount.h"

BOOL TGFolderChatCountIsTrustworthy(NSInteger count, BOOL chatListsLoaded) {
	return chatListsLoaded || count > 0;
}

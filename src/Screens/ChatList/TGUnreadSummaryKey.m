#import "TGUnreadSummaryKey.h"

NSString *TGUnreadSummaryKeyForBadge(BOOL countsChats, BOOL includesMuted) {
	if (countsChats)
		return includesMuted ? @"chats" : @"unmutedChats";
	return includesMuted ? @"messages" : @"unmutedMessages";
}

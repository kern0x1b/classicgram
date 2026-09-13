#import "TGMessageReadSource.h"

NSString *TGMessageReadSource(BOOL isViewingThread, BOOL chatIsForum) {
	if (!isViewingThread)
		return @"history";
	return chatIsForum ? @"forum_topic" : @"thread";
}

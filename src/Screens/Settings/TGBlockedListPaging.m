#import "TGBlockedListPaging.h"

BOOL TGBlockedListIsExhausted(NSInteger fetchedCount, NSInteger pageSize, NSInteger loadedCount,
	NSInteger totalCount) {
	if (pageSize <= 0)
		return YES;
	if (fetchedCount < pageSize)
		return YES;
	return totalCount > 0 && loadedCount >= totalCount;
}

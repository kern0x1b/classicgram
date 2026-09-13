#import "TGStoryPaging.h"

BOOL TGStoryPageHasMore(NSUInteger loadedCount, NSUInteger fetchedCount, NSInteger totalCount) {
	if (fetchedCount == 0 || totalCount <= 0)
		return NO;
	return (NSInteger)(loadedCount + fetchedCount) < totalCount;
}

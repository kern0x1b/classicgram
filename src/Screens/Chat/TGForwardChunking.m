#import "TGForwardChunking.h"

const NSUInteger TGForwardMessagesMaxChunkSize = 100;

NSArray<NSArray *> *TGChunkedForwardMessageIds(NSArray *sortedIds, NSUInteger chunkSize) {
	NSMutableArray<NSArray *> *chunks = [NSMutableArray array];
	if (!sortedIds.count || !chunkSize)
		return chunks;
	NSUInteger total = sortedIds.count;
	for (NSUInteger start = 0; start < total; start += chunkSize) {
		NSUInteger length = MIN(chunkSize, total - start);
		[chunks addObject:[sortedIds subarrayWithRange:NSMakeRange(start, length)]];
	}
	return chunks;
}

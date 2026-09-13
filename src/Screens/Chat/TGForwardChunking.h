#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern const NSUInteger TGForwardMessagesMaxChunkSize;

NSArray<NSArray *> *TGChunkedForwardMessageIds(NSArray *sortedIds, NSUInteger chunkSize);

NS_ASSUME_NONNULL_END

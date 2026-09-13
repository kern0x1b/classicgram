#import <Foundation/Foundation.h>

@class TGMessageItem;
@class TGChatLayoutContext;
@class TGMessageLayout;

@interface TGMessageLayoutCache : NSObject

- (instancetype)initWithCapacity:(NSUInteger)capacity NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (TGMessageLayout *)layoutForItem:(TGMessageItem *)item
						   context:(TGChatLayoutContext *)context;

- (void)invalidateMessageId:(int64_t)messageId;

@property (nonatomic, readonly) NSUInteger hitCount;
@property (nonatomic, readonly) NSUInteger missCount;
@property (nonatomic, readonly) NSUInteger evictionCount;

- (void)resetCounts;

@end

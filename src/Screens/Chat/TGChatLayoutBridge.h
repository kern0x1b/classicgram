#import <UIKit/UIKit.h>
#import "TGBubbleCellDelegate.h"

@class TGChatLayoutContext;
@class TGMessageItem;
@class TGMessageRowCell;

@protocol TGChatLayoutBridgeSelectionDelegate <NSObject>

- (void)configureSelectionForCell:(TGMessageRowCell *)cell atRow:(NSInteger)row;

@end

@interface TGChatLayoutBridge : NSObject

- (instancetype)initWithContext:(TGChatLayoutContext *)context NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong) TGChatLayoutContext *context;
@property (nonatomic, weak) id<TGBubbleCellDelegate> delegate;
@property (nonatomic, weak) id<TGChatLayoutBridgeSelectionDelegate> selectionDelegate;

- (void)setItem:(TGMessageItem *)item forRow:(NSInteger)row;
- (void)removeAllItems;

- (CGFloat)heightForRow:(NSInteger)row;
- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table;

- (void)invalidateMessageId:(int64_t)messageId;
- (NSString *)cacheCountsDescription;
- (void)resetCacheCounts;

@end

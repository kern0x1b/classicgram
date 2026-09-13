#import <UIKit/UIKit.h>
#import "TGSearchResultItem.h"

@class TGSearchResultsPresenter;
@class TGSearchResultsRowBridge;

BOOL TGSearchRowKindIsMigrated(TGSearchRowKind kind);

@protocol TGSearchResultsRowBridgeDelegate <NSObject>

@optional

- (UIImage *)searchResultsRowBridge:(TGSearchResultsRowBridge *)bridge
					avatarForChatId:(int64_t)chatId
							  title:(NSString *)title
							 fileId:(NSNumber *)fileId
							   size:(CGFloat)size;

@end

@interface TGSearchResultsRowBridge : NSObject

- (instancetype)initWithPresenter:(TGSearchResultsPresenter *)presenter NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) TGSearchResultsPresenter *presenter;
@property (nonatomic, weak) id<TGSearchResultsRowBridgeDelegate> delegate;

- (BOOL)ownsRowAtIndexPath:(NSIndexPath *)indexPath;
- (UITableViewCell *)cellForIndexPath:(NSIndexPath *)indexPath inTable:(UITableView *)table;

@end

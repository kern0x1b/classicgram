#import <UIKit/UIKit.h>
#import "TGInstantViewItem.h"

@class TGInstantViewPresenter;
@class TGInstantViewRowBridge;

BOOL TGInstantViewRowKindIsMigrated(TGInstantViewRowKind kind);

@protocol TGInstantViewRowBridgeDelegate <NSObject>

@optional

- (UIImage *)instantViewRowBridge:(TGInstantViewRowBridge *)bridge imageForFileId:(long long)fileId;

@end

@interface TGInstantViewRowBridge : NSObject

- (instancetype)initWithPresenter:(TGInstantViewPresenter *)presenter NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) TGInstantViewPresenter *presenter;
@property (nonatomic, weak) id<TGInstantViewRowBridgeDelegate> delegate;

- (BOOL)ownsRowAtIndex:(NSInteger)row;
- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table;

@end

#import <UIKit/UIKit.h>
#import "TGCallsItem.h"

@class TGCallsPresenter;
@class TGCallsRowBridge;

BOOL TGCallsRowKindIsMigrated(TGCallsRowKind kind);

@protocol TGCallsRowBridgeDelegate <NSObject>

@optional

- (UIImage *)callsRowBridge:(TGCallsRowBridge *)bridge avatarForKey:(NSNumber *)avatarKey;

@end

@interface TGCallsRowBridge : NSObject

- (instancetype)initWithPresenter:(TGCallsPresenter *)presenter NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) TGCallsPresenter *presenter;
@property (nonatomic, weak) id<TGCallsRowBridgeDelegate> delegate;

- (BOOL)ownsRowAtIndex:(NSInteger)row;
- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table;

@end

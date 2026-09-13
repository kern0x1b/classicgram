#import <UIKit/UIKit.h>
#import "TGGroupMembersItem.h"

@class TGGroupMembersPresenter;
@class TGGroupMembersRowBridge;

BOOL TGGroupMembersRowKindIsMigrated(TGGroupMembersRowKind kind);

@protocol TGGroupMembersRowBridgeDelegate <NSObject>

@optional

- (UIImage *)groupMembersRowBridge:(TGGroupMembersRowBridge *)bridge avatarForUserId:(long long)userId;

@end

@interface TGGroupMembersRowBridge : NSObject

- (instancetype)initWithPresenter:(TGGroupMembersPresenter *)presenter NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) TGGroupMembersPresenter *presenter;
@property (nonatomic, weak) id<TGGroupMembersRowBridgeDelegate> delegate;

- (BOOL)ownsRowAtIndex:(NSInteger)row;
- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table;

@end

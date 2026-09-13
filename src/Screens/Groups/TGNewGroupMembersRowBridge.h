#import <UIKit/UIKit.h>
#import "TGNewGroupMembersItem.h"

@class TGNewGroupMembersPresenter;
@class TGNewGroupMembersRowBridge;

BOOL TGNewGroupMembersRowKindIsMigrated(TGNewGroupMembersRowKind kind);

@interface TGNewGroupMembersRowBridge : NSObject

- (instancetype)initWithPresenter:(TGNewGroupMembersPresenter *)presenter NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) TGNewGroupMembersPresenter *presenter;

- (BOOL)ownsRowAtIndex:(NSInteger)row;
- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table;

@end

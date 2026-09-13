#import <UIKit/UIKit.h>
#import "TGProfileDetailItem.h"

@class TGProfileDetailPresenter;
@class TGProfileDetailRowBridge;

BOOL TGProfileDetailRowKindIsMigrated(TGProfileDetailRowKind kind);

@interface TGProfileDetailRowBridge : NSObject

- (instancetype)initWithPresenter:(TGProfileDetailPresenter *)presenter NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) TGProfileDetailPresenter *presenter;

- (BOOL)ownsRowAtIndex:(NSInteger)row;
- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table;

@end

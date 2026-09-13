#import <UIKit/UIKit.h>
#import "TGStarsListItem.h"

@class TGStarsListPresenter;

BOOL TGStarsListRowKindIsMigrated(TGStarsListRowKind kind);

@interface TGStarsListRowBridge : NSObject

- (instancetype)initWithPresenter:(TGStarsListPresenter *)presenter NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) TGStarsListPresenter *presenter;

- (BOOL)ownsRowAtIndex:(NSInteger)row;
- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table;

@end

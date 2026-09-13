#import <UIKit/UIKit.h>
#import "TGStoryViewersItem.h"

@class TGStoryViewersPresenter;

BOOL TGStoryViewersRowKindIsMigrated(TGStoryViewersRowKind kind);

@interface TGStoryViewersRowBridge : NSObject

- (instancetype)initWithPresenter:(TGStoryViewersPresenter *)presenter NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) TGStoryViewersPresenter *presenter;

- (BOOL)ownsRowAtIndex:(NSInteger)row;
- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table;

@end

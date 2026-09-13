#import <UIKit/UIKit.h>
#import "TGHiddenStoriesItem.h"

@class TGHiddenStoriesPresenter;
@class TGHiddenStoriesRowBridge;

BOOL TGHiddenStoriesRowKindIsMigrated(TGHiddenStoriesRowKind kind);

@interface TGHiddenStoriesRowBridge : NSObject

- (instancetype)initWithPresenter:(TGHiddenStoriesPresenter *)presenter NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) TGHiddenStoriesPresenter *presenter;

- (BOOL)ownsRowAtIndex:(NSInteger)row;
- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table;

@end

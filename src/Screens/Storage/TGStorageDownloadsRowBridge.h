#import <UIKit/UIKit.h>
#import "TGStorageDownloadsItem.h"

@class TGStorageDownloadsPresenter;

BOOL TGStorageDownloadsRowKindIsMigrated(TGStorageDownloadsRowKind kind);

@interface TGStorageDownloadsRowBridge : NSObject

- (instancetype)initWithPresenter:(TGStorageDownloadsPresenter *)presenter NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) TGStorageDownloadsPresenter *presenter;

- (BOOL)ownsEntryRowAtIndex:(NSInteger)row;
- (BOOL)ownsClearRow;
- (UITableViewCell *)cellForEntryRow:(NSInteger)row inTable:(UITableView *)table;
- (UITableViewCell *)cellForClearRowInTable:(UITableView *)table;

@end

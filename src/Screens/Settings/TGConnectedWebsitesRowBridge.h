#import <UIKit/UIKit.h>
#import "TGConnectedWebsitesItem.h"

@class TGConnectedWebsitesPresenter;
@class TGConnectedWebsitesRowBridge;

BOOL TGConnectedWebsitesRowKindIsMigrated(TGConnectedWebsitesRowKind kind);

@interface TGConnectedWebsitesRowBridge : NSObject

- (instancetype)initWithPresenter:(TGConnectedWebsitesPresenter *)presenter NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) TGConnectedWebsitesPresenter *presenter;

- (BOOL)ownsRowAtIndex:(NSInteger)row;
- (UITableViewCell *)cellForRow:(NSInteger)row inTable:(UITableView *)table;

@end

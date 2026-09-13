#import <UIKit/UIKit.h>

@interface TGTableReloadCoalescer : NSObject

- (instancetype)initWithTableView:(UITableView *)tableView;
- (void)setNeedsReload;

@property (nonatomic, readonly) BOOL reloadPending;

@end

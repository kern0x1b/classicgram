#import <UIKit/UIKit.h>

@interface TGBusinessBotSearchViewController : UITableViewController <UISearchBarDelegate>

@property (nonatomic, copy) NSString *initialUsername;
@property (nonatomic, copy) void (^onPick)(int64_t userId, NSString *name);

@end

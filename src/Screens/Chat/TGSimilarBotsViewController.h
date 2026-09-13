#import <UIKit/UIKit.h>

@interface TGSimilarBotsViewController : UITableViewController
@property (nonatomic, assign) int64_t botUserId;
@property (nonatomic, copy) void (^onPick)(NSDictionary *entry);
@end

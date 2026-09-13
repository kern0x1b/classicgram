#import <UIKit/UIKit.h>

@interface TGProfilePermissionsController : UITableViewController
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, strong) NSMutableDictionary *permissions;
@end

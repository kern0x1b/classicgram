#import <UIKit/UIKit.h>

@interface TGProfileCommonGroupsController : UITableViewController
@property (nonatomic, assign) int64_t userId;
@property (nonatomic, strong) NSArray *chats;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL loadFailed;
@end

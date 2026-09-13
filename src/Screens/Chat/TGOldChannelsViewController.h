#import <UIKit/UIKit.h>

@interface TGOldChannelsViewController : UITableViewController

@property (nonatomic, strong) NSArray *chats;
@property (nonatomic, copy) void (^onLeft)(void);

@end

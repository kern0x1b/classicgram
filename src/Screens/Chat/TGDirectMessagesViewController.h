#import <UIKit/UIKit.h>

@interface TGDirectMessagesViewController : UITableViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy) NSString *chatTitle;

@end

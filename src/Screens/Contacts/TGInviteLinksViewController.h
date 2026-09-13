#import <UIKit/UIKit.h>

@interface TGInviteLinksViewController : UITableViewController

@property (nonatomic, assign) int64_t chatId;

- (instancetype)initWithChatId:(int64_t)chatId;

@end

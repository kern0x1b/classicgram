#import <UIKit/UIKit.h>

@interface TGPrepaidGiveawayViewController : UITableViewController

- (instancetype)initWithChatId:(int64_t)chatId giveaways:(NSArray *)giveaways;

@end

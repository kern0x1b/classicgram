#import <UIKit/UIKit.h>

@interface TGBotCommandsViewController : UITableViewController
@property (nonatomic, strong) NSArray *commands;
@property (nonatomic, copy) void (^onPick)(NSString *command);
@end

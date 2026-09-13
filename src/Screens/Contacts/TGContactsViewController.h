#import <UIKit/UIKit.h>

@interface TGContactsViewController : UITableViewController
@property (nonatomic, assign) BOOL pickerMode;

@property (nonatomic, copy) void (^onUserPicked)(int64_t userId, NSString *name);

+ (UIViewController *)secretChatInfoForChat:(int64_t)chatId
									 userId:(int64_t)userId
									   name:(NSString *)name;
@end

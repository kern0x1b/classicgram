#import <UIKit/UIKit.h>

@interface TGGroupMembersViewController : UIViewController

@property (nonatomic, assign) int64_t chatId;

@property (nonatomic, assign) NSInteger initialMode;

@property (nonatomic, copy) void (^onChatUpgraded)(int64_t newChatId);

@end

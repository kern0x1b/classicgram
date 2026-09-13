#import <UIKit/UIKit.h>
#import "TGProfileChartView.h"

@interface TGProfileViewController : UITableViewController

@property (nonatomic, assign) int64_t threadId;
@property (nonatomic, copy) void (^onSearchTapped)(void);
@property (nonatomic, copy) void (^onChatUpgraded)(int64_t newChatId);

- (instancetype)initWithChatId:(int64_t)chatId
						userId:(int64_t)userId
						 title:(NSString *)title;

+ (void)showProfileForChatId:(int64_t)chatId
					  userId:(int64_t)userId
					   title:(NSString *)title
				inNavigation:(UINavigationController *)navigation;

@end

#import <UIKit/UIKit.h>

@interface TGDirectMessagesSettingsViewController : UITableViewController <UIAlertViewDelegate>

@property (nonatomic, assign) int64_t topicsChatId;
@property (nonatomic, copy) NSString *chatTitle;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSInteger starCount;
@property (nonatomic, copy) void (^onChange)(BOOL enabled, NSInteger starCount, void (^completion)(BOOL ok));
@property (nonatomic, copy) void (^onOpenTopics)(void);

@end

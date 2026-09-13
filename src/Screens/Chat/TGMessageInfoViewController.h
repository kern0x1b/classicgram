#import <UIKit/UIKit.h>

@interface TGPollVoteStatisticsViewController : UIViewController
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int64_t messageId;
@end

@interface TGPollOptionVotersViewController : UITableViewController
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int64_t messageId;
@property (nonatomic, assign) NSInteger optionIndex;
@property (nonatomic, copy) NSString *optionTitle;
@end

@interface TGMessageInfoViewController : UITableViewController <UIAlertViewDelegate,
											 UIActionSheetDelegate>
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int64_t messageId;
@property (nonatomic, strong) NSDictionary *message;
@property (nonatomic, assign) BOOL group;
@property (nonatomic, assign) BOOL canResend;
@property (nonatomic, copy) void (^onOpenChat)(int64_t chatId, NSString *title);
@property (nonatomic, assign) int64_t threadChatId;
@property (nonatomic, copy) NSString *focusSection;
@end

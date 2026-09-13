#import <UIKit/UIKit.h>

@interface TGScheduledMessagesViewController : UITableViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) BOOL remindersStyle;

@property (nonatomic, copy) NSString * (^previewOfMessage)(NSDictionary *message);
@property (nonatomic, copy) void (^onReschedule)(int64_t messageId, NSTimeInterval sendDate);
@property (nonatomic, copy) void (^onEdit)(NSDictionary *message);

@end

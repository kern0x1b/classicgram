#import <UIKit/UIKit.h>

@interface TGStorageChatViewController : UITableViewController <UIActionSheetDelegate>
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy) NSString *chatTitle;
@property (nonatomic, assign) long long bytes;
@property (nonatomic, assign) NSInteger files;
@property (nonatomic, copy) void (^didChange)(void);
@end

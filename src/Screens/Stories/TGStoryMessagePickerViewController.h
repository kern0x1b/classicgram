#import <UIKit/UIKit.h>

@interface TGStoryMessagePickerViewController : UITableViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy) void (^onPicked)(int64_t messageId);

@end

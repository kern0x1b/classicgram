#import <UIKit/UIKit.h>

@interface TGEmojiStatusPickerViewController : UITableViewController

- (instancetype)init;

- (instancetype)initForChat:(int64_t)chatId;

@end

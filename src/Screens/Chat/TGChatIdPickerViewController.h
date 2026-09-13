#import <UIKit/UIKit.h>

@interface TGChatIdPickerViewController : UITableViewController
@property (nonatomic, strong) NSArray *chatIds;
@property (nonatomic, strong) NSDictionary *titles;
@property (nonatomic, copy) NSString *prompt;
@property (nonatomic, copy) NSString *confirmTitle;
@property (nonatomic, copy) void (^onConfirm)(NSArray *chatIds);
@end

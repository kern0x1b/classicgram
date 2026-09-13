#import <UIKit/UIKit.h>

@interface TGCountryPickerViewController : UITableViewController
@property (nonatomic, copy) void (^onPick)(NSString *name, NSString *flag, NSString *dialCode);
@end

#import <UIKit/UIKit.h>

@interface TGTimeZonePickerViewController : UITableViewController

@property (nonatomic, copy) NSString *selectedTimeZoneId;
@property (nonatomic, copy) void (^onPicked)(NSString *timeZoneId);

@end

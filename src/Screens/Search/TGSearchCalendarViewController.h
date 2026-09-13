#import <UIKit/UIKit.h>

@interface TGSearchCalendarViewController : UITableViewController
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy) NSString *chatTitle;
@property (nonatomic, copy) NSString *filterName;
@property (nonatomic, copy) void (^onPickDate)(NSInteger date);
@end

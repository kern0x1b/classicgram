#import <UIKit/UIKit.h>

@interface TGStorageDownloadsViewController : UITableViewController <UIActionSheetDelegate>
@property (nonatomic, copy) void (^didChange)(void);
@end

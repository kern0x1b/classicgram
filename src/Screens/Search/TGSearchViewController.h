#import <UIKit/UIKit.h>

@interface TGSearchViewController : UITableViewController
@property (nonatomic, assign) BOOL archiveOnly;
@property (nonatomic, copy) NSString *presetQuery;
@end

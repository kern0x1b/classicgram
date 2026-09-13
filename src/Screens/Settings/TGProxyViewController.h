#import <UIKit/UIKit.h>

@interface TGProxyViewController : UITableViewController

- (instancetype)init;

+ (void)presentFormForProxyLink:(NSString *)link inNavigationController:(UINavigationController *)navigationController;

@end

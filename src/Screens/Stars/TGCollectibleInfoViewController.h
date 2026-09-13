#import <UIKit/UIKit.h>

@interface TGCollectibleInfoViewController : UITableViewController

- (instancetype)initWithUsername:(NSString *)username;
- (instancetype)initWithCollectibleType:(NSDictionary *)type title:(NSString *)title;

@end

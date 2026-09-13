#import <UIKit/UIKit.h>

extern NSString *const TGGiftValueInfoFragmentRowKind;

@interface TGGiftValueInfoViewController : UITableViewController

- (instancetype)initWithRows:(NSArray *)rows fragmentUrl:(NSString *)fragmentUrl;

@end

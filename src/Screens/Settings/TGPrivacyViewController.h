#import <UIKit/UIKit.h>

@interface TGPrivacyViewController : UITableViewController
@end

@interface TGBlockedUsersViewController : UITableViewController
@end

@interface TGPrivacyRuleViewController : UITableViewController
- (instancetype)initWithSetting:(NSString *)setting;
@end

@interface TGPasscodeViewController : UITableViewController
@end

@interface TGTwoStepViewController : UITableViewController
@end

#import <UIKit/UIKit.h>

@interface TGInviteFriendsViewController : UITableViewController
@property (nonatomic, strong) NSArray *entries;
@property (nonatomic, strong) NSMutableSet *selected;
@property (nonatomic, copy) NSString *inviteText;
@property (nonatomic, strong) UIButton *inviteButton;
@property (nonatomic, strong) UILabel *inviteLabel;
@end

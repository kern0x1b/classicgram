#import <UIKit/UIKit.h>

@interface TGNewGroupMembersViewController : UITableViewController <UIAlertViewDelegate>
@property (nonatomic, strong) NSArray *contacts;
@property (nonatomic, strong) NSMutableArray *selected;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) UILabel *nextLabel;
@property (nonatomic, assign) BOOL creatingGroup;
@end

#import <UIKit/UIKit.h>

@interface TGAccountUsernamesViewController : UITableViewController <UIActionSheetDelegate>
@property (nonatomic, strong) NSMutableArray *active;
@property (nonatomic, strong) NSMutableArray *disabled;
@property (nonatomic, copy) NSString *editableUsername;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, copy) NSString *pendingUsername;
@property (nonatomic, strong) NSArray *pendingActionTitles;
@property (nonatomic, copy) void (^onChanged)(NSArray *active, NSArray *disabled);
- (id)initWithActiveUsernames:(NSArray *)active
			disabledUsernames:(NSArray *)disabled
			 editableUsername:(NSString *)editableUsername;
@end

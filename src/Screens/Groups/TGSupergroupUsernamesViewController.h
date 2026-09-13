#import <UIKit/UIKit.h>

@interface TGSupergroupUsernamesViewController : UITableViewController <UIActionSheetDelegate>
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, strong) NSMutableArray *active;
@property (nonatomic, strong) NSMutableArray *disabled;
@property (nonatomic, strong) NSString *editableUsername;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, strong) NSString *pendingUsername;
@property (nonatomic, strong) NSArray *pendingActionTitles;
@property (nonatomic, copy) void (^onChanged)(NSArray *active, NSArray *disabled);

- (id)initWithChatId:(int64_t)chatId
	  activeUsernames:(NSArray *)active
	disabledUsernames:(NSArray *)disabled
	 editableUsername:(NSString *)editableUsername;
@end

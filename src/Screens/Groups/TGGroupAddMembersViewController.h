#import <UIKit/UIKit.h>

@interface TGGroupAddMembersViewController : UITableViewController <UISearchBarDelegate> {
	int64_t _chatId;
}

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray *users;
@property (nonatomic, strong) NSMutableArray *picked;
@property (nonatomic, strong) NSMutableDictionary *pickedNames;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) NSInteger generation;
@property (nonatomic, assign) BOOL adding;
@property (nonatomic, copy) void (^onAdded)(void);

- (id)initWithChatId:(int64_t)chatId;

@end

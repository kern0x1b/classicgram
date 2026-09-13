#import <UIKit/UIKit.h>

@interface TGStarsListViewController : UITableViewController

- (id)initWithTitle:(NSString *)title;

@property (nonatomic, strong) NSMutableArray *rows;
@property (nonatomic, strong) NSString *comment;
@property (nonatomic, strong) NSString *emptyText;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL moreAvailable;
@property (nonatomic, copy) void (^loadMoreBlock)(void);

@property (nonatomic, strong) NSArray *tabTitles;
@property (nonatomic, assign) NSInteger selectedTabIndex;
@property (nonatomic, copy) void (^onTabSelected)(NSInteger index);
@property (nonatomic, weak) TGStarsListViewController *mirrorTarget;

- (void)appendRow:(NSDictionary *)row;
- (void)finishLoadingWithMore:(BOOL)more;

@end

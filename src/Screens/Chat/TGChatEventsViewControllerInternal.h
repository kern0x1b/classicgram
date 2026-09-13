#import <UIKit/UIKit.h>
#import "TGChatEventsViewController.h"
#import "TGActionSheet.h"
#import "TGPlaceholderView.h"

extern const CGFloat kEventsAvatarSide;
extern const CGFloat kEventsMinRowHeight;

CGFloat TGEventsRetinaPixel(void);

NSNumber *TGEventsNumber(NSDictionary *source, NSString *key);
long long TGEventsLongLong(NSDictionary *source, NSString *key);
int TGEventsInt(NSDictionary *source, NSString *key);
NSString *TGEventsText(NSDictionary *source, NSString *key);

@interface TGChatEventCell : UITableViewCell

@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *bodyLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UIView *hairline;

+ (CGFloat)heightForText:(NSString *)text width:(CGFloat)width;

@end

@interface TGChatEventsViewController () <UISearchBarDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) TGPlaceholderView *messageView;
@property (nonatomic, strong) NSMutableArray *events;
@property (nonatomic, strong) NSMutableArray *sections;
@property (nonatomic, strong) NSArray *filters;
@property (nonatomic, strong) NSArray *userIds;
@property (nonatomic, strong) NSArray *administrators;
@property (nonatomic, strong) TGActionSheet *currentActionSheet;
@property (nonatomic, strong) UIView *headerContainer;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIButton *spamBanner;
@property (nonatomic, strong) UIButton *infoButton;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, strong) NSMutableSet *expandedGroupIds;
@property (nonatomic, assign) BOOL broadcastChannel;
@property (nonatomic, assign) long long oldestEventId;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL failed;
@property (nonatomic, assign) BOOL exhausted;
@property (nonatomic, assign) NSInteger loadGeneration;
@property (nonatomic, strong) id themeChangedObserverToken;

- (void)layoutHeaderContainer;
- (void)layoutOverlays;
@end

@interface TGChatEventsViewController (Spam)

- (void)updateSpamBanner;
- (void)markReported:(NSArray *)messageIds;
- (void)spamBannerPressed;

@end

@interface TGChatEventsViewController (Loading)

- (void)reload;
- (void)loadNextPage;
- (void)retryLoadingEvents;

@end

@interface TGChatEventsViewController (Grouping)

- (void)rebuildSections;
- (NSDictionary *)eventAtIndexPath:(NSIndexPath *)indexPath;
- (NSString *)summaryForEvent:(NSDictionary *)event;
- (void)toggleGroupExpanded:(NSNumber *)groupKey;

@end

@interface TGChatEventsViewController (Filter)

- (void)filterPressed;

@end

@interface TGChatEventsViewController (Table) <UITableViewDataSource, UITableViewDelegate>
@end

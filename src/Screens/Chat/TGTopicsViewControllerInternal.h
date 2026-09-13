#import "TGTopicsViewController.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGChatViewController.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGActionSheet.h"
#import "TGPopupMenu.h"
#import "TGDateUtils.h"
#import "TGDateLabel.h"
#import "UIView+SafeTint.h"
#import <QuartzCore/QuartzCore.h>
#import "TGAlertView.h"
#import "TGPlaceholderView.h"

#import "TGTopicCell.h"
#import "TGTopicInfoController.h"
#import "TGTopicComposeController.h"

extern const CGFloat kTopicRowHeight;
extern const CGFloat kTopicAvatar;
extern const CGFloat kTopicAvatarLeft;
extern const CGFloat kTopicTextLeft;
extern NSMutableDictionary *TGTopicAvatarCache;
extern const NSInteger kTopicNameAlertEdit;
extern const NSInteger kTopicDeleteAlert;
extern const NSInteger kTopicUnpinAllAlert;

UIImage *TGTopicBadgeImage(void);
UIImage *TGTopicBadgeHighlightedImage(void);
NSString *TGTopicDate(NSTimeInterval unix);
BOOL TGTopicFlag(NSDictionary *topic, NSString *key);
NSInteger TGTopicInteger(NSDictionary *topic, NSString *key);
long long TGTopicLongLong(NSDictionary *topic, NSString *key);
double TGTopicDouble(NSDictionary *topic, NSString *key);
NSString *TGTopicString(NSDictionary *topic, NSString *key);
NSString *TGTopicInitial(NSString *name);
UIImage *TGTopicPlateImage(void);
CGFloat TGTopicAvatarCornerRadius(CGFloat side);
UIImage *TGTopicDrawAvatar(NSString *initials, CGFloat size, NSInteger rgb);
void TGTopicFlushAvatarCache(void);
UIImage *TGTopicAvatarImage(NSString *initials, CGFloat size, NSInteger rgb);

@interface TGTopicsViewController () <UIAlertViewDelegate, UISearchBarDelegate>

@property (nonatomic, strong) NSArray *topics;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray *searchResults;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, assign) BOOL searching;
@property (nonatomic, assign) BOOL canCreateTopics;
@property (nonatomic, assign) BOOL canManageTopics;
@property (nonatomic, assign) BOOL canPinMessages;
@property (nonatomic, assign) BOOL canDeleteTopics;
@property (nonatomic, assign) BOOL rightsLoaded;
@property (nonatomic, assign) NSInteger pendingColour;
@property (nonatomic, copy) NSString *pendingName;
@property (nonatomic, strong) TGPlaceholderView *emptyContainer;
@property (nonatomic, assign) BOOL searchFieldStyled;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) NSDictionary *nextOffset;
@property (nonatomic, assign) NSInteger totalCount;
@property (nonatomic, assign) BOOL loadingMore;
@property (nonatomic, assign) BOOL reachedEnd;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL loadedOnce;
@property (nonatomic, strong) NSArray *iconChoices;
@property (nonatomic, strong) NSDictionary *actionTopic;
@property (nonatomic, assign) BOOL deletingTopic;
@property (nonatomic, strong) TGActionSheet *currentActionSheet;
@property (nonatomic, assign) CGPoint menuPoint;
@property (nonatomic, assign) BOOL reordering;
@property (nonatomic, assign) BOOL orderDirty;
@property (nonatomic, assign) BOOL reloadPendingAfterReorder;
@property (nonatomic, strong) id themeChangedObserverToken;
@property (nonatomic, strong) id customEmojiObserverToken;
@property (nonatomic, strong) id forumTopicObserverToken;

@end

@interface TGTopicsViewController (Private)

- (void)viewDidLoad;

- (void)buildBackgroundView;

- (void)buildRefreshControl;

- (void)buildSearchBar;

- (BOOL)usesPlainPlate;

- (void)styleSearchBar;

- (void)styleSearchInputField:(UIView *)view;

- (void)dealloc;

- (void)didReceiveMemoryWarning;

- (void)viewWillAppear:(BOOL)animated;

- (void)viewDidLayoutSubviews;

- (void)viewWillDisappear:(BOOL)animated;

- (void)buildTitleView;

- (void)updateSubtitle;

- (void)themeChanged;

- (void)forumTopicChanged:(NSNotification *)note;

- (void)loadRights;

- (void)updateCreateButton;

- (BOOL)canEditTopic:(NSDictionary *)topic;

- (BOOL)canDeleteTopic:(NSDictionary *)topic;

- (NSArray *)displayedTopics;

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar;

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text;

- (void)runSearch;

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar;

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar;

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar;

- (void)reloadTopics;

- (NSArray *)cleanedTopics:(NSArray *)topics;

- (NSArray *)orderedTopics:(NSArray *)topics;

- (void)updateEmptyState;

- (void)layoutEmptyContent;

- (void)loadMoreTopics;

- (void)tableView:(UITableView *)tableView
	  willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath;

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;

- (void)resetTopicCell:(TGTopicCell *)cell theme:(TGTheme *)theme plainPlate:(BOOL)plainPlate;

- (void)applyPlateToCell:(TGTopicCell *)cell unread:(NSInteger)unread closed:(BOOL)closed;

- (void)applyBadgeToCell:(TGTopicCell *)cell unread:(NSInteger)unread mentions:(NSInteger)mentions reactions:(NSInteger)reactions;

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

- (int32_t)topicIdOf:(NSDictionary *)topic;

- (void)showError:(NSString *)message;

- (BOOL)topicIsMuted:(NSDictionary *)topic;

- (NSInteger)pinnedCount;

- (void)topicHeld:(UILongPressGestureRecognizer *)hold;

- (void)appendMenuItemsForTopic:(NSDictionary *)t
					  intoItems:(NSMutableArray *)items
						   keys:(NSMutableArray *)keys;

- (void)runTopicAction:(NSString *)key;

- (void)openTopicInfoForTopic:(NSDictionary *)t topicId:(int32_t)topicId;

- (void)setTopic:(int32_t)topicId pinned:(BOOL)pin;

- (void)setTopic:(int32_t)topicId closed:(BOOL)close;

- (void)unmuteTopic:(int32_t)topicId;

- (void)markTopicRead:(int32_t)topicId;

- (void)copyLinkForTopic:(int32_t)topicId;

- (void)setGeneralTopicHidden:(BOOL)hide;

- (void)showMuteDurationsForTopic:(int32_t)topicId;

- (void)confirmDeleteTopic:(NSDictionary *)topic;

- (void)beginReordering;

- (void)finishReordering;

- (void)sendPinnedTopicOrder:(NSArray *)ids;

- (NSArray *)pinnedTopicIdsFromTopics:(NSArray *)topics;

- (NSArray *)reconcilePinnedOrder:(NSArray *)localOrderIds withLatestTopics:(NSArray *)latestTopics;

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath;

- (BOOL)canDeleteTopicAtRow:(NSInteger)row;

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath;

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
		   editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath;

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)style
	 forRowAtIndexPath:(NSIndexPath *)indexPath;

- (BOOL)tableView:(UITableView *)tableView
	shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath;

- (NSIndexPath *)tableView:(UITableView *)tableView
	targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)from
						 toProposedIndexPath:(NSIndexPath *)proposed;

- (void)tableView:(UITableView *)tableView
	moveRowAtIndexPath:(NSIndexPath *)from
		   toIndexPath:(NSIndexPath *)to;

- (void)newTopicPressed;

- (void)askTopicNameForEdit:(NSDictionary *)topic;

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;

- (NSArray *)availableIconChoices;

- (void)chooseIconForPendingName;

- (void)chooseIconForName:(NSString *)name editing:(BOOL)editing;

- (NSInteger)iconColourForName:(NSString *)name;

- (void)commitCreateWithName:(NSString *)name iconEmojiId:(int64_t)emojiId;

- (void)commitEditWithName:(NSString *)name changeIcon:(BOOL)changeIcon iconEmojiId:(int64_t)emojiId;

@end

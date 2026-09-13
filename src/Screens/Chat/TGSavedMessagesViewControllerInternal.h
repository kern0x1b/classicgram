#import "TGTableReloadCoalescer.h"
#import <UIKit/UIKit.h>
#import "TGSavedMessagesViewController.h"
#import "TGPlaceholderView.h"
#import "TGSavedMessagesText.h"

extern const CGFloat kSavedRowHeight;
extern const CGFloat kSavedAvatar;
extern const CGFloat kSavedAvatarLeft;
extern const CGFloat kSavedTextLeft;
extern const CGFloat kSavedMessageRowHeight;
extern const NSInteger kSavedTopicPage;
extern const NSInteger kSavedMessagePage;

extern const NSInteger kSavedDeleteAlertTag;
extern const NSInteger kSavedRangeAlertTag;
extern const NSInteger kSavedReminderSheetTag;
extern const NSInteger kSavedModeSheetTag;
extern const NSInteger kSavedReminderMenuSheetTag;
extern const CGFloat kSavedBannerHeight;

extern const CGFloat kSavedScopeHeight;
extern const CGFloat kSavedScopeButtonHeight;
extern const CGFloat kSavedSearchBarHeight;

extern const NSInteger kSavedScopeChats;

NSArray *TGSavedScopeTitles(void);
NSString *TGSavedDate(NSTimeInterval unix);
NSString *TGSavedTopicTitle(NSDictionary *topic);

@interface TGSavedMessagesViewController () <UIAlertViewDelegate, UIActionSheetDelegate,
	UISearchBarDelegate>
@property (nonatomic, strong) TGTableReloadCoalescer *avatarReload;
@property (nonatomic, strong) NSArray *topics;
@property (nonatomic, strong) NSArray *topicHits;
@property (nonatomic, strong) NSArray *messageHits;
@property (nonatomic, assign) NSInteger scope;
@property (nonatomic, strong) UIView *scopeBar;
@property (nonatomic, strong) NSMutableArray *scopeButtons;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, assign) BOOL searchBarRevealed;
@property (nonatomic, assign) CGFloat scrollAnchor;
@property (nonatomic, copy) NSString *query;
@property (nonatomic, assign) NSUInteger searchToken;
@property (nonatomic, assign) BOOL messagesLoading;
@property (nonatomic, assign) BOOL messagesLoadedOnce;
@property (nonatomic, assign) BOOL messagesCanLoadMore;
@property (nonatomic, assign) int64_t messagesNextId;
@property (nonatomic, strong) NSArray *reminders;
@property (nonatomic, strong) UIButton *reminderBanner;
@property (nonatomic, assign) int64_t rangeTopicId;
@property (nonatomic, strong) UIView *rangeDayPanel;
@property (nonatomic, strong) UIDatePicker *rangeDayPicker;
@property (nonatomic, copy) NSString *rangeTopicTitle;
@property (nonatomic, assign) NSInteger rangeMinDate;
@property (nonatomic, assign) NSInteger rangeMaxDate;
@property (nonatomic, strong) NSMutableDictionary *avatars;
@property (nonatomic, strong) NSMutableSet *avatarsRequested;
@property (nonatomic, strong) NSMutableSet *avatarChatIdsRequested;
@property (nonatomic, strong) NSMutableDictionary *chatFileIds;
@property (nonatomic, strong) TGPlaceholderView *emptyContainer;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL loadedOnce;
@property (nonatomic, assign) BOOL reordering;
@property (nonatomic, assign) BOOL orderDirty;
@property (nonatomic, strong) NSDictionary *actionTopic;
@property (nonatomic, strong) NSDictionary *actionReminder;
@property (nonatomic, assign) CGPoint menuPoint;
@property (nonatomic, strong) id themeChangedObserverToken;

- (void)updateSeparatorStyle;
- (void)buildTableBackground;
- (void)themeChanged;
@end

@interface TGSavedMessagesViewController (Filtering)

- (void)openSharedMediaForScope:(NSInteger)savedScope;

- (void)buildScopeBar;
- (void)layoutScopeBar;
- (void)scopeTapped:(UIButton *)button;
- (void)reloadForScope;
- (void)buildSearchBar;
- (void)styleSearchBar;
- (void)updateTableHeader;
- (BOOL)searchBarActive;
- (void)revealSearchBarIfPulled:(UIScrollView *)scrollView;
- (void)hideSearchBarIfScrolledPast:(UIScrollView *)scrollView;
- (CGFloat)restingSearchBarOffset;
- (void)snapSearchBar:(UIScrollView *)scrollView;
- (void)hideSearchBarOnFirstLayout;
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView;
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;
- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar;
- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar;
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar;
- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar;
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text;
- (NSArray *)topicsMatchingQuery:(NSString *)query;

@end

@interface TGSavedMessagesViewController (DataLoading)

- (void)reloadMessages;
- (void)loadMoreMessages;
- (void)buildReminderBanner;
- (void)reloadReminders;
- (void)updateReminderBanner;
- (NSString *)titleForReminder:(NSDictionary *)reminder;
- (void)showReminders;
- (void)reloadTopics;
- (void)applyCachedTopics;
- (void)applyTopics:(NSArray *)topics;
- (void)downloadTopicAvatarFileId:(NSNumber *)fileId;
- (void)fetchMissingAvatars;
- (UIImage *)avatarForTopic:(NSDictionary *)topic;
- (void)buildEmptyContainerInside:(UIView *)background;
- (void)updateEmptyContainer;
- (void)restyleEmptyContainerSearching:(BOOL)searching;
- (void)layoutEmptyContainer;

@end

@interface TGSavedMessagesViewController (TopicActions)

- (void)presentReminderMenu:(NSDictionary *)reminder;
- (BOOL)reminderSupportsTextEdit:(NSDictionary *)reminder;
- (void)deleteReminder:(NSDictionary *)reminder;
- (void)openRemindersChatForEditingMessageId:(int64_t)messageId;
- (void)openRemindersChatForReschedulingMessageId:(int64_t)messageId sendDate:(NSTimeInterval)sendDate;
- (void)showError:(NSString *)message;
- (void)topicHeld:(UILongPressGestureRecognizer *)hold;
- (void)runTopicAction:(NSString *)key;
- (void)showRangeSheet;
- (void)dismissRangeDayPicker;
- (void)commitRangeDayPicker;
- (void)clearConfirmedRange;
- (void)presentSheet:(UIActionSheet *)sheet fromBarButtonItem:(UIBarButtonItem *)item;
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index;
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)showListButtons;
- (void)showModeMenu;
- (void)presentSavedChat:(UIViewController *)controller;
- (void)openPlainChat;

@end

@interface TGSavedMessagesViewController (Cells)

- (UITableViewCell *)messageCellForRow:(NSInteger)row inTable:(UITableView *)tableView;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;

@end

@interface TGSavedMessagesViewController (TableView)

- (BOOL)showsTopicSection;
- (BOOL)showsMessageSection;
- (NSArray *)topicRows;
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
- (BOOL)sectionHoldsTopics:(NSInteger)section;
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section;
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)openTopic:(NSDictionary *)topic;
- (void)openMessageAtRow:(NSInteger)row;

@end

@interface TGSavedMessagesViewController (Reordering)

- (NSInteger)pinnedCount;
- (void)beginReordering;
- (void)finishReordering;
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath;
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
		   editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)tableView:(UITableView *)tableView
	shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *)tableView:(UITableView *)tableView
	targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)from
						 toProposedIndexPath:(NSIndexPath *)proposed;
- (void)tableView:(UITableView *)tableView
	moveRowAtIndexPath:(NSIndexPath *)from
		   toIndexPath:(NSIndexPath *)to;

@end

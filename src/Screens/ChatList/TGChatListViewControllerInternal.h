#import <UIKit/UIKit.h>
#import "TGChatListViewController.h"
#import "TGChatCell.h"
#import "TGChatListId.h"
#import "TGPlaceholderView.h"

extern const NSTimeInterval kChatListDeferredActionDelay;

NSString *TGAvatarKeyForChat(NSDictionary *chat);
UIColor *TGSecretChatColour(void);
NSString *TGChatDateParts(NSTimeInterval unix, NSString **suffix, BOOL *bold);

@interface TGChatListViewController () <UISearchBarDelegate, UIAlertViewDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) NSArray *chats;
@property (nonatomic, assign) BOOL showsArchive;
@property (nonatomic, assign) NSInteger folderId;
@property (nonatomic, strong) NSMutableDictionary *avatars;
@property (nonatomic, strong) NSMutableSet *avatarsRequested;
@property (nonatomic, strong) NSMutableSet *avatarsInFlight;
@property (nonatomic, strong) NSMutableSet *avatarsFailedOnce;
@property (nonatomic, assign) NSTimeInterval lastAvatarSweep;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray *searchResults;
@property (nonatomic, strong) NSDictionary *actionChat;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *chatsPendingDeletion;
@property (nonatomic, strong) NSDictionary *chatPendingDeleteChoice;
@property (nonatomic, assign) CGFloat headerHeight;
@property (nonatomic, copy) NSString *headerSignature;
@property (nonatomic, assign) CGFloat scrollAnchor;
@property (nonatomic, assign) BOOL searchBarRevealed;
@property (nonatomic, assign) BOOL archiveAvailable;
@property (nonatomic, assign) BOOL archiveRevealed;
@property (nonatomic, assign) CGFloat archiveRowTop;
@property (nonatomic, weak) TGChatCell *archiveRowView;
@property (nonatomic, assign) BOOL initialScrollApplied;
@property (nonatomic, strong) NSMutableDictionary *avatarMinis;
@property (nonatomic, assign) BOOL warmedFirstFrameAvatars;
@property (nonatomic, strong) TGPlaceholderView *emptyContainer;
@property (nonatomic, strong) UIView *overscrollFiller;
@property (nonatomic, strong) id themeObserver;
@property (nonatomic, strong) id storyObserver;
@property (nonatomic, strong) id birthdayObserver;
@property (nonatomic, strong) id chatsChangedObserver;
@property (nonatomic, strong) id unreadBadgesObserver;
@property (nonatomic, strong) id unreadReactionsObserver;
@property (nonatomic, strong) id archiveChangedObserver;
@property (nonatomic, strong) id connectionStateObserver;
@property (nonatomic, strong) id accountSwitchObserver;
@property (nonatomic, strong) NSArray *sheetItems;
@property (nonatomic, strong) NSDictionary *archiveSettings;
@property (nonatomic, assign) CGPoint menuPoint;
@property (nonatomic, strong) NSMutableDictionary *listUnread;
@property (nonatomic, strong) NSMutableSet *listUnreadIsNative;
@property (nonatomic, assign) NSInteger folderLimit;
@property (nonatomic, assign) BOOL loadingMore;
@property (nonatomic, strong) NSArray *storyPosters;
@property (nonatomic, strong) NSMutableDictionary *storyPostersById;
@property (nonatomic, assign) NSInteger storyProbesPending;
@property (nonatomic, assign) NSTimeInterval lastStorySweep;
@property (nonatomic, strong) UILabel *titleLabelView;
@property (nonatomic, strong) UIView *titleStatusContainer;
@property (nonatomic, strong) UILabel *titleStatusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *titleStatusIndicator;
@property (nonatomic, copy) NSString *connectionText;
@property (nonatomic, weak) TGChatCell *openSwipeCell;
@property (nonatomic, strong) NSMutableDictionary *secretStatuses;
@property (nonatomic, strong) NSMutableSet *secretStatusesRequested;
@property (nonatomic, strong) NSMutableDictionary *muteRemaining;
@property (nonatomic, strong) NSDictionary *unconfirmedSession;
@property (nonatomic, strong) NSArray *folderSheetItems;
@property (nonatomic, strong) NSArray *rowActionKinds;
@property (nonatomic, assign) int64_t chatPendingCustomMute;
@property (nonatomic, strong) UIView *mutePickerPanel;
@property (nonatomic, strong) UIDatePicker *mutePicker;
@property (nonatomic, strong) NSArray *folderNewChats;
@property (nonatomic, assign) NSInteger folderNewChatsFolderId;
@property (nonatomic, strong) NSMutableDictionary *rowDetails;
@property (nonatomic, strong) NSMutableSet *rowDetailsRequested;
@property (nonatomic, strong) NSArray *listsToAddIds;
@property (nonatomic, assign) BOOL actionChatUnread;
@property (nonatomic, strong) id folderObserver;
@property (nonatomic, strong) id folderLayoutObserver;
@property (nonatomic, strong) id unreadMessageCountObserver;
@property (nonatomic, strong) id unreadChatCountObserver;
@property (nonatomic, strong) id unconfirmedSessionObserver;
@property (nonatomic, strong) id secretChatStateObserver;
@property (nonatomic, strong) NSMutableSet *foldersPumped;
@property (nonatomic, assign) BOOL multiSelecting;
@property (nonatomic, strong) NSMutableSet *selectedChatIds;
@property (nonatomic, strong) UIView *batchPanel;
@property (nonatomic, strong) UIBarButtonItem *rightItemBeforeMultiSelect;
@property (nonatomic, strong) UIBarButtonItem *leftItemBeforeMultiSelect;
@property (nonatomic, assign) BOOL interactiveMoveInProgress;
@property (nonatomic, assign) BOOL reloadPendingAfterInteractiveMove;
@end

@interface TGChatListViewController (Internal)

- (void)installUnreadMessageCountObserver;
- (void)installSecretChatStateObserver;

- (void)reload;
- (NSArray *)headerRows;
- (NSArray *)visibleChats;
- (void)setChat:(int64_t)chatId read:(BOOL)read;
- (void)setChat:(int64_t)chatId muteForSeconds:(NSInteger)seconds;
- (void)setChat:(int64_t)chatId archived:(BOOL)archived;

@end

@interface TGChatListViewController (MultiSelect)

- (void)beginMultiSelectWithChat:(int64_t)chatId;
- (void)endMultiSelect;
- (void)toggleMultiSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)updateMultiSelectChrome;
- (void)buildBatchPanel;

@end

@interface TGChatListViewController (FolderInviteLinks)

- (void)askFolderInviteLink;
- (void)checkFolderInviteLink:(NSString *)link;
- (UIView *)folderStripWithWidth:(CGFloat)width top:(CGFloat)top;
- (NSArray *)folderStripEntries;
- (NSString *)folderStripCaptions;
- (UIButton *)folderStripButtonForEntry:(NSDictionary *)entry
								   font:(UIFont *)font
								   left:(CGFloat)left
							normalPlate:(UIImage *)normalPlate
						  selectedPlate:(UIImage *)selectedPlate;
- (void)styleFolderStripLabel:(UILabel *)label selected:(BOOL)selected;
- (void)folderButtonHeld:(UILongPressGestureRecognizer *)hold;
- (void)folderButtonTapped:(UIButton *)button;
- (UIView *)storyTrayWithWidth:(CGFloat)width top:(CGFloat)top;
- (UIView *)storyTrayCellForPoster:(NSDictionary *)poster index:(NSUInteger)index left:(CGFloat)x;
- (void)storyCellTapped:(UITapGestureRecognizer *)tap;
- (void)refreshStoryPosters;
- (void)commitStoryPosters;
- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar;
- (void)styleSearchBar;
- (BOOL)splitLayoutActive;
- (void)presentChatController:(UIViewController *)controller;
- (void)openSavedMessages;
- (void)composeTapped;
- (void)startNewMessage;
- (void)reload;
- (void)pumpFolderIfEmpty:(NSInteger)folderId;
- (void)refreshUnreadCounters;
- (void)handleUnreadMessageCountUpdate:(NSDictionary *)info;
- (void)handleUnreadChatCountUpdate:(NSDictionary *)info;
- (NSString *)unreadSuffixForList:(TGChatListId)list;
- (void)loadMoreIfNeeded;
- (NSArray *)headerRows;
- (void)openArchive;
- (TGChatListId)currentListId;
- (void)presentSheet:(UIActionSheet *)sheet;
- (void)presentSheetForItemsWithTitle:(NSString *)title cancelTitle:(NSString *)cancelTitle;
- (void)foldersTapped;
- (void)listOptionsTapped;
- (void)actionsTapped;
- (void)addStory;
- (void)openFolderManagement;
- (void)markCurrentListAsRead;
- (void)archiveOptionsTapped;
- (void)showArchiveSettings;
- (void)actionSheet:(UIActionSheet *)sheet didDismissWithButtonIndex:(NSInteger)index;
- (void)showFolderFromSheetItem:(NSDictionary *)item;
- (void)toggleArchiveSettingWithKey:(NSString *)key;
- (void)dropAvatarForKey:(NSString *)avatarKey;
- (void)evictAvatarsOutsideRows:(NSInteger)margin;
- (void)didReceiveMemoryWarning;
- (NSSet *)avatarKeysWithinRows:(NSInteger)margin;
- (NSSet *)minithumbnailKeysWithinRows:(NSInteger)margin;
- (NSSet *)avatarKeysWanted;
- (BOOL)storyPostersUseAvatarKey:(NSString *)avatarKey;
- (NSDictionary *)chatShownByCell:(TGChatCell *)cell;
- (TGChatCell *)cellShowingChatId:(long long)chatId;
- (void)applyArrivedAvatar:(UIImage *)image forKey:(NSString *)avatarKey;
- (void)reportFirstRows;
- (UIImage *)blurredAvatarPlaceholderForChat:(NSDictionary *)chat;
- (void)warmAvatarPlaceholders;
- (NSNumber *)avatarFileIdForKey:(NSString *)avatarKey;
- (void)startAvatarLoadForKey:(NSString *)avatarKey;
- (void)loadCachedAvatarsForFirstFrame;
- (void)downloadAvatarForKey:(NSString *)avatarKey;
- (void)avatarFailed:(NSString *)avatarKey;
- (void)fetchMissingAvatars;
- (void)fetchMissingAvatarsThrottled;
- (void)describeCell:(TGChatCell *)cell unread:(NSInteger)unread muted:(BOOL)muted;
- (NSString *)secretHandshakeTextForChat:(NSDictionary *)chat;
- (void)secretChatStateNotificationReceived:(NSNotification *)note;

@end

@interface TGChatListViewController (Table)

- (void)rowHeld:(UILongPressGestureRecognizer *)hold;
- (void)showActionsForRow:(NSInteger)row;
- (void)presentActionsForRow:(NSInteger)row chat:(int64_t)expected markedUnread:(BOOL)markedUnread;
- (NSArray *)rowActionItemsForChat:(int64_t)chatId
							pinned:(BOOL)pinned
							 muted:(BOOL)muted
							unread:(BOOL)unread
						hasFolders:(BOOL)hasFolders
							 group:(BOOL)isGroup;
- (NSArray *)rowActionKindsWithFolders:(BOOL)hasFolders;
- (void)runChatAction:(NSInteger)choice;
- (void)showFoldersForChat:(int64_t)chatId;
- (void)showAllFoldersForChat:(int64_t)chatId;
- (void)toggleChat:(int64_t)chatId inFolder:(NSInteger)folderId;
- (void)setChat:(int64_t)chatId read:(BOOL)read;
- (BOOL)chatIsUnread:(NSDictionary *)chat;
- (void)showNotificationsAlertWithMessage:(NSString *)message;
- (NSArray *)notificationMenuKindsForChatMuted:(BOOL)muted usesDefault:(BOOL)usesDefault;
- (NSArray *)notificationMenuItemsForChat:(int64_t)chatId
									muted:(BOOL)muted
								  preview:(BOOL)preview
							  usesDefault:(BOOL)usesDefault;
- (void)togglePreviewForChat:(int64_t)chatId currentlyOn:(BOOL)preview;
- (void)applyNotificationMenuKind:(NSString *)kind
						  forChat:(int64_t)chatId
						previewOn:(BOOL)preview;
- (void)showNotificationOptionsForChat:(int64_t)chatId;
- (void)showMuteDurationsForChat:(int64_t)chatId;
- (void)askCustomMuteForChat:(int64_t)chatId;
- (void)dismissMutePicker;
- (void)commitMutePicker;
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex;
- (void)refreshMuteRemainingForChat:(int64_t)chatId;
- (NSString *)unmuteTitleForChat:(int64_t)chatId;
- (void)setChat:(int64_t)chatId archived:(BOOL)archived;
- (NSInteger)pinnedChatCount;
- (void)showChatPinLimitReachedAlert:(NSInteger)max;
- (void)pinChat:(int64_t)chatId pinned:(BOOL)pinned;
- (void)confirmDeleteChat:(NSDictionary *)chat;
- (void)runChatDeleteChoiceAtIndex:(NSInteger)index;
- (void)beginDeletingChat:(int64_t)chatId revoke:(BOOL)revoke;

@end

@interface TGChatListViewController (Search)

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar;
- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar;
- (NSArray *)visibleChats;
- (NSDictionary *)chatForRow:(NSInteger)row;
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (void)resetCell:(TGChatCell *)cell plain:(BOOL)plainPlate;
- (void)configureHeaderCell:(TGChatCell *)cell kind:(NSString *)kind;
- (void)configurePreviewInCell:(TGChatCell *)cell chat:(NSDictionary *)c plain:(BOOL)plainPlate;
- (void)configureBadgeInCell:(TGChatCell *)cell chat:(NSDictionary *)c unread:(NSInteger)unread;
- (void)configureAvatarInCell:(TGChatCell *)cell chat:(NSDictionary *)c;
- (void)configureStatusIconsInCell:(TGChatCell *)cell chat:(NSDictionary *)c;
- (void)attachSwipeHandlersToCell:(TGChatCell *)cell chat:(NSDictionary *)c;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)fetchRowDetailForChat:(NSDictionary *)chat;
- (void)pruneRowDetails;
- (NSArray *)swipeActionsForChat:(NSDictionary *)chat;
- (void)closeOpenSwipeCellAnimated:(BOOL)animated;
- (void)runSwipeAction:(NSString *)kind forCell:(TGChatCell *)cell;
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell
	   forRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSInteger)pinnedRowCount;
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *)tableView:(UITableView *)tableView
	targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath
						 toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath;
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
		   toIndexPath:(NSIndexPath *)destinationIndexPath;
- (void)reloadRowsFrom:(NSInteger)first to:(NSInteger)last;
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
		   editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style
	 forRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)prefetchOpenHistoryForChat:(int64_t)chatId;

@end

@interface TGChatListViewController (Controller)

- (void)buildRowCaches;
- (void)buildSearchBar;
- (void)styleListTable;
- (void)viewDidLoad;
- (void)installComposeButton;
- (void)installThemeObserver;
- (void)installFolderObserver;
- (void)folderLayoutChanged;
- (void)foldersChanged;
- (BOOL)folderExists:(NSInteger)folderId;
- (void)installStoryObserver;
- (void)handleStoryUpdate:(id)update;
- (NSString *)storyTitleForChat:(int64_t)chatId;
- (NSNumber *)storyPhotoFileIdForChat:(int64_t)chatId;
- (void)mergeStoryPosterForChat:(int64_t)chatId attempt:(NSInteger)attempt;
- (void)updateEditingChrome;
- (BOOL)isPushedList;
- (NSString *)backTitle;
- (void)backTapped;
- (void)editTapped;
- (void)editHeld:(UILongPressGestureRecognizer *)hold;
- (void)endInteractiveMoveIfNeeded;
- (void)installClientHandlers;
- (NSString *)defaultTitle;
- (NSArray *)folderList;
- (BOOL)hasFolders;
- (BOOL)usesFolderStrip;
- (BOOL)usesFolderChooser;
- (UIView *)titleStatusView;
- (void)applyTitleView;
- (void)viewWillAppear:(BOOL)animated;
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView;
- (BOOL)searchBarActive;
- (void)revealSearchBarIfPulled:(UIScrollView *)scrollView;
- (void)hideSearchBarIfScrolledPast:(UIScrollView *)scrollView;
- (CGFloat)restingSearchBarOffset;
- (void)snapSearchBar:(UIScrollView *)scrollView;
- (void)resetSearchBarRevealOnAppear;
- (void)viewWillDisappear:(BOOL)animated;
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView;
- (BOOL)archiveBannerAllowed;
- (void)revealArchiveIfPulled:(UIScrollView *)scrollView;
- (void)collapseArchiveIfScrolledPast;
- (void)toggleArchiveHiddenByDefaultFromCell:(TGChatCell *)cell;
- (void)viewDidLayoutSubviews;
- (void)applyBottomBarInset;
- (void)buildOverscrollFiller;
- (void)buildEmptyContainer;
- (void)updateEmptyState;
- (NSDictionary *)emptyStateWording;
- (void)emptyActionButtonTapped;
- (void)openFolder:(NSInteger)identifier;
- (void)layoutEmptyContent;
- (void)dealloc;
- (void)applySeparatorStyle;
- (void)rebuildTableHeader;
- (void)pinHeaderIfSearchBarClipped;
- (void)applyInitialScrollOffset;
- (TGChatCell *)archiveHeaderRowWithWidth:(CGFloat)width top:(CGFloat)top count:(NSUInteger)archivedCount;
- (void)archiveRowTapped;
- (UIView *)loginBannerWithWidth:(CGFloat)width top:(CGFloat)top;
- (UIButton *)bannerButtonWithTitle:(NSString *)title
							  frame:(CGRect)frame
							 action:(SEL)action
						destructive:(BOOL)destructive;
- (void)refreshUnconfirmedSession;
- (void)fetchUnconfirmedSession;
- (void)installUnconfirmedSessionObserver;
- (void)confirmNewLogin;
- (void)terminateNewLogin;
- (void)refreshFolderNewChats;
- (UIView *)folderInviteBannerWithWidth:(CGFloat)width top:(CGFloat)top;
- (void)addNewFolderChats;
- (void)dismissNewFolderChats;
- (void)installBirthdayObserver;
- (void)handleCloseBirthdaysUpdate;
- (NSArray *)todaysBirthdayUsers;
- (UIView *)birthdayBannerWithWidth:(CGFloat)width top:(CGFloat)top;
- (void)dismissBirthdayBanner;
- (void)openBirthdayChat;

@end

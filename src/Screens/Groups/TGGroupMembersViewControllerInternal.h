#import <UIKit/UIKit.h>
#import "TGGroupMembersViewController.h"
#import "TGGroupMembersPresenter.h"
#import "TGGroupMembersRowBridge.h"
#import "TGAvatarPrefetcher.h"
#import "TGMembersStatusText.h"

extern const CGFloat kGroupMemberRowHeight;
extern const CGFloat kMemberAvatarLeft;
extern const CGFloat kMemberAvatarTop;
extern const CGFloat kMemberTextLeft;
extern const CGFloat kSectionHeaderHeight;
extern const CGFloat kModeBarHeight;
extern const CGFloat kGroupButtonHeight;
extern const CGFloat kGroupSeparatorWidth;
extern const CGFloat kGroupSideInset;
extern const NSInteger kMemberPageSize;
extern const NSInteger kMemberPhotoPrefetchRows;
extern const NSInteger kMemberPhotoRetainRows;
extern const NSInteger kMemberDurationDay;
extern const NSInteger kMemberDurationWeek;
extern const NSInteger kMemberDurationMonth;

NSString *TGMembersDurationText(NSInteger untilDate);
UIImage *TGMembersStretch(NSString *name, int leftCap);

@interface TGGroupMembersViewController () <UISearchBarDelegate, UIActionSheetDelegate, UIAlertViewDelegate, TGGroupMembersRowBridgeDelegate> {
	UIView *_modeBar;
	NSMutableArray *_groupButtons;
	NSMutableArray *_groupSeparators;
	int64_t _pendingUserId;
	NSArray *_manageActions;
	TGGroupMembersPresenter *_presenter;
	TGGroupMembersRowBridge *_rowBridge;
	NSArray *_presenterRowsSnapshot;
}

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray *members;
@property (nonatomic, strong) NSArray *searchResults;
@property (nonatomic, strong) NSString *query;
@property (nonatomic, strong) TGAvatarPrefetcher *avatarPrefetcher;
@property (nonatomic, strong) NSDictionary *groupInfo;
@property (nonatomic, strong) NSDictionary *myRights;
@property (nonatomic, strong) NSString *myStatus;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *emptyPlaceholder;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptyHelpLabel;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) NSInteger mode;
@property (nonatomic, assign) NSInteger totalCount;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL failed;
@property (nonatomic, assign) BOOL loadingMore;
@property (nonatomic, assign) NSInteger generation;
@property (nonatomic, strong) id chatMemberObserverToken;
@property (nonatomic, strong) id userStatusObserverToken;

@end

@interface TGGroupMembersViewController (Modes)
- (NSArray *)modeTitles;
- (NSString *)listFilterForMode:(NSInteger)mode;
- (NSString *)searchFilterForMode:(NSInteger)mode;
- (NSString *)emptyTextForMode:(NSInteger)mode;
- (NSString *)emptyHelpForMode:(NSInteger)mode;
- (NSString *)sectionCaptionForMode:(NSInteger)mode;
- (BOOL)hasSearchQuery;
@end

@interface TGGroupMembersViewController (Loading)
- (void)setUpAvatarPrefetcher;
- (void)loadGroupInfo;
- (void)observeChatMemberUpdates;
- (BOOL)isSupergroup;
- (NSInteger)pendingJoinRequestCount;
- (NSArray *)availableManageActions;
- (NSString *)titleForManageAction:(NSString *)action;
- (void)updateManageButton;
- (void)showManageMenu;
- (void)performManageAction:(NSString *)action;
- (void)upgradeToSupergroupThen:(void (^)(void))then;
- (BOOL)iMay:(NSString *)right;
- (void)updateTitle;
- (void)reload;
- (void)loadMore;
- (void)restoreListAfterSearch;
- (void)runSearch;
- (void)layoutEmptyPlaceholderWithTitle:(NSString *)title help:(NSString *)help;
- (void)updateStatusView;
- (NSArray *)rows;
- (NSDictionary *)memberAtIndexPath:(NSIndexPath *)indexPath;
- (void)reloadTableSoon;
- (void)reloadTableNow;
- (NSString *)statusTextForMember:(NSDictionary *)member;
@end

@interface TGGroupMembersViewController (Table) <UITableViewDataSource, UITableViewDelegate>
- (NSDictionary *)menuItemForAction:(NSString *)action;
- (NSArray *)actionsForMember:(NSDictionary *)member;
- (BOOL)actionNeedsSupergroup:(NSString *)action;
- (void)openRightsEditorForUser:(int64_t)userId name:(NSString *)name restricting:(BOOL)restricting;
- (void)performAction:(NSString *)action onMember:(NSDictionary *)member;
- (void)confirm:(NSString *)message ok:(NSString *)ok destructive:(BOOL)destructive run:(void (^)(void))run;
- (void)confirmWithTitle:(NSString *)title message:(NSString *)message ok:(NSString *)ok destructive:(BOOL)destructive run:(void (^)(void))run;
- (void)presentTwoStepVerificationRequirement;
- (void)finishWithSuccess:(BOOL)ok failureText:(NSString *)failureText userId:(int64_t)userId;
- (NSInteger)rowIndexForUser:(int64_t)userId;
- (BOOL)status:(NSString *)status belongsToMode:(NSInteger)mode;
- (void)replaceRowAtIndex:(NSInteger)index withMember:(NSDictionary *)member;
- (void)refreshRowForUser:(int64_t)userId;
- (void)runDismiss:(int64_t)userId;
- (void)runUnrestrict:(int64_t)userId;
- (void)beginTransferOwnershipToUser:(int64_t)userId name:(NSString *)name;
- (void)openBanScreenForUser:(int64_t)userId name:(NSString *)name;
- (void)runUnban:(int64_t)userId;
- (void)runRemove:(int64_t)userId;
- (void)handleLongPress:(UILongPressGestureRecognizer *)recogniser;
@end

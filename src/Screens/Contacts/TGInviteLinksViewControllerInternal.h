#import <UIKit/UIKit.h>
#import "TGInviteLinksViewController.h"
#import "TGActionSheet.h"

static const NSInteger kInviteSectionPrimary = 0;
static const NSInteger kInviteSectionRequests = 1;
static const NSInteger kInviteSectionLinks = 2;
static const NSInteger kInviteSectionRevoked = 3;

static const NSInteger kInviteSubscriptionPriceAlertTag = 7813;

extern const NSInteger kInviteRequestPageLimit;

@interface TGInviteLinksViewController () <UIAlertViewDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) UIActionSheet *createSheet;
@property (nonatomic, strong) NSString *primaryLink;
@property (nonatomic, strong) NSArray *links;
@property (nonatomic, strong) NSArray *revokedLinks;
@property (nonatomic, strong) NSArray *requests;
@property (nonatomic, assign) NSInteger requestTotal;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) TGActionSheet *currentActionSheet;
@property (nonatomic, strong) NSDictionary *pendingLink;
@property (nonatomic, strong) NSDictionary *pendingRequest;
@property (nonatomic, strong) NSDictionary *editingLink;
@property (nonatomic, strong) UIView *expiryPanel;
@property (nonatomic, strong) UIDatePicker *expiryPicker;
@property (nonatomic, strong) NSDictionary *nextRequestOffset;
@property (nonatomic, strong) id pendingJoinRequestsObserverToken;
@property (nonatomic, assign) BOOL canManage;
@property (nonatomic, assign) BOOL loadingMoreRequests;
@property (nonatomic, assign) NSInteger requestsGeneration;
@property (nonatomic, assign) NSInteger outstanding;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL failed;
@property (nonatomic, assign) BOOL busy;

- (instancetype)init;
- (instancetype)initWithStyle:(UITableViewStyle)style;
- (void)viewDidLoad;
- (void)viewWillAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)updateNewButton;
- (void)stepFinishedWithFailure:(BOOL)failure;
- (NSArray *)secondaryLinksFrom:(NSArray *)links;
@end

@interface TGInviteLinksViewController (Internal)

- (UITableViewCell *)actionCellForTable:(UITableView *)tableView
								   title:(NSString *)title
							 destructive:(BOOL)destructive;
@end

@interface TGInviteLinksViewController (Loading)

- (void)reload;
- (BOOL)canLoadMoreRequests;
- (void)loadMoreRequests;
- (void)rebuildSections;

@end

@interface TGInviteLinksViewController (TableData)

- (NSInteger)kindOfSection:(NSInteger)section;
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section;
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section;
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section;
- (NSDictionary *)linkAtIndexPath:(NSIndexPath *)indexPath;
- (NSDictionary *)requestAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)isActionRowAtIndexPath:(NSIndexPath *)indexPath;
- (UITableViewCell *)actionRowCellForTable:(UITableView *)tableView
									   kind:(NSInteger)kind
								  indexPath:(NSIndexPath *)indexPath;
- (void)configurePrimaryCell:(UITableViewCell *)cell;
- (void)configureRequestCell:(UITableViewCell *)cell
				  atIndexPath:(NSIndexPath *)indexPath;
- (void)configureLinkCell:(UITableViewCell *)cell
			   atIndexPath:(NSIndexPath *)indexPath
				   revoked:(BOOL)revoked;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSString *)initialsForName:(NSString *)name;
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
	 forRowAtIndexPath:(NSIndexPath *)indexPath;
- (UIView *)sheetHostView;
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

@end

@interface TGInviteLinksViewController (Formatting)

- (NSString *)shortLink:(NSString *)link;
- (NSString *)titleForLink:(NSDictionary *)link;
- (NSString *)dateText:(long long)stamp;
- (NSString *)subtitleForLink:(NSDictionary *)link revoked:(BOOL)revoked;
- (NSString *)subtitleForRequest:(NSDictionary *)request;
- (UIColor *)captionColour;
- (UILabel *)captionLabel;
- (NSString *)headerTitleForSection:(NSInteger)section;
- (NSString *)footerTitleForSection:(NSInteger)section;

@end

@interface TGInviteLinksViewController (LinkActions)

- (void)copyLink:(NSString *)link;
- (void)shareLink:(NSString *)link;
- (void)showSheetForPrimaryLink;
- (void)showSheetForLink:(NSDictionary *)link revoked:(BOOL)revoked;
- (void)failedWithMessage:(NSString *)message;
- (void)replacePrimaryLink;
- (void)revokeLink:(NSDictionary *)link;
- (void)deleteRevokedLink:(NSDictionary *)link;
- (void)confirmDeleteAllRevoked;
- (void)showSheetForRequest:(NSDictionary *)request;
- (void)processRequest:(NSDictionary *)request approve:(BOOL)approve;

@end

@interface TGInviteLinksViewController (Creation)

- (void)createLink;
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index;
- (void)askSubscriptionPrice;
- (void)createSubscriptionLinkWithStarCount:(int64_t)starCount;
- (void)createLinkExpiring:(NSInteger)expirationDate limit:(NSInteger)memberLimit
		  requiresApproval:(BOOL)requiresApproval;

@end

@interface TGInviteLinksViewController (Editing)

- (NSArray *)editSheetActionsForLink:(NSDictionary *)link;
- (void)applyEditAction:(NSString *)action toLink:(NSDictionary *)editing;
- (void)showEditSheetForLink:(NSDictionary *)link;
- (NSString *)nameOfLink:(NSDictionary *)link;
- (void)askUsesForLink:(NSDictionary *)link;
- (void)presentExpiryPickerForLink:(NSDictionary *)link;
- (void)dismissExpiryPicker;
- (void)commitExpiryPicker;
- (void)askNameForLink:(NSDictionary *)link;
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)applySubscriptionRenameToLink:(NSDictionary *)link name:(NSString *)name;
- (void)applyEditToLink:(NSDictionary *)link
				   name:(NSString *)name
		 expirationDate:(NSInteger)expirationDate
			memberLimit:(NSInteger)memberLimit
	   requiresApproval:(BOOL)requiresApproval;

@end

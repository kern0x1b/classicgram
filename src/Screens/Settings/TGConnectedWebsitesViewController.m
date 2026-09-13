#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGActionSheet.h"
#import "TGListLoadFailure.h"
#import "TGPrivacyViewController.h"
#import "TGPrivacyViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGClient+Privacy.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGSessionsViewController.h"
#import "TGPasscodeLock.h"
#import "TGSecurityStepViewController.h"
#import "TGConnectedWebsitesViewController.h"
#import "TGConnectedWebsitesPresenter.h"
#import "TGConnectedWebsitesRowBridge.h"
#import "TGConnectedWebsitesItemBuilder.h"
#import "TGConnectedWebsitesItem.h"

@interface TGConnectedWebsitesViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) NSMutableArray *websites;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL loadFailed;
@property (nonatomic, assign) NSUInteger loadGeneration;
@property (nonatomic, strong) TGConnectedWebsitesPresenter *rowPresenter;
@property (nonatomic, strong) TGConnectedWebsitesRowBridge *rowBridge;
@end

@implementation TGConnectedWebsitesViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"AuthSessions.LoggedInWithTelegram", @"Connected Websites");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.rowHeight = 56;
	self.websites = [NSMutableArray array];
	self.rowPresenter = [[TGConnectedWebsitesPresenter alloc] init];
	self.rowBridge = [[TGConnectedWebsitesRowBridge alloc] initWithPresenter:self.rowPresenter];
	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)reload {
	self.loadGeneration++;
	NSUInteger generation = self.loadGeneration;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] connectedWebsitesWithCompletion:^(NSArray *websites, BOOL failed) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || strongSelf.loadGeneration != generation)
			return;
		strongSelf.loaded = YES;
		strongSelf.loadFailed = failed;
		[strongSelf.websites removeAllObjects];
		if ([websites isKindOfClass:[NSArray class]])
			[strongSelf.websites addObjectsFromArray:websites];
		[strongSelf.rowPresenter updateWithSites:strongSelf.websites];
		[strongSelf.tableView reloadData];
	}];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.websites.count ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return (NSInteger)self.websites.count;
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0 && self.websites.count)
		return TGL(@"AuthSessions.LoggedInWithTelegram", @"Connected Websites");
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [[TGTheme shared] groupedHeaderHeightForTitle:
			[self tableView:tableView titleForHeaderInSection:section]];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == 0) {
		switch (TGListStatusOfList(self.loaded, self.loadFailed, self.websites.count)) {
			case TGListStatusLoading:
				return TGL(@"Channel.NotificationLoading", @"Loading…");
			case TGListStatusFailed:
				return TGL(@"AuthSessions.ConnectedWebsitesLoadFailed",
					@"The list of websites could not be loaded.");
			case TGListStatusEmpty:
				return TGL(@"AuthSessions.NoConnectedWebsites",
					@"No website is using your Telegram account to sign you in.");
			case TGListStatusRows:
				break;
		}
		return TGL(@"AuthSessions.SwipeToDisconnectWebsite", @"Swipe a website to log out of it.");
	}
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	CGFloat measured = [[TGTheme shared] groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	return [[TGTheme shared] groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0 && [self.rowBridge ownsRowAtIndex:indexPath.row])
		return [self.rowBridge cellForRow:indexPath.row inTable:tableView];

	if (indexPath.section == 1) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"all"];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:@"all"];
		[TGIcons actionButtonInCell:cell
							  title:TGL(@"AuthSessions.LogOutApplications", @"Disconnect All Websites")
							   kind:TGActionButtonKindDestructive
							 target:self
							 action:@selector(confirmDisconnectAll:)];
		return cell;
	}

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"site"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"site"];
	[[TGTheme shared] styleCell:cell];
	TGConnectedWebsitesItem *item = [TGConnectedWebsitesItemBuilder
			itemFromSite:self.websites[indexPath.row]];
	cell.textLabel.text = item.titleText;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.text = item.detailText;
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.detailTextLabel.numberOfLines = 2;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.section == 0;
}

- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGL(@"AuthSessions.LogOut", @"Disconnect");
}

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)style
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (style != UITableViewCellEditingStyleDelete || indexPath.section != 0)
		return;
	if ((NSUInteger)indexPath.row >= self.websites.count)
		return;
	id siteId = self.websites[indexPath.row][@"id"];
	if (![siteId isKindOfClass:[NSNumber class]])
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] disconnectWebsite:[siteId longLongValue] completion:^(BOOL ok) {
		if (!ok)
			TGPrivacyComplain(TGL(@"AuthSessions.WebsiteDisconnectFailed", @"That website could not be disconnected."));
		[weakSelf reload];
	}];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 1)
		return TGActionRowHeight();
	return 44;
}

- (void)confirmDisconnectAll:(UIButton *)sender {
	UIActionSheet *sheet = [[UIActionSheet alloc]
				 initWithTitle:nil
					  delegate:self
			 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonTitle:TGL(@"AuthSessions.LogOutApplications", @"Disconnect All Websites")
			 otherButtonTitles:nil];
	sheet.tag = 91;
	UIView *anchor = sender.superview ?: self.view;
	[sheet tg_showFromRect:sender.frame inView:anchor];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (sheet.tag != 91 || index != sheet.destructiveButtonIndex)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] disconnectAllWebsitesWithCompletion:^(BOOL ok) {
		if (!ok)
			TGPrivacyComplain(TGL(@"AuthSessions.AllWebsitesDisconnectFailed", @"The websites could not be disconnected."));
		[weakSelf reload];
	}];
}

@end

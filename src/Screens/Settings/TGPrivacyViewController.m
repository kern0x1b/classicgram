#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGClient+ChatState.h"
#import "TGSettingValueText.h"
#import "TGActionSheet.h"
#import "TGPrivacyViewController.h"
#import "TGPrivacyViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGClient+Privacy.h"
#import "TGClient+Account.h"
#import "TGClient+Network.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGSessionsViewController.h"
#import "TGPasscodeLock.h"
#import "TGSecurityStepViewController.h"
#import "TGHiddenStoriesViewController.h"
#import "TGCloseFriendsViewController.h"
#import "TGConnectedWebsitesViewController.h"
#import "TGActionSheetIndexBuilder.h"

void TGPrivacyComplain(NSString *message) {
	UIAlertView *alert = [[UIAlertView alloc]
			initWithTitle:nil
				  message:message
				 delegate:nil
		cancelButtonTitle:TGL(@"Common.OK", @"OK")
		otherButtonTitles:nil];
	[alert show];
}

#pragma mark - the hub

@interface TGPrivacyViewController () <UIActionSheetDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) NSMutableDictionary *ruleValues;
@property (nonatomic, assign) BOOL passwordOn;
@property (nonatomic, assign) BOOL passwordLoaded;
@property (nonatomic, assign) NSInteger autoDeleteSeconds;
@property (nonatomic, assign) BOOL autoDeleteLoaded;
@property (nonatomic, assign) BOOL autoDeleteFailed;
@property (nonatomic, assign) BOOL newChatsFromEverybody;
@property (nonatomic, assign) BOOL newChatsLoaded;
@property (nonatomic, assign) BOOL readDateShown;
@property (nonatomic, assign) BOOL readDateLoaded;
@property (nonatomic, assign) NSInteger accountTtlDays;
@property (nonatomic, assign) BOOL accountTtlLoaded;
@property (nonatomic, strong) NSString *loginEmailPattern;
@end

@implementation TGPrivacyViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self)
		_ruleValues = [NSMutableDictionary dictionary];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Settings.PrivacySettings", @"Privacy and Security");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.rowHeight = 44;
	TGApplyRTLTableMirroring(self.tableView);
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[self.tableView reloadData];
	[self reload];
}

- (void)tableView:(UITableView *)tableView
	  willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath {
	TGApplyRTLCellMirroring(cell);
}

- (void)reload {
	__weak typeof(self) weakSelf = self;
	for (NSString *setting in [TGClient privacySettingNames]) {
		[[TGClient shared] privacyRuleDetailed:setting completion:^(NSDictionary *info) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf || ![info isKindOfClass:[NSDictionary class]])
				return;
			id value = info[@"value"];
			if ([value isKindOfClass:[NSString class]])
				strongSelf.ruleValues[setting] = value;
			[strongSelf.tableView reloadData];
		}];
	}

	[[TGClient shared] passwordStateWithCompletion:^(NSDictionary *state) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSDictionary *info = [state isKindOfClass:[NSDictionary class]] ? state : nil;
		strongSelf.passwordLoaded = (info != nil);
		strongSelf.passwordOn = [info[@"hasPassword"] boolValue];
		id pattern = info[@"loginEmailPattern"];
		strongSelf.loginEmailPattern =
			([pattern isKindOfClass:[NSString class]] && [pattern length]) ? pattern : nil;
		[strongSelf.tableView reloadData];
	}];

	[[TGClient shared] defaultAutoDeleteSecondsWithCompletion:^(NSInteger seconds, BOOL failed) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.autoDeleteLoaded = !failed;
		strongSelf.autoDeleteFailed = failed;
		strongSelf.autoDeleteSeconds = failed ? strongSelf.autoDeleteSeconds : seconds;
		[strongSelf.tableView reloadData];
	}];

	[[TGClient shared] newChatPrivacySettingsWithCompletion:^(NSDictionary *info) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || ![info isKindOfClass:[NSDictionary class]])
			return;
		strongSelf.newChatsLoaded = YES;
		strongSelf.newChatsFromEverybody = [info[@"allowUnknownUsers"] boolValue];
		[strongSelf.tableView reloadData];
	}];

	[[TGClient shared] accountTtlWithCompletion:^(BOOL ok, NSInteger days) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || !ok)
			return;
		strongSelf.accountTtlLoaded = YES;
		strongSelf.accountTtlDays = days;
		[strongSelf.tableView reloadData];
	}];

	[[TGClient shared] readDatePrivacyShowWithCompletion:^(BOOL show, BOOL failed) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || failed)
			return;
		strongSelf.readDateLoaded = YES;
		strongSelf.readDateShown = show;
		[strongSelf.tableView reloadData];
	}];
}

- (NSArray *)autoDeleteOptions {
	return [NSArray arrayWithObjects:
			[NSNumber numberWithInteger:0],
		[NSNumber numberWithInteger:24 * 60 * 60],
		[NSNumber numberWithInteger:7 * 24 * 60 * 60],
		[NSNumber numberWithInteger:31 * 24 * 60 * 60], nil];
}

- (NSString *)autoDeleteTitleForSeconds:(NSInteger)seconds {
	if (seconds <= 0)
		return TGL(@"Autoremove.OptionOff", @"Off");
	if (seconds >= 31 * 24 * 60 * 60)
		return TGL(@"Privacy.AutoDelete.OneMonth", @"1 month");
	if (seconds >= 7 * 24 * 60 * 60)
		return TGL(@"Privacy.AutoDelete.OneWeek", @"1 week");
	if (seconds >= 24 * 60 * 60)
		return TGL(@"Privacy.AutoDelete.OneDay", @"1 day");
	NSInteger hours = seconds / 3600;
	return TGLPlural(@"Privacy.AutoDelete.HoursCount", hours, @"%d hour", @"%d hours");
}

- (void)showAutoDeletePicker {
	NSMutableArray *titles = [NSMutableArray array];
	for (NSNumber *option in [self autoDeleteOptions]) {
		NSString *title = [self autoDeleteTitleForSeconds:[option integerValue]];
		if ([option integerValue] == self.autoDeleteSeconds)
			title = [title stringByAppendingString:@" ✓"];
		[titles addObject:title];
	}
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"PeerInfo.AutoremoveMessages", @"Auto-Delete Messages")
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 91;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.navigationController.view.bounds), CGRectGetMidY(self.navigationController.view.bounds), 1, 1)
					 inView:self.navigationController.view];
}

- (void)showNewChatsPicker {
	BOOL everybody = self.newChatsLoaded && self.newChatsFromEverybody;
	BOOL contacts = self.newChatsLoaded && !self.newChatsFromEverybody;
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"Privacy.Messages.SectionTitle", @"Who can message me")
					  delegate:self
				   otherTitles:@[ everybody ? [TGL(@"PrivacySettings.LastSeenEverybody", @"Everybody") stringByAppendingString:@" ✓"] : TGL(@"PrivacySettings.LastSeenEverybody", @"Everybody"),
					   contacts ? [TGL(@"PrivacySettings.LastSeenContacts", @"My Contacts") stringByAppendingString:@" ✓"] : TGL(@"PrivacySettings.LastSeenContacts", @"My Contacts") ]
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 92;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.navigationController.view.bounds), CGRectGetMidY(self.navigationController.view.bounds), 1, 1)
					 inView:self.navigationController.view];
}

- (void)readReceiptsToggled:(UISwitch *)toggle {
	[self applyReadDateShown:toggle.on];
}

- (void)sensitiveContentToggled:(UISwitch *)toggle {
	[TGClient shared].ignoresSensitiveContentRestrictions = toggle.on;
	[[TGClient shared] setOptionNamed:@"ignore_sensitive_content_restrictions"
								 value:@(toggle.on)
							 isBoolean:YES];
}

- (void)applyReadDateShown:(BOOL)shown {
	if (shown == self.readDateShown && self.readDateLoaded)
		return;
	BOOL previous = self.readDateShown;
	BOOL previouslyLoaded = self.readDateLoaded;
	self.readDateShown = shown;
	self.readDateLoaded = YES;
	[self.tableView reloadData];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setReadDatePrivacyShow:shown completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (ok || !strongSelf)
			return;
		strongSelf.readDateShown = previous;
		strongSelf.readDateLoaded = previouslyLoaded;
		[strongSelf.tableView reloadData];
		TGPrivacyComplain(TGL(@"Privacy.TheSettingCouldNotBeChanged", @"That setting could not be changed."));
	}];
}

- (void)showAccountTtlPicker {
	NSMutableArray *titles = [NSMutableArray array];
	for (NSNumber *option in [self accountTtlOptions]) {
		NSString *title = [self accountTtlTitleForDays:[option integerValue]];
		if ([option integerValue] == self.accountTtlDays)
			title = [title stringByAppendingString:@" ✓"];
		[titles addObject:title];
	}
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"PrivacySettings.DeleteAccountIfAwayFor", @"Delete my account if away for")
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 93;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.navigationController.view.bounds), CGRectGetMidY(self.navigationController.view.bounds), 1, 1)
					 inView:self.navigationController.view];
}

- (NSArray *)accountTtlOptions {
	return [NSArray arrayWithObjects:
			[NSNumber numberWithInteger:30],
		[NSNumber numberWithInteger:90],
		[NSNumber numberWithInteger:180],
		[NSNumber numberWithInteger:365], nil];
}

- (NSString *)accountTtlTitleForDays:(NSInteger)days {
	if (days >= 365)
		return TGL(@"Privacy.AccountTtl.OneYear", @"1 year");
	if (days >= 180)
		return TGL(@"Privacy.AccountTtl.SixMonths", @"6 months");
	if (days >= 90)
		return TGL(@"Privacy.AccountTtl.ThreeMonths", @"3 months");
	return TGL(@"Privacy.AutoDelete.OneMonth", @"1 month");
}

- (void)confirmAccountDeletion {
	UIAlertView *alert = [[UIAlertView alloc]
			initWithTitle:TGL(@"DeleteAccount.ConfirmationAlertDelete", @"Delete Account")
				  message:TGL(@"DeleteAccount.ConfirmationAlertText", @"All your chats, messages and contacts on Telegram will be lost. This cannot be undone.")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Common.Delete", @"Delete"), nil];
	alert.tag = 500;
	[alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (alertView.tag != 500)
		return;
	if (buttonIndex == alertView.cancelButtonIndex)
		return;
	[self beginAccountDeletion];
}

- (void)beginAccountDeletion {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] passwordStateWithCompletion:^(NSDictionary *state) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (![state isKindOfClass:[NSDictionary class]]) {
			TGPrivacyComplain(TGL(@"DeleteAccount.CouldNotBeDeletedMessage", @"The account could not be deleted. Please try again later."));
			return;
		}
		if ([state[@"hasPassword"] boolValue]) {
			[strongSelf askAccountDeletionPassword];
			return;
		}
		[strongSelf deleteAccountWithPassword:@"" step:nil];
	}];
}

- (void)askAccountDeletionPassword {
	__weak typeof(self) weakSelf = self;
	TGSecurityStepViewController *step = [[TGSecurityStepViewController alloc] init];
	step.stepTitle = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	step.stepCaption = TGL(@"TwoStepAuth.EnterPasswordPassword", @"Your current password");
	step.placeholder = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	step.footerText = TGL(@"DeleteAccount.EnterPasswordFooter", @"Enter your password to permanently delete your account.");
	step.actionTitle = TGL(@"DeleteAccount.ConfirmationAlertDelete", @"Delete Account");
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if (!text.length) {
			[sender refuseWithMessage:TGL(@"TwoStepAuth.PleaseEnterYourPassword", @"Please enter your password.")];
			return;
		}
		[sender setBusy:YES];
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf deleteAccountWithPassword:text step:sender];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)deleteAccountWithPassword:(NSString *)password step:(TGSecurityStepViewController *)step {
	[[TGClient shared] deleteAccountWithReason:@"Deleted from Settings"
									   password:password
									 completion:^(BOOL ok) {
		if (ok)
			return;
		if (step)
			[step refuseWithMessage:TGL(@"TwoStepAuth.ThatPasswordIsWrong", @"That password is wrong.")];
		else
			TGPrivacyComplain(TGL(@"DeleteAccount.CouldNotBeDeletedMessage", @"The account could not be deleted. Please try again later."));
	}];
}

- (void)applyNewChatsFromEverybody:(BOOL)fromEverybody {
	if (fromEverybody == self.newChatsFromEverybody && self.newChatsLoaded)
		return;
	BOOL previous = self.newChatsFromEverybody;
	BOOL previouslyLoaded = self.newChatsLoaded;
	self.newChatsFromEverybody = fromEverybody;
	self.newChatsLoaded = YES;
	[self.tableView reloadData];

	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client setNewChatPrivacyAllowsUnknownUsers:fromEverybody completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (ok || !strongSelf)
			return;
		strongSelf.newChatsFromEverybody = previous;
		strongSelf.newChatsLoaded = previouslyLoaded;
		[strongSelf.tableView reloadData];
		TGPrivacyComplain(TGL(@"Privacy.TheSettingCouldNotBeChanged", @"That setting could not be changed."));
	}];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (index == sheet.cancelButtonIndex)
		return;
	if (sheet.tag == 92) {
		[self applyNewChatsFromEverybody:index == 0];
		return;
	}
	if (sheet.tag == 93) {
		NSArray *options = [self accountTtlOptions];
		if (index < 0 || index >= (NSInteger)options.count)
			return;
		NSInteger previousDays = self.accountTtlDays;
		BOOL previouslyLoaded = self.accountTtlLoaded;
		self.accountTtlDays = [[options objectAtIndex:index] integerValue];
		self.accountTtlLoaded = YES;
		[self.tableView reloadData];

		__weak typeof(self) weakSelf = self;
		[[TGClient shared] setAccountTtlDays:self.accountTtlDays completion:^(BOOL ok) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (ok || !strongSelf)
				return;
			strongSelf.accountTtlDays = previousDays;
			strongSelf.accountTtlLoaded = previouslyLoaded;
			[strongSelf.tableView reloadData];
			TGPrivacyComplain(TGL(@"Privacy.TheSettingCouldNotBeChanged", @"That setting could not be changed."));
		}];
		return;
	}
	if (sheet.tag != 91)
		return;
	NSArray *options = [self autoDeleteOptions];
	if (index < 0 || index >= (NSInteger)options.count)
		return;
	NSInteger previous = self.autoDeleteSeconds;
	NSInteger picked = [[options objectAtIndex:index] integerValue];
	self.autoDeleteSeconds = picked;
	[self.tableView reloadData];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setDefaultAutoDeleteSeconds:picked completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (ok || !strongSelf)
			return;
		strongSelf.autoDeleteSeconds = previous;
		[strongSelf.tableView reloadData];
		TGPrivacyComplain(TGL(@"Privacy.TheSettingCouldNotBeChanged", @"That setting could not be changed."));
	}];
}

- (NSArray *)settings {
	return [TGClient privacySettingNames] ?: [NSArray array];
}

- (NSString *)shortTitleForValue:(NSString *)value {
	if (!value.length)
		return @"...";
	if ([value isEqualToString:@"contacts"])
		return TGL(@"PrivacySettings.LastSeenContacts", @"My Contacts");
	if ([value isEqualToString:@"nobody"])
		return TGL(@"PrivacySettings.LastSeenNobody", @"Nobody");
	return TGL(@"PrivacySettings.LastSeenEverybody", @"Everybody");
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return 5;
	if (section == 1)
		return 1;
	if (section == 2)
		return (NSInteger)[self settings].count + 5;
	return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 2)
		return TGL(@"PrivacySettings.PrivacyTitle", @"PRIVACY");
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [[TGTheme shared] groupedHeaderHeightForTitle:
			[self tableView:tableView titleForHeaderInSection:section]];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	TGTheme *theme = [TGTheme shared];
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	UIView *header = [theme groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
	TGApplyRTLHeaderMirroring(header);
	return header;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == 0)
		return TGL(@"Privacy.SecuritySectionFooter",
			@"Two-step verification asks for a password of your own when you log in on a new device. The passcode only guards this device."
			 "in on a new device. The passcode only guards this phone.");
	if (section == 1)
		return TGL(@"PrivacySettings.LoginEmailSetupInfo", @"Set up an email address to receive Telegram login codes.");
	if (section == 2)
		return TGL(@"Privacy.WhoMaySeeAndReachYou", @"These settings decide who may see what about you, and who may reach you."
			 "reach you.");
	return TGL(@"PrivacySettings.DeleteAccountHelp", @"If you do not log in at least once within this period, your account will be deleted along with all groups, messages and contacts."
		 "account will be deleted along with all groups, messages and contacts.");
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	TGTheme *theme = [TGTheme shared];
	CGFloat measured = [theme groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	TGTheme *theme = [TGTheme shared];
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	UIView *footer = [theme groupedCommentViewWithText:caption width:tableView.bounds.size.width];
	TGApplyRTLHeaderMirroring(footer);
	return footer;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"row"];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	cell.accessoryView = nil;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;

	if (indexPath.section == 0) {
		[self configureSecurityCell:cell atRow:indexPath.row];
		return cell;
	}
	if (indexPath.section == 1) {
		cell.textLabel.text = TGL(@"PrivacySettings.LoginEmail", @"Login E-Mail");
		cell.detailTextLabel.text = !self.passwordLoaded
			? @"..."
			: (self.loginEmailPattern ?: TGL(@"PrivacySettings.PasscodeOff", @"Off"));
		return cell;
	}
	if (indexPath.section == 2) {
		[self configurePrivacyCell:cell atRow:indexPath.row];
		return cell;
	}
	[self configureDeleteAccountCell:cell atRow:indexPath.row];
	return cell;
}

- (void)configureDeleteAccountCell:(UITableViewCell *)cell atRow:(NSInteger)row {
	if (row == 1) {
		[TGIcons actionButtonInCell:cell
							  title:TGL(@"DeleteAccount.DeleteNowTitle", @"Delete My Account Now")
							   kind:TGActionButtonKindDestructive
							 target:self
							 action:@selector(confirmAccountDeletion)];
		return;
	}
	[TGIcons removeActionButtonFromCell:cell];
	cell.textLabel.text = TGL(@"PrivacySettings.DeleteAccountIfAwayFor", @"Delete my account if away for");
	cell.detailTextLabel.text = self.accountTtlLoaded
		? [self accountTtlTitleForDays:self.accountTtlDays]
		: @"...";
}

- (void)configurePrivacyCell:(UITableViewCell *)cell atRow:(NSInteger)row {
	NSArray *settings = [self settings];
	if ((NSUInteger)row < settings.count) {
		NSString *setting = settings[row];
		cell.textLabel.text = [TGClient titleForPrivacySetting:setting];
		cell.detailTextLabel.text = [self shortTitleForValue:self.ruleValues[setting]];
		return;
	}
	NSInteger extra = row - (NSInteger)settings.count;
	if (extra == 0) {
		cell.textLabel.text = TGL(@"Privacy.Messages.SectionTitle", @"Who can message me");
		cell.detailTextLabel.text = self.newChatsLoaded
			? (self.newChatsFromEverybody ? TGL(@"PrivacySettings.LastSeenEverybody", @"Everybody")
										  : TGL(@"PrivacySettings.LastSeenContacts", @"My Contacts"))
			: @"...";
		return;
	}
	if (extra == 1) {
		cell.textLabel.text = TGL(@"Settings.Privacy.ReadTime", @"Read Receipts");
		cell.detailTextLabel.text = @"";
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		UISwitch *toggle = [[UISwitch alloc] init];
		toggle.on = self.readDateLoaded && self.readDateShown;
		toggle.enabled = self.readDateLoaded;
		[toggle addTarget:self action:@selector(readReceiptsToggled:) forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
		return;
	}
	if (extra == 2) {
		cell.textLabel.text = TGL(@"Story.Privacy.CategoryCloseFriends", @"Close Friends");
		cell.detailTextLabel.text = @"";
		return;
	}
	if (extra == 3) {
		cell.textLabel.text = TGL(@"Story.Privacy.HideMyStoriesFrom", @"Hide My Stories From");
		cell.detailTextLabel.text = @"";
		return;
	}
	cell.textLabel.text = TGL(@"SensitiveContent.ShowInChats", @"Show Sensitive Content");
	cell.detailTextLabel.text = @"";
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	UISwitch *sensitiveToggle = [[UISwitch alloc] init];
	sensitiveToggle.on = [TGClient shared].ignoresSensitiveContentRestrictions;
	sensitiveToggle.enabled = [TGClient shared].canIgnoreSensitiveContentRestrictions;
	[sensitiveToggle addTarget:self action:@selector(sensitiveContentToggled:) forControlEvents:UIControlEventValueChanged];
	cell.accessoryView = sensitiveToggle;
}

- (void)configureSecurityCell:(UITableViewCell *)cell atRow:(NSInteger)row {
	if (row == 0) {
		cell.textLabel.text = TGL(@"Settings.BlockedUsers", @"Blocked Users");
		cell.detailTextLabel.text = @"";
		return;
	}
	if (row == 1) {
		cell.textLabel.text = TGL(@"AuthSessions.LoggedInWithTelegram", @"Connected Websites");
		cell.detailTextLabel.text = @"";
		return;
	}
	if (row == 2) {
		cell.textLabel.text = TGL(@"PrivacySettings.Passcode", @"Passcode Lock");
		cell.detailTextLabel.text = [[TGPasscodeLock shared] isSet]
			? TGL(@"PrivacySettings.PasscodeOn", @"On")
			: TGL(@"PrivacySettings.PasscodeOff", @"Off");
		return;
	}
	if (row == 3) {
		cell.textLabel.text = TGL(@"PrivacySettings.TwoStepAuth", @"Two-Step Verification");
		cell.detailTextLabel.text = self.passwordLoaded
			? (self.passwordOn ? TGL(@"PrivacySettings.PasscodeOn", @"On") : TGL(@"PrivacySettings.PasscodeOff", @"Off"))
			: @"...";
		return;
	}
	cell.textLabel.text = TGL(@"PeerInfo.AutoremoveMessages", @"Auto-Delete Messages");
	cell.detailTextLabel.text = TGSettingValueText(self.autoDeleteLoaded, self.autoDeleteFailed,
			[self autoDeleteTitleForSeconds:self.autoDeleteSeconds]);
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 3 && indexPath.row == 1)
		return TGActionRowHeight();
	return 44;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (indexPath.section == 2) {
		NSArray *settings = [self settings];
		if ((NSUInteger)indexPath.row < settings.count) {
			TGPrivacyRuleViewController *rule = [[TGPrivacyRuleViewController alloc]
				initWithSetting:settings[indexPath.row]];
			[self.navigationController pushViewController:rule animated:YES];
			return;
		}
		NSInteger extra = indexPath.row - (NSInteger)settings.count;
		if (extra == 0) {
			[self showNewChatsPicker];
			return;
		}
		if (extra == 1)
			return;
		if (extra == 2) {
			[self.navigationController pushViewController:
					[[TGCloseFriendsViewController alloc] init]
												 animated:YES];
			return;
		}
		if (extra == 3) {
			[self.navigationController pushViewController:
					[[TGHiddenStoriesViewController alloc] init]
												 animated:YES];
			return;
		}
		return;
	}

	if (indexPath.section == 3) {
		if (indexPath.row != 1)
			[self showAccountTtlPicker];
		return;
	}

	if (indexPath.section == 1) {
		[self startLoginEmail];
		return;
	}

	if (indexPath.row == 0) {
		[self.navigationController pushViewController:
				[[TGBlockedUsersViewController alloc] init]
											 animated:YES];
		return;
	}
	if (indexPath.row == 1) {
		[self.navigationController pushViewController:
				[[TGConnectedWebsitesViewController alloc] init]
											 animated:YES];
		return;
	}
	if (indexPath.row == 2) {
		[self.navigationController pushViewController:
				[[TGPasscodeViewController alloc] init]
											 animated:YES];
		return;
	}
	if (indexPath.row == 3) {
		[self.navigationController pushViewController:
				[[TGTwoStepViewController alloc] init]
											 animated:YES];
		return;
	}
	[self showAutoDeletePicker];
}

- (void)startLoginEmail {
	__weak typeof(self) weakSelf = self;
	TGSecurityStepViewController *step = [[TGSecurityStepViewController alloc] init];
	step.stepTitle = TGL(@"PrivacySettings.LoginEmail", @"Login E-Mail");
	step.stepCaption = TGL(@"PrivacySettings.LoginEmailCaption", @"Where log-in codes go");
	step.placeholder = TGL(@"TwoStepAuth.Email", @"E-Mail");
	step.secure = NO;
	step.email = YES;
	step.footerText = self.loginEmailPattern
		? [NSString stringWithFormat:
				  TGL(@"PrivacySettings.LoginEmailFooterPattern",
					  @"Log-in codes are going to %@ at the moment. Enter a new address to move them."
					   "move them."),
			  self.loginEmailPattern]
		: TGL(@"PrivacySettings.LoginEmailFooterEmpty",
			  @"Telegram can send the code you need when logging in on a new device to an e-mail address instead of a text message."
			   "e-mail address instead of a text message.");
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if ([text rangeOfString:@"@"].location == NSNotFound || text.length < 5) {
			[sender refuseWithMessage:TGL(@"TwoStepAuth.EmailInvalid",
										  @"Invalid e-mail address. Please try again.")];
			return;
		}
		[sender setBusy:YES];
		[[TGClient shared] setLoginEmailAddress:text
									 completion:^(NSString *pattern, NSInteger codeLength) {
										 __strong typeof(weakSelf) strongSelf = weakSelf;
										 if (!strongSelf)
											 return;
										 if (![pattern isKindOfClass:[NSString class]] || !pattern.length) {
											 [sender refuseWithMessage:TGL(@"Login.EmailNotAllowedError", @"Sorry, this email can't be used.")];
											 return;
										 }
										 [sender setBusy:NO];
										 [strongSelf askLoginEmailCodeSentTo:pattern length:codeLength];
									 }];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)askLoginEmailCodeSentTo:(NSString *)pattern length:(NSInteger)codeLength {
	__weak typeof(self) weakSelf = self;
	TGSecurityStepViewController *step = [[TGSecurityStepViewController alloc] init];
	step.stepTitle = TGL(@"Login.Code", @"Code");
	step.stepCaption = TGL(@"Login.EnterCodeEmailTitle", @"Check Your Email");
	step.placeholder = TGL(@"Login.Code", @"Code");
	step.secure = NO;
	step.numeric = YES;
	step.actionTitle = TGL(@"Common.Done", @"Done");
	step.skipTitle = TGL(@"TwoStepAuth.SetupResendEmailCode", @"Resend Code");
	step.footerText = [NSString stringWithFormat:TGL(@"Login.EnterCodeEmailText", @"Please enter the code we have sent to your email %@."), pattern];
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if (!text.length) {
			[sender refuseWithMessage:TGL(@"PrivacySettings.PleaseEnterTheCode", @"Please enter the code.")];
			return;
		}
		[sender setBusy:YES];
		[[TGClient shared] checkLoginEmailAddressCode:text completion:^(BOOL ok) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!ok) {
				[sender refuseWithMessage:TGL(@"Login.WrongCodeError", @"Wrong code, please try again.")];
				return;
			}
			[strongSelf.navigationController popToViewController:strongSelf animated:YES];
			[strongSelf reload];
		}];
	};
	step.onSkip = ^{
		[[TGClient shared] resendLoginEmailAddressCodeWithCompletion:
				^(NSString *newPattern, NSInteger newLength) {
					TGPrivacyComplain([newPattern isKindOfClass:[NSString class]] && [newPattern length]
							? TGL(@"TwoStepAuth.SetupResendEmailCodeAlert", @"The code has been sent. Please check your e-mail. Be sure to check the spam folder as well.")
							: TGL(@"PrivacySettings.CodeCouldNotBeSentAgain", @"The code could not be sent again."));
				}];
	};
	[self.navigationController pushViewController:step animated:YES];
}

@end

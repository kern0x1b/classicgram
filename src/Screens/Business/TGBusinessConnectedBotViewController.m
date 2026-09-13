#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGBusinessConnectedBotViewController.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGBusinessService.h"
#import "TGContactsService.h"
#import "TGUserDisplayNameStore.h"
#import "TGBusinessBotSearchViewController.h"
#import "TGTheme.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"

typedef NS_ENUM(NSInteger, TGBCBSection) {
	TGBCBSectionBot = 0,
	TGBCBSectionRecipients,
	TGBCBSectionRights,
	TGBCBSectionCount,
};

@interface TGBusinessConnectedBotViewController ()

@property (nonatomic, assign) int64_t botUserId;
@property (nonatomic, copy) NSString *botName;
@property (nonatomic, assign) BOOL recipientExistingChats;
@property (nonatomic, assign) BOOL recipientNewChats;
@property (nonatomic, assign) BOOL recipientContacts;
@property (nonatomic, assign) BOOL recipientNonContacts;
@property (nonatomic, copy) NSArray *recipientChatIds;
@property (nonatomic, copy) NSArray *recipientExcludedChatIds;
@property (nonatomic, assign) BOOL recipientExcludeSelected;
@property (nonatomic, strong) NSMutableDictionary *rights;
@property (nonatomic, assign) BOOL loaded;

@end

@implementation TGBusinessConnectedBotViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		self.title = TGL(@"ChatbotSetup.TitleItem", @"Chatbots");
		_rights = [NSMutableDictionary dictionary];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Save", @"Save") bold:YES
									   target:self
									   action:@selector(save)];
	self.navigationItem.rightBarButtonItem.enabled = NO;
	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (NSArray *)rightsList {
	return @[
		@[ @"canReply", TGL(@"ChatbotSetup.Rights.ReplyToMessages", @"Reply to messages") ],
		@[ @"canReadMessages", TGL(@"ChatbotSetup.Rights.MarkAsRead", @"Mark messages as read") ],
		@[ @"canDeleteSentMessages", TGL(@"ChatbotSetup.Rights.DeleteSentMessages", @"Delete its own messages") ],
		@[ @"canDeleteAllMessages", TGL(@"ChatbotSetup.Rights.DeleteReceivedMessages", @"Delete any message") ],
		@[ @"canEditName", TGL(@"ChatbotSetup.Rights.EditName", @"Edit your name") ],
		@[ @"canEditBio", TGL(@"ChatbotSetup.Rights.EditBio", @"Edit your bio") ],
		@[ @"canEditProfilePhoto", TGL(@"ChatbotSetup.Rights.EditProfilePhoto", @"Edit your profile photo") ],
		@[ @"canEditUsername", TGL(@"ChatbotSetup.Rights.EditUsername", @"Edit your username") ],
		@[ @"canViewGiftsAndStars", TGL(@"ChatbotSetup.Rights.ViewGifts", @"View gifts and Star balance") ],
		@[ @"canSellGifts", TGL(@"ChatbotSetup.Rights.SellGifts", @"Sell received gifts") ],
		@[ @"canChangeGiftSettings", TGL(@"ChatbotSetup.Rights.ChangeGiftSettings", @"Change gift settings") ],
		@[ @"canTransferAndUpgradeGifts", TGL(@"ChatbotSetup.Rights.TransferAndUpgradeGifts", @"Transfer and upgrade gifts") ],
		@[ @"canTransferStars", TGL(@"ChatbotSetup.Rights.TransferStars", @"Transfer Stars to itself") ],
		@[ @"canManageStories", TGL(@"ChatbotSetup.Rights.ManageStories", @"Post, edit and delete stories") ],
	];
}

- (void)reload {
	__weak typeof(self) weakSelf = self;
	[TGBusinessService businessConnectedBotWithCompletion:^(NSDictionary *bot) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.botUserId = [bot[@"botUserId"] longLongValue];
		strongSelf.botName = strongSelf.botUserId ? [TGUserDisplayNameStore nameForUserId:strongSelf.botUserId] : nil;
		NSDictionary *recipients = bot[@"recipients"];
		strongSelf.recipientExistingChats = [recipients[@"existingChats"] boolValue];
		strongSelf.recipientNewChats = [recipients[@"newChats"] boolValue];
		strongSelf.recipientContacts = [recipients[@"contacts"] boolValue];
		strongSelf.recipientNonContacts = [recipients[@"nonContacts"] boolValue];
		strongSelf.recipientChatIds = [recipients[@"chatIds"] isKindOfClass:NSArray.class] ? recipients[@"chatIds"] : @[];
		strongSelf.recipientExcludedChatIds = [recipients[@"excludedChatIds"] isKindOfClass:NSArray.class] ? recipients[@"excludedChatIds"] : @[];
		strongSelf.recipientExcludeSelected = [recipients[@"excludeSelected"] boolValue];
		NSDictionary *rights = bot[@"rights"];
		strongSelf.rights = rights ? [rights mutableCopy] : [NSMutableDictionary dictionary];
		strongSelf.loaded = YES;
		strongSelf.navigationItem.rightBarButtonItem.enabled = strongSelf.botUserId != 0;
		[strongSelf.tableView reloadData];
	}];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return TGBCBSectionCount + (self.botUserId ? 1 : 0);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case TGBCBSectionBot:
			return 1;
		case TGBCBSectionRecipients:
			return 4;
		case TGBCBSectionRights:
			return (NSInteger)[self rightsList].count;
		default:
			return 1;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == TGBCBSectionRecipients)
		return TGL(@"BusinessMessageSetup.RecipientsSectionHeader", @"Recipients");
	if (section == TGBCBSectionRights)
		return TGL(@"ChatbotSetup.PermissionsSectionHeader", @"What the Bot Can Do");
	return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == TGBCBSectionBot)
		return TGL(@"ChatbotSetup.Text", @"Let a bot answer messages sent to this account.");
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	CGFloat measured = [[TGTheme shared] groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	if (!caption.length)
		return nil;
	return [[TGTheme shared] groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (UITableViewCell *)cellWithIdentifier:(NSString *)identifier style:(UITableViewCellStyle)style {
	UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:identifier];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.font = [UIFont systemFontOfSize:16];
	cell.accessoryView = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == TGBCBSectionBot) {
		UITableViewCell *cell = [self cellWithIdentifier:@"bot" style:UITableViewCellStyleValue1];
		cell.textLabel.text = TGL(@"Business.Bot", @"Bot");
		cell.detailTextLabel.text = self.botName.length ? self.botName : TGL(@"GroupInfo.SharedMediaNone", @"None");
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}

	if (indexPath.section == TGBCBSectionRecipients) {
		UITableViewCell *cell = [self cellWithIdentifier:@"recipient" style:UITableViewCellStyleDefault];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		BOOL on = NO;
		switch (indexPath.row) {
			case 0:
				cell.textLabel.text = TGL(@"BusinessMessageSetup.Recipients.CategoryExistingChats", @"Existing Chats");
				on = self.recipientExistingChats;
				break;
			case 1:
				cell.textLabel.text = TGL(@"BusinessMessageSetup.Recipients.CategoryNewChats", @"New Chats");
				on = self.recipientNewChats;
				break;
			case 2:
				cell.textLabel.text = TGL(@"BusinessMessageSetup.Recipients.CategoryContacts", @"Contacts");
				on = self.recipientContacts;
				break;
			default:
				cell.textLabel.text = TGL(@"BusinessMessageSetup.Recipients.CategoryNonContacts", @"Non-Contacts");
				on = self.recipientNonContacts;
				break;
		}
		UISwitch *toggle = [[UISwitch alloc] init];
		toggle.tag = 100 + indexPath.row;
		toggle.on = on;
		[toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
		return cell;
	}

	if (indexPath.section == TGBCBSectionRights) {
		NSArray *pair = [self rightsList][(NSUInteger)indexPath.row];
		UITableViewCell *cell = [self cellWithIdentifier:@"right" style:UITableViewCellStyleDefault];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.textLabel.numberOfLines = 0;
		cell.textLabel.text = pair[1];
		UISwitch *toggle = [[UISwitch alloc] init];
		toggle.tag = 200 + indexPath.row;
		toggle.on = [self.rights[pair[0]] boolValue];
		[toggle addTarget:self action:@selector(rightSwitchChanged:) forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
		return cell;
	}

	UITableViewCell *cell = [self cellWithIdentifier:@"disconnect" style:UITableViewCellStyleDefault];
	[TGIcons actionButtonInCell:cell
						  title:TGL(@"Business.DisconnectBot", @"Disconnect Bot")
						   kind:TGActionButtonKindDestructive
						 target:self
						 action:@selector(confirmDisconnect)];
	return cell;
}

- (void)switchChanged:(UISwitch *)toggle {
	switch (toggle.tag - 100) {
		case 0:
			self.recipientExistingChats = toggle.on;
			break;
		case 1:
			self.recipientNewChats = toggle.on;
			break;
		case 2:
			self.recipientContacts = toggle.on;
			break;
		case 3:
			self.recipientNonContacts = toggle.on;
			break;
	}
}

- (void)rightSwitchChanged:(UISwitch *)toggle {
	NSArray *pair = [self rightsList][(NSUInteger)(toggle.tag - 200)];
	self.rights[pair[0]] = @(toggle.on);
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section >= TGBCBSectionCount)
		return TGActionRowHeight();
	return 44;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == TGBCBSectionBot) {
		[self askForBotUsername];
		return;
	}
}

#pragma mark - bot picker

- (void)askForBotUsername {
	TGBusinessBotSearchViewController *search = [[TGBusinessBotSearchViewController alloc] init];
	__weak typeof(self) weakSelf = self;
	search.onPick = ^(int64_t userId, NSString *name) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.botUserId = userId;
		strongSelf.botName = name;
		strongSelf.navigationItem.rightBarButtonItem.enabled = YES;
		[strongSelf.tableView reloadData];
	};
	[self.navigationController pushViewController:search animated:YES];
}

#pragma mark - save

- (void)save {
	if (!self.botUserId)
		return;
	if (!self.recipientExistingChats && !self.recipientNewChats && !self.recipientContacts && !self.recipientNonContacts) {
		[self showAlert:TGL(@"BusinessMessageSetup.Recipients.NoneSelected", @"Choose at least one recipient category.")];
		return;
	}
	NSDictionary *recipients = @{
		@"existingChats" : @(self.recipientExistingChats),
		@"newChats" : @(self.recipientNewChats),
		@"contacts" : @(self.recipientContacts),
		@"nonContacts" : @(self.recipientNonContacts),
		@"chatIds" : self.recipientChatIds ?: @[],
		@"excludedChatIds" : self.recipientExcludedChatIds ?: @[],
		@"excludeSelected" : @(self.recipientExcludeSelected),
	};
	__weak typeof(self) weakSelf = self;
	void (^completion)(BOOL) = ^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[TGSnackbar showInView:strongSelf.navigationController.view
							  text:TGL(@"Toast.CouldNotSaveBotSettings", @"Could not save the bot settings")
						   seconds:2
						  onCommit:nil];
			return;
		}
		[TGSnackbar showInView:strongSelf.navigationController.view
						  text:TGL(@"PeerInfo.SavedMessagesTabTitle", @"Saved")
					   seconds:2
					  onCommit:nil];
		[strongSelf.navigationController popViewControllerAnimated:YES];
	};
	[TGBusinessService setBusinessConnectedBotUserId:self.botUserId
										  recipients:recipients
											  rights:self.rights
										  completion:completion];
}

- (void)showAlert:(NSString *)message {
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:nil message:message
						delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

- (void)confirmDisconnect {
	__weak typeof(self) weakSelf = self;
	UIAlertView *confirm = [[TGAlertView alloc]
			initWithTitle:TGL(@"Business.DisconnectBot", @"Disconnect Bot")
				  message:TGL(@"Business.DisconnectBotConfirmText", @"The bot will stop replying to messages sent to this account.")
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			okButtonTitle:TGL(@"Business.DisconnectBot", @"Disconnect Bot")
		  completionBlock:^(bool okButtonPressed) {
			  __strong typeof(weakSelf) strongSelf = weakSelf;
			  if (!strongSelf || !okButtonPressed)
				  return;
			  [strongSelf disconnect];
		  }];
	[confirm show];
}

- (void)disconnect {
	int64_t botUserId = self.botUserId;
	if (!botUserId)
		return;
	__weak typeof(self) weakSelf = self;
	[TGBusinessService deleteBusinessConnectedBotUserId:botUserId completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[TGSnackbar showInView:strongSelf.navigationController.view
							  text:TGL(@"Toast.CouldNotDisconnectBot", @"Could not disconnect the bot")
						   seconds:2
						  onCommit:nil];
			return;
		}
		[TGSnackbar showInView:strongSelf.navigationController.view
						  text:TGL(@"Business.BotDisconnected", @"Bot disconnected")
					   seconds:2
					  onCommit:nil];
		[strongSelf.navigationController popViewControllerAnimated:YES];
	}];
}

@end

#import "TGGroupedCaption.h"
#import "TGIcons.h"
#import "TGListBackground.h"
#import "TGBotVerificationViewController.h"
#import "TGLocalization.h"
#import "TGBotService.h"
#import "TGContactsService.h"
#import "TGUserDisplayNameStore.h"
#import "TGTheme.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"

static const NSInteger kBotAlertTag = 1;
static const NSInteger kGrantTargetAlertTag = 2;
static const NSInteger kGrantDescriptionAlertTag = 3;
static const NSInteger kRevokeTargetAlertTag = 4;
static const NSInteger kRevokeConfirmAlertTag = 5;

@interface TGBotVerificationViewController () <UIAlertViewDelegate>

@property (nonatomic, assign) int64_t botUserId;
@property (nonatomic, copy) NSString *botName;
@property (nonatomic, assign) BOOL checked;
@property (nonatomic, strong) NSDictionary *parameters;
@property (nonatomic, assign) int64_t pendingTargetId;
@property (nonatomic, assign) BOOL pendingTargetIsChat;
@property (nonatomic, copy) NSString *pendingTargetDisplayName;

@end

@implementation TGBotVerificationViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self)
		self.title = TGL(@"BotVerification.ChooseChat", @"Choose Chat to Verify");
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if (!self.botUserId || !self.checked)
		return 1;
	return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return 1;
	if (section == 1)
		return 1;
	return 2;
}

- (NSString *)captionForSection:(NSInteger)section {
	if (section != 0)
		return nil;
	return TGL(@"BotVerification.ChooseBotInfo", @"Only a bot Telegram has granted verification rights can mark a chat as verified. Enter that bot's username to act as it."
			"Enter that bot's username to act as it.");
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self captionForSection:section];
	if (!caption)
		return 12;
	return [[TGTheme shared] groupedCommentHeightForText:caption width:tableView.bounds.size.width];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self captionForSection:section];
	if (!caption)
		return nil;
	return [[TGTheme shared] groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (UITableViewCell *)cellWithIdentifier:(NSString *)identifier style:(UITableViewCellStyle)style {
	UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:identifier];
	[[TGTheme shared] styleCell:cell];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0) {
		UITableViewCell *cell = [self cellWithIdentifier:@"bot" style:UITableViewCellStyleValue1];
		cell.textLabel.text = TGL(@"ChatbotSetup.BotSearchPlaceholder", @"Bot Username");
		cell.detailTextLabel.text = self.botName.length ? self.botName : TGL(@"GroupInfo.SharedMediaNone", @"None");
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}

	if (indexPath.section == 1) {
		UITableViewCell *cell = [self cellWithIdentifier:@"status" style:UITableViewCellStyleDefault];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		NSString *organizationName = [self.parameters[@"organizationName"] length]
			? self.parameters[@"organizationName"]
			: @"";
		cell.textLabel.text = [NSString stringWithFormat:
				TGL(@"BotVerification.Verify.Placeholder", @"This page is verified by %@"),
			organizationName];
		return cell;
	}

	UITableViewCell *cell = [self cellWithIdentifier:@"action" style:UITableViewCellStyleDefault];
	cell.textLabel.textAlignment = NSTextAlignmentCenter;
	if (indexPath.row == 0) {
		[TGIcons actionButtonInCell:cell
							  title:TGL(@"BotVerification.Verify.Verify", @"Verify")
							   kind:TGActionButtonKindNeutral
							 target:self
							 action:@selector(askForGrantTarget)];
	} else {
		[TGIcons actionButtonInCell:cell
							  title:TGL(@"BotVerification.Remove.Remove", @"Remove")
							   kind:TGActionButtonKindDestructive
							 target:self
							 action:@selector(askForRevokeTarget)];
	}
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 2)
		return TGActionRowHeight();
	return 44;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == 0) {
		[self askForBotUsername];
		return;
	}
}

#pragma mark - bot lookup

- (void)askForBotUsername {
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"ChatbotSetup.BotSearchPlaceholder", @"Bot Username")
						 message:nil
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"Common.Done", @"Done"), nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert textFieldAtIndex:0].text = self.botName.length ? self.botName : @"";
	[alert textFieldAtIndex:0].placeholder = TGL(@"ChatbotSetup.BotSearchPlaceholder", @"Bot Username");
	alert.tag = kBotAlertTag;
	[alert show];
}

- (void)askForGrantTarget {
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"BotVerification.ChooseChat", @"Choose Chat to Verify")
						 message:nil
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"Common.Next", @"Next"), nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert textFieldAtIndex:0].placeholder = TGL(@"Profile.Username", @"username");
	alert.tag = kGrantTargetAlertTag;
	[alert show];
}

- (void)askForRevokeTarget {
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"BotVerification.ChooseChat", @"Choose Chat to Verify")
						 message:nil
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"BotVerification.Remove.Remove", @"Remove"), nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert textFieldAtIndex:0].placeholder = TGL(@"Profile.Username", @"username");
	alert.tag = kRevokeTargetAlertTag;
	[alert show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex)
		return;
	NSString *text = [alertView textFieldAtIndex:0].text;

	if (alertView.tag == kBotAlertTag) {
		if (!text.length)
			return;
		[self resolveBotUsername:text];
		return;
	}

	if (alertView.tag == kGrantTargetAlertTag) {
		if (!text.length)
			return;
		__weak typeof(self) weakSelf = self;
		[TGBotService resolveBotVerificationTargetForUsername:text completion:^(BOOL found, BOOL isChat, int64_t targetId, NSString *displayName) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!found) {
				[strongSelf showAlert:TGL(@"BotVerification.Resolve.ErrorNotFound", @"Sorry, this chat doesn't seem to exist.")];
				return;
			}
			NSString *name = displayName.length ? displayName : text;
			strongSelf.pendingTargetId = targetId;
			strongSelf.pendingTargetIsChat = isChat;
			strongSelf.pendingTargetDisplayName = name;
			TGAlertView *ask = [TGAlertView alloc];
			ask = [ask initWithTitle:TGL(@"BotVerification.Verify.Verify", @"Verify")
							 message:[NSString stringWithFormat:
								 TGL(@"BotVerification.Verify.Confirm.Text", @"Do you want to verify “%@” with your verification mark and description?"),
								 name]
							delegate:strongSelf
				   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   otherButtonTitles:TGL(@"BotVerification.Verify.Verify", @"Verify"), nil];
			ask.alertViewStyle = UIAlertViewStylePlainTextInput;
			[ask textFieldAtIndex:0].text = strongSelf.parameters[@"defaultCustomDescription"] ?: @"";
			ask.tag = kGrantDescriptionAlertTag;
			[ask show];
		}];
		return;
	}

	if (alertView.tag == kGrantDescriptionAlertTag) {
		int64_t targetId = self.pendingTargetId;
		BOOL targetIsChat = self.pendingTargetIsChat;
		NSString *targetName = self.pendingTargetDisplayName;
		self.pendingTargetId = 0;
		self.pendingTargetIsChat = NO;
		self.pendingTargetDisplayName = nil;
		if (!targetId)
			return;
		__weak typeof(self) weakSelf = self;
		[TGBotService grantBotVerification:self.botUserId
								 toTargetId:targetId
							   targetIsChat:targetIsChat
						  customDescription:text
								 completion:^(BOOL ok) {
									__strong typeof(weakSelf) strongSelf = weakSelf;
									if (!strongSelf)
										return;
									NSString *note = TGL(@"Login.UnknownError", @"An error occurred, please try again later.");
									if (ok)
										note = [NSString stringWithFormat:
											TGL(@"BotVerification.Added", @"%@ has been notified and will receive your verification mark and description upon accepting."),
											targetName];
									[TGSnackbar showInView:strongSelf.view text:note seconds:2 onCommit:nil];
								}];
		return;
	}

	if (alertView.tag == kRevokeTargetAlertTag) {
		if (!text.length)
			return;
		__weak typeof(self) weakSelf = self;
		[TGBotService resolveBotVerificationTargetForUsername:text completion:^(BOOL found, BOOL isChat, int64_t targetId, NSString *displayName) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!found) {
				[strongSelf showAlert:TGL(@"BotVerification.Resolve.ErrorNotFound", @"Sorry, this chat doesn't seem to exist.")];
				return;
			}
			NSString *name = displayName.length ? displayName : text;
			strongSelf.pendingTargetId = targetId;
			strongSelf.pendingTargetIsChat = isChat;
			strongSelf.pendingTargetDisplayName = name;
			TGAlertView *confirm = [TGAlertView alloc];
			confirm = [confirm initWithTitle:TGL(@"BotVerification.Remove.Remove", @"Remove")
									 message:[NSString stringWithFormat:
										 TGL(@"BotVerification.Remove.Confirm.Text", @"Remove your verification mark from “%@”?"),
										 name]
									delegate:strongSelf
						   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
						   otherButtonTitles:TGL(@"BotVerification.Remove.Remove", @"Remove"), nil];
			confirm.tag = kRevokeConfirmAlertTag;
			[confirm show];
		}];
		return;
	}

	if (alertView.tag == kRevokeConfirmAlertTag) {
		int64_t targetId = self.pendingTargetId;
		BOOL targetIsChat = self.pendingTargetIsChat;
		NSString *targetName = self.pendingTargetDisplayName;
		self.pendingTargetId = 0;
		self.pendingTargetIsChat = NO;
		self.pendingTargetDisplayName = nil;
		if (!targetId)
			return;
		__weak typeof(self) weakSelf = self;
		[TGBotService revokeBotVerification:self.botUserId
								fromTargetId:targetId
								targetIsChat:targetIsChat
								  completion:^(BOOL ok) {
									 __strong typeof(weakSelf) innerSelf = weakSelf;
									 if (!innerSelf)
										 return;
									 NSString *note = TGL(@"Login.UnknownError", @"An error occurred, please try again later.");
									 if (ok)
										 note = [NSString stringWithFormat:
											 TGL(@"BotVerification.Removed", @"You have removed %@'s verification."),
											 targetName];
									 [TGSnackbar showInView:innerSelf.view text:note seconds:2 onCommit:nil];
								 }];
	}
}

- (void)resolveBotUsername:(NSString *)username {
	__weak typeof(self) weakSelf = self;
	[TGContactsService userIdForUsername:username completion:^(int64_t userId, BOOL failed) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (failed) {
			[strongSelf showAlert:TGL(@"ChatbotSetup.BotLookupFailed", @"That username could not be checked. Try again in a moment.")];
			return;
		}
		if (!userId) {
			[strongSelf showAlert:TGL(@"ChatbotSetup.BotNotFoundStatus", @"No bot was found with that username.")];
			return;
		}
		strongSelf.botUserId = userId;
		strongSelf.botName = [TGUserDisplayNameStore nameForUserId:userId];
		strongSelf.checked = NO;
		strongSelf.parameters = nil;
		[strongSelf.tableView reloadData];
		[TGBotService botVerificationParametersForBotUserId:userId completion:^(NSDictionary *parameters) {
			__strong typeof(weakSelf) innerSelf = weakSelf;
			if (!innerSelf || innerSelf.botUserId != userId)
				return;
			if (!parameters.count) {
				innerSelf.botUserId = 0;
				innerSelf.botName = nil;
				innerSelf.checked = NO;
				innerSelf.parameters = nil;
				[innerSelf.tableView reloadData];
				[innerSelf showAlert:TGL(@"BotVerification.Resolve.ErrorNotVerifier",
					@"This bot cannot verify chats.")];
				return;
			}
			innerSelf.checked = YES;
			innerSelf.parameters = parameters;
			[innerSelf.tableView reloadData];
		}];
	}];
}

- (void)showAlert:(NSString *)message {
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:nil
						 message:message
						delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

@end

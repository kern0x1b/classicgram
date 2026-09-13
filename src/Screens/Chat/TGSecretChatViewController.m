#import "TGIcons.h"
#import "TGGroupedCaption.h"
#import "TGClient+ChatManagement.h"
#import "TGSettingValueText.h"
#import "TGSecretChatViewController.h"
#import "TGChatViewController.h"
#import "TGClient.h"
#import "TGClient+SecretChats.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGActionSheet.h"
#import "TGSnackbar.h"
#import "TGHexColour.h"

static UIImage *TGSecretKeyImage(NSArray *cells) {
	if (![cells isKindOfClass:NSArray.class] || cells.count < 144)
		return nil;
	static const int palette[4] = {0xffffff, 0xd5e6f3, 0x2d5775, 0x2f99c9};
	CGFloat side = 8.0f;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side * 12, side * 12), YES, 0.0f);
	CGContextRef context = UIGraphicsGetCurrentContext();
	for (NSInteger i = 0; i < 144; i++) {
		id value = cells[(NSUInteger)i];
		NSInteger index = [value isKindOfClass:NSNumber.class] ? ([value intValue] & 3) : 0;
		CGContextSetFillColorWithColor(context, TGColourFromHex(palette[index]).CGColor);
		CGContextFillRect(context, CGRectMake((i % 12) * side, (i / 12) * side, side, side));
	}
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

@interface TGSecretChatViewController ()
@property (nonatomic, strong) id secretChatStateChangedObserverToken;
@property (nonatomic, strong) id autoDeleteTimeChangedObserverToken;
@end

@implementation TGSecretChatViewController

- (id)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.title = self.peerName.length ? self.peerName : TGL(@"SecretChat.Title", @"Secret Chat");
	self.stateText = TGL(@"Channel.NotificationLoading", @"Loading…");
	self.sendText = @"";
	self.ladder = [TGClient autoDeleteLadder];
	__weak typeof(self) weakSelf = self;
	self.secretChatStateChangedObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGSecretChatStateDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf secretChatStateChanged:note];
				}];
	self.autoDeleteTimeChangedObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatMessageAutoDeleteTimeDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf autoDeleteTimeChanged:note];
				}];
	[self reloadState];
	[self reloadTimers];
	[self reloadKey];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.secretChatStateChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.secretChatStateChangedObserverToken];
	if (self.autoDeleteTimeChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.autoDeleteTimeChangedObserverToken];
}

- (void)secretChatStateChanged:(NSNotification *)note {
	if (self.secretChatId == 0 ||
		![note.object respondsToSelector:@selector(intValue)] ||
		[(NSNumber *)note.object intValue] != self.secretChatId)
		return;
	[self reloadState];
	[self reloadKey];
}

- (void)autoDeleteTimeChanged:(NSNotification *)note {
	if (self.chatId == 0 ||
		![note.object respondsToSelector:@selector(longLongValue)] ||
		[(NSNumber *)note.object longLongValue] != self.chatId)
		return;
	[self reloadTimers];
}

- (NSString *)wordingForState:(NSString *)state {
	if ([state isEqualToString:@"ready"])
		return TGL(@"SecretChat.StateReady", @"Ready");
	if ([state isEqualToString:@"pending"])
		return TGL(@"SecretChat.StateWaiting", @"Waiting for the other side");
	if ([state isEqualToString:@"closed"])
		return TGL(@"SecretChat.StateCancelled", @"Cancelled");
	return state.length ? state : TGL(@"SecretChat.StateUnknown", @"Unknown");
}

- (void)reloadState {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] secretChatInfoForChat:self.chatId completion:^(NSDictionary *info) {
		TGSecretChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (![info isKindOfClass:NSDictionary.class]) {
			strongSelf.stateText = TGL(@"SecretChat.Unavailable", @"Unavailable");
			[strongSelf.tableView reloadData];
			return;
		}
		NSNumber *secretId = [info[@"secretChatId"] isKindOfClass:NSNumber.class]
			? info[@"secretChatId"]
			: nil;
		strongSelf.secretChatId = secretId ? secretId.intValue : 0;
		NSString *state = [info[@"state"] isKindOfClass:NSString.class] ? info[@"state"] : @"";
		strongSelf.rawState = state;
		strongSelf.stateText = [strongSelf wordingForState:state];
		if (!strongSelf.peerName.length) {
			NSString *name = [info[@"name"] isKindOfClass:NSString.class] ? info[@"name"] : nil;
			if (name.length) {
				strongSelf.peerName = name;
				strongSelf.title = name;
			}
		}
		[strongSelf.tableView reloadData];
	}];
	[[TGClient shared] canSendInSecretChat:self.chatId
								completion:^(BOOL canSend, NSString *state) {
									TGSecretChatViewController *strongSelf = weakSelf;
									if (!strongSelf)
										return;
									strongSelf.sendText = canSend ? @"" : TGL(@"SecretChat.CannotSendYet", @"You cannot send messages yet");
									[strongSelf.tableView reloadData];
								}];
}

- (void)reloadTimers {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] autoDeleteTimeForChat:self.chatId completion:^(NSInteger seconds) {
		TGSecretChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.ttl = seconds;
		strongSelf.ttlKnown = YES;
		[strongSelf.tableView reloadData];
	}];
	[[TGClient shared] defaultAutoDeleteTimeWithCompletion:^(NSInteger seconds, BOOL failed) {
		TGSecretChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.defaultTtl = failed ? strongSelf.defaultTtl : seconds;
		strongSelf.defaultTtlKnown = !failed;
		strongSelf.defaultTtlFailed = failed;
		[strongSelf.tableView reloadData];
	}];
}

- (void)reloadKey {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] encryptionKeyGridForChat:self.chatId completion:^(NSArray *cells) {
		TGSecretChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		UIImage *image = TGSecretKeyImage(cells);
		if (!image)
			return;
		[[TGClient shared] encryptionKeyHashForChat:strongSelf.chatId completion:^(NSString *base64) {
			TGSecretChatViewController *innerSelf = weakSelf;
			if (!innerSelf)
				return;
			[innerSelf showKeyImage:image hash:base64];
		}];
	}];
}

- (void)showKeyImage:(UIImage *)image hash:(NSString *)base64 {
	CGFloat width = self.tableView.bounds.size.width;
	UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 210)];
	footer.backgroundColor = [UIColor clearColor];

	UIImageView *grid = [[UIImageView alloc] initWithImage:image];
	grid.frame = CGRectMake((CGFloat)(int)((width - 96) / 2), 14, 96, 96);
	grid.layer.borderColor = [UIColor colorWithWhite:0.0f alpha:0.15f].CGColor;
	grid.layer.borderWidth = 1.0f;
	[footer addSubview:grid];

	UILabel *caption = [[UILabel alloc] initWithFrame:CGRectMake(20, 118, width - 40, 30)];
	caption.backgroundColor = [UIColor clearColor];
	caption.numberOfLines = 2;
	caption.textAlignment = NSTextAlignmentCenter;
	caption.font = [UIFont systemFontOfSize:13];
	caption.textColor = [UIColor colorWithWhite:0.0f alpha:0.55f];
	NSString *peerName = self.peerName.length ? self.peerName : TGL(@"SecretChat.Title", @"Secret Chat");
	caption.text = [NSString stringWithFormat:
			TGL(@"EncryptionKey.Description", @"This image and text were derived from the encryption key for this secret chat with %1$@.\n\n If they look the same on %2$@'s device, end-to-end encryption is guaranteed.\n\nLearn more at telegram.org"),
		peerName, peerName];
	[footer addSubview:caption];

	UILabel *hashLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 152, width - 40, 46)];
	hashLabel.backgroundColor = [UIColor clearColor];
	hashLabel.numberOfLines = 3;
	hashLabel.lineBreakMode = NSLineBreakByCharWrapping;
	hashLabel.textAlignment = NSTextAlignmentCenter;
	hashLabel.font = [UIFont fontWithName:@"Courier" size:11] ?: [UIFont systemFontOfSize:11];
	hashLabel.textColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
	hashLabel.text = [base64 isKindOfClass:NSString.class] ? base64 : @"";
	[footer addSubview:hashLabel];

	self.tableView.tableFooterView = footer;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return section == 2 ? 1 : 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0)
		return TGL(@"SecretChat.Title", @"Secret Chat");
	if (section == 1)
		return TGL(@"GlobalAutodeleteSettings.SetConfirmTitle", @"Self-Destruct Timer");
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
	if (section == 0 && self.sendText.length)
		return self.sendText;
	if (section == 1)
		return TGL(@"AutoremoveSetup.TimerInfoChat", @"Messages sent to this chat are removed for both sides after the timer runs out.");
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGSecretChatCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:reuse];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.detailTextLabel.text = @"";
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;

	if (indexPath.section == 0) {
		if (indexPath.row == 0) {
			cell.textLabel.text = TGL(@"SecretChat.Status", @"Status");
			cell.detailTextLabel.text = self.stateText;
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		} else {
			cell.textLabel.text = TGL(@"SavedMessages.OpenChat", @"Open Chat");
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
		return cell;
	}
	if (indexPath.section == 1) {
		if (indexPath.row == 0) {
			cell.textLabel.text = TGL(@"AutoremoveSetup.Title", @"Timer");
			cell.detailTextLabel.text = self.ttlKnown
				? [TGClient autoDeleteTitleForSeconds:self.ttl]
				: @"…";
		} else {
			cell.textLabel.text = TGL(@"SecretChat.DefaultForNewChats", @"Default for New Chats");
			cell.detailTextLabel.text = TGSettingValueText(self.defaultTtlKnown,
					self.defaultTtlFailed, [TGClient autoDeleteTitleForSeconds:self.defaultTtl]);
		}
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}
	[TGIcons actionButtonInCell:cell
						  title:TGL(@"SecretChat.Terminate", @"Terminate Secret Chat")
						   kind:TGActionButtonKindDestructive
						 target:self
						 action:@selector(confirmTerminate:)];
	return cell;
}

- (void)confirmTerminate:(UIButton *)sender {
	UIActionSheet *sheet = [[UIActionSheet alloc]
				 initWithTitle:[NSString stringWithFormat:
								 TGL(@"ChatList.DeleteSecretChatConfirmation",
										 @"Are you sure you want to delete secret chat\nwith %@?"),
								 self.peerName.length ? self.peerName : TGL(@"SecretChat.Title", @"Secret Chat")]
					  delegate:self
			 cancelButtonTitle:nil
		destructiveButtonTitle:TGL(@"AuthSessions.Terminate", @"Terminate")
			 otherButtonTitles:TGL(@"SecretChat.TerminateAndDeleteHistory", @"Terminate and Delete History"), nil];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = 3;
	UIView *anchor = sender.superview ?: self.view;
	[sheet tg_showFromRect:sender.frame inView:anchor];
}

- (void)showLadderWithTag:(NSInteger)tag title:(NSString *)title {
	UIActionSheet *sheet = [UIActionSheet alloc];
	sheet = [sheet initWithTitle:title
						delegate:self
			   cancelButtonTitle:nil
		  destructiveButtonTitle:nil
			   otherButtonTitles:nil];
	for (NSDictionary *entry in self.ladder) {
		NSString *entryTitle = [entry isKindOfClass:NSDictionary.class] ? entry[@"title"] : nil;
		if ([entryTitle isKindOfClass:NSString.class])
			[sheet addButtonWithTitle:entryTitle];
	}
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = tag;
	UIView *view = self.navigationController.view;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds), 1, 1) inView:view];
}

- (void)openChat {
	if (self.chatId != 0) {
		TGChatViewController *vc = [[TGChatViewController alloc] init];
		vc.chatId = self.chatId;
		vc.chatTitle = self.peerName.length ? self.peerName : TGL(@"SecretChat.Title", @"Secret Chat");
		[self.navigationController pushViewController:vc animated:YES];
		return;
	}
	if (self.secretChatId == 0) {
		[[[UIAlertView alloc] initWithTitle:nil
									message:TGL(@"Contacts.ThisSecretChatIsNotAvailable", @"This secret chat is not available.")
								   delegate:nil
						  cancelButtonTitle:TGL(@"Common.OK", @"OK")
						  otherButtonTitles:nil] show];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] openSecretChatId:self.secretChatId completion:^(int64_t chatId) {
		TGSecretChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (chatId == 0) {
			[[[UIAlertView alloc] initWithTitle:nil
										message:TGL(@"Contacts.CouldNotOpenThisSecretChat", @"Could not open this secret chat.")
									   delegate:nil
							  cancelButtonTitle:TGL(@"Common.OK", @"OK")
							  otherButtonTitles:nil] show];
			return;
		}
		strongSelf.chatId = chatId;
		[strongSelf openChat];
	}];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 2)
		return [TGIcons actionRowHeight];
	return 44.0f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == 0 && indexPath.row == 1) {
		[self openChat];
		return;
	}
	if (indexPath.section == 1) {
		if (indexPath.row == 0) {
			if (![self.rawState isEqualToString:@"ready"]) {
				[[[UIAlertView alloc] initWithTitle:nil
											message:TGL(@"SecretChat.CannotChangeTimerNow", @"You can't change the self-destruct timer for this chat right now.")
										   delegate:nil
								  cancelButtonTitle:TGL(@"Common.OK", @"OK")
								  otherButtonTitles:nil] show];
				return;
			}
			[self showLadderWithTag:1 title:TGL(@"GlobalAutodeleteSettings.SetConfirmTitle", @"Self-Destruct Timer")];
		} else {
			[self showLadderWithTag:2 title:TGL(@"SecretChat.DefaultForNewChats", @"Default for New Chats")];
		}
		return;
	}
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (index == sheet.cancelButtonIndex)
		return;
	if (sheet.tag == 3) {
		BOOL deleteHistory = (index != sheet.destructiveButtonIndex);
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] closeSecretChatForChat:self.chatId
									 deleteHistory:deleteHistory
										completion:^(BOOL ok) {
			TGSecretChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!ok) {
				[TGSnackbar showInView:strongSelf.navigationController.view
								   text:TGL(@"Toast.CouldNotTerminateSecretChat", @"Could not terminate this secret chat")
								seconds:2
							   onCommit:nil];
				return;
			}
			[strongSelf.navigationController popViewControllerAnimated:YES];
		}];
		return;
	}
	if (index < 0 || index >= (NSInteger)self.ladder.count)
		return;
	NSDictionary *entry = self.ladder[(NSUInteger)index];
	if (![entry isKindOfClass:NSDictionary.class])
		return;
	NSInteger seconds = [entry[@"seconds"] integerValue];
	if (sheet.tag == 1) {
		if (![self.rawState isEqualToString:@"ready"]) {
			[self reloadState];
			return;
		}
		NSInteger previous = self.ttl;
		self.ttl = seconds;
		self.ttlKnown = YES;
		[self.tableView reloadData];

		__weak typeof(self) weakSelf = self;
		[[TGClient shared] setChat:self.chatId autoDeleteSeconds:seconds completion:^(BOOL ok) {
			TGSecretChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!ok) {
				strongSelf.ttl = previous;
				[strongSelf.tableView reloadData];
				[[[UIAlertView alloc] initWithTitle:nil
											message:TGL(@"SecretChat.TimerCouldNotBeChanged", @"That setting could not be changed.")
										   delegate:nil
								  cancelButtonTitle:TGL(@"Common.OK", @"OK")
								  otherButtonTitles:nil] show];
				return;
			}
			[strongSelf reloadTimers];
		}];
		return;
	}
	NSInteger previousDefault = self.defaultTtl;
	self.defaultTtl = seconds;
	self.defaultTtlKnown = YES;
	self.defaultTtlFailed = NO;
	[self.tableView reloadData];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setDefaultAutoDeleteTime:seconds
									  completion:^(BOOL ok) {
		TGSecretChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			strongSelf.defaultTtl = previousDefault;
			[strongSelf.tableView reloadData];
			[[[UIAlertView alloc] initWithTitle:nil
										message:TGL(@"SecretChat.TimerCouldNotBeChanged", @"That setting could not be changed.")
									   delegate:nil
							  cancelButtonTitle:TGL(@"Common.OK", @"OK")
							  otherButtonTitles:nil] show];
			return;
		}
		[strongSelf reloadTimers];
	}];
}

@end

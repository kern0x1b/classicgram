#import "TGGroupedCaption.h"
#import "TGSupergroupUsernamesViewController.h"
#import "TGSectionHeaderTitle.h"
#import "TGFriendlyError.h"
#import "TGListBackground.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGPopupMenu.h"
#import "TGActionSheet.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGForwardPicker.h"
#import "UIView+SafeTint.h"
#import "TGImageDecode.h"
#import "TGClient+Groups.h"
#import "TGGroupMembersViewController.h"
#import "TGLazyFramework.h"
#import <AVFoundation/AVFoundation.h>
#import <AddressBook/AddressBook.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import "TGEmoji.h"
#import "TGDateLabel.h"
#import "TGDateUtils.h"
#import "TGAlertView.h"
#import "TGSupergroupUsernamesPresenter.h"
#import "TGSupergroupUsernamesRowBridge.h"

@interface TGSupergroupUsernamesViewController ()
@property (nonatomic, strong) TGSupergroupUsernamesPresenter *rowPresenter;
@property (nonatomic, strong) TGSupergroupUsernamesRowBridge *rowBridge;
@end

@implementation TGSupergroupUsernamesViewController

- (id)initWithChatId:(int64_t)chatId
	  activeUsernames:(NSArray *)active
	disabledUsernames:(NSArray *)disabled
	 editableUsername:(NSString *)editableUsername {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (!self)
		return nil;
	_chatId = chatId;
	self.active = [NSMutableArray arrayWithArray:
			[active isKindOfClass:[NSArray class]] ? active : @[]];
	self.disabled = [NSMutableArray arrayWithArray:
			[disabled isKindOfClass:[NSArray class]] ? disabled : @[]];
	self.editableUsername = editableUsername.length ? editableUsername : nil;
	self.rowPresenter = [[TGSupergroupUsernamesPresenter alloc] init];
	self.rowBridge = [[TGSupergroupUsernamesRowBridge alloc] initWithPresenter:self.rowPresenter];
	[self.rowPresenter updateWithActive:self.active
							   disabled:self.disabled
					   editableUsername:self.editableUsername];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Username.Title", @"Username");
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	NSInteger count = 1;
	if (self.disabled.count)
		count++;
	return count;
}

- (NSInteger)disabledSection {
	return self.disabled.count ? 1 : -1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return (NSInteger)self.active.count;
	if (section == [self disabledSection])
		return (NSInteger)self.disabled.count;
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0)
		return TGSectionHeaderTitle(TGL(@"Username.SectionActive", @"Active"),
			(NSInteger)self.active.count);
	if (section == [self disabledSection])
		return TGSectionHeaderTitle(TGL(@"Username.SectionDisabled", @"Disabled"),
			(NSInteger)self.disabled.count);
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == 0)
		return TGL(@"Username.SupergroupActiveFooter",
				@"The first username is shown as the primary. Tap a username to move "
				@"it to the top or turn it off. The public link username cannot be "
				@"turned off.");
	if (section == [self disabledSection])
		return TGL(@"Username.SectionDisabledFooter", @"Tap a username to turn it back on.");
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

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [[TGTheme shared] groupedHeaderHeightForTitle:
			[self tableView:tableView titleForHeaderInSection:section]];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	TGTheme *theme = [TGTheme shared];
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [theme groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0 || indexPath.section == [self disabledSection]) {
		TGSupergroupUsernamesRowSection bridgeSection = indexPath.section == 0
			? TGSupergroupUsernamesRowSectionActive
			: TGSupergroupUsernamesRowSectionDisabled;
		if ([self.rowBridge ownsRowAtIndex:indexPath.row inSection:bridgeSection])
			return [self.rowBridge cellForRow:indexPath.row inSection:bridgeSection inTable:tableView];
	}

	NSArray *list = indexPath.section == 0 ? self.active : self.disabled;
	static NSString *reuse = @"TGUsernameCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:reuse];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.font = TGGroupedRowTitleFont();
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];

	NSString *username = indexPath.row < (NSInteger)list.count ? list[indexPath.row] : @"";
	cell.textLabel.text = [NSString stringWithFormat:@"@%@", username];
	BOOL isEditable = self.editableUsername.length && [username isEqualToString:self.editableUsername];
	if (indexPath.section == 0 && isEditable) {
		cell.detailTextLabel.text = nil;
		cell.accessoryType = UITableViewCellAccessoryNone;
		UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 90, 20)];
		badge.backgroundColor = [UIColor clearColor];
		badge.font = [UIFont systemFontOfSize:13];
		badge.textColor = [[TGTheme shared] secondaryTextColour];
		badge.textAlignment = NSTextAlignmentRight;
		badge.text = TGL(@"GroupInfo.PublicLink", @"Public Link");
		cell.accessoryView = badge;
	} else {
		cell.accessoryView = nil;
		cell.accessoryType = UITableViewCellAccessoryNone;
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (self.busy)
		return;

	if (indexPath.section == 0) {
		if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.active.count)
			return;
		[self showActionsForActiveUsername:self.active[indexPath.row]
									 atRow:indexPath.row];
		return;
	}

	if (indexPath.section == [self disabledSection]) {
		if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.disabled.count)
			return;
		[self enableUsername:self.disabled[indexPath.row]];
	}
}

- (void)showActionsForActiveUsername:(NSString *)username atRow:(NSInteger)row {
	BOOL isEditable = self.editableUsername.length && [username isEqualToString:self.editableUsername];
	NSMutableArray *titles = [NSMutableArray array];
	if (row > 0)
		[titles addObject:TGL(@"Username.MoveToTopAction", @"Move to Top")];
	if (!isEditable)
		[titles addObject:TGL(@"Username.DisableAction", @"Disable")];
	if (!titles.count)
		return;

	self.pendingUsername = username;
	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:[NSString stringWithFormat:@"@%@", username]
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	sheet.tag = 501;
	self.pendingActionTitles = titles;
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
	[sheet tg_showFromRect:cell.frame inView:self.tableView];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (actionSheet.tag != 501 || buttonIndex == actionSheet.cancelButtonIndex) {
		self.pendingUsername = nil;
		self.pendingActionTitles = nil;
		return;
	}
	NSArray *titles = self.pendingActionTitles;
	NSString *username = self.pendingUsername;
	self.pendingUsername = nil;
	self.pendingActionTitles = nil;
	if (!username.length || buttonIndex < 0 || buttonIndex >= (NSInteger)titles.count)
		return;
	NSString *action = titles[buttonIndex];
	if ([action isEqualToString:TGL(@"Username.MoveToTopAction", @"Move to Top")])
		[self promoteUsername:username];
	else if ([action isEqualToString:TGL(@"Username.DisableAction", @"Disable")])
		[self disableUsername:username];
}

- (void)promoteUsername:(NSString *)username {
	NSMutableArray *reordered = [NSMutableArray arrayWithObject:username];
	for (NSString *existing in self.active) {
		if (![existing isEqualToString:username])
			[reordered addObject:existing];
	}
	[self applyReorder:reordered];
}

- (void)disableUsername:(NSString *)username {
	self.busy = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setGroupChat:self.chatId username:username active:NO
						 completion:^(BOOL ok, NSString *errorMessage) {
							 __strong typeof(weakSelf) strongSelf = weakSelf;
							 if (!strongSelf)
								 return;
							 strongSelf.busy = NO;
							 if (!ok) {
								 [strongSelf showFailure:TGFriendlyErrorText(errorMessage,
											TGL(@"Username.DisableFailed", @"This username could not be turned off."))];
								 return;
							 }
							 [strongSelf.active removeObject:username];
							 if (![strongSelf.disabled containsObject:username])
								 [strongSelf.disabled addObject:username];
							 [strongSelf reloadAndNotify];
						 }];
}

- (void)enableUsername:(NSString *)username {
	self.busy = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setGroupChat:self.chatId username:username active:YES
						 completion:^(BOOL ok, NSString *errorMessage) {
							 __strong typeof(weakSelf) strongSelf = weakSelf;
							 if (!strongSelf)
								 return;
							 strongSelf.busy = NO;
							 if (!ok) {
								 [strongSelf showFailure:TGFriendlyErrorText(errorMessage,
											TGL(@"Username.EnableFailed", @"This username could not be turned on."))];
								 return;
							 }
							 [strongSelf.disabled removeObject:username];
							 if (![strongSelf.active containsObject:username])
								 [strongSelf.active addObject:username];
							 [strongSelf reloadAndNotify];
						 }];
}

- (void)applyReorder:(NSArray *)order {
	self.busy = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] reorderUsernames:order forGroup:self.chatId
							 completion:^(BOOL ok, NSString *errorMessage) {
								 __strong typeof(weakSelf) strongSelf = weakSelf;
								 if (!strongSelf)
									 return;
								 strongSelf.busy = NO;
								 if (!ok) {
									 [strongSelf showFailure:TGFriendlyErrorText(errorMessage,
											TGL(@"Username.ReorderFailed", @"This order could not be saved."))];
									 return;
								 }
								 strongSelf.active = [NSMutableArray arrayWithArray:order];
								 [strongSelf reloadAndNotify];
							 }];
}

- (void)reloadAndNotify {
	[self.rowPresenter updateWithActive:self.active
							   disabled:self.disabled
					   editableUsername:self.editableUsername];
	[self.tableView reloadData];
	if (self.onChanged)
		self.onChanged([self.active copy], [self.disabled copy]);
}

- (void)showFailure:(NSString *)message {
	[[[TGAlertView alloc] initWithTitle:nil message:message cancelButtonTitle:TGL(@"Common.OK", @"OK")
						  okButtonTitle:nil
						completionBlock:nil] show];
}

@end

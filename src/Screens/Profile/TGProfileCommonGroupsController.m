#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGProfileCommonGroupsController.h"
#import "TGListLoadFailure.h"
#import "TGProfileViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGPopupMenu.h"
#import "TGActionSheet.h"
#import "TGForwardPicker.h"
#import "UIView+SafeTint.h"
#import "TGImageDecode.h"
#import "TGClient+Contacts.h"
#import "TGChatViewController.h"
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

@implementation TGProfileCommonGroupsController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"UserInfo.GroupsInCommon", @"Groups in Common");
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	if (!self.chats.count)
		[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)reload {
	if (!self.userId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] groupsInCommonWithUser:self.userId completion:^(NSArray *chats) {
		weakSelf.loadFailed = ![chats isKindOfClass:[NSArray class]];
		weakSelf.loaded = YES;
		weakSelf.chats = [chats isKindOfClass:[NSArray class]] ? chats : @[];
		[weakSelf.tableView reloadData];
	}];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.chats.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (TGListShowsLoadFailureNotice(self.loadFailed, self.chats.count))
		return TGL(@"UserInfo.GroupsInCommonLoadFailed",
			@"The groups you have in common could not be loaded.");
	if (!self.loaded)
		return TGL(@"Channel.NotificationLoading", @"Loading…");
	if (!self.chats.count)
		return TGL(@"UserInfo.GroupsInCommonEmpty", @"You have no groups in common.");
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

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return kMemberRowHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"common"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"common"];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	id raw = indexPath.row < (NSInteger)self.chats.count ? self.chats[indexPath.row] : nil;
	NSDictionary *chat = [raw isKindOfClass:[NSDictionary class]] ? raw : @{};
	NSString *title = TGProfileText(chat[@"title"]) ?: @"";
	cell.textLabel.text = title;
	UIImage *avatar = [TGIcons avatarWithInitials:TGProfileInitial(title)
											 size:kMemberAvatarSide
										 colourId:TGProfileInt64(chat[@"id"])];
	cell.imageView.image = avatar;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	id raw = indexPath.row < (NSInteger)self.chats.count ? self.chats[indexPath.row] : nil;
	if (![raw isKindOfClass:[NSDictionary class]])
		return;
	int64_t chatId = TGProfileInt64([raw objectForKey:@"id"]);
	if (!chatId)
		return;
	TGChatViewController *chat = [[TGChatViewController alloc] init];
	chat.chatId = chatId;
	chat.chatTitle = TGProfileText([raw objectForKey:@"title"]) ?: @"";
	[self.navigationController pushViewController:chat animated:YES];
}

@end

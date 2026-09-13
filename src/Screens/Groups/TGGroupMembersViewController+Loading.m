#import "TGClient+ChatManagement.h"
#import "TGGroupMembersViewController.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGActionSheet.h"
#import "TGClient+Files.h"
#import "TGGroupMembersViewControllerInternal.h"
#import "TGListLoadFailure.h"
#import "TGAvatarRowKey.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGClient+Groups.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGPopupMenu.h"
#import "TGAlertView.h"
#import "TGImageDecode.h"
#import "UIView+SafeTint.h"
#import <QuartzCore/QuartzCore.h>
#import "TGMemberRightsViewController.h"
#import "TGGroupAddMembersViewController.h"
#import "TGGroupPublicLinkViewController.h"
#import "TGGroupMemberCell.h"

@implementation TGGroupMembersViewController (Loading)

- (void)refreshVisibleRowsForMemberKey:(NSNumber *)key {
	NSMutableArray *paths = [NSMutableArray array];
	for (NSIndexPath *path in [self.tableView indexPathsForVisibleRows]) {
		NSDictionary *member = [self memberAtIndexPath:path];
		int64_t userId = member ? TGMembersUserId(member) : 0;
		if (userId != 0 && TGAvatarRowKeyMatches([NSNumber numberWithLongLong:userId], key))
			[paths addObject:path];
	}
	if (paths.count)
		[self.tableView reloadRowsAtIndexPaths:paths
							  withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - loading

- (void)loadGroupInfo {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] groupInfoForChat:self.chatId completion:^(NSDictionary *info) {
		TGGroupMembersViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if ([info isKindOfClass:NSDictionary.class]) {
			strongSelf.groupInfo = info;
			[strongSelf updateTitle];
			[strongSelf updateManageButton];
		}
	}];

	[[TGClient shared] myAdministratorRightsInGroup:self.chatId
										 completion:^(NSDictionary *rights, NSString *status) {
											 TGGroupMembersViewController *strongSelf = weakSelf;
											 if (!strongSelf)
												 return;
											 if ([rights isKindOfClass:NSDictionary.class])
												 strongSelf.myRights = rights;
											 if ([status isKindOfClass:NSString.class])
												 strongSelf.myStatus = status;
											 [strongSelf updateManageButton];
										 }];
}

- (void)observeChatMemberUpdates {
	__weak typeof(self) weakSelf = self;
	self.chatMemberObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatMemberDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGGroupMembersViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					if (![note.object isEqual:@(strongSelf.chatId)])
						return;
					int64_t userId = [note.userInfo[TGChatMemberUserIdKey] longLongValue];
					if (!userId)
						return;
					[strongSelf refreshRowForUser:userId];
				}];

	self.userStatusObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGUserStatusDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGGroupMembersViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					int64_t userId = [note.userInfo[@"userId"] longLongValue];
					if (!userId || [strongSelf rowIndexForUser:userId] < 0)
						return;
					[strongSelf refreshRowForUser:userId];
				}];
}

#pragma mark - manage menu

- (BOOL)isSupergroup {
	return [[self.groupInfo objectForKey:@"isSupergroup"] boolValue];
}

- (NSInteger)pendingJoinRequestCount {
	return TGMembersInteger(self.groupInfo, @"pendingJoinRequests");
}

- (NSArray *)availableManageActions {
	if (![self.groupInfo isKindOfClass:NSDictionary.class])
		return [NSArray array];

	NSMutableArray *actions = [NSMutableArray array];
	if ([self iMay:@"can_invite_users"])
		[actions addObject:@"addMembers"];
	if ([self isSupergroup] && [self iMay:@"can_restrict_members"])
		[actions addObject:@"defaultPermissions"];
	if ([self isSupergroup] && [self iMay:@"can_change_info"])
		[actions addObject:@"publicLink"];
	if (![self isSupergroup] && [self.myStatus isEqualToString:@"creator"])
		[actions addObject:@"upgrade"];
	return actions;
}

- (NSString *)titleForManageAction:(NSString *)action {
	if ([action isEqualToString:@"addMembers"])
		return TGL(@"Group.Members.AddMembers", @"Add Members");
	if ([action isEqualToString:@"defaultPermissions"])
		return TGL(@"GroupInfo.Permissions", @"Permissions");
	if ([action isEqualToString:@"publicLink"]) {
		NSString *current = TGMembersString(self.groupInfo, @"editableUsername");
		return current.length
			? [NSString stringWithFormat:TGL(@"Group.PublicLinkWithUsername", @"Public Link (t.me/%@)"), current]
			: TGL(@"GroupInfo.PublicLink", @"Public Link");
	}
	return TGL(@"GroupInfo.ConvertToSupergroup", @"Convert to Supergroup");
}

- (void)updateManageButton {
	_manageActions = [self availableManageActions];
	if (_manageActions.count == 0) {
		self.navigationItem.rightBarButtonItem = nil;
		return;
	}
	if (self.navigationItem.rightBarButtonItem)
		return;
	self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Media.LimitedAccessManage", @"Manage") bold:NO
									   target:self
									   action:@selector(showManageMenu)];
}

- (void)showManageMenu {
	NSArray *actions = [self availableManageActions];
	if (actions.count == 0)
		return;
	_manageActions = actions;

	[self.searchBar resignFirstResponder];
	NSMutableArray *otherTitles = [NSMutableArray array];
	for (NSString *action in actions)
		[otherTitles addObject:[self titleForManageAction:action]];
	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:nil
					  delegate:self
				   otherTitles:otherTitles
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	sheet.tag = 2;
	[sheet tg_showFromBarButtonItem:self.navigationItem.rightBarButtonItem inView:self.navigationController.view ?: self.view];
}

- (void)performManageAction:(NSString *)action {
	__weak typeof(self) weakSelf = self;
	if ([action isEqualToString:@"addMembers"]) {
		TGGroupAddMembersViewController *picker =
			[[TGGroupAddMembersViewController alloc] initWithChatId:self.chatId];
		picker.onAdded = ^{
			TGGroupMembersViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[strongSelf loadGroupInfo];
			[strongSelf reload];
		};
		[self.navigationController pushViewController:picker animated:YES];
		return;
	}
	if ([action isEqualToString:@"defaultPermissions"]) {
		TGMemberRightsViewController *editor = [[TGMemberRightsViewController alloc]
			initWithDefaultPermissionsOfChat:self.chatId];
		[self.navigationController pushViewController:editor animated:YES];
		return;
	}
	if ([action isEqualToString:@"publicLink"]) {
		TGGroupPublicLinkViewController *editor = [[TGGroupPublicLinkViewController alloc]
			initWithChatId:self.chatId
				  username:TGMembersString(self.groupInfo, @"editableUsername")
				 isChannel:[[self.groupInfo objectForKey:@"isChannel"] boolValue]];
		editor.onChanged = ^{
			TGGroupMembersViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[strongSelf loadGroupInfo];
		};
		[self.navigationController pushViewController:editor animated:YES];
		return;
	}
	if ([action isEqualToString:@"upgrade"]) {
		[self confirm:TGL(@"Group.UpgradeConfirmation", @"Warning: this action is irreversible. It is not possible to downgrade a supergroup to a regular group.")
					 ok:TGL(@"Gift.Upgrade.Upgrade", @"Upgrade")
			destructive:YES run:^{
				TGGroupMembersViewController *strongSelf = weakSelf;
				if (!strongSelf)
					return;
				[strongSelf upgradeToSupergroupThen:nil];
			}];
		return;
	}
}

- (void)upgradeToSupergroupThen:(void (^)(void))then {
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client upgradeBasicGroupToSupergroup:self.chatId
							   completion:^(int64_t newChatId) {
								   TGGroupMembersViewController *strongSelf = weakSelf;
								   if (!strongSelf)
									   return;
								   if (newChatId == 0) {
									   [[[UIAlertView alloc] initWithTitle:nil
																	message:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")
																   delegate:nil
														  cancelButtonTitle:TGL(@"Common.OK", @"OK")
														  otherButtonTitles:nil] show];
									   return;
								   }
								   strongSelf.chatId = newChatId;
								   strongSelf.groupInfo = nil;
								   if (strongSelf.onChatUpgraded)
									   strongSelf.onChatUpgraded(newChatId);
								   [client groupInfoForChat:newChatId completion:^(NSDictionary *info) {
									   TGGroupMembersViewController *innerSelf = weakSelf;
									   if (!innerSelf)
										   return;
									   if ([info isKindOfClass:NSDictionary.class]) {
										   innerSelf.groupInfo = info;
										   [innerSelf updateTitle];
									   }
									   [client myAdministratorRightsInGroup:newChatId completion:^(NSDictionary *rights, NSString *status) {
										   TGGroupMembersViewController *last = weakSelf;
										   if (!last)
											   return;
										   if ([rights isKindOfClass:NSDictionary.class])
											   last.myRights = rights;
										   if ([status isKindOfClass:NSString.class])
											   last.myStatus = status;
										   [last updateManageButton];
										   [last reload];
										   if (then)
											   then();
									   }];
								   }];
							   }];
}

- (BOOL)iMay:(NSString *)right {
	if ([self.myStatus isEqualToString:@"creator"])
		return YES;
	if (![self.myRights isKindOfClass:NSDictionary.class])
		return NO;
	return [[self.myRights objectForKey:right] boolValue];
}

- (void)updateTitle {
	NSInteger count = TGMembersInteger(self.groupInfo, @"memberCount");
	NSArray *titles = [self modeTitles];
	if (self.mode < 0 || self.mode >= (NSInteger)titles.count)
		self.mode = 0;
	if (self.mode == 0 && count > 0)
		self.title = TGLPlural(@"Conversation.StatusMembers", count, @"1 member", @"%@ members");
	else
		self.title = [titles objectAtIndex:(NSUInteger)self.mode];
}

- (void)setUpAvatarPrefetcher {
	self.avatarPrefetcher = [[TGAvatarPrefetcher alloc] initWithAvatarSide:kMemberAvatar
															 prefetchMargin:kMemberPhotoPrefetchRows
															   retainMargin:kMemberPhotoRetainRows];
	__weak typeof(self) weakSelf = self;
	self.avatarPrefetcher.rowCountProvider = ^NSInteger{
		return (NSInteger)[weakSelf rows].count;
	};
	self.avatarPrefetcher.rowKeyProvider = ^NSNumber *(NSInteger row) {
		TGGroupMembersViewController *strongSelf = weakSelf;
		NSArray *rows = [strongSelf rows];
		if (!strongSelf || row < 0 || row >= (NSInteger)rows.count)
			return nil;
		NSDictionary *member = [rows objectAtIndex:(NSUInteger)row];
		if (![member isKindOfClass:NSDictionary.class])
			return nil;
		int64_t userId = TGMembersUserId(member);
		return userId != 0 ? [NSNumber numberWithLongLong:userId] : nil;
	};
	self.avatarPrefetcher.fileIdProvider = ^NSNumber *(int64_t userId) {
		return [[TGClient shared] photoFileIdForUserId:userId];
	};
	self.avatarPrefetcher.downloadProvider = ^(int64_t fileId, void (^completion)(NSString *path)) {
		[[TGClient shared] downloadFile:fileId completion:completion];
	};
	self.avatarPrefetcher.photosChangedHandler = ^(NSNumber *key) {
		[weakSelf refreshVisibleRowsForMemberKey:key];
	};
	self.avatarPrefetcher.evictionSkipHandler = ^BOOL{
		TGGroupMembersViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return YES;
		if (!strongSelf.avatarPrefetcher.photos.count || strongSelf.searchResults)
			return YES;
		if (![strongSelf.tableView indexPathsForVisibleRows].count)
			return YES;
		return NO;
	};
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	[self.avatarPrefetcher evictPhotosOutsideRows:0];
}

- (void)reload {
	self.generation++;
	NSInteger generation = self.generation;
	self.loaded = NO;
	self.failed = NO;
	self.loading = YES;
	self.loadingMore = NO;
	self.totalCount = 0;
	self.members = [NSArray array];
	self.searchResults = nil;
	[self.tableView reloadData];
	[self updateStatusView];
	[self updateTitle];

	if ([self hasSearchQuery]) {
		[self runSearch];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] membersInGroup:self.chatId
							   filter:[self listFilterForMode:self.mode]
							   offset:0
								limit:kMemberPageSize
						   completion:^(NSArray *members, NSInteger totalCount) {
							   TGGroupMembersViewController *strongSelf = weakSelf;
							   if (!strongSelf || strongSelf.generation != generation)
								   return;
							   strongSelf.loading = NO;
							   if (![members isKindOfClass:NSArray.class]) {
								   strongSelf.failed = YES;
								   [strongSelf updateStatusView];
								   return;
							   }
							   strongSelf.loaded = YES;
							   strongSelf.members = members;
							   strongSelf.totalCount = totalCount;
							   [strongSelf.tableView reloadData];
							   [strongSelf updateStatusView];
							   [strongSelf.avatarPrefetcher fetchPhotosForRows];
						   }];
}

- (void)loadMore {
	if (self.loadingMore || self.loading || [self hasSearchQuery])
		return;
	if (self.totalCount <= (NSInteger)self.members.count)
		return;

	self.loadingMore = YES;
	NSInteger generation = self.generation;
	NSInteger offset = (NSInteger)self.members.count;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] membersInGroup:self.chatId
							   filter:[self listFilterForMode:self.mode]
							   offset:offset
								limit:kMemberPageSize
						   completion:^(NSArray *members, NSInteger totalCount) {
							   TGGroupMembersViewController *strongSelf = weakSelf;
							   if (!strongSelf || strongSelf.generation != generation)
								   return;
							   strongSelf.loadingMore = NO;
							   if (![members isKindOfClass:NSArray.class])
								   return;
							   if (members.count == 0) {
								   strongSelf.totalCount = (NSInteger)strongSelf.members.count;
								   [strongSelf.tableView reloadData];
								   return;
							   }
							   NSMutableArray *combined = [strongSelf.members mutableCopy];
							   [combined addObjectsFromArray:members];
							   strongSelf.members = combined;
							   strongSelf.totalCount = totalCount;
							   [strongSelf.tableView reloadData];
							   [strongSelf.avatarPrefetcher fetchPhotosForRows];
						   }];
}

- (void)restoreListAfterSearch {
	self.searchResults = nil;
	if (self.loading) {
		[self.tableView reloadData];
		[self updateStatusView];
		return;
	}
	if (self.members.count == 0) {
		[self reload];
		return;
	}
	[self.tableView reloadData];
	[self updateStatusView];
}

- (void)runSearch {
	NSString *text = [self.query stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!text.length) {
		[self restoreListAfterSearch];
		return;
	}

	NSInteger generation = self.generation;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] searchMembersInGroup:self.chatId
									  query:text
									 filter:[self searchFilterForMode:self.mode]
									  limit:kMemberPageSize
								 completion:^(NSArray *members, BOOL failed) {
									 TGGroupMembersViewController *strongSelf = weakSelf;
									 if (!strongSelf || strongSelf.generation != generation)
										 return;
									 strongSelf.loading = NO;
									 strongSelf.loaded = YES;
									 strongSelf.failed = failed;
									 strongSelf.searchResults = [members isKindOfClass:NSArray.class] ? members : [NSArray array];
									 [strongSelf.tableView reloadData];
									 [strongSelf updateStatusView];
									 [strongSelf.avatarPrefetcher fetchPhotosForRows];
								 }];
}

- (void)layoutEmptyPlaceholderWithTitle:(NSString *)title help:(NSString *)help {
	CGFloat width = self.emptyPlaceholder.bounds.size.width;
	self.emptyTitleLabel.text = title;
	CGSize titleSize = [title sizeWithFont:self.emptyTitleLabel.font];
	self.emptyTitleLabel.frame = CGRectMake(0, 0, width, titleSize.height);

	self.emptyHelpLabel.text = help;
	CGSize helpSize = [help sizeWithFont:self.emptyHelpLabel.font
					   constrainedToSize:CGSizeMake(260, 1000)
						   lineBreakMode:NSLineBreakByWordWrapping];
	self.emptyHelpLabel.frame = CGRectMake((CGFloat)(int)((width - 260) / 2), 26,
		260, helpSize.height);

	CGFloat totalHeight = 26 + helpSize.height;
	UIView *host = self.emptyPlaceholder.superview;
	CGFloat hostHeight = host ? host.bounds.size.height : totalHeight;
	CGRect frame = self.emptyPlaceholder.frame;
	frame.size.height = totalHeight;
	frame.origin.y = (CGFloat)(int)((hostHeight - totalHeight) / 2) - 40;
	if (frame.origin.y < 0)
		frame.origin.y = 0;
	self.emptyPlaceholder.frame = frame;
}

- (void)updateStatusView {
	if (self.loading) {
		[self.spinner startAnimating];
		self.statusLabel.text = TGL(@"Channel.NotificationLoading", @"Loading…");
		self.statusLabel.hidden = NO;
		self.emptyPlaceholder.hidden = YES;
		self.retryButton.hidden = YES;
		return;
	}
	[self.spinner stopAnimating];

	self.retryButton.hidden = YES;
	self.statusLabel.hidden = YES;

	NSArray *rows = [self rows];
	if (TGListShowsLoadFailureNotice(self.failed, rows.count)) {
		self.statusLabel.text = TGL(@"Group.Members.LoadFailed", @"The member list could not be loaded.");
		self.statusLabel.hidden = NO;
		self.retryButton.hidden = NO;
		self.emptyPlaceholder.hidden = YES;
		return;
	}
	if (rows.count == 0 && self.loaded) {
		if ([self hasSearchQuery])
			[self layoutEmptyPlaceholderWithTitle:TGL(@"ChatList.Search.NoResults", @"No Results")
											 help:TGL(@"Contacts.Search.NoResults", @"No contact or Telegram user matches that name.")];
		else
			[self layoutEmptyPlaceholderWithTitle:[self emptyTextForMode:self.mode]
											 help:[self emptyHelpForMode:self.mode]];
		self.emptyPlaceholder.hidden = NO;
		return;
	}
	self.emptyPlaceholder.hidden = YES;
}

#pragma mark - photos

- (NSArray *)rows {
	if (self.searchResults)
		return self.searchResults;
	return self.members ?: [NSArray array];
}

- (NSDictionary *)memberAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *rows = [self rows];
	if (indexPath.row < 0 || indexPath.row >= (NSInteger)rows.count)
		return nil;
	NSDictionary *member = [rows objectAtIndex:(NSUInteger)indexPath.row];
	return [member isKindOfClass:NSDictionary.class] ? member : nil;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	[self.avatarPrefetcher fetchPhotosForRowsThrottled];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	if (!decelerate)
		[self.avatarPrefetcher fetchPhotosForRows];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	[self.avatarPrefetcher fetchPhotosForRows];
}

- (void)reloadTableSoon {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(reloadTableNow)
											   object:nil];
	[self performSelector:@selector(reloadTableNow) withObject:nil afterDelay:0.15f];
}

- (void)reloadTableNow {
	[self.tableView reloadData];
}

#pragma mark - row text

- (NSString *)statusTextForMember:(NSDictionary *)member {
	return TGMembersStatusText(member);
}

@end

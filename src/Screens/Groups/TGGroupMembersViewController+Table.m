#import "TGClient+Contacts.h"
#import "TGStringTruncation.h"
#import "TGGroupMembersViewController.h"
#import "TGGroupMembersViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGClient+Groups.h"
#import "TGClient+Privacy.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGPopupMenu.h"
#import "TGAlertView.h"
#import "TGImageDecode.h"
#import "TGProfileViewController.h"
#import "TGPrivacyViewController.h"
#import "UIView+SafeTint.h"
#import <QuartzCore/QuartzCore.h>
#import "TGMemberRightsViewController.h"
#import "TGGroupAddMembersViewController.h"
#import "TGGroupPublicLinkViewController.h"
#import "TGGroupMemberCell.h"
#import "TGOwnershipTransferWaitText.h"

@implementation TGGroupMembersViewController (Table)

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)[self rows].count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return kGroupMemberRowHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [self rows].count == 0 ? 0.0f : kSectionHeaderHeight;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	if ([self rows].count == 0)
		return nil;

	CGFloat width = tableView.bounds.size.width;
	UIView *container = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, width, kSectionHeaderHeight)];
	container.clipsToBounds = NO;
	container.backgroundColor = [UIColor clearColor];

	UIImage *plate = [UIImage imageNamed:@"CategoryDividerFirst.png"];
	BOOL plated = plate != nil;
	if (plated) {
		UIImageView *plateView = [[UIImageView alloc] initWithImage:plate];
		plateView.frame = CGRectMake(0, -1, width, kSectionHeaderHeight + 1);
		plateView.autoresizingMask =
			UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[container addSubview:plateView];
	} else {
		container.backgroundColor = [[TGTheme shared] inputBarColour];
	}

	UILabel *caption = [[UILabel alloc] initWithFrame:CGRectZero];
	caption.backgroundColor = [UIColor clearColor];
	caption.font = [UIFont boldSystemFontOfSize:15];
	caption.textColor = plated ? [UIColor whiteColor] : [[TGTheme shared] secondaryTextColour];
	if (plated) {
		caption.shadowColor = [UIColor colorWithRed:0x88 / 255.0f green:0x92 / 255.0f
											   blue:0x9c / 255.0f
											  alpha:1.0f];
		caption.shadowOffset = CGSizeMake(0, -1);
	}
	caption.text = [self sectionCaptionForMode:self.mode];
	[caption sizeToFit];
	caption.frame = CGRectOffset(caption.frame, 10, 1);
	[container addSubview:caption];

	return container;
}

- (void)syncMembersPresenterIfNeeded {
	NSArray *rows = [self rows];
	if (rows == _presenterRowsSnapshot)
		return;
	_presenterRowsSnapshot = rows;
	[_presenter updateWithMembers:rows];
}

- (UIImage *)groupMembersRowBridge:(TGGroupMembersRowBridge *)bridge avatarForUserId:(long long)userId {
	return [self.avatarPrefetcher.photos objectForKey:[NSNumber numberWithLongLong:userId]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	[self syncMembersPresenterIfNeeded];
	if ([_rowBridge ownsRowAtIndex:indexPath.row]) {
		if (indexPath.row + 5 >= (NSInteger)[self rows].count)
			[self loadMore];
		return [_rowBridge cellForRow:indexPath.row inTable:tableView];
	}

	static NSString *reuse = @"TGGroupMemberCell";
	TGGroupMemberCell *cell = (TGGroupMemberCell *)
		[tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGGroupMemberCell alloc] initWithStyle:UITableViewCellStyleDefault
										reuseIdentifier:reuse];

	NSDictionary *member = [self memberAtIndexPath:indexPath];
	if (!member) {
		[cell setName:@""];
		cell.subtitleLabel.text = @"";
		cell.roleLabel.text = @"";
		cell.subtitleIsOnline = NO;
		cell.avatarView.image = nil;
		return cell;
	}

	NSString *name = TGMembersString(member, @"name");
	if (!name.length)
		name = TGL(@"Contacts.UnknownName", @"Unknown");
	[cell setName:name];
	cell.subtitleLabel.text = [self statusTextForMember:member];
	cell.roleLabel.text = TGMembersRoleText(member) ?: @"";
	cell.subtitleIsOnline = TGMembersStatusIsOnline(member);

	int64_t userId = TGMembersUserId(member);
	NSNumber *key = [NSNumber numberWithLongLong:userId];
	UIImage *photo = [self.avatarPrefetcher.photos objectForKey:key];
	if (!photo)
		photo = [TGIcons avatarWithInitials:TGSafeFirstCharacter(name).uppercaseString
									   size:kMemberAvatar
								   colourId:userId];
	cell.avatarView.image = photo;
	[cell setNeedsLayout];

	if (indexPath.row + 5 >= (NSInteger)[self rows].count)
		[self loadMore];

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSDictionary *member = [self memberAtIndexPath:indexPath];
	if (!member)
		return;
	if ([[member objectForKey:@"isChat"] boolValue])
		return;
	int64_t userId = TGMembersUserId(member);
	if (userId == 0)
		return;
	NSString *name = TGMembersString(member, @"name");

	[self.searchBar resignFirstResponder];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] privateChatWithUser:userId completion:^(int64_t chatId) {
		TGGroupMembersViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[TGProfileViewController showProfileForChatId:chatId
											   userId:userId
												title:name
										 inNavigation:strongSelf.navigationController];
	}];
}

#pragma mark - long press menu

- (void)handleLongPress:(UILongPressGestureRecognizer *)recogniser {
	if (recogniser.state != UIGestureRecognizerStateBegan)
		return;

	CGPoint point = [recogniser locationInView:self.tableView];
	NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
	if (!indexPath)
		return;
	NSDictionary *member = [self memberAtIndexPath:indexPath];
	if (!member)
		return;

	NSArray *actions = [self actionsForMember:member];
	if (actions.count == 0)
		return;

	[self.searchBar resignFirstResponder];

	NSMutableArray *items = [NSMutableArray array];
	for (NSString *action in actions)
		[items addObject:[self menuItemForAction:action]];

	UIView *host = self.navigationController.view ?: self.view;
	CGPoint hostPoint = [self.tableView convertPoint:point toView:host];
	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:hostPoint inView:host
				  onChoice:^(NSInteger index, NSString *title) {
					  TGGroupMembersViewController *strongSelf = weakSelf;
					  if (!strongSelf || index < 0 || index >= (NSInteger)actions.count)
						  return;
					  [strongSelf performAction:[actions objectAtIndex:(NSUInteger)index] onMember:member];
				  }];
}

- (NSDictionary *)menuItemForAction:(NSString *)action {
	if ([action isEqualToString:@"promote"])
		return [NSDictionary dictionaryWithObjectsAndKeys:
				TGL(@"GroupMembers.ActionPromoteToAdmin", @"Promote to Admin"), @"title",
			@"edit", @"icon", nil];
	if ([action isEqualToString:@"editRights"])
		return [NSDictionary dictionaryWithObjectsAndKeys:
				TGL(@"GroupInfo.ActionEditAdmin", @"Edit Admin Rights"), @"title",
			@"edit", @"icon", nil];
	if ([action isEqualToString:@"editRestrictions"])
		return [NSDictionary dictionaryWithObjectsAndKeys:
				TGL(@"GroupMembers.ActionEditRestrictions", @"Edit Restrictions"), @"title",
			@"edit", @"icon", nil];
	if ([action isEqualToString:@"dismiss"])
		return [NSDictionary dictionaryWithObjectsAndKeys:
				TGL(@"Channel.Moderator.AccessLevelRevoke", @"Dismiss Admin"), @"title",
			@"edit", @"icon", nil];
	if ([action isEqualToString:@"transferOwnership"])
		return [NSDictionary dictionaryWithObjectsAndKeys:
				TGL(@"GroupMembers.ActionTransferOwnership", @"Transfer Ownership"), @"title",
			@"edit", @"icon",
			[NSNumber numberWithBool:YES], @"destructive", nil];
	if ([action isEqualToString:@"restrict"])
		return [NSDictionary dictionaryWithObjectsAndKeys:
				TGL(@"GroupInfo.ActionRestrict", @"Restrict"), @"title", @"mute", @"icon", nil];
	if ([action isEqualToString:@"unrestrict"])
		return [NSDictionary dictionaryWithObjectsAndKeys:
				TGL(@"GroupMembers.ActionLiftRestrictions", @"Lift Restrictions"), @"title",
			@"unmute", @"icon", nil];
	if ([action isEqualToString:@"unban"])
		return [NSDictionary dictionaryWithObjectsAndKeys:
				TGL(@"Channel.BanUser.Unban", @"Unban"), @"title", @"unmute", @"icon", nil];
	if ([action isEqualToString:@"ban"])
		return [NSDictionary dictionaryWithObjectsAndKeys:
				TGL(@"Conversation.ContextMenuBanFull", @"Ban"), @"title", @"delete", @"icon",
			[NSNumber numberWithBool:YES], @"destructive", nil];
	if ([action isEqualToString:@"deleteMessages"])
		return [NSDictionary dictionaryWithObjectsAndKeys:
				TGL(@"Chat.AdminActionSheet.DeleteAllMessages", @"Delete All Messages"), @"title",
			@"delete", @"icon",
			[NSNumber numberWithBool:YES], @"destructive", nil];
	return [NSDictionary dictionaryWithObjectsAndKeys:
			TGL(@"GroupMembers.ActionRemoveFromGroup", @"Remove from Group"), @"title",
		@"delete", @"icon",
		[NSNumber numberWithBool:YES], @"destructive", nil];
}

- (NSArray *)actionsForMember:(NSDictionary *)member {
	NSString *status = TGMembersString(member, @"status");
	BOOL canEdit = [[member objectForKey:@"canBeEdited"] boolValue];
	BOOL isOwner = [[member objectForKey:@"isOwner"] boolValue];
	int64_t userId = TGMembersUserId(member);

	if ([[member objectForKey:@"isChat"] boolValue])
		return [NSArray array];
	if (isOwner || [status isEqualToString:@"creator"])
		return [NSArray array];
	if (userId == 0)
		return [NSArray array];

	NSMutableArray *actions = [NSMutableArray array];
	BOOL mayRestrict = [self iMay:@"can_restrict_members"];
	BOOL mayPromote = [self iMay:@"can_promote_members"];
	BOOL mayDelete = [self iMay:@"can_delete_messages"];

	if ([status isEqualToString:@"banned"]) {
		if (mayRestrict)
			[actions addObject:@"unban"];
		if (mayDelete)
			[actions addObject:@"deleteMessages"];
		return actions;
	}

	if ([status isEqualToString:@"restricted"]) {
		if (mayRestrict) {
			[actions addObject:@"editRestrictions"];
			[actions addObject:@"unrestrict"];
			[actions addObject:@"ban"];
		}
		return actions;
	}

	if ([status isEqualToString:@"administrator"]) {
		if (canEdit && mayPromote) {
			[actions addObject:@"editRights"];
			[actions addObject:@"dismiss"];
		}
		if ([self.myStatus isEqualToString:@"creator"])
			[actions addObject:@"transferOwnership"];
		if (mayRestrict && canEdit)
			[actions addObject:@"remove"];
		return actions;
	}

	if (mayPromote)
		[actions addObject:@"promote"];
	if (mayRestrict) {
		[actions addObject:@"restrict"];
		[actions addObject:@"ban"];
		[actions addObject:@"remove"];
	}
	return actions;
}

- (BOOL)actionNeedsSupergroup:(NSString *)action {
	if (![self.groupInfo isKindOfClass:NSDictionary.class] || [self isSupergroup])
		return NO;
	return [action isEqualToString:@"restrict"] || [action isEqualToString:@"editRestrictions"] || [action isEqualToString:@"unrestrict"];
}

- (void)openRightsEditorForUser:(int64_t)userId name:(NSString *)name
					restricting:(BOOL)restricting {
	TGMemberRightsViewController *editor = [[TGMemberRightsViewController alloc]
		initWithChatId:self.chatId
				userId:userId
				  name:name
		   restricting:restricting];
	editor.basicGroupAdmin = !restricting && ![self isSupergroup];
	__weak typeof(self) weakSelf = self;
	editor.onSaved = ^{
		TGGroupMembersViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf refreshRowForUser:userId];
		[strongSelf loadGroupInfo];
	};
	if (!restricting && [self.myStatus isEqualToString:@"creator"]) {
		editor.canTransferOwnership = YES;
		editor.onTransferOwnership = ^{
			TGGroupMembersViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[strongSelf.navigationController popToViewController:strongSelf animated:YES];
			[strongSelf beginTransferOwnershipToUser:userId name:name];
		};
	}
	[self.navigationController pushViewController:editor animated:YES];
}

- (void)openBanScreenForUser:(int64_t)userId name:(NSString *)name {
	TGMemberRightsViewController *editor = [[TGMemberRightsViewController alloc]
		initForBanningWithChatId:self.chatId
						   userId:userId
							 name:name];
	__weak typeof(self) weakSelf = self;
	editor.onSaved = ^{
		TGGroupMembersViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf refreshRowForUser:userId];
		[strongSelf loadGroupInfo];
	};
	[self.navigationController pushViewController:editor animated:YES];
}

- (void)performAction:(NSString *)action onMember:(NSDictionary *)member {
	int64_t userId = TGMembersUserId(member);
	NSString *name = TGMembersString(member, @"name");
	if (!name.length)
		name = TGL(@"GroupMembers.FallbackName", @"this user");
	__weak typeof(self) weakSelf = self;

	if ([self actionNeedsSupergroup:action]) {
		if (![self.myStatus isEqualToString:@"creator"]) {
			[[[UIAlertView alloc] initWithTitle:nil
										message:TGL(@"GroupMembers.RequiresSupergroupUpgrade", @"This action requires the group to be a supergroup. Ask the group owner to upgrade it.")
									   delegate:nil
							  cancelButtonTitle:TGL(@"Common.OK", @"OK")
							  otherButtonTitles:nil] show];
			return;
		}
		[self confirm:TGL(@"Group.UpgradeConfirmation", @"Warning: this action is irreversible. It is not possible to downgrade a supergroup to a regular group.")
					 ok:TGL(@"Gift.Upgrade.Upgrade", @"Upgrade")
			destructive:YES run:^{
				TGGroupMembersViewController *strongSelf = weakSelf;
				if (!strongSelf)
					return;
				[strongSelf upgradeToSupergroupThen:^{
					TGGroupMembersViewController *innerSelf = weakSelf;
					if (!innerSelf)
						return;
					[innerSelf performAction:action onMember:member];
				}];
			}];
		return;
	}

	if ([action isEqualToString:@"promote"] || [action isEqualToString:@"editRights"]) {
		[self openRightsEditorForUser:userId name:name restricting:NO];
		return;
	}
	if ([action isEqualToString:@"editRestrictions"]) {
		[self openRightsEditorForUser:userId name:name restricting:YES];
		return;
	}
	if ([action isEqualToString:@"dismiss"]) {
		[self confirm:[NSString stringWithFormat:TGL(@"GroupMembers.ConfirmDismissAdmin", @"Dismiss %@ as administrator?"), name]
					 ok:TGL(@"Channel.Management.DismissAdmin", @"Dismiss")
			destructive:NO run:^{
				TGGroupMembersViewController *strongSelf = weakSelf;
				if (!strongSelf)
					return;
				[strongSelf runDismiss:userId];
			}];
		return;
	}
	if ([action isEqualToString:@"restrict"]) {
		[self openRightsEditorForUser:userId name:name restricting:YES];
		return;
	}
	if ([action isEqualToString:@"unrestrict"]) {
		[self runUnrestrict:userId];
		return;
	}
	if ([action isEqualToString:@"unban"]) {
		[self runUnban:userId];
		return;
	}
	if ([action isEqualToString:@"transferOwnership"]) {
		[self beginTransferOwnershipToUser:userId name:name];
		return;
	}
	if ([action isEqualToString:@"ban"]) {
		[self openBanScreenForUser:userId name:name];
		return;
	}
	if ([action isEqualToString:@"deleteMessages"]) {
		[self confirm:[NSString stringWithFormat:TGL(@"GroupMembers.ConfirmDeleteMessages", @"Delete every message %@ has sent here?"), name]
					 ok:TGL(@"Common.Delete", @"Delete")
			destructive:YES run:^{
				TGGroupMembersViewController *strongSelf = weakSelf;
				if (!strongSelf)
					return;
				[strongSelf runDeleteMessages:userId];
			}];
		return;
	}

	[self confirm:[NSString stringWithFormat:TGL(@"GroupMembers.ConfirmRemove", @"Remove %@ from this group?"), name]
				 ok:TGL(@"Appearance.RemoveTheme", @"Remove")
		destructive:YES run:^{
			TGGroupMembersViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[strongSelf runRemove:userId];
		}];
}

- (void)presentTwoStepVerificationRequirement {
	__weak typeof(self) weakSelf = self;
	NSString *requirements = TGL(@"OwnershipTransfer.SecurityRequirements", @"Ownership transfers are available if:\n\n• 2-Step verification was enabled for your account more than 7 days ago.\n\n• You have logged in on this device more than 24 hours ago.");
	TGAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"OwnershipTransfer.SecurityCheck", @"Security Check")
				  message:requirements
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			okButtonTitle:TGL(@"OwnershipTransfer.SetupTwoStepAuth", @"Enable 2-Step Verification")
		  completionBlock:^(bool okPressed) {
			  TGGroupMembersViewController *strongSelf = weakSelf;
			  if (!okPressed || !strongSelf)
				  return;
			  [strongSelf.navigationController pushViewController:[[TGTwoStepViewController alloc] init]
												 animated:YES];
		  }];
	[alert show];
}

- (void)confirm:(NSString *)message ok:(NSString *)ok destructive:(BOOL)destructive
			run:(void (^)(void))run {
	[self confirmWithTitle:nil message:message ok:ok destructive:destructive run:run];
}

- (void)confirmWithTitle:(NSString *)title
				 message:(NSString *)message
					  ok:(NSString *)ok
			 destructive:(BOOL)destructive
					 run:(void (^)(void))run {
	TGAlertView *alert = [[TGAlertView alloc]
			initWithTitle:title
				  message:message
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			okButtonTitle:ok
		  completionBlock:^(bool okPressed) {
			  if (okPressed && run)
				  run();
		  }];
	[alert show];
}

- (void)finishWithSuccess:(BOOL)ok failureText:(NSString *)failureText
				   userId:(int64_t)userId {
	if (!ok) {
		[[[UIAlertView alloc] initWithTitle:nil
									message:failureText
								   delegate:nil
						  cancelButtonTitle:TGL(@"Common.OK", @"OK")
						  otherButtonTitles:nil] show];
		return;
	}
	[self loadGroupInfo];
	[self refreshRowForUser:userId];
}

- (NSInteger)rowIndexForUser:(int64_t)userId {
	NSArray *rows = [self rows];
	for (NSInteger i = 0; i < rows.count; i++) {
		NSDictionary *member = [rows objectAtIndex:i];
		if (![member isKindOfClass:NSDictionary.class])
			continue;
		if (TGMembersUserId(member) == userId)
			return (NSInteger)i;
	}
	return -1;
}

- (BOOL)status:(NSString *)status belongsToMode:(NSInteger)mode {
	switch (mode) {
		case 1:
			return [status isEqualToString:@"administrator"] || [status isEqualToString:@"creator"];
		case 2:
			return [status isEqualToString:@"banned"];
		case 3:
			return [status isEqualToString:@"restricted"];
		default:
			return ![status isEqualToString:@"banned"] && ![status isEqualToString:@"left"];
	}
}

- (void)replaceRowAtIndex:(NSInteger)index withMember:(NSDictionary *)member {
	NSMutableArray *rows = [[self rows] mutableCopy];
	if (index < 0 || index >= (NSInteger)rows.count)
		return;
	if (member)
		[rows replaceObjectAtIndex:(NSUInteger)index withObject:member];
	else
		[rows removeObjectAtIndex:(NSUInteger)index];

	if (self.searchResults)
		self.searchResults = rows;
	else {
		self.members = rows;
		if (!member && self.totalCount > 0)
			self.totalCount--;
	}

	NSArray *paths = [NSArray arrayWithObject:
			[NSIndexPath indexPathForRow:index inSection:0]];
	if (!member && rows.count == 0) {
		[self.tableView reloadData];
		[self updateStatusView];
		[self updateTitle];
		return;
	}
	if (member)
		[self.tableView reloadRowsAtIndexPaths:paths
							  withRowAnimation:UITableViewRowAnimationNone];
	else
		[self.tableView deleteRowsAtIndexPaths:paths
							  withRowAnimation:UITableViewRowAnimationFade];
	[self updateStatusView];
	[self updateTitle];
}

- (void)refreshRowForUser:(int64_t)userId {
	NSInteger generation = self.generation;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] memberStatusOfUser:userId
								  inGroup:self.chatId
							   completion:^(NSDictionary *member) {
								   TGGroupMembersViewController *strongSelf = weakSelf;
								   if (!strongSelf || strongSelf.generation != generation)
									   return;
								   NSInteger index = [strongSelf rowIndexForUser:userId];
								   if (index < 0)
									   return;
								   if (![member isKindOfClass:NSDictionary.class]) {
									   [strongSelf replaceRowAtIndex:index withMember:nil];
									   return;
								   }
								   NSString *status = TGMembersString(member, @"status");
								   if (![strongSelf status:status belongsToMode:strongSelf.mode]) {
									   [strongSelf replaceRowAtIndex:index withMember:nil];
									   return;
								   }
								   [strongSelf replaceRowAtIndex:index withMember:member];
								   [strongSelf.avatarPrefetcher fetchPhotosForRows];
							   }];
}

- (void)runDismiss:(int64_t)userId {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] dismissAdmin:userId inGroup:self.chatId completion:^(BOOL ok) {
		TGGroupMembersViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf finishWithSuccess:ok
				  failureText:TGL(@"GroupMembers.CouldNotDismissAdministrator",
								  @"Could not dismiss this administrator.")
					   userId:userId];
	}];
}

- (void)runUnrestrict:(int64_t)userId {
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client defaultPermissionsInGroup:self.chatId
						   completion:^(NSDictionary *permissions) {
							   TGGroupMembersViewController *strongSelf = weakSelf;
							   if (!strongSelf)
								   return;
							   NSDictionary *restore = [permissions isKindOfClass:NSDictionary.class]
								   ? permissions
								   : [NSDictionary dictionary];
							   [client
								   restrictMember:userId
										  inGroup:strongSelf.chatId
									  permissions:restore
										untilDate:0
									   completion:^(BOOL ok) {
										   TGGroupMembersViewController *innerSelf = weakSelf;
										   if (!innerSelf)
											   return;
										   NSString *failure = TGL(@"GroupMembers.CouldNotLiftRestrictions",
																   @"Could not lift the restrictions.");
										   [innerSelf finishWithSuccess:ok failureText:failure userId:userId];
									   }];
						   }];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (actionSheet.tag != 2)
		return;
	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;
	if (buttonIndex < 0 || buttonIndex >= (NSInteger)_manageActions.count)
		return;
	[self performManageAction:[_manageActions objectAtIndex:(NSUInteger)buttonIndex]];
}

- (void)presentOwnershipTransferTooFreshAlert:(NSString *)reason retryAfterSeconds:(NSInteger)retryAfterSeconds {
	NSString *durationText = TGOwnershipTransferRetryDurationText(retryAfterSeconds);
	NSString *format = [reason isEqualToString:@"sessionTooFresh"]
		? TGL(@"OwnershipTransfer.SessionTooFreshFormat", @"This session was created too recently. Try again in %@.")
		: TGL(@"OwnershipTransfer.PasswordTooFreshFormat", @"Your 2-Step Verification password was set up too recently. Try again in %@.");
	UIAlertView *alert = [[UIAlertView alloc]
			initWithTitle:TGL(@"OwnershipTransfer.SecurityCheck", @"Security Check")
				  message:[NSString stringWithFormat:format, durationText]
				 delegate:nil
		cancelButtonTitle:TGL(@"Common.OK", @"OK")
		otherButtonTitles:nil];
	[alert show];
}

- (void)beginTransferOwnershipToUser:(int64_t)userId name:(NSString *)name {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] canTransferOwnershipWithCompletion:^(NSString *status, NSInteger retryAfterSeconds) {
		TGGroupMembersViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if ([status isEqualToString:@"passwordNeeded"]) {
			[strongSelf presentTwoStepVerificationRequirement];
			return;
		}
		if ([status isEqualToString:@"passwordTooFresh"] || [status isEqualToString:@"sessionTooFresh"]) {
			[strongSelf presentOwnershipTransferTooFreshAlert:status retryAfterSeconds:retryAfterSeconds];
			return;
		}
		NSString *group = [strongSelf.groupInfo[@"title"] isKindOfClass:NSString.class]
			? strongSelf.groupInfo[@"title"]
			: @"";
		NSString *description = [NSString stringWithFormat:
				TGL(@"Group.OwnershipTransfer.DescriptionInfo", @"This will transfer the full owner rights for %1$@ to %2$@.\n\nYou will no longer be considered the creator of the group. The new owner will be free to remove any of your admin privileges or even ban you."),
				group, name];
		[strongSelf confirmWithTitle:TGL(@"Group.OwnershipTransfer.Title", @"Transfer Group Ownership")
					 message:description
						  ok:TGL(@"Channel.OwnershipTransfer.ChangeOwner", @"Change Owner")
				 destructive:YES
						 run:^{
							 TGGroupMembersViewController *innerSelf = weakSelf;
							 if (!innerSelf)
								 return;
							 innerSelf->_pendingUserId = userId;
							 UIAlertView *prompt = [[TGAlertView alloc]
									 initWithTitle:TGL(@"Channel.OwnershipTransfer.EnterPassword", @"Enter Password")
										   message:TGL(@"Channel.OwnershipTransfer.EnterPasswordText", @"Please enter your 2-Step Verification password to complete the transfer.")
										  delegate:innerSelf
								 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
								 otherButtonTitles:TGL(@"OwnershipTransfer.Transfer", @"Transfer"), nil];
							 prompt.alertViewStyle = UIAlertViewStyleSecureTextInput;
							 [prompt show];
						 }];
	}];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex || _pendingUserId == 0)
		return;
	NSString *password = [[alertView textFieldAtIndex:0] text] ?: @"";
	int64_t userId = _pendingUserId;
	_pendingUserId = 0;
	if (!password.length)
		return;

	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client transferOwnershipOfGroup:self.chatId
							  toUser:userId
							password:password
						  completion:^(BOOL ok, NSString *errorMessage) {
							  TGGroupMembersViewController *strongSelf = weakSelf;
							  if (!strongSelf)
								  return;
							  if (!ok) {
								  NSString *message = errorMessage.length
									  ? errorMessage
									  : TGL(@"TwoStepAuth.EnterPasswordInvalid", @"Could not transfer this group. Check the password and try again.");
								  UIAlertView *alert = [[UIAlertView alloc]
										  initWithTitle:nil
												message:message
											   delegate:nil
									  cancelButtonTitle:TGL(@"Common.OK", @"OK")
									  otherButtonTitles:nil];
								  [alert show];
								  return;
							  }
							  strongSelf.myStatus = @"administrator";
							  [strongSelf loadGroupInfo];
							  [strongSelf reload];
						  }];
}

- (void)runUnban:(int64_t)userId {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] unbanMember:userId inGroup:self.chatId completion:^(BOOL ok) {
		TGGroupMembersViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf finishWithSuccess:ok
				  failureText:TGL(@"GroupMembers.CouldNotLiftThisBan", @"Could not lift this ban.")
					   userId:userId];
	}];
}

- (void)runRemove:(int64_t)userId {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] removeMember:userId fromGroup:self.chatId completion:^(BOOL ok) {
		TGGroupMembersViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf finishWithSuccess:ok
				  failureText:TGL(@"GroupMembers.CouldNotRemoveThisMember",
								  @"Could not remove this member.")
					   userId:userId];
	}];
}

- (void)runDeleteMessages:(int64_t)userId {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] deleteAllMessagesFromUser:userId inGroup:self.chatId completion:^(BOOL ok) {
		TGGroupMembersViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf finishWithSuccess:ok
				  failureText:TGL(@"GroupMembers.CouldNotDeleteMessages",
								  @"Could not delete these messages.")
					   userId:userId];
	}];
}

#pragma mark - search

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text {
	self.query = text;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runSearch)
											   object:nil];
	if (![self hasSearchQuery]) {
		[self restoreListAfterSearch];
		return;
	}
	[self performSelector:@selector(runSearch) withObject:nil afterDelay:0.3f];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:NO animated:YES];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	searchBar.text = @"";
	self.query = nil;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runSearch)
											   object:nil];
	[self restoreListAfterSearch];
	[searchBar resignFirstResponder];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	[self.searchBar resignFirstResponder];
	[TGPopupMenu dismiss];
}

@end

#import "TGContactsViewController.h"
#import "TGStringTruncation.h"
#import "TGContactsViewControllerInternal.h"
#import "TGContactPhotoMatch.h"
#import "TGFlatActionCell.h"
#import "TGContactRowCell.h"
#import "TGInviteFriendsViewController.h"
#import "TGChatViewController.h"
#import "TGContactsService.h"
#import "TGFileDownloadService.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGImageDecode.h"
#import "TGNewContactViewController.h"
#import "RootViewController.h"
#import "UIView+SafeTint.h"
#import "TGEmoji.h"
#import <QuartzCore/QuartzCore.h>
#import <AddressBook/AddressBook.h>
#import <dlfcn.h>
#import "TGAlertView.h"
#import "TGHexColour.h"

@implementation TGContactsViewController (TableView)

- (void)refreshVisibleRowsForUserId:(NSNumber *)userId {
	NSMutableArray *paths = [NSMutableArray array];
	for (NSIndexPath *path in [self.tableView indexPathsForVisibleRows])
		if (TGContactRowIsUserId([self userAtIndexPath:path], userId))
			[paths addObject:path];
	if (paths.count)
		[self.tableView reloadRowsAtIndexPaths:paths
							  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)refreshVisibleRowsForEmojiStatusFileId:(NSNumber *)fileId {
	NSMutableArray *paths = [NSMutableArray array];
	for (NSIndexPath *path in [self.tableView indexPathsForVisibleRows]) {
		NSDictionary *user = [self userAtIndexPath:path];
		NSNumber *userId = [user[@"id"] isKindOfClass:NSNumber.class] ? user[@"id"] : nil;
		NSDictionary *icon = userId ? self.emojiStatusIcons[userId] : nil;
		NSNumber *own = icon ? [self fileIdForEmojiStatusIcon:icon] : nil;
		if (own && [own longLongValue] == [fileId longLongValue])
			[paths addObject:path];
	}
	if (paths.count)
		[self.tableView reloadRowsAtIndexPaths:paths
							  withRowAnimation:UITableViewRowAnimationNone];
}

- (NSDictionary *)badgesForUser:(NSDictionary *)u {
	NSNumber *userId = [u[@"id"] isKindOfClass:NSNumber.class] ? u[@"id"] : nil;
	if (!userId)
		return nil;
	NSDictionary *cached = self.badges[userId];
	if (cached)
		return cached;
	if ([self.badgesRequested containsObject:userId])
		return nil;
	[self.badgesRequested addObject:userId];

	__weak typeof(self) weakSelf = self;
	[TGContactsService badgesForUser:userId.longLongValue
						  completion:^(NSDictionary *badges) {
							  TGContactsViewController *strongSelf = weakSelf;
							  if (!strongSelf)
								  return;
							  strongSelf.badges[userId] = [badges isKindOfClass:NSDictionary.class] ? badges : @{};
							  [strongSelf refreshVisibleRowsForUserId:userId];
						  }];
	return nil;
}

- (NSDictionary *)emojiStatusIconForUser:(NSDictionary *)u {
	NSNumber *userId = [u[@"id"] isKindOfClass:NSNumber.class] ? u[@"id"] : nil;
	if (!userId)
		return nil;
	NSDictionary *cached = self.emojiStatusIcons[userId];
	if (cached)
		return cached;
	if ([self.emojiStatusIconsRequested containsObject:userId])
		return nil;
	[self.emojiStatusIconsRequested addObject:userId];

	__weak typeof(self) weakSelf = self;
	[TGContactsService emojiStatusForUser:userId.longLongValue
								completion:^(NSDictionary *status) {
									TGContactsViewController *strongSelf = weakSelf;
									if (!strongSelf)
										return;
									strongSelf.emojiStatusIcons[userId] =
										[status isKindOfClass:NSDictionary.class] ? status : @{};
									[strongSelf refreshVisibleRowsForUserId:userId];
								}];
	return nil;
}

- (NSNumber *)fileIdForEmojiStatusIcon:(NSDictionary *)icon {
	NSNumber *thumb = [icon[@"thumbFileId"] isKindOfClass:NSNumber.class] ? icon[@"thumbFileId"] : nil;
	if (thumb)
		return thumb;
	return [icon[@"stickerFileId"] isKindOfClass:NSNumber.class] ? icon[@"stickerFileId"] : nil;
}

- (UIImage *)emojiStatusImageForIcon:(NSDictionary *)icon {
	NSNumber *fileId = [self fileIdForEmojiStatusIcon:icon];
	if (!fileId)
		return nil;
	UIImage *cached = [self.emojiStatusImages objectForKey:fileId];
	if (cached)
		return cached;
	if ([self.emojiStatusImagesRequested containsObject:fileId])
		return nil;
	[self.emojiStatusImagesRequested addObject:fileId];

	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:fileId.longLongValue completion:^(NSString *path) {
		if (!path.length)
			return;
		dispatch_async(TGImageDecodeQueue(), ^{
			UIImage *thumb = TGDecodeSquareThumbnail(path, kContactBadgeSide);
			dispatch_async(dispatch_get_main_queue(), ^{
				TGContactsViewController *strongSelf = weakSelf;
				if (!strongSelf || !thumb)
					return;
				[strongSelf.emojiStatusImages setObject:thumb forKey:fileId
													cost:TGContactPhotoCost(thumb)];
				[strongSelf refreshVisibleRowsForEmojiStatusFileId:fileId];
			});
		});
	}];
	return nil;
}

- (NSArray *)rowsForSection:(NSInteger)section {
	if (self.sections)
		return (section >= 0 && section < (NSInteger)self.sections.count)
			? self.sections[section]
			: @[];
	return self.filteredUsers ?: self.users;
}

- (NSDictionary *)userAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *rows = [self rowsForSection:indexPath.section];
	if (indexPath.row < 0 || indexPath.row >= (NSInteger)rows.count)
		return nil;
	id u = rows[indexPath.row];
	return [u isKindOfClass:NSDictionary.class] ? u : nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.sections ? self.sections.count : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [self rowsForSection:section].count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return [self actionIdentifierAtIndexPath:indexPath]
		? kContactActionRowHeight
		: kContactRowHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [self letterForSection:section] ? kContactSectionHeight : 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *letter = [self letterForSection:section];
	if (!letter)
		return nil;

	CGFloat width = tableView.bounds.size.width;
	BOOL first = (section == 0);
	if (!self.reusableSectionHeaders)
		self.reusableSectionHeaders = [NSMutableArray arrayWithObjects:
				[NSMutableArray array], [NSMutableArray array], nil];
	NSMutableArray *pool = [self.reusableSectionHeaders objectAtIndex:(first ? 0 : 1)];
	for (UIView *view in pool) {
		if (view.superview)
			continue;
		UILabel *existing = (UILabel *)[view viewWithTag:100];
		existing.text = letter;
		[existing sizeToFit];
		existing.frame = CGRectOffset(existing.frame, 10 - existing.frame.origin.x,
			1 - existing.frame.origin.y);
		return view;
	}

	UIView *container = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, width, kContactSectionHeight)];
	container.clipsToBounds = NO;
	container.backgroundColor = [UIColor clearColor];

	UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
	label.tag = 100;
	label.backgroundColor = [UIColor clearColor];
	label.font = [UIFont boldSystemFontOfSize:15];
	label.numberOfLines = 1;
	label.text = letter;

	UIImage *background = [UIImage imageNamed:
			(first ? @"CategoryDividerFirst" : @"CategoryDivider")];
	if (background) {
		UIImageView *backgroundView = [[UIImageView alloc] initWithImage:background];
		backgroundView.frame = CGRectMake(0, -1, width, kContactSectionHeight + 1);
		backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[container addSubview:backgroundView];
	} else {
		container.backgroundColor = TGColourFromHex(0xa8b0b8);
	}
	label.textColor = [UIColor whiteColor];
	label.shadowColor = TGColourFromHex(0x88929c);
	label.shadowOffset = CGSizeMake(0, -1);

	[label sizeToFit];
	label.frame = CGRectOffset(label.frame, 10, 1);
	[container addSubview:label];
	[pool addObject:container];
	return container;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
	if (!self.sectionTitles.count || self.filteredUsers || (self.sortByLastSeen && !self.pickerMode))
		return nil;
	NSMutableArray *indices = [NSMutableArray array];
	if (self.searchBar)
		[indices addObject:UITableViewIndexSearch];
	for (id title in self.sectionTitles) {
		if ([title isKindOfClass:NSString.class])
			[indices addObject:title];
	}
	return (indices.count > 10) ? indices : nil;
}

- (NSInteger)tableView:(UITableView *)tableView
	sectionForSectionIndexTitle:(NSString *)title
						atIndex:(NSInteger)index {
	if ([title isEqualToString:UITableViewIndexSearch]) {
		[tableView setContentOffset:CGPointMake(0, -tableView.contentInset.top) animated:NO];
		return -1;
	}
	for (NSInteger section = 0; section < self.sectionTitles.count; section++) {
		if ([self.sectionTitles[section] isEqual:title])
			return (NSInteger)section;
	}
	return 0;
}

- (UITableViewCell *)actionCellForTableView:(UITableView *)tableView identifier:(NSString *)action {
	static NSString *actionReuse = @"TGFlatActionCell";
	TGFlatActionCell *cell = (TGFlatActionCell *)
		[tableView dequeueReusableCellWithIdentifier:actionReuse];
	if (!cell)
		cell = [[TGFlatActionCell alloc] initWithStyle:UITableViewCellStyleDefault
									   reuseIdentifier:actionReuse];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.disclosureIndicator.hidden = NO;
	if ([action isEqualToString:TGContactActionInvite]) {
		cell.titleLabel.text = TGL(@"Contacts.InviteFriends", @"Invite Friends");
		[cell setIconNamed:@"ListIconInvite" at:CGPointMake(13, 12)];
	} else if ([action isEqualToString:TGContactActionNewGroup]) {
		cell.titleLabel.text = TGL(@"Compose.NewGroup", @"New Group");
		[cell setIconNamed:@"ListIconFriends" at:CGPointMake(10, 12)];
	} else if ([action isEqualToString:TGContactActionNewChannel]) {
		cell.titleLabel.text = TGL(@"Compose.NewChannel", @"New Channel");
		[cell setIconNamed:@"ListIconFriends" at:CGPointMake(10, 12)];
	} else {
		cell.titleLabel.text = TGL(@"Contacts.QrCode.MyCode", @"My QR Code");
		[cell setIconNamed:@"ListIconInvite" at:CGPointMake(13, 12)];
	}
	[cell setNeedsLayout];
	return cell;
}

- (void)clearContactCell:(TGContactRowCell *)cell {
	cell.titleLabel.text = @"";
	cell.secondTitleLabel.text = @"";
	cell.secondTitleLabel.hidden = YES;
	cell.subtitleLabel.text = @"";
	cell.avatarView.image = nil;
	cell.premiumView.hidden = YES;
	cell.verifiedLabel.hidden = YES;
	cell.closeFriendLabel.hidden = YES;
}

- (void)applyNameToCell:(TGContactRowCell *)cell user:(NSDictionary *)u {
	NSString *first = [u[@"first_name"] isKindOfClass:NSString.class] ? u[@"first_name"] : @"";
	NSString *last = [u[@"last_name"] isKindOfClass:NSString.class] ? u[@"last_name"] : @"";
	BOOL online = [u[@"isOnline"] boolValue];

	UIFont *regular = [UIFont systemFontOfSize:19];
	UIFont *bold = [UIFont boldSystemFontOfSize:19];
	NSString *primary = self.displayFirstNameFirst ? first : last;
	NSString *secondary = self.displayFirstNameFirst ? last : first;
	BOOL boldPrimary = (self.displayFirstNameFirst == self.sortByFirstName);

	if (primary.length && secondary.length) {
		cell.titleLabel.font = boldPrimary ? bold : regular;
		cell.secondTitleLabel.font = boldPrimary ? regular : bold;
		cell.titleLabel.text = primary;
		cell.secondTitleLabel.text = secondary;
		cell.secondTitleLabel.hidden = NO;
	} else {
		cell.titleLabel.font = bold;
		cell.titleLabel.text = primary.length ? primary
											  : (secondary.length ? secondary : TGContactName(u));
		cell.secondTitleLabel.text = @"";
		cell.secondTitleLabel.hidden = YES;
	}

	NSString *phone = TGContactString(u, @"phone");
	cell.subtitleLabel.text = self.pickerMode
		? (phone.length ? [NSString stringWithFormat:@"+%@", phone] : @"")
		: TGContactString(u, @"statusText");
	cell.subtitleLabel.textColor = (online && !self.pickerMode)
		? TGColourFromHex(0x0779d0)
		: TGColourFromHex(0x888888);
	cell.backgroundColor = [[TGTheme shared] listBackgroundColour];
	cell.accessoryType = UITableViewCellAccessoryNone;
}

- (void)applyBadgesToCell:(TGContactRowCell *)cell user:(NSDictionary *)u {
	NSDictionary *badges = [self badgesForUser:u];
	BOOL premium = [badges[@"isPremium"] boolValue];
	BOOL verified = [badges[@"isVerified"] boolValue];
	BOOL flagged = [badges[@"isScam"] boolValue] || [badges[@"isFake"] boolValue];
	UIImage *premiumIcon = nil;
	if (premium) {
		NSDictionary *emojiStatus = [self emojiStatusIconForUser:u];
		UIImage *statusImage = emojiStatus.count ? [self emojiStatusImageForIcon:emojiStatus] : nil;
		premiumIcon = statusImage ?: TGContactsScaledImage(@"tgpremiumicon.png", kContactBadgeSide);
	}
	cell.premiumView.image = premiumIcon;
	cell.premiumView.hidden = (premiumIcon == nil);
	cell.verifiedLabel.hidden = !verified;
	cell.closeFriendLabel.hidden = self.pickerMode || ![self isCloseFriend:u];
	if (flagged && !self.pickerMode) {
		cell.subtitleLabel.textColor = TGColourFromHex(0xcc1e2c);
		NSString *mark = [badges[@"isScam"] boolValue]
			? TGL(@"Message.ScamAccount", @"Scam").uppercaseString
			: TGL(@"Message.FakeAccount", @"Fake").uppercaseString;
		cell.subtitleLabel.text = cell.subtitleLabel.text.length
			? [NSString stringWithFormat:@"%@ · %@", mark, cell.subtitleLabel.text]
			: mark;
	}
}

- (void)applyAvatarToCell:(TGContactRowCell *)cell user:(NSDictionary *)u {
	NSString *name = TGContactName(u);
	NSNumber *fileId = [u[@"photoFileId"] isKindOfClass:NSNumber.class]
		? u[@"photoFileId"]
		: nil;
	UIImage *photo = fileId ? [self.photos objectForKey:fileId] : nil;
	if (!photo)
		photo = [TGIcons avatarWithInitials:
				(name.length ? TGSafeFirstCharacter(name).uppercaseString : @"?")
									   size:kContactAvatar
								   colourId:[u[@"id"] longLongValue]];
	cell.avatarView.image = photo;
	cell.avatarView.layer.cornerRadius = kContactAvatarCorner;
	if (fileId)
		[self requestPhotoForUser:u];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGContactCell";

	NSString *action = [self actionIdentifierAtIndexPath:indexPath];
	if (action)
		return [self actionCellForTableView:tableView identifier:action];

	TGContactRowCell *cell = (TGContactRowCell *)[tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGContactRowCell alloc] initWithStyle:UITableViewCellStyleDefault
									   reuseIdentifier:reuse];
	[cell resetForConfiguration];

	NSDictionary *u = [self userAtIndexPath:indexPath];
	if (!u) {
		[self clearContactCell:cell];
		return cell;
	}
	[self applyNameToCell:cell user:u];
	[self applyBadgesToCell:cell user:u];
	[cell setNeedsLayout];
	[self applyAvatarToCell:cell user:u];
	return cell;
}

- (BOOL)keepsSelectionForDetailPane {
	return !self.pickerMode && TGContactsTabletLayout();
}

- (void)openTarget:(UIViewController *)target {
	if (!target)
		return;
	if (!self.pickerMode && TGContactsShowInDetailPane(self, target))
		return;
	[self.navigationController pushViewController:target animated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *action = [self actionIdentifierAtIndexPath:indexPath];
	if (action || ![self keepsSelectionForDetailPane])
		[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (action) {
		if ([action isEqualToString:TGContactActionInvite])
			[self inviteFriendsTapped];
		else if ([action isEqualToString:TGContactActionNewGroup])
			[self newGroupTapped];
		else if ([action isEqualToString:TGContactActionNewChannel])
			[self newChannelTapped];
		else
			[self contactLinkTapped];
		return;
	}
	NSDictionary *u = [self userAtIndexPath:indexPath];
	if (!u) {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		return;
	}
	NSString *name = TGContactName(u);
	__weak typeof(self) weakSelf = self;

	[self.searchBar resignFirstResponder];

	if (self.onUserPicked) {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		self.onUserPicked([u[@"id"] longLongValue], name);
		return;
	}

	int64_t userId = [u[@"id"] longLongValue];
	void (^completion)(int64_t chatId) = ^(int64_t chatId) {
		TGContactsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (chatId == 0) {
			[strongSelf.tableView deselectRowAtIndexPath:indexPath animated:YES];
			return;
		}
		TGChatViewController *vc = [[TGChatViewController alloc] init];
		vc.chatId = chatId;
		vc.chatTitle = name;
		[strongSelf openTarget:vc];
	};
	[TGContactsService privateChatWithUser:userId completion:completion];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.pickerMode)
		return NO;
	return [self userAtIndexPath:indexPath] != nil;
}

- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGL(@"Common.Delete", @"Delete");
}

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;
	NSDictionary *u = [self userAtIndexPath:indexPath];
	if (u)
		[self deleteContact:u];
}

@end

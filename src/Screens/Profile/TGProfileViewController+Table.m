#import "TGProfileViewController.h"
#import "TGProfileDetailRowBridge.h"
#import "TGProfileViewControllerInternal.h"
#import "TGProfileDetailRowHeight.h"
#import "TGProfileButtonsCell.h"
#import "TGProfileRedButtonCell.h"
#import "TGProfilePermissionsController.h"
#import "TGProfileStatisticsController.h"
#import "TGProfileBoostsController.h"
#import "TGProfileCommonGroupsController.h"
#import "TGProfileLinkJoinsController.h"
#import "TGLocalization.h"
#import "TGContactsService.h"
#import "TGProfileSectionMetrics.h"
#import "TGUserDisplayNameStore.h"
#import "TGClient.h"
#import "TGClient+ChatState.h"
#import "TGFileDownloadService.h"
#import "TGSettingsService.h"
#import "TGClient+WebLinks.h"
#import "TGWebViewController.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGPopupMenu.h"
#import "TGActionSheet.h"
#import "TGForwardPicker.h"
#import "UIView+SafeTint.h"
#import "TGImageDecode.h"
#import "TGQRCodeViewController.h"
#import "TGCollectibleInfoViewController.h"
#import "TGMediaViewController.h"
#import "TGStarsViewController.h"
#import "TGLazyFramework.h"
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import "TGEmoji.h"
#import "TGDateLabel.h"
#import "TGDateUtils.h"
#import "TGAlertView.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGProfileDetailItemBuilder.h"
#import "TGHexColour.h"

@implementation TGProfileViewController (Table)

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.sectionKinds.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSString *kind = [self kindForSection:section];
	if ([kind isEqualToString:@"story"])
		return 1;
	if ([kind isEqualToString:@"details"])
		return self.details.count + self.gifts.count;
	if ([kind isEqualToString:@"personal"])
		return self.personalChatId ? 1 : 0;
	if ([kind isEqualToString:@"manage"])
		return self.manageRows.count;
	if ([kind isEqualToString:@"members"])
		return self.members.count;
	if ([kind isEqualToString:@"actions"])
		return [self actionRowCount];
	if ([kind isEqualToString:@"delete"])
		return 1;
	if ([kind isEqualToString:@"media"])
		return self.chatId ? 2 : 1;
	return 1;
}

- (BOOL)mediaSectionHasNotificationsRow {
	return self.chatId != 0;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *kind = [self kindForSection:indexPath.section];
	if ([kind isEqualToString:@"details"] || [kind isEqualToString:@"manage"])
		[self adoptGroupedInsetFromCell:cell inTable:tableView];
	if (![kind isEqualToString:@"actions"] && ![kind isEqualToString:@"delete"] && ![kind isEqualToString:@"story"])
		return;
	cell.backgroundColor = [UIColor clearColor];
	cell.backgroundView = [[UIView alloc] initWithFrame:cell.bounds];
	cell.backgroundView.backgroundColor = [UIColor clearColor];
	cell.selectedBackgroundView = nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	BOOL isSecret = self.chatId != 0 && [TGContactsService isSecretChat:self.chatId];
	return TGProfileSectionHeaderHeight([self kindForSection:section], section == 0,
		[self isGroupProfile], isSecret,
		[self tableView:tableView numberOfRowsInSection:section] == 0, self.details.count > 0);
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	if ([self tableView:tableView numberOfRowsInSection:section] == 0)
		return 0;
	if ([self isGroupProfile])
		return 1;
	if ([[self kindForSection:section] isEqualToString:@"details"])
		return 0;
	return 1 + ([UIScreen mainScreen].scale > 1.5f ? 0.5f : 1.0f);
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *kind = [self kindForSection:indexPath.section];
	if ([kind isEqualToString:@"members"])
		return kMemberRowHeight;
	if ([kind isEqualToString:@"story"])
		return kButtonsRowHeight;
	if ([kind isEqualToString:@"actions"]) {
		BOOL lastRow = indexPath.row + 1 >= [self actionRowCount];
		return lastRow ? kButtonsRowHeight : kButtonsRowHeight + kButtonsRowGutter;
	}
	if ([kind isEqualToString:@"delete"])
		return kActionButtonHeight;
	if ([kind isEqualToString:@"details"]) {
		NSString *heightKey = [self detailHeightKeyForRow:indexPath.row];
		NSNumber *measured = heightKey ? self.measuredRowHeights[heightKey] : nil;
		if (measured)
			return [measured floatValue];
		return TGProfileDetailRowHeightForValue([self detailValueForRow:indexPath.row],
			[UIFont boldSystemFontOfSize:15], [self detailContentWidthInTable:tableView]);
	}
	return 44;
}

- (CGFloat)detailContentWidthInTable:(UITableView *)tableView {
	CGFloat width = tableView.bounds.size.width;
	CGFloat inset = self.groupedInset > 0.5f ? self.groupedInset : 10;
	return MAX(80, width - inset * 2);
}

- (NSString *)detailHeightKeyForRow:(NSInteger)row {
	if (row < (NSInteger)self.details.count)
		return self.details[row][0];
	NSInteger giftIndex = row - self.details.count;
	if (giftIndex < (NSInteger)self.gifts.count)
		return [NSString stringWithFormat:@"gift-%ld", (long)giftIndex];
	return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *kind = [self kindForSection:indexPath.section];

	if ([kind isEqualToString:@"story"])
		return [self storyCell:tableView];

	if ([kind isEqualToString:@"actions"])
		return [self actionsCell:tableView row:indexPath.row];

	if ([kind isEqualToString:@"delete"])
		return [self deleteContactCell:tableView];

	if ([kind isEqualToString:@"media"]) {
		if ([self mediaSectionHasNotificationsRow] && indexPath.row == 0)
			return [self notificationsCell:tableView];
		return [self sharedMediaCell:tableView];
	}

	if ([kind isEqualToString:@"manage"])
		return [self manageCell:tableView row:indexPath.row];

	if ([kind isEqualToString:@"personal"])
		return [self personalChatCell:tableView];

	if ([kind isEqualToString:@"details"])
		return [self detailsRowCell:tableView row:indexPath.row];

	return [self plainRowCell:tableView kind:kind row:indexPath.row];
}

- (UITableViewCell *)storyCell:(UITableView *)tableView {
	TGProfileButtonsCell *cell = (TGProfileButtonsCell *)
		[tableView dequeueReusableCellWithIdentifier:@"storybutton"];
	if (![cell isKindOfClass:[TGProfileButtonsCell class]])
		cell = [[TGProfileButtonsCell alloc] initWithStyle:UITableViewCellStyleDefault
										   reuseIdentifier:@"storybutton"];
	cell.rightButton.hidden = YES;
	cell.leftButton.hidden = NO;
	[cell.leftButton setTitle:TGL(@"Story.Privacy.PostStory", @"Post a Story") forState:UIControlStateNormal];
	[cell.leftButton removeTarget:self action:NULL
				 forControlEvents:UIControlEventTouchUpInside];
	[cell.leftButton addTarget:self action:@selector(postStoryTapped)
			  forControlEvents:UIControlEventTouchUpInside];
	[cell setNeedsLayout];
	return cell;
}

- (UITableViewCell *)deleteContactCell:(UITableView *)tableView {
	TGProfileRedButtonCell *cell = (TGProfileRedButtonCell *)
		[tableView dequeueReusableCellWithIdentifier:@"delete"];
	if (![cell isKindOfClass:[TGProfileRedButtonCell class]])
		cell = [[TGProfileRedButtonCell alloc]
			  initWithStyle:UITableViewCellStyleDefault
			reuseIdentifier:@"delete"];
	[cell.button setTitle:TGL(@"UserInfo.DeleteContact", @"Delete Contact") forState:UIControlStateNormal];
	[cell.button removeTarget:self action:NULL
			 forControlEvents:UIControlEventTouchUpInside];
	[cell.button addTarget:self action:@selector(deleteContactTapped)
		  forControlEvents:UIControlEventTouchUpInside];
	return cell;
}

- (void)openGiftsPageOpeningCatalogue:(BOOL)catalogue {
	if (!self.navigationController)
		return;
	TGStarsViewController *stars = [[TGStarsViewController alloc] init];
	stars.opensGiftCatalogue = catalogue;
	[self.navigationController pushViewController:stars animated:YES];
}

- (UITableViewCell *)personalChatCell:(UITableView *)tableView {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"manage"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"manage"];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.textLabel.text = self.personalChatTitle ?: TGL(@"Channel.Setup.Title", @"Channel");
	cell.detailTextLabel.text = nil;
	cell.imageView.image = nil;
	return cell;
}

- (void)adoptGroupedInsetFromCell:(UITableViewCell *)cell inTable:(UITableView *)tableView {
	CGFloat width = tableView.bounds.size.width;
	if (width < 1)
		return;
	CGFloat inset = cell.frame.origin.x;
	if (inset < 1) {
		CGFloat content = cell.contentView.bounds.size.width;
		if (content < 1)
			return;
		inset = MAX(0, floorf((width - content) / 2) - 1);
	}
	if (inset < 0 || fabsf(inset - self.groupedInset) < 0.5f)
		return;
	self.groupedInset = inset;
	[self layoutHeaderForInset:inset];
}

- (void)layoutHeaderForInset:(CGFloat)inset {
	if (!self.avatarView)
		return;
	CGRect avatar = self.avatarView.frame;
	avatar.origin.x = inset;
	self.avatarView.frame = avatar;
	self.avatarOverlayView.frame = avatar;

	CGFloat width = self.tableView.bounds.size.width;
	CGFloat labelLeft = inset + kProfileAvatarSide + [self headerNameGap];
	CGFloat available = MAX(40, width - labelLeft - inset);
	CGRect name = self.nameLabel.frame;
	name.origin.x = labelLeft;
	name.size.width = available;
	self.nameLabel.frame = name;
	self.statusLabel.frame = [self headerStatusFrameForLeft:labelLeft width:available];
	[self layoutNameBadge];
}

- (void)recordRowHeight:(CGFloat)height forLabel:(NSString *)label inTable:(UITableView *)tableView {
	if (!label)
		return;
	if (!self.measuredRowHeights)
		self.measuredRowHeights = [NSMutableDictionary dictionary];
	NSNumber *known = self.measuredRowHeights[label];
	if (known && fabsf([known floatValue] - height) < 0.5f)
		return;
	self.measuredRowHeights[label] = @(height);
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		[weakSelf.tableView reloadData];
	});
}

- (NSString *)detailGiftValueAtIndex:(NSInteger)giftIndex {
	id gift = giftIndex < (NSInteger)self.gifts.count ? self.gifts[giftIndex] : nil;
	NSDictionary *giftDict = [gift isKindOfClass:[NSDictionary class]] ? gift : nil;
	NSString *giftTitle = TGProfileText(giftDict[@"title"]);
	if (giftTitle && [giftDict[@"isUnique"] boolValue]) {
		NSString *currency = giftDict[@"valueCurrency"];
		long long valueAmount = [giftDict[@"valueAmount"] longLongValue];
		return ([currency isKindOfClass:[NSString class]] && currency.length && valueAmount > 0)
			? [NSString stringWithFormat:@"%@ - %.2f %@", giftTitle, valueAmount / 100.0, currency]
			: giftTitle;
	}
	NSInteger starCount = [giftDict[@"starCount"] integerValue];
	if (giftTitle && starCount > 0)
		return [NSString stringWithFormat:@"%@ - %@", giftTitle,
			TGLPlural(@"Premium.Gift.Stars", starCount, @"%@ Star", @"%@ Stars")];
	return giftTitle ?: TGL(@"Attachment.Gift", @"Gift");
}

- (NSString *)detailValueForRow:(NSInteger)row {
	if (row < (NSInteger)self.details.count) {
		NSArray *pair = self.details[row];
		return pair.count > 1 ? pair[1] : @"";
	}
	return [self detailGiftValueAtIndex:row - (NSInteger)self.details.count];
}

- (UITableViewCell *)detailsRowCell:(UITableView *)tableView row:(NSInteger)row {
	if ([self.profileDetailRowBridge ownsRowAtIndex:row]) {
		UITableViewCell *migrated = [self.profileDetailRowBridge cellForRow:row inTable:tableView];
		if (migrated)
			return migrated;
	}

	NSString *label = @"gift";
	BOOL hiddenPhone = NO;
	NSString *heightKey = [self detailHeightKeyForRow:row];
	if (row < (NSInteger)self.details.count) {
		NSArray *pair = self.details[row];
		label = pair[0];
		hiddenPhone = pair.count > 2 && [pair[2] boolValue];
	}
	return [self detailCell:tableView
					  label:label
					  value:[self detailValueForRow:row]
				  heightKey:heightKey
				hiddenPhone:hiddenPhone];
}

static NSString *TGProfileMemberRoleLabel(NSString *status) {
	if ([status isEqualToString:@"creator"])
		return @"owner";
	if ([status isEqualToString:@"administrator"])
		return @"admin";
	return @"";
}

- (UITableViewCell *)plainRowCell:(UITableView *)tableView
							 kind:(NSString *)kind
							  row:(NSInteger)row {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"row"];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.imageView.image = nil;
	[[TGTheme shared] styleCell:cell];
	CGFloat retinaPixel = TGProfileRetinaPixel();
	BOOL isMember = [kind isEqualToString:@"members"];
	if (isMember) {
		cell.textLabel.font = [UIFont boldSystemFontOfSize:15 + retinaPixel];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:13 + retinaPixel];
	} else {
		cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	}
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];

	if (isMember) {
		id member = row < (NSInteger)self.members.count
			? self.members[row]
			: nil;
		if (![member isKindOfClass:[NSDictionary class]])
			member = @{};
		int64_t userId = TGProfileInt64(member[@"id"]);
		NSString *name = TGProfileText(member[@"name"])
			?: TGProfileText([TGUserDisplayNameStore nameForUserId:userId]);
		cell.selectionStyle = userId ? UITableViewCellSelectionStyleBlue
									 : UITableViewCellSelectionStyleNone;
		cell.textLabel.text = name ?: @"";
		cell.detailTextLabel.text = TGProfileMemberRoleLabel(TGProfileText(member[@"status"]));
		UIImage *photo = userId ? self.memberAvatars[@(userId)] : nil;
		if (!photo) {
			NSString *initial = TGProfileInitial(name);
			photo = [TGIcons avatarWithInitials:initial size:kMemberAvatarSide colourId:userId];
			[self loadMemberAvatarForUserId:userId];
		}
		cell.imageView.layer.cornerRadius = 4;
		cell.imageView.clipsToBounds = YES;
		cell.imageView.image = photo;
	}
	return cell;
}

- (void)loadMemberAvatarForUserId:(int64_t)userId {
	if (userId == 0)
		return;
	if (!self.memberAvatars)
		self.memberAvatars = [NSMutableDictionary dictionary];
	if (!self.memberAvatarsRequested)
		self.memberAvatarsRequested = [NSMutableSet set];
	NSNumber *key = @(userId);
	if (self.memberAvatars[key] || [self.memberAvatarsRequested containsObject:key])
		return;
	[self.memberAvatarsRequested addObject:key];
	__weak typeof(self) weakSelf = self;
	[TGSettingsService resolvePhotoFileIdForUserId:userId completion:^(NSNumber *fileId) {
		if (![fileId isKindOfClass:[NSNumber class]] || fileId.longLongValue <= 0)
			return;
		[weakSelf downloadMemberAvatarFile:fileId.longLongValue forKey:key];
	}];
}

- (void)downloadMemberAvatarFile:(long long)fileId forKey:(NSNumber *)key {
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:fileId completion:^(NSString *path) {
		if (!path.length)
			return;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			UIImage *image = TGDecodeSquareThumbnail(path, kMemberAvatarSide);
			if (!image)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				TGProfileViewController *strongSelf = weakSelf;
				if (!strongSelf)
					return;
				strongSelf.memberAvatars[key] = image;
				if (!strongSelf.memberAvatarReload)
					strongSelf.memberAvatarReload = [[TGTableReloadCoalescer alloc]
						initWithTableView:strongSelf.tableView];
				[strongSelf.memberAvatarReload setNeedsReload];
			});
		});
	}];
}

- (UITableViewCell *)sharedMediaCell:(UITableView *)tableView {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"sharedmedia"];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"sharedmedia"];
		UILabel *count = [[UILabel alloc] initWithFrame:
				CGRectMake(cell.contentView.bounds.size.width - 200 - 11 - 14, 11, 200, 21)];
		count.tag = 21;
		count.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		count.textAlignment = NSTextAlignmentRight;
		count.contentMode = UIViewContentModeRight;
		count.font = [UIFont systemFontOfSize:17];
		count.backgroundColor = [UIColor clearColor];
		count.textColor = TGColourFromHex(0x415d7f);
		count.highlightedTextColor = [UIColor whiteColor];
		[cell.contentView addSubview:count];

		UILabel *title = [[UILabel alloc] initWithFrame:
				CGRectMake(11, 12, cell.contentView.bounds.size.width - 30, 21)];
		title.tag = 22;
		title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		title.font = [UIFont boldSystemFontOfSize:17];
		title.backgroundColor = [UIColor clearColor];
		title.highlightedTextColor = [UIColor whiteColor];
		title.text = TGL(@"GroupInfo.SharedMedia", @"Shared Media");
		[cell.contentView addSubview:title];
	}
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.textLabel.text = nil;
	cell.imageView.image = nil;
	((UILabel *)[cell.contentView viewWithTag:22]).textColor =
		[[TGTheme shared] primaryTextColour];

	UILabel *count = (UILabel *)[cell.contentView viewWithTag:21];
	BOOL loaded = self.photosLoaded && self.filesLoaded;
	if (loaded) {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.accessoryView = nil;
		count.text = [NSString stringWithFormat:@"%lu",
			(unsigned long)(self.photoCount + self.fileCount)];
	} else {
		count.text = @"";
		cell.accessoryType = UITableViewCellAccessoryNone;
		UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
			initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		[spinner startAnimating];
		cell.accessoryView = spinner;
	}
	return cell;
}

- (UITableViewCell *)notificationsCell:(UITableView *)tableView {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"notifications"];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"notifications"];
		UISwitch *toggle = [[UISwitch alloc] init];
		toggle.tag = 23;
		toggle.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		toggle.frame = CGRectMake(cell.contentView.bounds.size.width - toggle.frame.size.width - 9, 8,
			toggle.frame.size.width, toggle.frame.size.height);
		[toggle addTarget:self action:@selector(notificationsToggled:)
			forControlEvents:UIControlEventValueChanged];
		[cell.contentView addSubview:toggle];

		UILabel *title = [[UILabel alloc] initWithFrame:
				CGRectMake(11, 12, cell.contentView.bounds.size.width - 28 - toggle.frame.size.width, 20)];
		title.tag = 24;
		title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		title.font = [UIFont boldSystemFontOfSize:17];
		title.backgroundColor = [UIColor clearColor];
		title.highlightedTextColor = [UIColor whiteColor];
		title.text = TGL(@"Notifications.Title", @"Notifications");
		[cell.contentView addSubview:title];
	}
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.accessoryView = nil;
	cell.textLabel.text = nil;
	cell.imageView.image = nil;
	((UILabel *)[cell.contentView viewWithTag:24]).textColor =
		[[TGTheme shared] primaryTextColour];
	UISwitch *toggle = (UISwitch *)[cell.contentView viewWithTag:23];
	self.notificationsSwitch = toggle;
	[toggle setOn:!self.muted animated:NO];
	return cell;
}

- (void)openSharedMedia {
	if (!self.chatId || !self.navigationController)
		return;
	TGMediaViewController *media =
		[[TGMediaViewController alloc] initWithChatId:self.chatId];
	media.topicId = self.threadId;
	media.chatTitle = TGProfileText(self.name) ?: @"";
	[self.navigationController pushViewController:media animated:YES];
}

- (void)deleteContactTapped {
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:nil
					  delegate:self
				   otherTitles:@[ TGL(@"UserInfo.DeleteContact", @"Delete Contact") ]
			  destructiveIndex:0
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 82;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)deleteContactConfirmed {
	if (!self.userId)
		return;
	NSString *name = TGProfileText(self.name) ?: @"";
	__weak typeof(self) weakSelf = self;
	[TGContactsService removeContacts:@[ @(self.userId) ] completion:^(BOOL ok) {
		TGProfileViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[strongSelf showToast:TGL(@"Toast.CouldNotDeleteContact", @"Could not delete the contact")];
			return;
		}
		strongSelf.contact = NO;
		[strongSelf rebuildDetailRows];
		[strongSelf showToast:[NSString stringWithFormat:TGL(@"Conversation.DeletedFromContacts", @"%@ deleted from your contacts"), name]];
		[strongSelf.navigationController popViewControllerAnimated:YES];
	}];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSString *kind = [self kindForSection:indexPath.section];

	if ([kind isEqualToString:@"manage"]) {
		[self openManageRow:indexPath.row];
		return;
	}

	if ([kind isEqualToString:@"personal"]) {
		[self openChatId:self.personalChatId title:self.personalChatTitle];
		return;
	}

	if ([kind isEqualToString:@"members"]) {
		[self openMemberAtRow:indexPath.row];
		return;
	}

	if ([kind isEqualToString:@"media"]) {
		if (![self mediaSectionHasNotificationsRow] || indexPath.row == 1)
			[self openSharedMedia];
		return;
	}

	if (![kind isEqualToString:@"details"] || indexPath.row >= (NSInteger)self.details.count)
		return;
	NSString *label = self.details[indexPath.row][0];
	if ([label isEqualToString:@"note"]) {
		[self editNote];
		return;
	}
	if ([label isEqualToString:@"about"]) {
		[self openBioEntityIfAny];
		return;
	}
	if ([label isEqualToString:@"groups in common"]) {
		[self openCommonGroups];
		return;
	}
	if ([label isEqualToString:@"invite link"]) {
		[self showInviteLinkActions];
		return;
	}
	if ([label isEqualToString:@"username"]) {
		if ([self isCollectibleUsernameRow:indexPath]) {
			[self showCollectibleInfoForUsername:self.collectibleUsername];
			return;
		}
		NSArray *pair = self.details[indexPath.row];
		if (pair.count > 1)
			[self showUsernameCode:pair[1]];
		return;
	}
	if ([label isEqualToString:@"mobile"])
		[self dialPhoneNumber];
	if ([label isEqualToString:@"song"])
		[self toggleSongPlayback];
}

- (void)showUsernameCode:(NSString *)value {
	NSString *username = [value hasPrefix:@"@"] ? [value substringFromIndex:1] : value;
	if (!username.length || !self.navigationController)
		return;
	NSString *caption = [NSString stringWithFormat:
			TGL(@"Profile.ScanCodeToOpenFormat", @"Anyone can scan this code to open @%@."), username];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] publicLinkForUsername:username completion:^(NSString *link) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || !strongSelf.navigationController)
			return;
		NSString *resolvedLink = link.length ? link : [@"https://t.me/" stringByAppendingString:username];
		TGQRCodeViewController *code = [[TGQRCodeViewController alloc]
			initWithLink:resolvedLink
				 caption:caption];
		[strongSelf.navigationController pushViewController:code animated:YES];
	}];
}

- (void)dialPhoneNumber {
	NSString *phone = self.phoneNumber;
	if (!phone.length)
		return;
	NSMutableString *digits = [NSMutableString string];
	for (NSInteger i = 0; i < phone.length; i++) {
		unichar c = [phone characterAtIndex:i];
		if ((c >= '0' && c <= '9') || (c == '+' && digits.length == 0))
			[digits appendFormat:@"%C", c];
	}
	if (!digits.length)
		return;
	UIApplication *application = [UIApplication sharedApplication];
	NSString *scheme = @"tel:";
	if (![application canOpenURL:[NSURL URLWithString:@"tel://"]])
		scheme = @"facetime:";
	NSURL *url = [NSURL URLWithString:[scheme stringByAppendingString:digits]];
	if (url)
		[application openURL:url];
}

- (BOOL)isCollectibleUsernameRow:(NSIndexPath *)indexPath {
	if (![[self kindForSection:indexPath.section] isEqualToString:@"details"])
		return NO;
	if (indexPath.row >= (NSInteger)self.details.count)
		return NO;
	NSArray *pair = self.details[indexPath.row];
	return self.usernameIsCollectible && pair.count > 0 &&
		[pair[0] isEqualToString:@"username"];
}

- (BOOL)tableView:(UITableView *)tableView
	shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (![[self kindForSection:indexPath.section] isEqualToString:@"details"])
		return NO;
	if (indexPath.row >= (NSInteger)self.details.count)
		return NO;
	NSArray *pair = self.details[indexPath.row];
	if (pair.count <= 1 || ![pair[1] length])
		return NO;

	[UIMenuController sharedMenuController].menuItems = nil;
	return YES;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action
	forRowAtIndexPath:(NSIndexPath *)indexPath
		   withSender:(id)sender {
	if (action == @selector(copy:))
		return YES;
	return NO;
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action
	forRowAtIndexPath:(NSIndexPath *)indexPath
		   withSender:(id)sender {
	if (action != @selector(copy:))
		return;
	if (indexPath.row >= (NSInteger)self.details.count)
		return;
	NSArray *pair = self.details[indexPath.row];
	if (pair.count > 1)
		[UIPasteboard generalPasteboard].string = pair[1];
}

- (void)showCollectibleInfoForUsername:(NSString *)username {
	if (!username.length || !self.navigationController)
		return;
	TGCollectibleInfoViewController *info = [[TGCollectibleInfoViewController alloc]
		initWithUsername:username];
	[self.navigationController pushViewController:info animated:YES];
}

- (void)openMemberAtRow:(NSInteger)row {
	if (row >= (NSInteger)self.members.count)
		return;
	id member = self.members[row];
	if (![member isKindOfClass:[NSDictionary class]])
		return;
	int64_t userId = TGProfileInt64(member[@"id"]);
	if (!userId || userId == self.userId)
		return;
	NSString *storedName = TGProfileText([TGUserDisplayNameStore nameForUserId:userId]);
	NSString *name = TGProfileText(member[@"name"]) ?: (storedName ?: @"");
	UINavigationController *navigation = self.navigationController;
	if (!navigation)
		return;
	[TGContactsService privateChatWithUser:userId completion:^(int64_t chatId) {
		[TGProfileViewController showProfileForChatId:chatId
											   userId:userId
												title:name
										 inNavigation:navigation];
	}];
}

- (NSString *)fragmentOfBio:(NSString *)text entity:(NSDictionary *)entity {
	NSInteger offset = [entity[@"offset"] integerValue];
	NSInteger length = [entity[@"length"] integerValue];
	if (offset < 0 || length <= 0 || offset + length > (NSInteger)text.length)
		return @"";
	return [text substringWithRange:NSMakeRange((NSUInteger)offset, (NSUInteger)length)];
}

- (void)openBioMentionName:(int64_t)userId {
	if (userId <= 0 || userId == self.userId)
		return;
	UINavigationController *navigation = self.navigationController;
	if (!navigation)
		return;
	NSString *name = [[TGClient shared] nameForUserId:userId] ?: @"";
	[TGContactsService privateChatWithUser:userId completion:^(int64_t chatId) {
		if (!chatId)
			return;
		[TGProfileViewController showProfileForChatId:chatId
											   userId:userId
												title:name
										 inNavigation:navigation];
	}];
}

- (void)openBioMentionUsername:(NSString *)username {
	if (!username.length)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] publicLinkForUsername:username completion:^(NSString *link) {
		typeof(self) strongSelf = weakSelf;
		if (strongSelf && link.length)
			[TGWebViewController openURLString:link fromViewController:strongSelf];
	}];
}

- (void)openBioEntityIfAny {
	NSString *text = self.profileBio ?: @"";
	for (NSDictionary *entity in self.profileBioEntities) {
		if (![entity isKindOfClass:[NSDictionary class]])
			continue;
		NSString *kind = [([entity[@"kind"] isKindOfClass:[NSString class]]
				? entity[@"kind"]
				: @"") lowercaseString];
		if ([kind isEqualToString:@"url"]) {
			NSString *fragment = [self fragmentOfBio:text entity:entity];
			if (fragment.length) {
				[TGWebViewController openURLString:fragment fromViewController:self];
				return;
			}
		} else if ([kind isEqualToString:@"texturl"]) {
			NSString *url = [entity[@"url"] isKindOfClass:[NSString class]] ? entity[@"url"] : @"";
			if (url.length) {
				[TGWebViewController openURLString:url fromViewController:self];
				return;
			}
		} else if ([kind isEqualToString:@"mention"]) {
			NSString *fragment = [self fragmentOfBio:text entity:entity];
			if (fragment.length > 1) {
				[self openBioMentionUsername:[fragment substringFromIndex:1]];
				return;
			}
		} else if ([kind isEqualToString:@"mentionname"]) {
			[self openBioMentionName:[entity[@"userId"] longLongValue]];
			return;
		}
	}
}

- (NSString *)displayLabelForKind:(NSString *)kind {
	return [TGProfileDetailItemBuilder displayLabelForKind:kind];
}

- (UITableViewCell *)detailCell:(UITableView *)tableView
						  label:(NSString *)label
						  value:(NSString *)value
					  heightKey:(NSString *)heightKey
					hiddenPhone:(BOOL)phoneHidden {
	TGTheme *theme = [TGTheme shared];
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"detail"];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"detail"];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;

		UILabel *labelView = [[UILabel alloc] initWithFrame:CGRectMake(4, 13, 62, 16)];
		labelView.tag = 11;
		labelView.textAlignment = NSTextAlignmentRight;
		labelView.font = [UIFont boldSystemFontOfSize:13];
		labelView.adjustsFontSizeToFitWidth = YES;
		labelView.minimumFontSize = 10;
		labelView.backgroundColor = [UIColor clearColor];
		[cell.contentView addSubview:labelView];

		UILabel *valueView = [[UILabel alloc] initWithFrame:
				CGRectMake(78, 11, cell.contentView.bounds.size.width - 80, 20)];
		valueView.tag = 12;
		valueView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		valueView.font = [UIFont boldSystemFontOfSize:15];
		valueView.numberOfLines = 0;
		valueView.lineBreakMode = NSLineBreakByWordWrapping;
		valueView.backgroundColor = [UIColor clearColor];
		[cell.contentView addSubview:valueView];
	}
	[theme styleCell:cell];

	BOOL opens = [label isEqualToString:@"note"] || [label isEqualToString:@"groups in common"] || [label isEqualToString:@"invite link"] || [label isEqualToString:@"username"];
	BOOL isPhone = [label isEqualToString:@"mobile"];
	BOOL hiddenPhone = isPhone && phoneHidden;
	BOOL isSong = [label isEqualToString:@"song"];
	cell.selectionStyle = (opens || isSong || (isPhone && !hiddenPhone))
		? UITableViewCellSelectionStyleBlue
		: UITableViewCellSelectionStyleNone;
	cell.accessoryType = opens ? UITableViewCellAccessoryDisclosureIndicator
							   : UITableViewCellAccessoryNone;
	cell.userInteractionEnabled = !hiddenPhone;

	UILabel *labelView = (UILabel *)[cell.contentView viewWithTag:11];
	UILabel *valueView = (UILabel *)[cell.contentView viewWithTag:12];
	labelView.text = [self displayLabelForKind:label];
	labelView.textColor = TGColourFromHex(0x5d708f);
	if (isSong) {
		BOOL playing = self.songPlayer.playing &&
			self.songPlayerFileId == [self.profileAudioInfo[@"fileId"] longLongValue];
		value = [NSString stringWithFormat:@"%@  %@", (playing ? @"⏸" : @"▶"), value ?: @""];
	}
	valueView.text = value;
	CGFloat contentWidth = cell.contentView.bounds.size.width;
	CGFloat valueWidth = TGProfileDetailValueWidthForContentWidth(contentWidth);
	CGFloat valueHeight = TGProfileDetailValueHeight(value, valueView.font, contentWidth);
	valueView.frame = CGRectMake(kTGProfileDetailValueLeft, 11, valueWidth, valueHeight);
	[self recordRowHeight:TGProfileDetailRowHeightForValue(value, valueView.font, contentWidth)
				 forLabel:(heightKey ?: label)
				  inTable:tableView];
	[self adoptGroupedInsetFromCell:cell inTable:tableView];
	if (hiddenPhone)
		valueView.textColor = TGColourFromHex(0xaaaaaa);
	else if (isPhone)
		valueView.textColor = TGColourFromHex(0x347fd4);
	else
		valueView.textColor = [UIColor blackColor];
	return cell;
}

- (UITableViewCell *)manageCell:(UITableView *)tableView row:(NSInteger)row {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"manage"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"manage"];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	NSArray *item = row < (NSInteger)self.manageRows.count ? self.manageRows[row] : nil;
	cell.textLabel.text = item.count > 0 ? item[0] : @"";
	cell.detailTextLabel.text = item.count > 2 ? item[2] : nil;
	cell.imageView.image = nil;
	return cell;
}

@end

#import "TGExceptionsListText.h"
#import "TGLanguageListText.h"
#import "TGImageDecode.h"
#import "TGStringTruncation.h"
#import "TGAccountUsernamesViewController.h"
#import "TGAccountSettingsViewController.h"
#import "TGLocalization.h"
#import "TGNotificationManager.h"
#import "TGSettingsViewController.h"
#import "TGEmoji.h"
#import "RootViewController.h"
#import "TGTheme.h"
#import "TGSessionsViewController.h"
#import "TGDeviceViewController.h"
#import "TGWebBrowserSettingsViewController.h"
#import "TGDevice.h"
#import "TGFoldersViewController.h"
#import "TGProxyViewController.h"
#import "TGPrivacyViewController.h"
#import "TGPrivacyViewController.h"
#import "TGTabBar.h"
#import "TGSettingsService.h"
#import "TGPreferenceFlags.h"
#import "TGCapabilities.h"
#import "TGAccountManager.h"
#import "TGPhoneFormat.h"
#import "TGIcons.h"
#import <QuartzCore/QuartzCore.h>
#import "TGSettingsViewControllerInternal.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGActionSheet.h"
#import "TGHexColour.h"

static UIView *TGSettingsAccountUnreadBadge(NSInteger count) {
	if (count <= 0)
		return nil;
	NSString *text = count > 999 ? @"999+" : [NSString stringWithFormat:@"%ld", (long)count];
	UILabel *label = [[UILabel alloc] init];
	label.text = text;
	label.font = [UIFont boldSystemFontOfSize:13];
	label.textColor = [UIColor whiteColor];
	label.textAlignment = NSTextAlignmentCenter;
	label.backgroundColor = [UIColor colorWithWhite:0.6f alpha:1.0f];
	[label sizeToFit];
	CGFloat width = MAX(22.0f, label.bounds.size.width + 12);
	label.frame = CGRectMake(0, 0, width, 20);
	label.layer.cornerRadius = 10.0f;
	label.clipsToBounds = YES;
	label.transform = TGLocalizedIsRTL() ? CGAffineTransformMakeScale(-1, 1) : CGAffineTransformIdentity;
	return label;
}

@implementation TGSettingsViewController (Rows)

#pragma mark - rows

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.page == TGSettingsPageRoot) {
		NSInteger kind = [self rootKindForSection:indexPath.section];
		if (kind == TGSettingsRootKindPhoto)
			return [self profilePhotoCellInTable:tableView];
		if (kind == TGSettingsRootKindLogout)
			return [self logoutCellInTable:tableView];
		if (kind == TGSettingsRootKindSuggestions)
			return [self suggestionCellInTable:tableView at:indexPath];
	}

	NSString *reuse = @"TGSettingsCell";
	UITableViewCellStyle style = UITableViewCellStyleSubtitle;
	if (self.page == TGSettingsPageRoot) {
		reuse = @"TGSettingsRootRowCell";
		style = UITableViewCellStyleValue1;
	}
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:style
									  reuseIdentifier:reuse];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.accessoryView = nil;
	cell.imageView.image = nil;
	cell.detailTextLabel.text = @"";
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	[[TGTheme shared] styleCell:cell];

	if ((NSInteger)self.page == TGSettingsPageAutoDownload)
		return [self fillAutoDownloadCell:cell at:indexPath];
	if ((NSInteger)self.page == TGSettingsPageAutoDownloadKind)
		return [self fillAutoDownloadKindCell:cell at:indexPath];
	if ((NSInteger)self.page == TGSettingsPageAutosave)
		return [self fillAutosaveCell:cell at:indexPath];
	if ((NSInteger)self.page == TGSettingsPageDataUsage)
		return [self fillUsageCell:cell at:indexPath];
	if ((NSInteger)self.page == TGSettingsPageWallpaper)
		return [self fillWallpaperCell:cell at:indexPath];
	if ((NSInteger)self.page == TGSettingsPageChatListLayout)
		return [self fillChatListLayoutCell:cell at:indexPath];
	if ((NSInteger)self.page == TGSettingsPageTextSize)
		return [self fillTextSizeCell:cell at:indexPath];
	if ((NSInteger)self.page == TGSettingsPageNotificationExceptions)
		return [self fillExceptionCell:cell at:indexPath];
	if ((NSInteger)self.page == TGSettingsPageNotificationSounds)
		return [self fillSoundCell:cell at:indexPath];
	if ((NSInteger)self.page == TGSettingsPageNotificationTone)
		return [self fillToneCell:cell at:indexPath];
	switch (self.page) {
		case TGSettingsPageAppearance:
			return [self fillAppearanceCell:cell at:indexPath];
		case TGSettingsPageData:
			return [self fillDataCell:cell at:indexPath];
		case TGSettingsPageNotifications:
			return [self fillNotificationCell:cell at:indexPath];
		case TGSettingsPageLanguage:
			return [self fillLanguageCell:cell at:indexPath];
		default:
			return [self fillRootCell:cell at:indexPath];
	}
}

+ (NSArray *)accountsRows {
	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *account in [[TGAccountManager shared] accounts]) {
		NSString *name = account[@"name"];
		if (![name isKindOfClass:[NSString class]] || !name.length) {
			NSString *phone = account[@"phone"];
			name = ([phone isKindOfClass:[NSString class]] && phone.length)
				? [[TGPhoneFormat instance] format:phone implicitPlus:true]
				: @"";
		}
		[rows addObject:@[ name, @"profile" ]];
	}
	if ([[TGAccountManager shared] canAddAccount])
		[rows addObject:@[ TGL(@"Settings.AddAccount", @"Add Account"), @"add" ]];
	return rows;
}

+ (NSArray *)profileRows {
	return @[ @[ TGL(@"Settings.MyProfile", @"My Profile"), @"devices" ],
		@[ TGL(@"Settings.MyAccount", @"Account"), @"devices" ] ];
}

+ (NSArray *)proxyRows {
	return @[ @[ TGL(@"SocksProxySetup.Title", @"Proxy"), @"data" ] ];
}

+ (NSArray *)shortcutRows {
	return @[ @[ TGL(@"Settings.SavedMessages", @"Saved Messages"), @"pin" ],
		@[ TGL(@"Premium.MessageTags", @"Saved Message Tags"), @"pin" ],
		@[ TGL(@"CallSettings.RecentCalls", @"Recent Calls"), @"call" ],
		@[ TGL(@"Settings.Devices", @"Devices"), @"devices" ],
		@[ TGL(@"Settings.ChatFolders", @"Chat Folders"), @"chat" ],
		@[ TGL(@"Settings.MyStories", @"My Stories"), @"more" ] ];
}

+ (NSArray *)advancedRows {
	return @[ @[ TGL(@"Settings.NotificationsAndSounds", @"Notifications and Sounds"), @"notifications" ],
		@[ TGL(@"Settings.PrivacySettings", @"Privacy and Security"), @"privacy" ],
		@[ TGL(@"Settings.ChatSettings", @"Data and Storage"), @"data" ],
		@[ TGL(@"Settings.Appearance", @"Appearance"), @"chat" ],
		@[ TGL(@"Settings.AppLanguage", @"Language"), @"language" ] ];
}

+ (NSArray *)paymentRows {
	return @[ @[ TGL(@"Settings.Premium", @"Telegram Premium"), @"more" ],
		@[ TGL(@"Stars.Intro.Title", @"Telegram Stars"), @"react" ] ];
}

+ (NSArray *)extraRows {
	return @[ @[ TGL(@"PeerInfo.VerifyAccounts", @"Verify Accounts"), @"verified" ],
		@[ TGL(@"DialogList.SearchSectionPublicPosts", @"Public Posts"), @"search" ] ];
}

+ (NSArray *)helpRows {
	return @[ @[ TGL(@"Settings.Support", @"Ask a Question"), @"chat" ],
		@[ TGL(@"Settings.FAQ", @"Telegram FAQ"), @"faq" ],
		@[ TGL(@"Permissions.PrivacyPolicy", @"Privacy Policy"), @"policy" ] ];
}

- (UITableViewCell *)fillRootCell:(UITableViewCell *)cell at:(NSIndexPath *)indexPath {
	NSInteger kind = [self rootKindForSection:indexPath.section];
	if (kind == TGSettingsRootKindAccounts)
		return [self fillAccountCell:cell at:indexPath];
	NSArray *table = [self rootRowTableForKind:kind];

	if (table && (NSUInteger)indexPath.row < table.count) {
		NSArray *row = table[indexPath.row];
		cell.textLabel.text = row[0];
		cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
		[self decorateRootCell:cell kind:kind title:row[0]];
		[self markDisclosure:cell];
		return cell;
	}

	[TGIcons actionButtonInCell:cell
						  title:TGL(@"Settings.Logout", @"Log Out")
						   kind:TGActionButtonKindDestructive
						 target:self
						 action:@selector(confirmLogout)];
	return cell;
}

- (NSArray *)rootRowTableForKind:(NSInteger)kind {
	if (kind == TGSettingsRootKindAccounts)
		return [TGSettingsViewController accountsRows];
	if (kind == TGSettingsRootKindProfile)
		return [TGSettingsViewController profileRows];
	if (kind == TGSettingsRootKindProxy)
		return [TGSettingsViewController proxyRows];
	if (kind == TGSettingsRootKindShortcuts)
		return [TGSettingsViewController shortcutRows];
	if (kind == TGSettingsRootKindAdvanced)
		return [TGSettingsViewController advancedRows];
	if (kind == TGSettingsRootKindPayment)
		return [TGSettingsViewController paymentRows];
	if (kind == TGSettingsRootKindExtra)
		return [TGSettingsViewController extraRows];
	if (kind == TGSettingsRootKindHelp)
		return [TGSettingsViewController helpRows];
	return nil;
}

- (NSString *)nameForAccount:(NSDictionary *)account {
	NSString *name = account[@"name"];
	if ([name isKindOfClass:[NSString class]] && name.length)
		return name;
	NSString *phone = account[@"phone"];
	if ([phone isKindOfClass:[NSString class]] && phone.length)
		return [[TGPhoneFormat instance] format:phone implicitPlus:true];
	return @"";
}

- (NSString *)subtitleForAccount:(NSDictionary *)account {
	NSString *phone = account[@"phone"];
	if ([phone isKindOfClass:[NSString class]] && phone.length)
		return [[TGPhoneFormat instance] format:phone implicitPlus:true];
	NSString *username = account[@"username"];
	if ([username isKindOfClass:[NSString class]] && username.length)
		return [@"@" stringByAppendingString:username];
	return @"";
}

- (NSString *)initialsForAccountName:(NSString *)name {
	if (name.length)
		return TGSafeFirstCharacter(name).uppercaseString;
	return TGSafeFirstCharacter(TGL(@"Tour.Title1", @"Telegram")).uppercaseString;
}

- (UITableViewCell *)fillAccountCell:(UITableViewCell *)cell at:(NSIndexPath *)indexPath {
	NSArray *accounts = [[TGAccountManager shared] accounts];
	if ((NSUInteger)indexPath.row >= accounts.count) {
		cell.textLabel.text = TGL(@"Settings.AddAccount", @"Add Account");
		cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
		cell.textLabel.textColor = [[TGTheme shared] accentColour];
		return cell;
	}

	NSDictionary *account = [accounts objectAtIndex:(NSUInteger)indexPath.row];
	NSString *name = [self nameForAccount:account];
	cell.textLabel.text = name;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.detailTextLabel.text = [self subtitleForAccount:account];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.imageView.image = [TGIcons avatarWithInitials:[self initialsForAccountName:name]
												   size:30
											   colourId:[account[@"userId"] longLongValue]];
	if ([account[@"slot"] integerValue] == [TGAccountManager shared].currentSlot)
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	else
		cell.accessoryView = TGSettingsAccountUnreadBadge([account[@"unread"] integerValue]);
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	if ((NSInteger)self.page == TGSettingsPageNotificationExceptions)
		return [self canEditNotificationExceptionRowAtIndexPath:indexPath];
	if (self.page == TGSettingsPageLanguage)
		return [self canDeleteLanguagePackAtIndexPath:indexPath];
	if (self.page != TGSettingsPageRoot)
		return NO;
	if ([self rootKindForSection:indexPath.section] != TGSettingsRootKindAccounts)
		return NO;
	NSArray *accounts = [[TGAccountManager shared] accounts];
	if ((NSUInteger)indexPath.row >= accounts.count)
		return NO;
	NSDictionary *account = [accounts objectAtIndex:(NSUInteger)indexPath.row];
	return [account[@"slot"] integerValue] != [TGAccountManager shared].currentSlot;
}

- (BOOL)canDeleteLanguagePackAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == TGSettingsLanguageSectionTranslation)
		return NO;
	if ((NSUInteger)indexPath.row >= self.languages.count)
		return NO;
	NSDictionary *language = self.languages[indexPath.row];
	if (![language isKindOfClass:[NSDictionary class]] || ![language[@"installed"] boolValue])
		return NO;
	NSString *packId = language[@"id"];
	if (![packId isKindOfClass:[NSString class]] || [packId isEqualToString:@"en"])
		return NO;
	return ![packId isEqualToString:self.currentLanguage];
}

- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.page == TGSettingsPageLanguage)
		return TGL(@"Common.Delete", @"Delete");
	return TGL(@"Settings.Logout", @"Log Out");
}

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)style
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (style != UITableViewCellEditingStyleDelete)
		return;
	if (![self tableView:tableView canEditRowAtIndexPath:indexPath])
		return;
	if ((NSInteger)self.page == TGSettingsPageNotificationExceptions) {
		[self commitDeleteNotificationExceptionAtIndexPath:indexPath];
		return;
	}
	if (self.page == TGSettingsPageLanguage) {
		NSDictionary *language = self.languages[indexPath.row];
		NSString *packId = language[@"id"];
		__weak typeof(self) weakSelf = self;
		[TGSettingsService deleteLanguagePack:packId completion:^(BOOL deleted) {
			(void)deleted;
			[weakSelf loadForPage];
		}];
		return;
	}
	NSDictionary *account = [[[TGAccountManager shared] accounts]
		objectAtIndex:(NSUInteger)indexPath.row];
	self.slotPendingSignOut = [account[@"slot"] integerValue];
	UIActionSheet *confirm = [[UIActionSheet alloc]
					 initWithTitle:TGL(@"Settings.LogoutConfirmationText", @"Note that you can seamlessly use Telegram on all your devices at once.\n\nRemember, logging out kills all your Secret Chats.")
						  delegate:self
				 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			destructiveButtonTitle:TGL(@"Settings.Logout", @"Log Out")
				 otherButtonTitles:nil];
	confirm.tag = 180;
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	[confirm tg_showFromRect:cell.frame inView:tableView];
}

- (void)decorateRootCell:(UITableViewCell *)cell
					kind:(NSInteger)kind
				   title:(NSString *)title {
	if (kind == TGSettingsRootKindPayment && [title isEqualToString:TGL(@"Settings.Premium", @"Telegram Premium")]) {
		cell.detailTextLabel.text = self.premiumSummary.length
			? self.premiumSummary
			: @"";
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	}
	if (kind == TGSettingsRootKindProxy && [title isEqualToString:TGL(@"SocksProxySetup.Title", @"Proxy")]) {
		cell.detailTextLabel.text = self.proxyDetail.length ? self.proxyDetail : @"";
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	}
}

- (UITableViewCell *)profilePhotoCellInTable:(UITableView *)tableView {
	static NSString *reuse = @"TGSettingsPhotoButtonCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:reuse];
	}
	[TGIcons actionButtonInCell:cell
						  title:TGL(@"Settings.SetProfilePhoto", @"Set Profile Photo")
						   kind:TGActionButtonKindNeutral
						 target:self
						 action:@selector(changePhotoButtonPressed)];
	return cell;
}

- (void)changePhotoButtonPressed {
	NSMutableArray *actions = [NSMutableArray array];
	NSMutableArray *titles = [NSMutableArray array];
	if ([UIImagePickerController isSourceTypeAvailable:
				UIImagePickerControllerSourceTypeCamera]) {
		[titles addObject:TGL(@"Common.TakePhoto", @"Take Photo")];
		[actions addObject:@"camera"];
	}
	if ([UIImagePickerController isSourceTypeAvailable:
				UIImagePickerControllerSourceTypePhotoLibrary]) {
		[titles addObject:TGL(@"Media.ChooseFromGallery", @"Choose from Library")];
		[actions addObject:@"library"];
	}
	if (!actions.count) {
		UIAlertView *alert = [UIAlertView alloc];
		alert = [alert initWithTitle:TGL(@"Privacy.ProfilePhoto", @"Profile Photo")
							 message:TGL(@"Settings.ThereIsNoCameraAndNo", @"There is no camera and no photo library on this device.")
							delegate:nil
				   cancelButtonTitle:TGL(@"Common.OK", @"OK")
				   otherButtonTitles:nil];
		[alert show];
		return;
	}
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:nil
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 160;
	self.photoSheetActions = actions;
	[self showSheet:sheet];
}

- (void)presentProfilePhotoPickerFromSource:(UIImagePickerControllerSourceType)source {
	self.pickingProfilePhoto = YES;
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = source;
	picker.delegate = self;
	picker.allowsEditing = YES;
	[self showPicker:picker];
}

- (void)takeProfilePhoto:(UIImage *)image {
	CGSize size = image.size;
	CGFloat limit = 640.0f;
	CGFloat scale = MIN(1.0f, MIN(limit / MAX(size.width, 1.0f), limit / MAX(size.height, 1.0f)));
	UIImage *sized = image;
	if (scale < 1.0f || image.imageOrientation != UIImageOrientationUp) {
		CGSize target = CGSizeMake(floorf(size.width * scale),
			floorf(size.height * scale));
		UIGraphicsBeginImageContextWithOptions(target, YES, 1.0f);
		[image drawInRect:CGRectMake(0, 0, target.width, target.height)];
		sized = UIGraphicsGetImageFromCurrentImageContext() ?: image;
		UIGraphicsEndImageContext();
	}
	NSData *jpeg = UIImageJPEGRepresentation(sized, 0.8f);
	NSString *path = [NSTemporaryDirectory()
		stringByAppendingPathComponent:@"tg-profile-photo.jpg"];
	if (!jpeg || ![jpeg writeToFile:path atomically:YES])
		return;
	__weak typeof(self) weakSelf = self;
	[TGSettingsService setProfilePhotoAtPath:path completion:^(BOOL ok) {
		[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
		if (!ok)
			return;
		[weakSelf refreshHeader];
	}];
}

- (UITableViewCell *)logoutCellInTable:(UITableView *)tableView {
	static NSString *reuse = @"TGSettingsLogoutCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:reuse];
	}
	[TGIcons actionButtonInCell:cell
						  title:TGL(@"Settings.Logout", @"Log Out")
						   kind:TGActionButtonKindDestructive
						 target:self
						 action:@selector(confirmLogout)];
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.page == TGSettingsPageRoot) {
		NSInteger kind = [self rootKindForSection:indexPath.section];
		if (kind == TGSettingsRootKindLogout || kind == TGSettingsRootKindPhoto)
			return [TGIcons actionRowHeight];
		if (kind == TGSettingsRootKindSuggestions)
			return 64;
	}
	if (self.page == TGSettingsPageNotifications && indexPath.section == TGSettingsNotifSectionReset)
		return [TGIcons actionRowHeight];
	if ((NSInteger)self.page == TGSettingsPageNotificationExceptions && indexPath.section == 1)
		return [TGIcons actionRowHeight];
	return 44;
}

- (UISwitch *)notificationSwitchOn:(BOOL)on tag:(NSInteger)tag {
	UISwitch *toggle = [[UISwitch alloc] init];
	toggle.on = on;
	toggle.tag = tag;
	[toggle addTarget:self action:@selector(notificationToggled:)
		forControlEvents:UIControlEventValueChanged];
	return toggle;
}

- (UITableViewCell *)fillNotificationCell:(UITableViewCell *)cell at:(NSIndexPath *)path {
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];

	if (path.section <= TGSettingsNotifSectionChannels)
		return [self fillNotificationScopeCell:cell at:path];

	if (path.section == TGSettingsNotifSectionReactions)
		return [self fillReactionCell:cell at:path];

	if (path.section == TGSettingsNotifSectionStories) {
		cell.textLabel.text = TGL(@"Notifications.StoriesTitle", @"Stories");
		NSNumber *count = self.exceptionCounts[TGSettingsStoriesExceptionsScope];
		cell.detailTextLabel.text = count ? [count stringValue] : @"";
		[self markDisclosure:cell];
		return cell;
	}

	if (path.section == TGSettingsNotifSectionSounds) {
		if (path.row == 0) {
			cell.textLabel.text = TGL(@"Notifications.TextTone", @"Notification Tone");
			cell.detailTextLabel.text = [TGNotificationManager
				nameForToneId:[TGNotificationManager selectedToneId]];
			[self markDisclosure:cell];
			return cell;
		}
		cell.textLabel.text = TGL(@"Notifications.AlertTones", @"Notification Sounds");
		NSNumber *count = self.savedSoundsLoaded ? @(self.savedSounds.count) : nil;
		cell.detailTextLabel.text = count ? [count stringValue] : @"";
		[self markDisclosure:cell];
		return cell;
	}

	if (path.section == TGSettingsNotifSectionContacts) {
		cell.textLabel.text = TGL(@"NotificationSettings.ContactJoined", @"New Contacts");
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.accessoryView = [self notificationSwitchOn:!self.contactRegisteredMuted tag:path.section * 10 + path.row];
		return cell;
	}

	if (path.section == TGSettingsNotifSectionBadge) {
		if (path.row == 0) {
			cell.textLabel.text = TGL(@"Notifications.Badge.CountUnreadMessages", @"Count Unread Messages");
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			BOOL countsMessages = ![TGPreferenceFlags badgeCountsUnreadChats];
			cell.accessoryView = [self notificationSwitchOn:countsMessages tag:path.section * 10 + path.row];
			return cell;
		}
		cell.textLabel.text = TGL(@"Notifications.Badge.IncludeMutedChats", @"Include Muted Chats");
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		BOOL includesMuted = [TGPreferenceFlags badgeIncludesMuted];
		cell.accessoryView = [self notificationSwitchOn:includesMuted tag:path.section * 10 + path.row];
		return cell;
	}

	if (path.section == TGSettingsNotifSectionInApp) {
		NSArray *titles = @[ TGL(@"Notifications.InAppSounds", @"In-App Sounds"),
			TGL(@"Notifications.InAppVibrate", @"In-App Vibrate"),
			TGL(@"Notifications.InAppPreview", @"In-App Preview") ];
		cell.textLabel.text = titles[path.row];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		BOOL on = path.row == 0 ? [TGInAppNotificationPreferences inAppSoundsEnabled]
			: path.row == 1		? [TGInAppNotificationPreferences inAppVibrateEnabled]
								: [TGInAppNotificationPreferences inAppPreviewEnabled];
		cell.accessoryView = [self notificationSwitchOn:on tag:path.section * 10 + path.row];
		return cell;
	}

	[TGIcons actionButtonInCell:cell
						  title:TGL(@"Notifications.ResetAllNotifications", @"Reset All Notifications")
						   kind:TGActionButtonKindDestructive
						 target:self
						 action:@selector(confirmResetAllNotifications)];
	return cell;
}

- (UITableViewCell *)fillReactionCell:(UITableViewCell *)cell at:(NSIndexPath *)path {
	if (path.row == 0) {
		cell.textLabel.text = TGL(@"Notifications.Reactions", @"Notify About Reactions");
		NSUInteger index = [[TGSettingsViewController reactionSources]
			indexOfObject:[TGSettingsViewController reactionSource]];
		if (index == NSNotFound)
			index = 1;
		cell.detailTextLabel.text =
			[TGSettingsViewController reactionSourceTitles][index];
		[self markDisclosure:cell];
		return cell;
	}
	if (path.row == 1) {
		cell.textLabel.text = TGL(@"Settings.NotifyAboutPollVotes", @"Notify About Poll Votes");
		NSUInteger index = [[TGSettingsViewController reactionSources]
			indexOfObject:[TGSettingsViewController pollVoteSource]];
		if (index == NSNotFound)
			index = 1;
		cell.detailTextLabel.text =
			[TGSettingsViewController reactionSourceTitles][index];
		[self markDisclosure:cell];
		return cell;
	}
	cell.textLabel.text = TGL(@"Settings.ReactionPreview", @"Reaction Preview");
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.accessoryView = [self notificationSwitchOn:
			[TGSettingsViewController reactionPreview]
												tag:path.section * 10 + path.row];
	return cell;
}

- (UITableViewCell *)fillNotificationScopeCell:(UITableViewCell *)cell
											at:(NSIndexPath *)path {
	NSArray *rows = [TGSettingsViewController
		notificationRowsForSection:path.section];
	if ((NSUInteger)path.row >= rows.count)
		return cell;
	NSString *row = rows[path.row];
	NSDictionary *settings = [self settingsForScopeAtSection:path.section];
	NSString *scope = [TGSettingsViewController notificationScopes][path.section];

	if ([row isEqualToString:@"exceptions"]) {
		cell.textLabel.text = TGL(@"Notifications.MessageNotificationsExceptions", @"Exceptions");
		NSNumber *count = self.exceptionCounts[scope];
		cell.detailTextLabel.text = count ? [count stringValue] : @"";
		[self markDisclosure:cell];
		return cell;
	}

	BOOL on = NO;
	if ([row isEqualToString:@"alert"]) {
		cell.textLabel.text = TGL(@"Notifications.MessageNotificationsAlert", @"Alert");
		on = ![settings[@"muted"] boolValue];
	} else if ([row isEqualToString:@"preview"]) {
		cell.textLabel.text = TGL(@"Notifications.MessageNotificationsPreview", @"Message Preview");
		on = [settings[@"showPreview"] boolValue];
	} else if ([row isEqualToString:@"pinned"]) {
		cell.textLabel.text = TGL(@"Channel.AdminLogFilter.EventsPinned", @"Pinned messages");
		on = ![settings[@"disablePinnedMessageNotifications"] boolValue];
	} else {
		cell.textLabel.text = TGL(@"Settings.Mentions", @"Mentions");
		on = ![settings[@"disableMentionNotifications"] boolValue];
	}

	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.accessoryView = [self notificationSwitchOn:on
												tag:path.section * 10 + path.row];
	return cell;
}

- (UITableViewCell *)fillSoundCell:(UITableViewCell *)cell at:(NSIndexPath *)path {
	if (!self.savedSoundsLoaded) {
		cell.textLabel.text = TGL(@"Channel.NotificationLoading", @"Loading…");
		cell.textLabel.font = [UIFont systemFontOfSize:15];
		cell.textLabel.textColor = [[TGTheme shared] secondaryTextColour];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}
	NSDictionary *sound = self.savedSounds[path.row];
	if (![sound isKindOfClass:[NSDictionary class]])
		return cell;
	NSString *title = [sound[@"title"] isKindOfClass:[NSString class]]
		? sound[@"title"]
		: nil;
	cell.textLabel.text = title.length ? title : TGL(@"GroupInfo.Sound", @"Sound");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.detailTextLabel.text = TGSettingsDuration([sound[@"duration"] doubleValue]);
	return cell;
}

- (UITableViewCell *)fillExceptionCell:(UITableViewCell *)cell at:(NSIndexPath *)path {
	if (path.section == 1) {
		[TGIcons actionButtonInCell:cell
							  title:TGL(@"Notifications.DeleteAllExceptions", @"Delete All Exceptions")
							   kind:TGActionButtonKindDestructive
							 target:self
							 action:@selector(confirmClearExceptions)];
		return cell;
	}
	if (!self.exceptions.count) {
		cell.textLabel.text = TGExceptionsListText(self.exceptionsLoaded, self.exceptionsFailed);
		cell.textLabel.font = [UIFont systemFontOfSize:15];
		cell.textLabel.textColor = [[TGTheme shared] secondaryTextColour];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}
	NSDictionary *chat = self.exceptions[path.row];
	if (![chat isKindOfClass:[NSDictionary class]])
		return cell;
	NSString *title = [chat[@"title"] isKindOfClass:[NSString class]]
		? chat[@"title"]
		: nil;
	cell.textLabel.text = title.length ? title : TGL(@"ChatList.UnnamedChat", @"Chat");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	if ([self.exceptionsScope isEqualToString:TGSettingsStoriesExceptionsScope]) {
		cell.detailTextLabel.text = TGL(@"Notifications.ExceptionsMuted", @"Muted");
		return cell;
	}
	NSMutableArray *parts = [NSMutableArray array];
	[parts addObject:[chat[@"muted"] boolValue]
		? TGL(@"Notifications.ExceptionsMuted", @"Muted")
		: TGL(@"Notifications.ExceptionsUnmuted", @"Unmuted")];
	if (chat[@"showPreview"])
		[parts addObject:[chat[@"showPreview"] boolValue]
			? TGL(@"Notifications.ExceptionsPreviewOn", @"Preview On")
			: TGL(@"Notifications.ExceptionsPreviewOff", @"Preview Off")];
	if ([chat[@"customSound"] boolValue])
		[parts addObject:TGL(@"Notifications.ExceptionsCustomSound", @"Custom Sound")];
	cell.detailTextLabel.text = [parts componentsJoinedByString:@", "];
	return cell;
}

- (UITableViewCell *)fillStoriesCell:(UITableViewCell *)cell {
	cell.textLabel.text = TGL(@"Settings.ShowStories", @"Show Stories");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	UISwitch *toggle = [[UISwitch alloc] init];
	toggle.on = [TGPreferenceFlags storiesEnabled];
	[toggle addTarget:self action:@selector(storiesToggled:)
		forControlEvents:UIControlEventValueChanged];
	cell.accessoryView = toggle;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

- (UITableViewCell *)fillChatListLayoutCell:(UITableViewCell *)cell
										 at:(NSIndexPath *)path {
	NSArray *layouts = [TGPreferenceFlags chatListLayouts];
	if ((NSUInteger)path.row >= layouts.count)
		return cell;
	cell.textLabel.text = [TGPreferenceFlags chatListLayoutTitles][path.row];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	[self markChecked:[layouts[path.row] isEqualToString:
							  [TGPreferenceFlags chatListLayout]]
				   on:cell];
	return cell;
}

- (void)showTranslateToggled:(UISwitch *)toggle {
	[[NSUserDefaults standardUserDefaults] setBool:toggle.on
											forKey:TGSettingsShowTranslateKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (UITableViewCell *)fillTranslationCell:(UITableViewCell *)cell {
	cell.textLabel.text = TGL(@"Localization.ShowTranslate", @"Show Translate Button");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.detailTextLabel.text = nil;
	UISwitch *toggle = [[UISwitch alloc] init];
	toggle.on = [TGInAppNotificationPreferences showTranslateButton];
	[toggle addTarget:self action:@selector(showTranslateToggled:)
		forControlEvents:UIControlEventValueChanged];
	cell.accessoryView = toggle;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

- (UITableViewCell *)fillLanguageCell:(UITableViewCell *)cell at:(NSIndexPath *)path {
	if (path.section == TGSettingsLanguageSectionTranslation)
		return [self fillTranslationCell:cell];
	if (!self.languages.count) {
		cell.textLabel.text = TGLanguageListText(self.languagesLoaded, self.languagesFailed);
		cell.textLabel.font = [UIFont systemFontOfSize:15];
		cell.textLabel.textColor = [[TGTheme shared] secondaryTextColour];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}
	NSDictionary *language = self.languages[path.row];
	if (![language isKindOfClass:[NSDictionary class]])
		return cell;
	NSString *nativeName = [language[@"nativeName"] isKindOfClass:[NSString class]]
		? language[@"nativeName"]
		: nil;
	NSString *englishName = [language[@"name"] isKindOfClass:[NSString class]]
		? language[@"name"]
		: nil;
	NSString *languageName = nativeName.length ? nativeName : englishName;
	cell.textLabel.text = languageName.length ? languageName : TGL(@"Settings.AppLanguage", @"Language");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];

	NSMutableArray *parts = [NSMutableArray array];
	if (englishName.length && ![englishName isEqualToString:languageName])
		[parts addObject:englishName];
	if ([language[@"installed"] boolValue])
		[parts addObject:TGL(@"Localization.Downloaded", @"downloaded")];
	if (self.suggestedLanguage.length && [language[@"id"] isKindOfClass:[NSString class]] && [language[@"id"] isEqualToString:self.suggestedLanguage])
		[parts addObject:TGL(@"Localization.SuggestedHere", @"suggested here")];
	cell.detailTextLabel.text = [parts componentsJoinedByString:@" - "];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];

	[self markChecked:([language[@"id"] isKindOfClass:[NSString class]] && [language[@"id"] isEqualToString:self.currentLanguage]) on:cell];
	return cell;
}

- (UITableViewCell *)fillTextSizeCell:(UITableViewCell *)cell
								   at:(NSIndexPath *)path {
	NSArray *sizes = [TGTheme messageFontSizes];
	if ((NSUInteger)path.row >= sizes.count)
		return cell;
	cell.textLabel.text = [NSString stringWithFormat:@"%.0f %@", [sizes[path.row] floatValue],
		TGL(@"ChatSettings.TextSizeUnits", @"pt")];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	[self markChecked:(path.row == (NSInteger)[TGTheme shared].messageFontStep)
				   on:cell];
	return cell;
}

- (UITableViewCell *)fillAppearanceCell:(UITableViewCell *)cell at:(NSIndexPath *)indexPath {
	if (indexPath.section == 0) {
		cell.textLabel.text = TGL(@"Settings.ChatBackground", @"Chat Background");
		cell.detailTextLabel.text = [TGTheme shared].wallpaper ? TGL(@"Wallpaper.Set", @"Set") : TGL(@"Stickers.SuggestNone", @"None");
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		[self markDisclosure:cell];
		return cell;
	}

	if (indexPath.section == 1) {
		if (indexPath.row == 0) {
			cell.textLabel.text = TGL(@"ChatSettings.TextSize", @"Text Size");
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0f %@", [TGTheme shared].messageFontSize,
				TGL(@"ChatSettings.TextSizeUnits", @"pt")];
			cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		} else {
			cell.textLabel.text = TGL(@"ChatSettings.StickersAndReactions", @"Stickers and Emoji");
		}
		[self markDisclosure:cell];
		return cell;
	}

	if (indexPath.row == 0) {
		cell.textLabel.text = TGL(@"Settings.ChatList", @"Chat List");
		cell.detailTextLabel.text = [TGPreferenceFlags chatListLayoutTitle];
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
		[self markDisclosure:cell];
		return cell;
	}
	if (indexPath.row == 1)
		return [self fillStoriesCell:cell];
	if (indexPath.row == 2)
		return [self fillSavedAsListCell:cell];
	return [self fillCallsTabCell:cell];
}

- (UITableViewCell *)fillCallsTabCell:(UITableViewCell *)cell {
	cell.textLabel.text = TGL(@"CallSettings.TabIcon", @"Show Calls Tab");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.detailTextLabel.text = nil;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	UISwitch *toggle = [[UISwitch alloc] init];
	toggle.on = [TGTabBar callsTabEnabled];
	[toggle addTarget:self action:@selector(callsTabToggled:)
		forControlEvents:UIControlEventValueChanged];
	cell.accessoryView = toggle;
	return cell;
}

- (UITableViewCell *)fillSavedAsListCell:(UITableViewCell *)cell {
	cell.textLabel.text = TGL(@"Settings.SavedMessagesAsList", @"Saved Messages as List");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.detailTextLabel.text = nil;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	UISwitch *toggle = [[UISwitch alloc] init];
	toggle.on = [TGPreferenceFlags savedMessagesShowsTopics];
	[toggle addTarget:self action:@selector(savedTopicsToggled:)
		forControlEvents:UIControlEventValueChanged];
	cell.accessoryView = toggle;
	return cell;
}

- (UITableViewCell *)suggestionCellInTable:(UITableView *)tableView
										at:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGSettingsSuggestionCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:reuse];
	[[TGTheme shared] styleCell:cell];
	cell.accessoryType = UITableViewCellAccessoryNone;

	NSDictionary *suggestion = self.suggestions[indexPath.row];
	cell.textLabel.text = suggestion[@"title"];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.detailTextLabel.text = suggestion[@"subtitle"];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.numberOfLines = 2;
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];

	UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
	close.frame = CGRectMake(0, 0, 34, 34);
	UIImage *clear = [UIImage imageNamed:@"ClearInput.png"];
	if (clear) {
		[close setImage:clear forState:UIControlStateNormal];
		[close setImage:([UIImage imageNamed:@"ClearInput_Pressed.png"] ?: clear)
			   forState:UIControlStateHighlighted];
	} else {
		close.titleLabel.font = [UIFont boldSystemFontOfSize:17];
		[close setTitle:@"x" forState:UIControlStateNormal];
		[close setTitleColor:[[TGTheme shared] secondaryTextColour]
					forState:UIControlStateNormal];
	}
	close.accessibilityLabel = TGL(@"Common.Close", @"Close");
	close.tag = indexPath.row;
	[close addTarget:self action:@selector(suggestionDismissTapped:)
		forControlEvents:UIControlEventTouchUpInside];
	cell.accessoryView = close;
	return cell;
}

- (UITableViewCell *)fillAutoDownloadCell:(UITableViewCell *)cell at:(NSIndexPath *)path {
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];

	if (path.section == 0) {
		NSString *kind = [TGSettingsViewController networkKinds][path.row];
		cell.textLabel.text = [TGSettingsViewController networkTitles][path.row];
		cell.detailTextLabel.text = [self detailForNetwork:kind];
		[self markDisclosure:cell];
		return cell;
	}

	cell.textLabel.text = TGL(@"ChatSettings.UseLessDataForCalls", @"Use less data for calls");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	UISwitch *toggle = [[UISwitch alloc] init];
	toggle.on = self.lessCallData;
	[toggle addTarget:self action:@selector(lessCallDataToggled:)
		forControlEvents:UIControlEventValueChanged];
	cell.accessoryView = toggle;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

@end

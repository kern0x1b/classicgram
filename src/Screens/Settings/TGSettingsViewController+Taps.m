#import "TGImageDecode.h"
#import "TGAccountUsernamesViewController.h"
#import "TGAccountSettingsViewController.h"
#import "TGLocalization.h"
#import "TGNotificationManager.h"
#import "TGPopupMenu.h"
#import "TGSnackbar.h"
#import "TGClient+Notifications.h"
#import "TGSettingsViewController.h"
#import "TGEmoji.h"
#import "RootViewController.h"
#import "TGTheme.h"
#import "TGStorageViewController.h"
#import "TGSessionsViewController.h"
#import "TGDeviceViewController.h"
#import "TGWebBrowserSettingsViewController.h"
#import "TGWebViewController.h"
#import "TGDevice.h"
#import "TGEditProfileViewController.h"
#import "TGCallsViewController.h"
#import "TGStickersViewController.h"
#import "TGContactsService.h"
#import "TGFoldersViewController.h"
#import "TGProxyViewController.h"
#import "TGPrivacyViewController.h"
#import "TGPremiumViewController.h"
#import "TGStarsViewController.h"
#import "TGPrivacyViewController.h"
#import "TGSavedMessagesTagsViewController.h"
#import "TGSavedMessagesViewController.h"
#import "TGChatViewController.h"
#import "TGTabBar.h"
#import "TGStoriesViewController.h"
#import "TGGroupMembersViewController.h"
#import "TGInviteLinksViewController.h"
#import "TGChatEventsViewController.h"
#import "TGSettingsService.h"
#import "TGPreferenceFlags.h"
#import "TGCapabilities.h"
#import "TGAccountManager.h"
#import "TGPhoneFormat.h"
#import "TGBotVerificationViewController.h"
#import "TGPublicPostSearchViewController.h"
#import "TGIcons.h"
#import <QuartzCore/QuartzCore.h>
#import "TGSettingsViewControllerInternal.h"
#import "TGActionSheetIndexBuilder.h"

@implementation TGSettingsViewController (Taps)

#pragma mark - taps

- (void)notificationToggled:(UISwitch *)toggle {
	NSInteger section = toggle.tag / 10;
	NSInteger row = toggle.tag % 10;

	if (section == TGSettingsNotifSectionReactions) {
		[self writeReactionSource:[TGSettingsViewController reactionSource]
				   pollVoteSource:[TGSettingsViewController pollVoteSource]
						  preview:toggle.on];
		return;
	}

	if (section == TGSettingsNotifSectionContacts) {
		self.contactRegisteredMuted = !toggle.on;
		[TGSettingsService setOptionNamed:TGSettingsContactRegisteredOption
									value:@(!toggle.on)
								isBoolean:YES];
		return;
	}

	if (section == TGSettingsNotifSectionBadge) {
		if (row == 0)
			[TGPreferenceFlags setBadgeCountsUnreadChats:!toggle.on];
		else
			[TGPreferenceFlags setBadgeIncludesMuted:toggle.on];
		if ([self.tabBarController isKindOfClass:[RootViewController class]])
			[(RootViewController *)self.tabBarController updateUnreadBadge];
		return;
	}

	if (section == TGSettingsNotifSectionInApp) {
		NSString *key = row == 0 ? TGSettingsInAppSoundsKey
			: row == 1			 ? TGSettingsInAppVibrateKey
								 : TGSettingsInAppPreviewKey;
		[[NSUserDefaults standardUserDefaults] setBool:toggle.on forKey:key];
		[[NSUserDefaults standardUserDefaults] synchronize];
		return;
	}

	[self applyScopeToggle:toggle section:section row:row];
}

- (NSDictionary *)scopeChangesForKind:(NSString *)kind on:(BOOL)on {
	if ([kind isEqualToString:@"alert"])
		return @{@"muteFor" : @(on ? 0 : [TGSettingsService notificationMuteForever])};
	if ([kind isEqualToString:@"preview"])
		return @{@"showPreview" : @(on)};
	if ([kind isEqualToString:@"pinned"])
		return @{@"disablePinnedMessageNotifications" : @(!on)};
	if ([kind isEqualToString:@"mentions"])
		return @{@"disableMentionNotifications" : @(!on)};
	return nil;
}

- (void)applyScopeToggle:(UISwitch *)toggle
				 section:(NSInteger)section
					 row:(NSInteger)row {
	NSArray *rows = [TGSettingsViewController notificationRowsForSection:section];
	if ((NSUInteger)row >= rows.count)
		return;
	NSString *kind = rows[row];
	NSString *scope = [TGSettingsViewController notificationScopes][section];

	NSDictionary *changes = [self scopeChangesForKind:kind on:toggle.on];
	if (!changes)
		return;

	NSDictionary *previousSettings = self.scopeSettings[scope];
	NSNumber *previousMuted = self.muted[scope];

	NSMutableDictionary *merged = [NSMutableDictionary dictionary];
	if (previousSettings)
		[merged addEntriesFromDictionary:previousSettings];
	[merged addEntriesFromDictionary:changes];
	if ([kind isEqualToString:@"alert"]) {
		merged[@"muted"] = @(!toggle.on);
		self.muted[scope] = @(!toggle.on);
	}
	self.scopeSettings[scope] = merged;

	__weak typeof(self) weakSelf = self;
	[TGSettingsService updateScope:scope values:changes completion:^(BOOL ok) {
		if (ok)
			return;
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (previousSettings)
			strongSelf.scopeSettings[scope] = previousSettings;
		else
			[strongSelf.scopeSettings removeObjectForKey:scope];
		if (previousMuted)
			strongSelf.muted[scope] = previousMuted;
		else
			[strongSelf.muted removeObjectForKey:scope];
		[strongSelf.tableView reloadData];
		[TGSnackbar showInView:strongSelf.view
						   text:TGL(@"Toast.CouldNotChangeNotificationSettings", @"Could not change notification settings")
						seconds:2
					   onCommit:nil];
	}];
}

- (void)openExceptionsForScope:(NSString *)scope {
	TGSettingsViewController *next = [[TGSettingsViewController alloc] init];
	next.exceptionsScope = scope;
	next.page = (TGSettingsPage)TGSettingsPageNotificationExceptions;
	[self.navigationController pushViewController:next animated:YES];
}

- (void)tapNotifications:(NSIndexPath *)path {
	if (path.section <= TGSettingsNotifSectionChannels) {
		NSArray *rows = [TGSettingsViewController
			notificationRowsForSection:path.section];
		if ((NSUInteger)path.row < rows.count && [rows[path.row] isEqualToString:@"exceptions"])
			[self openExceptionsForScope:
					[TGSettingsViewController notificationScopes][path.section]];
		return;
	}
	if (path.section == TGSettingsNotifSectionStories) {
		[self openExceptionsForScope:TGSettingsStoriesExceptionsScope];
		return;
	}
	if (path.section == TGSettingsNotifSectionSounds) {
		if (path.row == 0)
			[self openNotificationTone];
		else
			[self openNotificationSounds];
		return;
	}
	if (path.section == TGSettingsNotifSectionReactions && path.row == 1) {
		[self showPollVoteSourceSheet];
		return;
	}
	if (path.section == TGSettingsNotifSectionReactions && path.row == 0) {
		[self showReactionSourceSheet];
		return;
	}
	if (path.section == TGSettingsNotifSectionReset)
		[self confirmResetAllNotifications];
}

- (void)showPollVoteSourceSheet {
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"Settings.NotifyAboutPollVotesFrom", @"Notify about poll votes from")
					  delegate:self
				   otherTitles:@[ TGL(@"PrivacySettings.LastSeenEverybody", @"Everybody"),
					   TGL(@"PrivacySettings.LastSeenContacts", @"My Contacts"),
					   TGL(@"PrivacySettings.LastSeenNobody", @"Nobody") ]
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 142;
	[self showSheet:sheet];
}

- (void)showReactionSourceSheet {
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"Notifications.Reactions.SheetTitleMessages", @"Notify about reactions from")
					  delegate:self
				   otherTitles:@[ TGL(@"PrivacySettings.LastSeenEverybody", @"Everybody"),
					   TGL(@"PrivacySettings.LastSeenContacts", @"My Contacts"),
					   TGL(@"PrivacySettings.LastSeenNobody", @"Nobody") ]
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 141;
	[self showSheet:sheet];
}

- (void)confirmResetAllNotifications {
	UIAlertView *confirm = [[UIAlertView alloc]
			initWithTitle:TGL(@"Notifications.ResetAllNotifications", @"Reset All Notifications")
				  message:TGL(@"Notifications.ResetAllNotificationsText", @"Are you sure you want to reset all notification settings to default?")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Notifications.Reset", @"Reset"), nil];
	confirm.tag = 404;
	[confirm show];
}

- (BOOL)canClearExceptions {
	if ((NSInteger)self.page != TGSettingsPageNotificationExceptions)
		return NO;
	if ([self.exceptionsScope isEqualToString:TGSettingsStoriesExceptionsScope])
		return NO;
	return self.exceptions.count > 0;
}

- (void)confirmClearExceptions {
	UIAlertView *confirm = [[UIAlertView alloc]
			initWithTitle:TGL(@"Notifications.DeleteAllExceptions", @"Delete All Exceptions")
				  message:TGL(@"Notification.Exceptions.DeleteAllConfirmation", @"Are you sure you want to delete all exceptions?")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Notification.Exceptions.DeleteAll", @"Delete All"), nil];
	confirm.tag = 407;
	[confirm show];
}

- (void)openNotificationSounds {
	TGSettingsViewController *next = [[TGSettingsViewController alloc] init];
	next.page = (TGSettingsPage)TGSettingsPageNotificationSounds;
	[self.navigationController pushViewController:next animated:YES];
}

- (void)openNotificationTone {
	TGSettingsViewController *next = [[TGSettingsViewController alloc] init];
	next.page = (TGSettingsPage)TGSettingsPageNotificationTone;
	[self.navigationController pushViewController:next animated:YES];
}

- (UITableViewCell *)fillToneCell:(UITableViewCell *)cell at:(NSIndexPath *)path {
	NSArray *ids = [TGNotificationManager builtInToneIds];
	long long selected = [TGNotificationManager selectedToneId];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	if (path.row == 0) {
		cell.textLabel.text = TGL(@"UserInfo.NotificationsDefault", @"Default");
		[self markChecked:![ids containsObject:@(selected)] on:cell];
		return cell;
	}
	NSNumber *toneId = ids[(NSUInteger)path.row - 1];
	cell.textLabel.text = [TGNotificationManager builtInToneNames][(NSUInteger)path.row - 1];
	[self markChecked:[toneId longLongValue] == selected on:cell];
	return cell;
}

- (void)tapTone:(NSIndexPath *)path {
	NSArray *ids = [TGNotificationManager builtInToneIds];
	if (path.row == 0) {
		[TGNotificationManager setSelectedToneId:-1];
	} else if ((NSUInteger)path.row - 1 < ids.count) {
		long long toneId = [ids[(NSUInteger)path.row - 1] longLongValue];
		[TGNotificationManager setSelectedToneId:toneId];
		[TGNotificationManager previewToneId:toneId];
	}
	[self.tableView reloadData];
}

- (void)loadSavedSounds {
	__weak typeof(self) weakSelf = self;
	[TGSettingsService savedNotificationSoundsWithCompletion:^(NSArray *sounds) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.savedSounds = [sounds isKindOfClass:[NSArray class]] ? sounds : @[];
		strongSelf.savedSoundsLoaded = YES;
		[strongSelf.tableView reloadData];
	}];
}

- (void)tapSound:(NSIndexPath *)path {
	if ((NSUInteger)path.row >= self.savedSounds.count)
		return;
	NSDictionary *sound = self.savedSounds[path.row];
	if (![sound isKindOfClass:[NSDictionary class]] || ![sound[@"id"] longLongValue])
		return;
	self.pressedSound = sound;
	NSString *title = [sound[@"title"] isKindOfClass:[NSString class]]
		? sound[@"title"]
		: @"Sound";
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:title.length ? title : TGL(@"GroupInfo.Sound", @"Sound")
					  delegate:self
				   otherTitles:@[ TGL(@"PeerInfo.DeleteToneTitle", @"Delete Sound") ]
			  destructiveIndex:0
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 155;
	[self showSheet:sheet];
}

- (void)tapException:(NSIndexPath *)path {
	if (path.section == 1) {
		[self confirmClearExceptions];
		return;
	}
	if ((NSUInteger)path.row >= self.exceptions.count)
		return;
	NSDictionary *chat = self.exceptions[path.row];
	if (![chat isKindOfClass:[NSDictionary class]])
		return;
	int64_t chatId = [chat[@"id"] longLongValue];
	if (chatId == 0)
		return;

	[self showNotificationOptionsForExceptionChat:chatId atIndexPath:path];
}

- (void)showNotificationOptionsForExceptionChat:(int64_t)chatId atIndexPath:(NSIndexPath *)path {
	if ([self.exceptionsScope isEqualToString:TGSettingsStoriesExceptionsScope]) {
		[self removeExceptionForChatId:chatId];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] notificationSettingsForChat:chatId completion:^(NSDictionary *reply) {
		TGSettingsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSDictionary *settings = [reply isKindOfClass:[NSDictionary class]] ? reply : nil;
		if (!settings)
			return;

		BOOL muted = [settings[@"muted"] boolValue];
		BOOL preview = [settings[@"showPreview"] boolValue];

		NSArray *items = @[
			@{@"title" : muted ? TGL(@"ChatList.Context.Unmute", @"Unmute") : TGL(@"ChatList.Context.Mute", @"Mute")},
			@{@"title" : preview ? TGL(@"Notification.Exceptions.PreviewAlwaysOff", @"Hide Message Text") : TGL(@"Notification.Exceptions.PreviewAlwaysOn", @"Show Message Text")},
			@{@"title" : TGL(@"Notifications.ExceptionsResetToDefaults", @"Use Default Settings")},
		];

		CGRect rowFrame = [strongSelf.tableView rectForRowAtIndexPath:path];
		CGPoint point = [strongSelf.tableView convertPoint:CGPointMake(CGRectGetMidX(rowFrame), CGRectGetMidY(rowFrame))
											 toView:strongSelf.navigationController.view];

		[TGPopupMenu showItems:items atPoint:point inView:strongSelf.navigationController.view
					  onChoice:^(NSInteger choice, NSString *title) {
						  (void)title;
						  TGSettingsViewController *innerSelf = weakSelf;
						  if (!innerSelf)
							  return;
						  if (choice == 0)
							  [innerSelf showMuteDurationsForExceptionChat:chatId muted:muted];
						  else if (choice == 1)
							  [innerSelf togglePreviewForExceptionChat:chatId currentlyOn:preview];
						  else if (choice == 2)
							  [innerSelf removeExceptionForChatId:chatId];
					  }];
	}];
}

- (void)reportExceptionSettingCouldNotBeChanged {
	[TGSnackbar showInView:self.view
					   text:TGL(@"Toast.CouldNotChangeNotificationSettings", @"Could not change notification settings")
					seconds:2
				   onCommit:nil];
}

- (void)showMuteDurationsForExceptionChat:(int64_t)chatId muted:(BOOL)muted {
	__weak typeof(self) weakSelf = self;
	if (muted) {
		[[TGClient shared] setChat:chatId muteForSeconds:0 completion:^(BOOL ok) {
			if (ok)
				return;
			TGSettingsViewController *strongSelf = weakSelf;
			[strongSelf reportExceptionSettingCouldNotBeChanged];
		}];
		return;
	}

	NSArray *items = @[
		@{@"title" : TGL(@"Notification.Mute1h", @"Mute for 1 hour")},
		@{@"title" : TGLPlural(@"MuteFor.Hours", 8, @"Mute for %@ hour", @"Mute for %@ hours")},
		@{@"title" : TGL(@"MuteFor.Days_2", @"Mute for 2 days")},
		@{@"title" : TGL(@"MuteFor.Forever", @"Mute forever")},
	];
	NSArray *seconds = @[ @(3600), @(8 * 3600), @(2 * 24 * 3600), @(kNotificationMuteForever) ];

	[TGPopupMenu showItems:items atPoint:self.view.center inView:self.navigationController.view
				  onChoice:^(NSInteger choice, NSString *title) {
					  (void)title;
					  TGSettingsViewController *strongSelf = weakSelf;
					  if (!strongSelf || choice < 0 || choice >= (NSInteger)seconds.count)
						  return;
					  [[TGClient shared] setChat:chatId
								  muteForSeconds:[seconds[choice] integerValue]
									  completion:^(BOOL ok) {
						  if (ok)
							  return;
						  TGSettingsViewController *innerSelf = weakSelf;
						  [innerSelf reportExceptionSettingCouldNotBeChanged];
					  }];
				  }];
}

- (void)togglePreviewForExceptionChat:(int64_t)chatId currentlyOn:(BOOL)preview {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] updateChat:chatId
						   values:@{@"showPreview" : @(!preview),
							   @"useDefaultShowPreview" : @NO}
					   completion:^(BOOL ok) {
		if (ok)
			return;
		TGSettingsViewController *strongSelf = weakSelf;
		[strongSelf reportExceptionSettingCouldNotBeChanged];
	}];
}

- (void)removeExceptionForChatId:(int64_t)chatId {
	NSUInteger row = [self.exceptions indexOfObjectPassingTest:
			^BOOL(NSDictionary *chat, NSUInteger idx, BOOL *stop) {
				(void)idx;
				(void)stop;
				return [chat[@"id"] longLongValue] == chatId;
			}];
	if (row == NSNotFound)
		return;

	NSDictionary *removed = self.exceptions[row];
	NSMutableArray *rest = [self.exceptions mutableCopy];
	[rest removeObjectAtIndex:row];
	self.exceptions = rest;
	[self.tableView reloadData];

	if ([self.exceptionsScope isEqualToString:TGSettingsStoriesExceptionsScope]) {
		[TGSettingsService setChat:chatId storiesMuted:NO];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[TGSettingsService resetNotificationSettingsForChat:chatId
											  completion:^(BOOL ok) {
		if (ok)
			return;
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || !removed)
			return;
		NSMutableArray *restored = [strongSelf.exceptions mutableCopy];
		NSUInteger insertAt = MIN(row, restored.count);
		[restored insertObject:removed atIndex:insertAt];
		strongSelf.exceptions = restored;
		[strongSelf.tableView reloadData];
		[TGSnackbar showInView:strongSelf.view
						   text:TGL(@"Toast.CouldNotChangeNotificationException", @"Could not remove this notification exception")
						seconds:2
					   onCommit:nil];
	}];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	self.detailPaneShown = NO;
	[self handleSelectionAtIndexPath:indexPath inTable:tableView];
	if (indexPath.section >= [tableView numberOfSections] || indexPath.row >= [tableView numberOfRowsInSection:indexPath.section])
		return;
	if (self.detailPaneShown) {
		[tableView selectRowAtIndexPath:indexPath animated:NO
						 scrollPosition:UITableViewScrollPositionNone];
		return;
	}
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)handleSelectionAtIndexPath:(NSIndexPath *)indexPath
						   inTable:(UITableView *)tableView {
	if ((NSInteger)self.page == TGSettingsPageAutoDownloadKind) {
		[self tapAutoDownloadKind:indexPath];
		return;
	}

	if ((NSInteger)self.page == TGSettingsPageAutoDownload) {
		[self tapAutoDownload:indexPath];
		return;
	}
	if ((NSInteger)self.page == TGSettingsPageAutosave) {
		if (indexPath.section == 4)
			[self confirmClearAutosaveExceptions];
		return;
	}
	if ((NSInteger)self.page == TGSettingsPageDataUsage) {
		if (indexPath.section == TGSettingsUsageSectionReset)
			[self confirmResetUsage];
		return;
	}
	if ((NSInteger)self.page == TGSettingsPageWallpaper) {
		[self tapWallpaper:indexPath];
		return;
	}
	if ((NSInteger)self.page == TGSettingsPageNotificationExceptions) {
		[self tapException:indexPath];
		return;
	}
	if ((NSInteger)self.page == TGSettingsPageNotificationSounds) {
		[self tapSound:indexPath];
		return;
	}
	if ((NSInteger)self.page == TGSettingsPageNotificationTone) {
		[self tapTone:indexPath];
		return;
	}
	if ((NSInteger)self.page == TGSettingsPageChatListLayout) {
		NSArray *layouts = [TGPreferenceFlags chatListLayouts];
		if ((NSUInteger)indexPath.row < layouts.count)
			[TGPreferenceFlags setChatListLayout:layouts[indexPath.row]];
		[tableView reloadData];
		return;
	}
	if ((NSInteger)self.page == TGSettingsPageTextSize) {
		if ((NSUInteger)indexPath.row < [TGTheme messageFontSizes].count)
			[TGTheme shared].messageFontStep = (NSUInteger)indexPath.row;
		[tableView reloadData];
		return;
	}

	switch (self.page) {
		case TGSettingsPageAppearance:
			[self tapAppearance:indexPath];
			return;
		case TGSettingsPageNotifications:
			[self tapNotifications:indexPath];
			return;
		case TGSettingsPageLanguage:
			[self tapLanguage:indexPath];
			return;
		case TGSettingsPageData:
			[self tapData:indexPath];
			return;
		default:
			break;
	}

	[self tapRootRowAtIndexPath:indexPath];
}

- (void)tapRootRowAtIndexPath:(NSIndexPath *)indexPath {
	NSInteger kind = [self rootKindForSection:indexPath.section];

	if (kind == TGSettingsRootKindSuggestions) {
		[self acceptSuggestionAtRow:indexPath.row];
		return;
	}

	if (kind == TGSettingsRootKindPhoto)
		return;

	if (kind == TGSettingsRootKindAccounts) {
		NSArray *accounts = [[TGAccountManager shared] accounts];
		if ((NSUInteger)indexPath.row >= accounts.count) {
			[[TGAccountManager shared] beginAddingAccount];
			return;
		}
		NSDictionary *account = [accounts objectAtIndex:(NSUInteger)indexPath.row];
		NSInteger slot = [account[@"slot"] integerValue];
		if (slot != [TGAccountManager shared].currentSlot)
			[[TGAccountManager shared] switchToSlot:slot];
		return;
	}

	if (kind == TGSettingsRootKindProfile) {
		UIViewController *next = indexPath.row == 0
			? (UIViewController *)[[TGEditProfileViewController alloc] init]
			: (UIViewController *)[[TGAccountSettingsViewController alloc] init];
		[self openViewController:next];
		return;
	}

	if (kind == TGSettingsRootKindProxy) {
		[self openViewController:[[TGProxyViewController alloc] init]];
		return;
	}

	if (kind == TGSettingsRootKindShortcuts) {
		[self tapShortcutRow:indexPath.row];
		return;
	}

	if (kind == TGSettingsRootKindAdvanced) {
		[self tapAdvancedRow:indexPath.row];
		return;
	}

	if (kind == TGSettingsRootKindPayment) {
		[self tapPaymentRow:indexPath.row];
		return;
	}

	if (kind == TGSettingsRootKindExtra) {
		if (indexPath.row == 0) {
			[self openViewController:[[TGBotVerificationViewController alloc] init]];
			return;
		}
		if (indexPath.row == 1) {
			[self openViewController:[[TGPublicPostSearchViewController alloc] init]];
			return;
		}
		return;
	}

	if (kind == TGSettingsRootKindHelp) {
		if ((NSUInteger)indexPath.row < [TGSettingsViewController helpRows].count)
			[self openHelp:indexPath.row];
		return;
	}

	[self confirmLogout];
}

- (void)tapShortcutRow:(NSInteger)row {
	if (row == 0) {
		[self openViewController:[self savedMessagesController]];
		return;
	}
	if (row == 1) {
		[self openViewController:
				[[TGSavedMessagesTagsViewController alloc] initWithTopicId:0]];
		return;
	}
	if (row == 2) {
		TGCallsViewController *calls = [[TGCallsViewController alloc] init];
		calls.pushedStandalone = YES;
		[self openViewController:calls];
		return;
	}
	if (row == 3) {
		[self openViewController:[[TGSessionsViewController alloc] init]];
		return;
	}
	if (row == 4) {
		TGFoldersViewController *folders = [[TGFoldersViewController alloc] init];
		folders.page = TGFoldersPageList;
		[self openViewController:folders];
		return;
	}
	[self openViewController:[TGStoriesViewController myStoriesController]];
}

- (void)tapAdvancedRow:(NSInteger)row {
	switch (row) {
		case 0:
			[self openPage:TGSettingsPageNotifications];
			break;
		case 1:
			[self openViewController:[[TGPrivacyViewController alloc] init]];
			break;
		case 2:
			[self openPage:TGSettingsPageData];
			break;
		case 3:
			[self openPage:TGSettingsPageAppearance];
			break;
		default:
			[self openPage:TGSettingsPageLanguage];
			break;
	}
}

- (void)tapPaymentRow:(NSInteger)row {
	[self openViewController:(row == 0
									 ? (UIViewController *)[[TGPremiumViewController alloc] init]
									 : (UIViewController *)[[TGStarsViewController alloc] init])];
}

- (void)tapData:(NSIndexPath *)indexPath {
	if (indexPath.section == 0 && indexPath.row == 0) {
		TGStorageViewController *storage = [[TGStorageViewController alloc] init];
		[self openViewController:storage];
	} else if (indexPath.section == 0 && indexPath.row == 1) {
		[self openPage:(TGSettingsPage)TGSettingsPageDataUsage];
	} else if (indexPath.section == 0 && indexPath.row == 2) {
		[self openPage:(TGSettingsPage)TGSettingsPageAutoDownload];
	} else if (indexPath.section == 0 && indexPath.row == 3) {
		[self openPage:(TGSettingsPage)TGSettingsPageAutosave];
	} else if (indexPath.section == 0 && indexPath.row == 4) {
		[self openViewController:[[TGDeviceViewController alloc] init]];
	} else if (indexPath.section == 0 && indexPath.row == 5) {
		[self openViewController:[[TGWebBrowserSettingsViewController alloc] init]];
	} else if (indexPath.section == 1 && indexPath.row == 3) {
		[self confirmDeleteSyncedContacts];
	} else if (indexPath.section == 3) {
		[self confirmClearDatabase];
	}
}

- (void)confirmDeleteSyncedContacts {
	UIAlertView *confirm = [[UIAlertView alloc]
			initWithTitle:nil
				  message:TGL(@"Privacy.ContactsResetConfirmation", @"This will remove your contacts from the Telegram servers.\nIf 'Sync Contacts' is enabled, contacts will be re-synced.")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Privacy.ContactsReset", @"Delete Synced Contacts"), nil];
	confirm.tag = 408;
	[confirm show];
}

- (void)confirmedDeleteSyncedContacts {
	[TGContactsService contactsWithCompletion:^(NSArray *users) {
		NSMutableArray *userIds = [NSMutableArray array];
		for (NSDictionary *user in users) {
			NSNumber *userId = user[@"id"];
			if ([userId isKindOfClass:NSNumber.class] && [userId longLongValue] != 0)
				[userIds addObject:userId];
		}
		[TGContactsService removeContacts:userIds completion:^(BOOL ok) {
			[TGContactsService clearImportedContactsWithCompletion:nil];
		}];
	}];
}

- (void)confirmLogout {
	UIAlertView *confirm = [[UIAlertView alloc]
			initWithTitle:TGL(@"LogoutOptions.Title", @"Log out")
				  message:TGL(@"Settings.LogoutConfirmationTitle", @"Sign out of this account on this device?")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"LogoutOptions.Title", @"Log out"), nil];
	confirm.tag = 401;
	[confirm show];
}

- (void)confirmClearDatabase {
	UIAlertView *confirm = [[UIAlertView alloc]
			initWithTitle:TGL(@"Cache.ClearCache", @"Clear local database")
				  message:TGL(@"ClearCache.Description", @"Messages and media cached on this device are removed. Nothing is deleted from Telegram itself.")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"WebSearch.RecentSectionClear", @"Clear"), nil];
	confirm.tag = 402;
	[confirm show];
}

- (UIViewController *)savedMessagesController {
	int64_t chatId = [TGSettingsService savedMessagesChatId];
	if ([TGPreferenceFlags savedMessagesShowsTopics] || !chatId)
		return [[TGSavedMessagesViewController alloc] init];
	TGChatViewController *chat = [[TGChatViewController alloc] init];
	chat.chatId = chatId;
	chat.chatTitle = TGL(@"Settings.SavedMessages", @"Saved Messages");
	return chat;
}

- (void)savedTopicsToggled:(UISwitch *)toggle {
	[TGPreferenceFlags setSavedMessagesShowsTopics:toggle.on];
}

- (void)callsTabToggled:(UISwitch *)toggle {
	[TGTabBar setCallsTabEnabled:toggle.on];
}

- (void)openHelp:(NSInteger)row {
	if (row == 0) {
		__weak typeof(self) weakSelf = self;
		[TGSettingsService chatWithUsername:@"BotSupport" completion:^(int64_t chatId, NSString *title) {
			if (!chatId)
				return;
			[weakSelf openSupportChat:chatId title:title];
		}];
		return;
	}
	NSString *url = (row == 1) ? @"https://telegram.org/faq"
							   : @"https://telegram.org/privacy";
	UIViewController *browser = [TGWebViewController controllerForURLString:url];
	if (browser)
		[self openViewController:browser];
	else
		[TGWebViewController openURLString:url fromViewController:self];
}

- (void)openSupportChat:(int64_t)chatId title:(NSString *)title {
	if (!self.navigationController) {
		UIAlertView *alert = [UIAlertView alloc];
		alert = [alert initWithTitle:TGL(@"SettingsSearch.Synonyms.Support", @"Support")
							 message:TGL(@"Settings.TheSupportChatCouldNotBe", @"The support chat could not be opened.")
							delegate:nil
				   cancelButtonTitle:TGL(@"Common.OK", @"OK")
				   otherButtonTitles:nil];
		[alert show];
		return;
	}
	TGChatViewController *chat = [[TGChatViewController alloc] init];
	chat.chatId = chatId;
	chat.chatTitle = title.length ? title : @"Telegram Support";
	[self openViewController:chat];
}

- (void)tapLanguage:(NSIndexPath *)indexPath {
	if (indexPath.section == TGSettingsLanguageSectionTranslation)
		return;
	if ((NSUInteger)indexPath.row >= self.languages.count)
		return;
	NSDictionary *language = self.languages[indexPath.row];
	if (![language[@"id"] isKindOfClass:[NSString class]])
		return;
	NSString *packId = language[@"id"];
	NSString *previousLanguage = self.currentLanguage;
	[TGSettingsService setLanguage:packId];
	[TGSettingsService synchronizeLanguagePack:packId];
	self.currentLanguage = packId;
	[self.tableView reloadData];

	if ([packId isEqualToString:@"en"]) {
		[[TGLocalization shared] clearInstalledPack];
		return;
	}
	NSString *pluralCode = [language[@"pluralCode"] isKindOfClass:[NSString class]]
		? language[@"pluralCode"]
		: packId;
	BOOL rtl = [language[@"rtl"] boolValue];
	__weak typeof(self) weakSelf = self;
	[TGSettingsService languagePackStrings:packId keys:nil
							completion:^(NSDictionary *strings) {
								__strong typeof(weakSelf) strongSelf = weakSelf;
								if (!strongSelf || ![strongSelf.currentLanguage isEqualToString:packId])
									return;
								if (!strings) {
									[TGSettingsService setLanguage:previousLanguage];
									strongSelf.currentLanguage = previousLanguage;
									[strongSelf.tableView reloadData];
									UIAlertView *alert = [UIAlertView alloc];
									alert = [alert initWithTitle:@""
													 message:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")
													delegate:nil
											   cancelButtonTitle:TGL(@"Common.OK", @"OK")
											   otherButtonTitles:nil];
									[alert show];
									return;
								}
								[[TGLocalization shared] installPackId:packId strings:strings pluralCode:pluralCode rtl:rtl];
							}];
}

- (void)longPressed:(UILongPressGestureRecognizer *)gesture {
	if (gesture.state != UIGestureRecognizerStateBegan)
		return;
	NSIndexPath *path = [self.tableView indexPathForRowAtPoint:
			[gesture locationInView:self.tableView]];
	if (!path)
		return;

	if ((NSInteger)self.page == TGSettingsPageNotificationSounds) {
		[self tapSound:path];
		return;
	}

	if ((NSInteger)self.page != TGSettingsPageWallpaper || path.section != 2)
		return;
	[self pressBackgroundAtRow:path.row];
}

- (void)pressBackgroundAtRow:(NSInteger)row {
	if ((NSUInteger)row >= self.backgrounds.count)
		return;
	NSDictionary *background = self.backgrounds[row];
	if (![background isKindOfClass:[NSDictionary class]])
		return;
	self.pressedBackground = background;
	NSInteger cancelIndex;
	NSInteger ordinal = [self ordinalOfBackgroundAtRow:row];
	NSString *sheetTitle = [TGSettingsViewController titleForBackground:background at:ordinal];
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:sheetTitle
					  delegate:self
				   otherTitles:@[ TGL(@"GroupInfo.InviteLink.CopyLink", @"Copy Link"),
					   TGLPlural(@"Wallpaper.DeleteConfirmation", 1, @"Delete Background", @"Delete %@ Backgrounds") ]
			  destructiveIndex:1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 152;
	[self showSheet:sheet];
}

- (void)tapAppearance:(NSIndexPath *)indexPath {
	if (indexPath.section == 0) {
		[self openPage:(TGSettingsPage)TGSettingsPageWallpaper];
		return;
	}

	if (indexPath.section == 1) {
		if (indexPath.row == 0) {
			[self openPage:(TGSettingsPage)TGSettingsPageTextSize];
		} else {
			TGStickersViewController *stickers = [[TGStickersViewController alloc] init];
			stickers.page = TGStickersPageRoot;
			[self openViewController:stickers];
		}
		return;
	}

	if (indexPath.row == 0)
		[self openPage:(TGSettingsPage)TGSettingsPageChatListLayout];
}

@end

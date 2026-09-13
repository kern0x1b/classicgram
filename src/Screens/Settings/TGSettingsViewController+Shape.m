#import "TGImageDecode.h"
#import "TGDateUtils.h"
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

@implementation TGSettingsViewController (Shape)

#pragma mark - account switch

+ (void)resetAutoDownloadPresetCacheForAccountSwitch {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:TGSettingsPresetDefaultsKey];
	[defaults synchronize];
}

#pragma mark - shape

+ (NSArray *)networkKinds {
	static NSArray *kinds = nil;
	if (!kinds)
		kinds = @[ @"wifi", @"mobile", @"roaming" ];
	return kinds;
}

+ (NSArray *)networkTitles {
	return @[ TGL(@"NetworkUsageSettings.Wifi", @"Wi-Fi"),
		TGL(@"NetworkUsageSettings.Cellular", @"Cellular"),
		TGL(@"Settings.Roaming", @"Roaming") ];
}

+ (NSArray *)presetNames {
	static NSArray *names = nil;
	if (!names)
		names = @[ @"low", @"medium", @"high" ];
	return names;
}

+ (NSArray *)autosaveScopes {
	static NSArray *scopes = nil;
	if (!scopes)
		scopes = @[ @"private", @"groups", @"channels" ];
	return scopes;
}

+ (NSArray *)autosaveTitles {
	return @[ TGL(@"ChatSettings.PrivateChats", @"Private Chats"),
		TGL(@"ChatSettings.Groups", @"Groups"),
		TGL(@"AutoDownloadSettings.Channels", @"Channels") ];
}

- (NSString *)presetNameForNetwork:(NSString *)kind {
	NSDictionary *stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGSettingsPresetDefaultsKey];
	if ([stored isKindOfClass:[NSDictionary class]] && [stored[kind] isKindOfClass:[NSString class]])
		return stored[kind];
	return nil;
}

- (void)rememberPreset:(NSString *)name forNetwork:(NSString *)kind {
	NSDictionary *stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGSettingsPresetDefaultsKey];
	NSMutableDictionary *next = [stored isKindOfClass:[NSDictionary class]]
		? [stored mutableCopy]
		: [NSMutableDictionary dictionary];
	if (name)
		next[kind] = name;
	else
		[next removeObjectForKey:kind];
	[[NSUserDefaults standardUserDefaults] setObject:next
											  forKey:TGSettingsPresetDefaultsKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)titleForPresetName:(NSString *)name {
	if ([name isEqualToString:@"low"])
		return TGL(@"AutoDownloadSettings.DataUsageLow", @"Low");
	if ([name isEqualToString:@"high"])
		return TGL(@"AutoDownloadSettings.DataUsageHigh", @"High");
	return TGL(@"PhotoEditor.QualityMedium", @"Medium");
}

- (NSString *)detailForNetwork:(NSString *)kind {
	NSDictionary *mirror = [TGSettingsService autoDownloadSettingsForNetworkType:kind];
	if (!mirror)
		return TGL(@"AutoDownloadSettings.NotSet", @"Not set");
	if (![mirror[@"enabled"] boolValue])
		return TGL(@"PrivacySettings.PasscodeOff", @"Off");

	NSString *name = [self presetNameForNetwork:kind];
	if (name)
		return [self titleForPresetName:name];

	NSMutableArray *on = [NSMutableArray array];
	if ([mirror[@"maxPhotoSize"] longLongValue] > 0)
		[on addObject:TGL(@"AutoDownloadSettings.Photos", @"Photos")];
	if ([mirror[@"maxVideoSize"] longLongValue] > 0)
		[on addObject:TGL(@"AutoDownloadSettings.Videos", @"Videos")];
	if ([mirror[@"maxOtherSize"] longLongValue] > 0)
		[on addObject:TGL(@"AutoDownloadSettings.Files", @"Files")];
	if (!on.count)
		return TGL(@"AutoDownloadSettings.Nothing", @"Nothing");
	return [on componentsJoinedByString:@", "];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if ((NSInteger)self.page == TGSettingsPageAutoDownload)
		return 2;
	if ((NSInteger)self.page == TGSettingsPageAutoDownloadKind)
		return 4;
	if ((NSInteger)self.page == TGSettingsPageAutosave)
		return 5;
	if ((NSInteger)self.page == TGSettingsPageDataUsage)
		return TGSettingsUsageSectionCount;
	if ((NSInteger)self.page == TGSettingsPageWallpaper)
		return 4;
	if ((NSInteger)self.page == TGSettingsPageChatListLayout)
		return 1;
	if ((NSInteger)self.page == TGSettingsPageTextSize)
		return 1;
	if ((NSInteger)self.page == TGSettingsPageNotificationExceptions)
		return [self canClearExceptions] ? 2 : 1;
	if ((NSInteger)self.page == TGSettingsPageNotificationSounds)
		return 1;
	if ((NSInteger)self.page == TGSettingsPageNotificationTone)
		return 1;
	if (self.page == TGSettingsPageRoot)
		return ([self showsSuggestions] ? 10 : 9) + (self.tableView.isEditing ? 1 : 0);
	switch (self.page) {
		case TGSettingsPageAppearance:
			return 3;
		case TGSettingsPageData:
			return 4;
		case TGSettingsPageNotifications:
			return TGSettingsNotifSectionCount;
		case TGSettingsPageLanguage:
			return 2;
		default:
			return 6;
	}
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if ((NSInteger)self.page == TGSettingsPageAutoDownload)
		return section == 0 ? (NSInteger)[TGSettingsViewController networkKinds].count : 1;
	if ((NSInteger)self.page == TGSettingsPageAutoDownloadKind)
		return [self autoDownloadKindRowsInSection:section];
	if ((NSInteger)self.page == TGSettingsPageAutosave)
		return [self autosaveRowsInSection:section];
	if ((NSInteger)self.page == TGSettingsPageDataUsage)
		return [self usageRowsInSection:section];
	if ((NSInteger)self.page == TGSettingsPageWallpaper)
		return [self wallpaperRowsInSection:section];
	if ((NSInteger)self.page == TGSettingsPageChatListLayout)
		return (NSInteger)[TGPreferenceFlags chatListLayouts].count;
	if ((NSInteger)self.page == TGSettingsPageTextSize)
		return (NSInteger)[TGTheme messageFontSizes].count;
	if ((NSInteger)self.page == TGSettingsPageNotificationExceptions)
		return section == 1
			? 1
			: (NSInteger)MAX((NSUInteger)1, self.exceptions.count);
	if ((NSInteger)self.page == TGSettingsPageNotificationSounds)
		return self.savedSoundsLoaded ? (NSInteger)self.savedSounds.count : 1;
	if ((NSInteger)self.page == TGSettingsPageNotificationTone)
		return (NSInteger)[TGNotificationManager builtInToneIds].count + 1;
	switch (self.page) {
		case TGSettingsPageAppearance:
			if (section == 0)
				return 1;
			if (section == 1)
				return 2;
			return 4;
		case TGSettingsPageData:
			if (section == 0)
				return 7;
			if (section == 1)
				return 4;
			if (section == 2)
				return 3;
			return 1;
		case TGSettingsPageNotifications:
			if (section <= TGSettingsNotifSectionChannels)
				return (NSInteger)[TGSettingsViewController
					notificationRowsForSection:section]
					.count;
			if (section == TGSettingsNotifSectionReactions)
				return 3;
			if (section == TGSettingsNotifSectionSounds)
				return 2;
			if (section == TGSettingsNotifSectionBadge)
				return 2;
			if (section == TGSettingsNotifSectionInApp)
				return 3;
			return 1;
		case TGSettingsPageLanguage:
			if (section == TGSettingsLanguageSectionTranslation)
				return 1;
			return (NSInteger)MAX((NSUInteger)1, self.languages.count);
		default:
			break;
	}

	return [self rootRowsInSection:section];
}

- (NSInteger)autosaveRowsInSection:(NSInteger)section {
	if (section == 3)
		return (NSInteger)MAX((NSUInteger)1, self.autosaveExceptions.count);
	if (section == 4)
		return 1;
	return 2;
}

- (NSInteger)usageRowsInSection:(NSInteger)section {
	if (section == TGSettingsUsageSectionTotal)
		return 2 + (NSInteger)self.usageNetworks.count;
	if (section == TGSettingsUsageSectionMedia)
		return (NSInteger)MAX((NSUInteger)1, self.usageMedia.count);
	if (section == TGSettingsUsageSectionCalls)
		return 2;
	return 1;
}

- (NSInteger)wallpaperRowsInSection:(NSInteger)section {
	if (section == 0)
		return [TGTheme shared].wallpaper ? 5 : 4;
	if (section == 1)
		return (NSInteger)[TGSettingsViewController builtinWallpaperNames].count;
	if (section == 3)
		return 1;
	if (self.backgroundsLoaded && self.backgrounds.count)
		return (NSInteger)self.backgrounds.count;
	return 1;
}

- (NSInteger)rootRowsInSection:(NSInteger)section {
	switch ([self rootKindForSection:section]) {
		case TGSettingsRootKindSuggestions:
			return (NSInteger)self.suggestions.count;
		case TGSettingsRootKindPhoto:
			return 1;
		case TGSettingsRootKindAccounts: {
			NSInteger rows = (NSInteger)[[TGAccountManager shared] accounts].count;
			return rows + ([[TGAccountManager shared] canAddAccount] ? 1 : 0);
		}
		case TGSettingsRootKindProfile:
			return (NSInteger)[TGSettingsViewController profileRows].count;
		case TGSettingsRootKindProxy:
			return (NSInteger)[TGSettingsViewController proxyRows].count;
		case TGSettingsRootKindShortcuts:
			return (NSInteger)[TGSettingsViewController shortcutRows].count - ([TGPreferenceFlags storiesEnabled] ? 0 : 1);
		case TGSettingsRootKindAdvanced:
			return (NSInteger)[TGSettingsViewController advancedRows].count;
		case TGSettingsRootKindPayment:
			return (NSInteger)[TGSettingsViewController paymentRows].count;
		case TGSettingsRootKindExtra:
			return (NSInteger)[TGSettingsViewController extraRows].count;
		case TGSettingsRootKindHelp:
			return (NSInteger)[TGSettingsViewController helpRows].count;
		default:
			break;
	}
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if ((NSInteger)self.page == TGSettingsPageAutoDownload)
		return section == 0
			? TGL(@"AutoDownloadSettings.DownloadAutomaticallyOn", @"Download automatically on")
			: TGL(@"Calls.TabTitle", @"Calls");
	if ((NSInteger)self.page == TGSettingsPageAutoDownloadKind)
		return [self autoDownloadKindHeaderForSection:section];
	if ((NSInteger)self.page == TGSettingsPageAutosave) {
		if (section == 3)
			return TGL(@"Notifications.ExceptionsTitle", @"Exceptions");
		if (section == 4)
			return nil;
		return [TGSettingsViewController autosaveTitles][section];
	}
	if ((NSInteger)self.page == TGSettingsPageDataUsage) {
		if (section == TGSettingsUsageSectionTotal)
			return TGL(@"Stats.Total", @"Total");
		if (section == TGSettingsUsageSectionMedia)
			return TGL(@"StorageManagement.TabMedia", @"Media");
		if (section == TGSettingsUsageSectionCalls)
			return TGL(@"Calls.TabTitle", @"Calls");
		return nil;
	}
	if ((NSInteger)self.page == TGSettingsPageWallpaper) {
		if (section == 1)
			return TGL(@"Wallpaper.BuiltInSection", @"Built-in");
		if (section == 2)
			return TGL(@"Wallpaper.FromYourAccountSection", @"From your account");
		return nil;
	}
	switch (self.page) {
		case TGSettingsPageAppearance:
			if (section == 1)
				return TGL(@"Appearance.MessageSection", @"Message");
			if (section == 2)
				return TGL(@"DialogList.Title", @"Chats");
			return nil;
		case TGSettingsPageNotifications:
			if (section <= TGSettingsNotifSectionChannels)
				return [TGSettingsViewController notificationScopeTitles][section];
			if (section == TGSettingsNotifSectionReactions)
				return TGL(@"Notifications.Reactions.Title", @"Reactions");
			if (section == TGSettingsNotifSectionStories)
				return TGL(@"Notifications.StoriesTitle", @"Stories");
			if (section == TGSettingsNotifSectionContacts)
				return TGL(@"Contacts.Title", @"Contacts");
			if (section == TGSettingsNotifSectionSounds)
				return TGL(@"Notifications.SoundsSection", @"Sounds");
			if (section == TGSettingsNotifSectionBadge)
				return TGL(@"Notifications.Badge", @"BADGE COUNTER");
			if (section == TGSettingsNotifSectionInApp)
				return TGL(@"Notifications.InAppNotifications", @"IN-APP NOTIFICATIONS");
			return nil;
		case TGSettingsPageData:
			if (section == 1)
				return TGL(@"ChatSettings.ContactsAndLinksSection", @"Contacts and links");
			if (section == 2)
				return TGL(@"ChatList.Archive", @"Archive");
			return nil;
		case TGSettingsPageLanguage:
			return section == TGSettingsLanguageSectionTranslation
				? TGL(@"Translate.Languages.Translation", @"Translation")
				: TGL(@"Localization.InterfaceLanguage", @"Interface Language");
		default:
			break;
	}
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if ((NSInteger)self.page == TGSettingsPageAutoDownload)
		return [self autoDownloadFooterForSection:section];
	if ((NSInteger)self.page == TGSettingsPageAutoDownloadKind)
		return [self autoDownloadKindFooterForSection:section];
	if ((NSInteger)self.page == TGSettingsPageAutosave)
		return [self autosaveFooterForSection:section];
	if ((NSInteger)self.page == TGSettingsPageDataUsage)
		return [self usageFooterForSection:section];
	if ((NSInteger)self.page == TGSettingsPageWallpaper)
		return [self wallpaperFooterForSection:section];
	if ((NSInteger)self.page == TGSettingsPageChatListLayout)
		return TGL(@"ChatSettings.ChatListLayoutFooter",
			@"The chooser keeps the list as it is: the folder name sits in the "
			@"title bar and tapping it raises the list of folders. The strip "
			@"puts the folders under the title bar, where they are always "
			@"visible and cost one row of chats.");
	if ((NSInteger)self.page == TGSettingsPageTextSize)
		return TGL(@"Appearance.TextSizeFooter",
			@"The text size applies to messages and to the names and previews "
			@"in the chat list.");
	if (self.page == TGSettingsPageRoot)
		return [self rootFooterForSection:section];
	if (self.page == TGSettingsPageAppearance)
		return [self appearanceFooterForSection:section];
	if (self.page == TGSettingsPageNotifications)
		return [self notificationsFooterForSection:section];
	if ((NSInteger)self.page == TGSettingsPageNotificationSounds)
		return self.savedSoundsLoaded && !self.savedSounds.count
			? TGL(@"Notifications.SavedSoundsEmptyFooter",
				  @"Nothing here yet. Sounds are uploaded from a desktop or "
				  @"mobile Telegram and appear on every device signed into the "
				  @"account.")
			: TGL(@"Notifications.SavedSoundsHelpFooter", @"Hold or tap a sound to drop it from the account.");
	if ((NSInteger)self.page == TGSettingsPageNotificationTone)
		return TGL(@"Notifications.ToneSectionFooter",
			@"The eight tones shipped with Telegram in 2013. Tapping one "
			@"plays it and keeps it for the alerts this device raises. "
			@"Default hands the choice back to iOS.");
	if ((NSInteger)self.page == TGSettingsPageNotificationExceptions)
		return [self exceptionsFooterForSection:section];
	if (self.page == TGSettingsPageData && section == 0)
		return TGL(@"Settings.DataSaverFooter",
			@"Data Saver applies Telegram's low preset to Wi-Fi, mobile and "
			@"roaming at once. Turning it off puts back whatever each network "
			@"had before, and Auto-Download Media tunes them one by one.");
	if (self.page == TGSettingsPageData && section == 1)
		return TGL(@"ChatSettings.SyncContactsSectionFooter",
			@"Sync Contacts lets this device hand your address book to "
			@"Telegram; with it off, Contacts will not offer to. Frequent "
			@"contacts are the faces the search page suggests, kept on the "
			@"account. A link preview in a secret chat is fetched by "
			@"Telegram's servers, which learn the address.");
	if (self.page == TGSettingsPageLanguage)
		return TGL(@"Localization.InterfaceFooter",
			@"This app's own text is English throughout. The language is "
			@"what Telegram itself writes in, and it follows the account "
			@"onto your other devices.");
	return nil;
}

- (NSString *)autoDownloadFooterForSection:(NSInteger)section {
	return section == 0
		? TGL(@"AutoDownloadSettings.NetworkStateFooter",
			  @"Telegram cannot report which settings are in force, so these "
			  @"rows show what this device last applied.")
		: TGL(@"AutoDownloadSettings.CallsNetworkFooter",
			  @"Voice calls send less audio, which sounds worse and costs less "
			  @"data. It is written onto every network type at once.");
}

- (NSString *)autosaveFooterForSection:(NSInteger)section {
	if (section == 3)
		return TGL(@"Autosave.ExceptionsSectionFooter",
			@"Chats with a setting of their own. Per-chat exceptions are set "
			@"from the chat itself.");
	if (section == 4)
		return TGL(@"Autosave.CameraRollSectionFooter", @"Media arriving in these chats is copied into the camera roll.");
	return nil;
}

- (NSString *)usageFooterForSection:(NSInteger)section {
	if (section == TGSettingsUsageSectionReset) {
		if (self.usageSince <= 0)
			return nil;
		return [NSString stringWithFormat:TGL(@"DataUsage.InfoTotalUsageSinceTime",
									 @"Your data usage since %@"),
			[TGDateUtils stringForFullDateAndTime:(int)self.usageSince]];
	}
	if (section == TGSettingsUsageSectionCalls)
		return TGL(@"DataUsage.CallsSectionFooter",
			@"Call traffic never reaches Telegram's own counters, so it is "
			@"added here as each call ends.");
	return nil;
}

- (NSString *)wallpaperFooterForSection:(NSInteger)section {
	if (section == 0)
		return TGL(@"Wallpaper.BlurSectionFooter",
			@"Blur softens a photographic wallpaper so message text stays "
			@"readable over it.");
	if (section == 1)
		return TGL(@"Wallpaper.BuiltInSectionFooter",
			@"The backgrounds Telegram shipped with. They live in the app, "
			@"so they cost nothing to fetch.");
	if (section == 3)
		return TGL(@"Wallpaper.ManageListSectionFooter",
			@"Hold a background in the list above to copy its link or drop it "
			@"from the list. Clearing empties the whole list on your account.");
	if (section == 2)
		return [TGCapabilities canShowWallpaper]
			? TGL(@"Wallpaper.PhotoAllowedSectionFooter",
				  @"Colours and gradients cost nothing to draw. A photograph "
				  @"is held full-screen in memory, so pick a small one.")
			: TGL(@"Settings.ThisDeviceHasTooLittleMemory",
				  @"This device has too little memory to hold a photographic "
				  @"wallpaper. Colours and gradients still work.");
	return nil;
}

- (NSString *)rootFooterForSection:(NSInteger)section {
	return nil;
}

- (NSString *)appearanceFooterForSection:(NSInteger)section {
	if (section == 1)
		return TGL(@"Appearance.TextSizeFooter",
			@"The text size applies to messages and to the names and "
			@"previews in the chat list.");
	if (section == 2)
		return TGL(@"Appearance.ChatsSectionFooter",
			@"Stories off hides the tray over the chat list and every story "
			@"entry in the app. Saved Messages as List opens your saved "
			@"messages as a list of chats instead of one long chat. Show "
			@"Calls Tab puts the Calls tab in the main screen tab bar; with "
			@"it off the tab bar keeps Contacts, Chats and Settings only.");
	return nil;
}

- (NSString *)notificationsFooterForSection:(NSInteger)section {
	if (section == TGSettingsNotifSectionReactions)
		return TGL(@"Notifications.ReactionsSectionFooter",
			@"Who may raise a notification when they react to your "
			@"messages or your stories, or answer one of your polls. "
			@"Telegram cannot report these back, so the rows show what "
			@"this device last wrote.");
	if (section == TGSettingsNotifSectionSounds)
		return TGL(@"Notifications.SoundsSectionFooter",
			@"The tone is this device's own and is never written to the "
			@"account. Saved sounds are the ones uploaded to your account; "
			@"alerts raised while Telegram is closed use the sound the "
			@"system gives them.");
	if (section == TGSettingsNotifSectionContacts)
		return TGL(@"Notifications.ContactsSectionFooter",
			@"Telegram announces a phone-book contact the first time "
			@"they sign up. Turn this off to keep that quiet.");
	if (section == TGSettingsNotifSectionReset)
		return TGL(@"Notifications.ResetSectionFooter",
			@"Every scope and every chat goes back to the settings a "
			@"fresh account has.");
	if (section == TGSettingsNotifSectionBadge)
		return TGL(@"Notifications.BadgeSectionFooter", @"Controls the number shown on the app icon.");
	if (section == TGSettingsNotifSectionInApp)
		return TGL(@"Notifications.InAppSectionFooter",
			@"These apply only while Telegram is open and in the "
			@"foreground; a closed or backgrounded app always uses the "
			@"scopes above.");
	return nil;
}

- (NSString *)exceptionsFooterForSection:(NSInteger)section {
	if (section == 1)
		return TGL(@"NotificationExceptions.ReturnToDefaultFooter", @"Every chat in the list above goes back to the scope default.");
	return [self.exceptionsScope isEqualToString:TGSettingsStoriesExceptionsScope]
		? TGL(@"NotificationExceptions.StoryOverrideFooter",
			  @"These chats have a story setting of their own. Tap one to "
			  @"hand it back to the default.")
		: TGL(@"NotificationExceptions.ChatOverrideFooter",
			  @"These chats have notification settings of their own. Tap one "
			  @"to hand it back to the scope default.");
}

@end

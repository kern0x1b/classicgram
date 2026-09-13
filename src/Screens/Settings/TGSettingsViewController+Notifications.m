#import "TGImageDecode.h"
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
#import "TGSnackbar.h"
#import "TGCapabilities.h"
#import "TGAccountManager.h"
#import "TGPhoneFormat.h"
#import "TGIcons.h"
#import <QuartzCore/QuartzCore.h>
#import "TGSettingsViewControllerInternal.h"

@implementation TGSettingsViewController (Notifications)

#pragma mark - notifications

+ (NSArray *)notificationScopes {
	static NSArray *scopes = nil;
	if (!scopes)
		scopes = @[ @"private", @"groups", @"channels" ];
	return scopes;
}

+ (NSArray *)notificationScopeTitles {
	return @[ TGL(@"Notifications.MessageNotifications", @"MESSAGE NOTIFICATIONS"),
		TGL(@"Notifications.GroupNotifications", @"GROUP NOTIFICATIONS"),
		TGL(@"Notifications.ChannelNotifications", @"CHANNEL NOTIFICATIONS") ];
}

+ (NSArray *)reactionSources {
	static NSArray *sources = nil;
	if (!sources)
		sources = @[ @"all", @"contacts", @"none" ];
	return sources;
}

+ (NSArray *)reactionSourceTitles {
	return @[ TGL(@"PrivacySettings.LastSeenEverybody", @"Everybody"),
		TGL(@"PrivacySettings.LastSeenContacts", @"My Contacts"),
		TGL(@"PrivacySettings.LastSeenNobody", @"Nobody") ];
}

+ (NSString *)reactionSource {
	NSString *stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGSettingsReactionSourceKey()];
	if ([stored isKindOfClass:[NSString class]] && [[TGSettingsViewController reactionSources] containsObject:stored])
		return stored;
	return @"contacts";
}

+ (BOOL)reactionPreview {
	NSNumber *stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGSettingsReactionPreviewKey()];
	if (![stored isKindOfClass:[NSNumber class]])
		return YES;
	return [stored boolValue];
}

+ (NSString *)pollVoteSource {
	NSString *stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGSettingsPollVoteSourceKey()];
	if ([stored isKindOfClass:[NSString class]] && [[TGSettingsViewController reactionSources] containsObject:stored])
		return stored;
	return @"contacts";
}

- (void)writeReactionSource:(NSString *)source
			 pollVoteSource:(NSString *)pollVoteSource
					preview:(BOOL)preview {
	NSString *previousSource = [TGSettingsViewController reactionSource];
	NSString *previousPollVoteSource = [TGSettingsViewController pollVoteSource];
	BOOL previousPreview = [TGSettingsViewController reactionPreview];

	[[NSUserDefaults standardUserDefaults] setObject:source
											  forKey:TGSettingsReactionSourceKey()];
	[[NSUserDefaults standardUserDefaults] setObject:pollVoteSource
											  forKey:TGSettingsPollVoteSourceKey()];
	[[NSUserDefaults standardUserDefaults] setObject:@(preview)
											  forKey:TGSettingsReactionPreviewKey()];
	[[NSUserDefaults standardUserDefaults] synchronize];

	NSUInteger generation = ++self.reactionSettingsWriteGeneration;
	__weak typeof(self) weakSelf = self;
	[TGSettingsService setReactionNotificationsSource:source
									   pollVoteSource:pollVoteSource
										  showPreview:preview
										   completion:^(BOOL ok) {
		if (ok)
			return;
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (strongSelf.reactionSettingsWriteGeneration != generation)
			return;
		[[NSUserDefaults standardUserDefaults] setObject:previousSource
												  forKey:TGSettingsReactionSourceKey()];
		[[NSUserDefaults standardUserDefaults] setObject:previousPollVoteSource
												  forKey:TGSettingsPollVoteSourceKey()];
		[[NSUserDefaults standardUserDefaults] setObject:@(previousPreview)
												  forKey:TGSettingsReactionPreviewKey()];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[strongSelf.tableView reloadData];
		[TGSnackbar showInView:strongSelf.view
						   text:TGL(@"Toast.CouldNotChangeReactionNotifications", @"Could not change reaction notification settings")
						seconds:2
					   onCommit:nil];
	}];
}

- (NSDictionary *)settingsForScopeAtSection:(NSInteger)section {
	NSArray *scopes = [TGSettingsViewController notificationScopes];
	if ((NSUInteger)section >= scopes.count)
		return nil;
	NSDictionary *settings = self.scopeSettings[scopes[section]];
	return [settings isKindOfClass:[NSDictionary class]] ? settings : nil;
}

+ (NSArray *)notificationRowsForSection:(NSInteger)section {
	if (section == TGSettingsNotifSectionGroups)
		return @[ @"alert", @"preview", @"pinned", @"mentions", @"exceptions" ];
	if (section == TGSettingsNotifSectionChannels)
		return @[ @"alert", @"preview", @"pinned", @"exceptions" ];
	return @[ @"alert", @"preview", @"exceptions" ];
}

@end

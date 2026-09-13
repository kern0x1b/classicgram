#import "TGStorageKindName.h"
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
#import "TGCapabilities.h"
#import "TGAccountManager.h"
#import "TGPhoneFormat.h"
#import "TGIcons.h"
#import <QuartzCore/QuartzCore.h>
#import "TGSettingsViewControllerInternal.h"

@implementation TGSettingsViewController (Loading)

#pragma mark - loading

- (void)loadForPage {
	if ((NSInteger)self.page == TGSettingsPageAutoDownloadKind) {
		[self loadAutoDownloadKindPage];
		return;
	}

	if ((NSInteger)self.page == TGSettingsPageAutosave) {
		[self loadAutosavePage];
		return;
	}

	if ((NSInteger)self.page == TGSettingsPageDataUsage) {
		[self loadUsage];
		return;
	}

	if ((NSInteger)self.page == TGSettingsPageWallpaper) {
		[self loadWallpaperPage];
		return;
	}

	if (self.page == TGSettingsPageRoot) {
		[self loadRootPage];
		return;
	}

	if (self.page == TGSettingsPageNotifications) {
		[self loadNotificationsPage];
		return;
	}

	if ((NSInteger)self.page == TGSettingsPageNotificationSounds) {
		[self loadSavedSounds];
		return;
	}

	if ((NSInteger)self.page == TGSettingsPageNotificationExceptions) {
		[self loadExceptionsPage];
		return;
	}

	if (self.page == TGSettingsPageLanguage) {
		[self loadLanguagePage];
		return;
	}

	if (self.page == TGSettingsPageData)
		[self loadDataPage];
}

- (void)loadAutosaveSettings {
	__weak typeof(self) weakSelf = self;
	[TGSettingsService autosaveSettingsWithCompletion:^(NSDictionary *privateChats,
		NSDictionary *groups,
		NSDictionary *channels) {
		if ([privateChats isKindOfClass:[NSDictionary class]])
			weakSelf.autosave[@"private"] = privateChats;
		if ([groups isKindOfClass:[NSDictionary class]])
			weakSelf.autosave[@"groups"] = groups;
		if ([channels isKindOfClass:[NSDictionary class]])
			weakSelf.autosave[@"channels"] = channels;
		[weakSelf.tableView reloadData];
	}];
}

- (void)loadAutosavePage {
	__weak typeof(self) weakSelf = self;
	[self loadAutosaveSettings];
	[TGSettingsService autosaveExceptionsWithCompletion:^(NSArray *exceptions) {
		weakSelf.autosaveExceptions = [exceptions isKindOfClass:[NSArray class]]
			? exceptions
			: @[];
		weakSelf.autosaveExceptionsLoaded = YES;
		[weakSelf loadTitlesForAutosaveExceptions];
		[weakSelf.tableView reloadData];
	}];
}

- (void)loadWallpaperPage {
	self.wallpaperBackgroundId = [TGTheme shared].defaultBackgroundId;
	__weak typeof(self) weakSelf = self;
	[TGSettingsService installedBackgroundsForDarkTheme:NO completion:^(NSArray *backgrounds, BOOL failed) {
		weakSelf.backgroundsFailed = failed;
		if (!failed)
			weakSelf.backgrounds = [backgrounds isKindOfClass:[NSArray class]]
				? backgrounds
				: @[];
		weakSelf.backgroundsLoaded = YES;
		weakSelf.wallpaperBackgroundId = [TGTheme shared].defaultBackgroundId;
		[weakSelf.tableView reloadData];
	}];
}

- (void)loadRootPage {
	[self loadSuggestions];
	[self loadProxyStatus];
	[self loadPremiumSummary];
	[self loadAutosaveSettings];
}

- (void)loadPremiumSummary {
	__weak typeof(self) weakSelf = self;
	[TGSettingsService premiumStateWithCompletion:^(NSString *summary) {
		weakSelf.premiumSummary = [summary isKindOfClass:[NSString class]]
			? summary
			: nil;
		[weakSelf.tableView reloadData];
	}];
}

- (void)loadNotificationsPage {
	__weak typeof(self) weakSelf = self;
	for (NSString *scope in [TGSettingsViewController notificationScopes]) {
		[TGSettingsService notificationSettingsForScope:scope completion:^(NSDictionary *settings) {
			if (![settings isKindOfClass:[NSDictionary class]])
				return;
			weakSelf.scopeSettings[scope] = settings;
			weakSelf.muted[scope] = @([settings[@"muted"] boolValue]);
			[weakSelf.tableView reloadData];
		}];
		[TGSettingsService notificationExceptionsForScope:scope compareSound:YES completion:^(NSArray *chats, BOOL failed) {
			if (failed)
				return;
			weakSelf.exceptionCounts[scope] =
				@([chats isKindOfClass:[NSArray class]] ? chats.count : 0);
			[weakSelf.tableView reloadData];
		}];
	}
	[TGSettingsService storyNotificationExceptionsWithCompletion:^(NSArray *chats, BOOL failed) {
		if (failed)
			return;
		weakSelf.exceptionCounts[TGSettingsStoriesExceptionsScope] =
			@([chats isKindOfClass:[NSArray class]] ? chats.count : 0);
		[weakSelf.tableView reloadData];
	}];
	[TGSettingsService optionNamed:TGSettingsContactRegisteredOption
						completion:^(id value) {
							weakSelf.contactRegisteredMuted = [value respondsToSelector:@selector(boolValue)]
								? [value boolValue]
								: NO;
							[weakSelf.tableView reloadData];
						}];
	[self loadSavedSounds];
}

- (void)loadExceptionsPage {
	__weak typeof(self) weakSelf = self;
	void (^received)(NSArray *, BOOL) = ^(NSArray *chats, BOOL failed) {
		weakSelf.exceptionsFailed = failed;
		if (!failed)
			weakSelf.exceptions = [chats isKindOfClass:[NSArray class]] ? chats : @[];
		weakSelf.exceptionsLoaded = YES;
		[weakSelf.tableView reloadData];
	};
	if ([self.exceptionsScope isEqualToString:TGSettingsStoriesExceptionsScope])
		[TGSettingsService storyNotificationExceptionsWithCompletion:received];
	else
		[TGSettingsService notificationExceptionsForScope:self.exceptionsScope
											 compareSound:YES
											   completion:received];
}

- (void)loadLanguagePage {
	__weak typeof(self) weakSelf = self;
	[TGSettingsService languagePacksWithCompletion:^(NSArray *packs,
		NSString *current,
		BOOL failed) {
		weakSelf.languagesFailed = failed;
		if (!failed)
			weakSelf.languages = [packs isKindOfClass:[NSArray class]] ? packs : @[];
		weakSelf.currentLanguage = current;
		weakSelf.languagesLoaded = YES;
		[weakSelf.tableView reloadData];
	}];
	[TGSettingsService guessedCountryCodeWithCompletion:^(NSString *countryCode) {
		if (!countryCode.length)
			return;
		[TGSettingsService preferredLanguageForCountry:countryCode completion:^(NSString *languageCode) {
			weakSelf.suggestedLanguage = [languageCode isKindOfClass:[NSString class]]
				? languageCode
				: nil;
			[weakSelf.tableView reloadData];
		}];
	}];
}

- (void)loadDataPage {
	__weak typeof(self) weakSelf = self;
	[TGSettingsService archiveSettingsWithCompletion:^(NSDictionary *settings) {
		if ([settings isKindOfClass:[NSDictionary class]])
			[weakSelf.archive addEntriesFromDictionary:settings];
		[weakSelf.tableView reloadData];
	}];

	[TGSettingsService optionNamed:TGSettingsTopChatsOption completion:^(id value) {
		weakSelf.topChatsDisabled = [value boolValue];
		weakSelf.topChatsLoaded = YES;
		[weakSelf.tableView reloadData];
	}];
}

- (void)loadTitlesForAutosaveExceptions {
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *entry in self.autosaveExceptions) {
		if (![entry isKindOfClass:[NSDictionary class]])
			continue;
		int64_t chatId = [entry[@"chatId"] longLongValue];
		if (!chatId || self.chatTitles[@(chatId)])
			continue;
		[TGSettingsService titleForChatId:chatId completion:^(NSString *title) {
			if (![title isKindOfClass:[NSString class]] || !title.length)
				return;
			weakSelf.chatTitles[@(chatId)] = title;
			[weakSelf.tableView reloadData];
		}];
	}
}

- (void)loadUsage {
	[self loadUsageByKind];
	[self loadUsageTotals];
}

- (void)loadUsageByKind {
	__weak typeof(self) weakSelf = self;
	[TGSettingsService networkStatsOnlyCurrent:NO completion:^(NSArray *entries, NSInteger sinceDate) {
		NSArray *fixedKinds = @[TGStorageKindName(@"fileTypePhoto"),
			TGStorageKindName(@"fileTypeVideo"),
			TGStorageKindName(@"fileTypeAudio"),
			TGStorageKindName(@"fileTypeDocument")];
		NSMutableDictionary *media = [NSMutableDictionary dictionary];
		for (NSString *kind in fixedKinds)
			media[kind] = @0;
		long long callsSent = 0, callsReceived = 0;
		double callsDuration = 0;

		for (NSDictionary *entry in entries) {
			if (![entry isKindOfClass:[NSDictionary class]])
				continue;
			NSString *kind = [entry[@"kind"] isKindOfClass:[NSString class]]
				? entry[@"kind"]
				: @"other";
			long long sent = [entry[@"sent"] longLongValue];
			long long received = [entry[@"received"] longLongValue];
			if ([kind isEqualToString:@"calls"]) {
				callsSent += sent;
				callsReceived += received;
				callsDuration += [entry[@"duration"] doubleValue];
				continue;
			}
			NSString *title = TGStorageKindName(kind);
			NSString *bucket = title.length ? title : kind;
			long long running = [media[bucket] longLongValue];
			media[bucket] = @(running + sent + received);
		}

		NSArray *kinds = [[media allKeys] sortedArrayUsingComparator:
				^NSComparisonResult(NSString *a, NSString *b) {
					long long left = [media[a] longLongValue];
					long long right = [media[b] longLongValue];
					if (left == right)
						return [a compare:b];
					return left > right ? NSOrderedAscending : NSOrderedDescending;
				}];
		NSMutableArray *rows = [NSMutableArray array];
		for (NSString *title in kinds) {
			if ([media[title] longLongValue] <= 0 && ![fixedKinds containsObject:title])
				continue;
			[rows addObject:@{@"title" : title, @"bytes" : media[title]}];
		}

		weakSelf.usageMedia = rows;
		weakSelf.usageCalls = @{@"sent" : @(callsSent),
			@"received" : @(callsReceived),
			@"duration" : @(callsDuration)};
		weakSelf.usageSince = sinceDate;
		weakSelf.usageLoaded = YES;
		[weakSelf.tableView reloadData];
	}];
}

- (void)loadUsageTotals {
	__weak typeof(self) weakSelf = self;
	[TGSettingsService networkTotalsOnlyCurrent:NO
									 completion:^(long long sent, long long received,
										 NSDictionary *byNetwork) {
										 weakSelf.usageSent = sent;
										 weakSelf.usageReceived = received;
										 NSMutableArray *networks = [NSMutableArray array];
										 for (NSString *name in @[ @"wifi", @"mobile", @"roaming", @"other" ]) {
											 NSDictionary *values = [byNetwork isKindOfClass:[NSDictionary class]]
												 ? byNetwork[name]
												 : nil;
											 if (![values isKindOfClass:[NSDictionary class]])
												 continue;
											 long long total = [values[@"sent"] longLongValue] + [values[@"received"] longLongValue];
											 if (total <= 0)
												 continue;
											 [networks addObject:@{@"name" : name,
												 @"bytes" : @(total)}];
										 }
										 weakSelf.usageNetworks = networks;
										 [weakSelf.tableView reloadData];
									 }];
}

+ (NSString *)usageNetworkTitle:(NSString *)name {
	if ([name isEqualToString:@"wifi"])
		return TGL(@"NetworkUsageSettings.Wifi", @"Wi-Fi");
	if ([name isEqualToString:@"mobile"])
		return TGL(@"NetworkUsageSettings.Cellular", @"Cellular");
	if ([name isEqualToString:@"roaming"])
		return TGL(@"NetworkUsageSettings.Roaming", @"Roaming");
	return TGL(@"NetworkUsageSettings.Other", @"Other");
}

- (void)loadProxyStatus {
	__weak typeof(self) weakSelf = self;
	[TGSettingsService activeProxyIdWithCompletion:^(NSInteger proxyId) {
		weakSelf.activeProxyId = proxyId;
		if (proxyId >= 0) {
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			[defaults setInteger:proxyId forKey:TGSettingsLastProxyKey];
			[defaults synchronize];
		}
		if (proxyId < 0) {
			weakSelf.proxyDetail = TGL(@"VoiceOver.Common.Off", @"Off");
			[weakSelf.tableView reloadData];
			return;
		}
		[TGSettingsService activeProxyWithCompletion:^(NSDictionary *proxy) {
			NSString *server = [proxy[@"server"] isKindOfClass:[NSString class]]
				? proxy[@"server"]
				: nil;
			NSString *type = [proxy[@"type"] isKindOfClass:[NSString class]]
				? proxy[@"type"]
				: nil;
			if (!server.length) {
				weakSelf.proxyDetail = TGL(@"VoiceOver.Common.On", @"On");
			} else if (type.length) {
				weakSelf.proxyDetail = [NSString stringWithFormat:@"%@ (%@)",
					server, type];
			} else {
				weakSelf.proxyDetail = server;
			}
			[weakSelf.tableView reloadData];
		}];
	}];
}

- (void)loadSuggestions {
	if ([[NSUserDefaults standardUserDefaults]
			boolForKey:[TGAccountManager defaultsKey:TGSettingsArchiveSuggestionKey]])
		return;
	__weak typeof(self) weakSelf = self;
	[TGSettingsService archiveChatListSettingsWithCompletion:^(NSDictionary *settings) {
		if (![settings isKindOfClass:[NSDictionary class]])
			return;
		if ([settings[@"archiveAndMuteNewChatsFromUnknownUsers"] boolValue])
			return;
		weakSelf.suggestions = @[ @{
			@"name" : @"suggestedActionEnableArchiveAndMuteNewChats",
			@"title" : TGL(@"PrivacySettings.AutoArchive", @"Archive and mute new chats"),
			@"subtitle" : TGL(@"PrivacySettings.AutoArchiveInfo", @"Chats from people you do not know go straight to the archive.")
		} ];
		[weakSelf.tableView reloadData];
	}];
}

- (BOOL)showsSuggestions {
	return self.page == TGSettingsPageRoot && self.suggestions.count > 0;
}

- (NSInteger)rootKindForSection:(NSInteger)section {
	NSInteger kind = section + ([self showsSuggestions] ? 0 : 1);
	return kind;
}

- (void)acceptSuggestionAtRow:(NSInteger)row {
	if ((NSUInteger)row >= self.suggestions.count)
		return;
	[TGSettingsService acceptArchiveAndMuteSuggestion];
	self.archive[@"archiveUnknownSenders"] = @YES;
	[self dismissSuggestionAtRow:row];
}

- (void)dismissSuggestionAtRow:(NSInteger)row {
	if ((NSUInteger)row >= self.suggestions.count)
		return;
	NSDictionary *suggestion = self.suggestions[row];
	if ([suggestion[@"name"] isKindOfClass:[NSString class]])
		[TGSettingsService hideSuggestedActionNamed:suggestion[@"name"]];
	[[NSUserDefaults standardUserDefaults] setBool:YES
											forKey:[TGAccountManager defaultsKey:TGSettingsArchiveSuggestionKey]];
	[[NSUserDefaults standardUserDefaults] synchronize];
	NSMutableArray *rest = [self.suggestions mutableCopy];
	[rest removeObjectAtIndex:row];
	self.suggestions = rest;
	[self.tableView reloadData];
}

- (void)suggestionDismissTapped:(UIButton *)button {
	[self dismissSuggestionAtRow:button.tag];
}

@end

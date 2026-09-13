#import "TGClient+AppSettings.h"
#import "TGClient+Private.h"
#import "TGFlattenAppSettings.h"

static NSString *TGASIdString(id value) {
	if ([value isKindOfClass:NSString.class])
		return value;
	if ([value isKindOfClass:NSNumber.class])
		return [NSString stringWithFormat:@"%lld", [value longLongValue]];
	return nil;
}

static NSDictionary *TGASDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static BOOL TGASErrorNeedsPremium(NSDictionary *result) {
	NSString *message = TGResultErrorMessage(result);
	return [message rangeOfString:@"PREMIUM" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

@implementation TGClient (AppSettings)

#pragma mark - wallpapers

- (void)tgas_setDefaultBackground:(NSDictionary *)background
							 type:(NSDictionary *)type
					 forDarkTheme:(BOOL)forDarkTheme
					   completion:(void (^)(NSDictionary *background))completion {
	NSMutableDictionary *request = [NSMutableDictionary dictionary];
	request[@"@type"] = @"setDefaultBackground";
	if (background)
		request[@"background"] = background;
	if (type)
		request[@"type"] = type;
	request[@"for_dark_theme"] = @(forDarkTheme);
	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		completion(TGASBackgroundRow(result));
	}];
}

- (void)installedBackgroundsForDarkTheme:(BOOL)forDarkTheme
							  completion:(void (^)(NSArray *backgrounds, BOOL failed))completion {
	[self request:@{@"@type" : @"getInstalledBackgrounds",
		@"for_dark_theme" : @(forDarkTheme)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(@[], YES);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			NSArray *backgrounds = result[@"backgrounds"];
			if ([backgrounds isKindOfClass:NSArray.class]) {
				for (id item in backgrounds) {
					NSDictionary *row = TGASBackgroundRow(item);
					if (row)
						[out addObject:row];
				}
			}
			completion(out, NO);
		}];
}

- (void)setDefaultBackgroundId:(NSString *)backgroundId
					   blurred:(BOOL)blurred
						moving:(BOOL)moving
				  forDarkTheme:(BOOL)forDarkTheme
					completion:(void (^)(NSDictionary *background))completion {
	NSString *identifier = TGASIdString(backgroundId);
	if (identifier.length == 0) {
		if (completion)
			completion(nil);
		return;
	}
	[self tgas_setDefaultBackground:@{@"@type" : @"inputBackgroundRemote",
		@"background_id" : identifier}
							   type:@{@"@type" : @"backgroundTypeWallpaper",
								   @"is_blurred" : @(blurred),
								   @"is_moving" : @(moving)}
					   forDarkTheme:forDarkTheme
						 completion:completion];
}

- (void)setDefaultBackgroundRow:(NSDictionary *)row
						blurred:(BOOL)blurred
				   forDarkTheme:(BOOL)forDarkTheme
					 completion:(void (^)(NSDictionary *background))completion {
	if (![row isKindOfClass:NSDictionary.class]) {
		if (completion)
			completion(nil);
		return;
	}
	NSString *kind = [row[@"kind"] isKindOfClass:NSString.class] ? row[@"kind"] : @"wallpaper";

	if ([kind isEqualToString:@"fill"]) {
		[self tgas_setDefaultBackground:nil
								   type:@{@"@type" : @"backgroundTypeFill",
									   @"fill" : TGASFillFromRow(row)}
						   forDarkTheme:forDarkTheme
							 completion:completion];
		return;
	}

	NSString *identifier = TGASIdString(row[@"id"]);
	if (identifier.length == 0 || [identifier isEqualToString:@"0"]) {
		if (completion)
			completion(nil);
		return;
	}
	NSDictionary *background = @{@"@type" : @"inputBackgroundRemote",
		@"background_id" : identifier};

	if ([kind isEqualToString:@"pattern"]) {
		NSInteger intensity = [row[@"intensity"] isKindOfClass:NSNumber.class]
			? [row[@"intensity"] integerValue]
			: 50;
		[self tgas_setDefaultBackground:background
								   type:@{@"@type" : @"backgroundTypePattern",
									   @"fill" : TGASFillFromRow(row),
									   @"intensity" : @((int)intensity),
									   @"is_inverted" : @([row[@"isInverted"] boolValue]),
									   @"is_moving" : @([row[@"isMoving"] boolValue])}
						   forDarkTheme:forDarkTheme
							 completion:completion];
		return;
	}

	[self tgas_setDefaultBackground:background
							   type:@{@"@type" : @"backgroundTypeWallpaper",
								   @"is_blurred" : @(blurred),
								   @"is_moving" : @([row[@"isMoving"] boolValue])}
					   forDarkTheme:forDarkTheme
						 completion:completion];
}

- (void)setDefaultBackgroundColor:(NSInteger)color
					 forDarkTheme:(BOOL)forDarkTheme
					   completion:(void (^)(NSDictionary *background))completion {
	[self tgas_setDefaultBackground:nil
							   type:@{@"@type" : @"backgroundTypeFill",
								   @"fill" : @{@"@type" : @"backgroundFillSolid",
									   @"color" : @((int)color)}}
					   forDarkTheme:forDarkTheme
						 completion:completion];
}

- (void)setDefaultBackgroundGradientTop:(NSInteger)topColor
								 bottom:(NSInteger)bottomColor
							   rotation:(NSInteger)rotation
						   forDarkTheme:(BOOL)forDarkTheme
							 completion:(void (^)(NSDictionary *background))completion {
	NSInteger angle = rotation % 360;
	if (angle < 0)
		angle += 360;
	angle = (angle / 45) * 45;
	[self tgas_setDefaultBackground:nil
							   type:@{@"@type" : @"backgroundTypeFill",
								   @"fill" : @{@"@type" : @"backgroundFillGradient",
									   @"top_color" : @((int)topColor),
									   @"bottom_color" : @((int)bottomColor),
									   @"rotation_angle" : @((int)angle)}}
					   forDarkTheme:forDarkTheme
						 completion:completion];
}

- (void)setDefaultBackgroundAtPath:(NSString *)path
						   blurred:(BOOL)blurred
					  forDarkTheme:(BOOL)forDarkTheme
						completion:(void (^)(NSDictionary *background))completion {
	if (path.length == 0) {
		if (completion)
			completion(nil);
		return;
	}
	[self tgas_setDefaultBackground:@{@"@type" : @"inputBackgroundLocal",
		@"background" : @{@"@type" : @"inputFileLocal",
			@"path" : path}}
							   type:@{@"@type" : @"backgroundTypeWallpaper",
								   @"is_blurred" : @(blurred),
								   @"is_moving" : @NO}
					   forDarkTheme:forDarkTheme
						 completion:completion];
}

- (void)resetDefaultBackgroundForDarkTheme:(BOOL)forDarkTheme completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"deleteDefaultBackground",
		@"for_dark_theme" : @(forDarkTheme)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)shareUrlForBackgroundNamed:(NSString *)name
							  kind:(NSString *)kind
						completion:(void (^)(NSString *url))completion {
	if (name.length == 0) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{@"@type" : @"getBackgroundUrl",
		@"name" : name,
		@"type" : TGASBackgroundTypeForKind(kind)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			NSString *url = TGResultIsError(result) ? nil : result[@"url"];
			completion([url isKindOfClass:NSString.class] ? url : nil);
		}];
}

- (void)removeInstalledBackgroundId:(NSString *)backgroundId completion:(void (^)(BOOL))completion {
	NSString *identifier = TGASIdString(backgroundId);
	if (identifier.length == 0) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{@"@type" : @"removeInstalledBackground",
		@"background_id" : identifier}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)resetInstalledBackgroundsWithCompletion:(void (^)(BOOL success))completion {
	[self request:@{@"@type" : @"resetInstalledBackgrounds"}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

static NSMutableArray *TGASEmojiChatThemesCache(void) {
	static NSMutableArray *cache = nil;
	if (!cache)
		cache = [[NSMutableArray alloc] init];
	return cache;
}

#pragma mark - web browser settings

static NSMutableDictionary *TGASWebBrowserSettingsCache(void) {
	static NSMutableDictionary *cache = nil;
	if (!cache)
		cache = [[NSMutableDictionary alloc] initWithDictionary:@{
			@"openExternalBrowser" : @NO,
			@"displayCloseButton" : @NO,
			@"externalExceptions" : @[],
			@"inAppExceptions" : @[],
		}];
	return cache;
}

static NSString *TGASWebExceptionDomain(NSString *url) {
	NSString *host = [[NSURL URLWithString:url ?: @""] host].lowercaseString;
	return host.length ? host : (url.lowercaseString ?: @"");
}

static NSArray *TGASWebExceptionsWithoutDomain(NSArray *entries, NSString *domain) {
	NSMutableArray *out = [NSMutableArray arrayWithCapacity:entries.count];
	for (NSDictionary *entry in entries) {
		NSString *entryDomain = [entry[@"domain"] lowercaseString];
		if (entryDomain.length && [entryDomain isEqualToString:domain])
			continue;
		[out addObject:entry];
	}
	return out;
}

static void TGASWebBrowserSettingsChanged(void) {
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGWebBrowserSettingsDidChangeNotification
					  object:nil];
}

- (void)handleUpdateWebBrowserSettings:(NSDictionary *)update {
	NSDictionary *settings = TGASDict(update[@"settings"]);
	NSMutableDictionary *cache = TGASWebBrowserSettingsCache();
	cache[@"openExternalBrowser"] = @([settings[@"open_external_browser"] boolValue]);
	cache[@"displayCloseButton"] = @([settings[@"display_close_button"] boolValue]);
	cache[@"externalExceptions"] = TGASWebDomainExceptions(settings[@"external_exceptions"]);
	cache[@"inAppExceptions"] = TGASWebDomainExceptions(settings[@"in_app_exceptions"]);
	TGASWebBrowserSettingsChanged();
}

- (NSDictionary *)cachedWebBrowserSettings {
	return [TGASWebBrowserSettingsCache() copy];
}

- (BOOL)shouldOpenExternallyForUrl:(NSString *)url {
	NSString *host = [[NSURL URLWithString:url ?: @""] host].lowercaseString;
	if (!host.length)
		return YES;
	NSDictionary *settings = TGASWebBrowserSettingsCache();
	for (NSDictionary *entry in settings[@"inAppExceptions"]) {
		NSString *domain = [entry[@"domain"] lowercaseString];
		if (domain.length && ([host isEqualToString:domain] || [host hasSuffix:[@"." stringByAppendingString:domain]]))
			return NO;
	}
	for (NSDictionary *entry in settings[@"externalExceptions"]) {
		NSString *domain = [entry[@"domain"] lowercaseString];
		if (domain.length && ([host isEqualToString:domain] || [host hasSuffix:[@"." stringByAppendingString:domain]]))
			return YES;
	}
	return [settings[@"openExternalBrowser"] boolValue];
}

- (void)changeWebBrowserSettingsOpenExternal:(BOOL)openExternal
						  displayCloseButton:(BOOL)displayCloseButton
								  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"changeWebBrowserSettings",
		@"open_external_browser" : @(openExternal),
		@"display_close_button" : @(displayCloseButton),
	} completion:^(NSDictionary *result) {
		BOOL success = !TGResultIsError(result);
		if (success) {
			NSMutableDictionary *cache = TGASWebBrowserSettingsCache();
			cache[@"openExternalBrowser"] = @(openExternal);
			cache[@"displayCloseButton"] = @(displayCloseButton);
			TGASWebBrowserSettingsChanged();
		}
		if (completion)
			completion(success);
	}];
}

- (void)addWebBrowserSettingsExceptionForUrl:(NSString *)url
							  openExternally:(BOOL)openExternal
								  completion:(void (^)(BOOL))completion {
	if (!url.length) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"addWebBrowserSettingsException",
		@"open_external_browser" : @(openExternal),
		@"url" : url,
	} completion:^(NSDictionary *result) {
		BOOL success = !TGResultIsError(result);
		if (success) {
			NSString *domain = TGASWebExceptionDomain(url);
			NSMutableDictionary *cache = TGASWebBrowserSettingsCache();
			NSArray *inApp = TGASWebExceptionsWithoutDomain(cache[@"inAppExceptions"], domain);
			NSArray *external = TGASWebExceptionsWithoutDomain(cache[@"externalExceptions"], domain);
			NSDictionary *entry = @{@"url" : url, @"domain" : domain, @"title" : @""};
			cache[@"inAppExceptions"] = openExternal ? inApp : [inApp arrayByAddingObject:entry];
			cache[@"externalExceptions"] = openExternal ? [external arrayByAddingObject:entry] : external;
			TGASWebBrowserSettingsChanged();
		}
		if (completion)
			completion(success);
	}];
}

- (void)removeWebBrowserSettingsExceptionForUrl:(NSString *)url
									 completion:(void (^)(BOOL))completion {
	if (!url.length) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"removeWebBrowserSettingsException",
		@"url" : url,
	} completion:^(NSDictionary *result) {
		BOOL success = !TGResultIsError(result);
		if (success) {
			NSString *domain = TGASWebExceptionDomain(url);
			NSMutableDictionary *cache = TGASWebBrowserSettingsCache();
			cache[@"inAppExceptions"] = TGASWebExceptionsWithoutDomain(cache[@"inAppExceptions"], domain);
			cache[@"externalExceptions"] = TGASWebExceptionsWithoutDomain(cache[@"externalExceptions"], domain);
			TGASWebBrowserSettingsChanged();
		}
		if (completion)
			completion(success);
	}];
}

- (void)removeAllWebBrowserSettingsExceptionsWithCompletion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"removeAllWebBrowserSettingsExceptions"}
		completion:^(NSDictionary *result) {
			BOOL success = !TGResultIsError(result);
			if (success) {
				NSMutableDictionary *cache = TGASWebBrowserSettingsCache();
				cache[@"inAppExceptions"] = @[];
				cache[@"externalExceptions"] = @[];
				TGASWebBrowserSettingsChanged();
			}
			if (completion)
				completion(success);
		}];
}

#pragma mark - account switch

- (void)resetAppSettingsCachesForAccountSwitch {
	NSMutableDictionary *cache = TGASWebBrowserSettingsCache();
	[cache removeAllObjects];
	[cache addEntriesFromDictionary:@{
		@"openExternalBrowser" : @NO,
		@"displayCloseButton" : @NO,
		@"externalExceptions" : @[],
		@"inAppExceptions" : @[],
	}];
	[TGASEmojiChatThemesCache() removeAllObjects];
}

#pragma mark - per-chat wallpaper

- (void)chatBackgroundRowForChat:(int64_t)chatId
					  completion:(void (^)(NSDictionary *row, NSInteger darkThemeDimming))completion {
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil, 0);
				return;
			}
			NSDictionary *chatBackground = TGASDict(result[@"background"]);
			NSDictionary *row = TGASBackgroundRow(TGASDict(chatBackground[@"background"]));
			NSInteger dimming = [chatBackground[@"dark_theme_dimming"] integerValue];
			completion(row, dimming);
		}];
}

- (void)setChatBackgroundRow:(NSDictionary *)row
					 blurred:(BOOL)blurred
					 forChat:(int64_t)chatId
				 onlyForSelf:(BOOL)onlyForSelf
				  completion:(void (^)(BOOL success, BOOL premiumRequired))completion {
	if (![row isKindOfClass:NSDictionary.class]) {
		if (completion)
			completion(NO, NO);
		return;
	}
	NSString *kind = [row[@"kind"] isKindOfClass:NSString.class] ? row[@"kind"] : @"wallpaper";
	NSMutableDictionary *request = [NSMutableDictionary dictionary];
	request[@"@type"] = @"setChatBackground";
	request[@"chat_id"] = @(chatId);
	request[@"dark_theme_dimming"] = @(50);
	request[@"only_for_self"] = @(onlyForSelf);

	if ([kind isEqualToString:@"fill"]) {
		request[@"type"] = @{@"@type" : @"backgroundTypeFill", @"fill" : TGASFillFromRow(row)};
	} else {
		NSString *identifier = TGASIdString(row[@"id"]);
		if (identifier.length == 0 || [identifier isEqualToString:@"0"]) {
			if (completion)
				completion(NO, NO);
			return;
		}
		request[@"background"] = @{@"@type" : @"inputBackgroundRemote", @"background_id" : identifier};
		if ([kind isEqualToString:@"pattern"]) {
			NSInteger intensity = [row[@"intensity"] isKindOfClass:NSNumber.class]
				? [row[@"intensity"] integerValue]
				: 50;
			request[@"type"] = @{@"@type" : @"backgroundTypePattern",
				@"fill" : TGASFillFromRow(row),
				@"intensity" : @((int)intensity),
				@"is_inverted" : @([row[@"isInverted"] boolValue]),
				@"is_moving" : @([row[@"isMoving"] boolValue])};
		} else {
			request[@"type"] = @{@"@type" : @"backgroundTypeWallpaper",
				@"is_blurred" : @(blurred),
				@"is_moving" : @([row[@"isMoving"] boolValue])};
		}
	}

	[self request:request completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result), TGASErrorNeedsPremium(result));
	}];
}

- (void)setChatBackgroundAtPath:(NSString *)path
						blurred:(BOOL)blurred
						forChat:(int64_t)chatId
					onlyForSelf:(BOOL)onlyForSelf
					 completion:(void (^)(BOOL success, BOOL premiumRequired))completion {
	if (path.length == 0) {
		if (completion)
			completion(NO, NO);
		return;
	}
	[self request:@{@"@type" : @"setChatBackground",
		@"chat_id" : @(chatId),
		@"only_for_self" : @(onlyForSelf),
		@"dark_theme_dimming" : @(50),
		@"background" : @{@"@type" : @"inputBackgroundLocal",
			@"background" : @{@"@type" : @"inputFileLocal",
				@"path" : path}},
		@"type" : @{@"@type" : @"backgroundTypeWallpaper",
			@"is_blurred" : @(blurred),
			@"is_moving" : @NO}}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result), TGASErrorNeedsPremium(result));
		}];
}

- (void)resetChatBackgroundForChat:(int64_t)chatId
						completion:(void (^)(BOOL success))completion {
	[self deleteChatBackgroundForChat:chatId restorePrevious:NO completion:completion];
}

- (void)deleteChatBackgroundForChat:(int64_t)chatId
					restorePrevious:(BOOL)restorePrevious
						 completion:(void (^)(BOOL success))completion {
	[self request:@{@"@type" : @"deleteChatBackground",
		@"chat_id" : @(chatId),
		@"restore_previous" : @(restorePrevious)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

#pragma mark - per-chat theme

- (void)chatThemeEmojiForChat:(int64_t)chatId
				   completion:(void (^)(NSString *emoji))completion {
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			NSDictionary *theme = TGASDict(result[@"theme"]);
			NSString *name = theme[@"name"];
			if ([theme[@"@type"] isEqualToString:@"chatThemeEmoji"] &&
				[name isKindOfClass:NSString.class] && name.length > 0) {
				completion(name);
				return;
			}
			completion(nil);
		}];
}

- (void)chatThemeColoursForChat:(int64_t)chatId
					  completion:(void (^)(NSDictionary *colours))completion {
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			NSDictionary *theme = TGASDict(result[@"theme"]);
			NSString *type = theme[@"@type"];
			NSDictionary *settings = nil;
			BOOL hasUnresolvedThemeName = NO;
			if ([type isEqualToString:@"chatThemeEmoji"]) {
				NSString *name = [theme[@"name"] isKindOfClass:NSString.class] ? theme[@"name"] : @"";
				for (NSDictionary *catalogTheme in TGASEmojiChatThemesCache()) {
					if ([catalogTheme[@"name"] isEqualToString:name]) {
						settings = TGASDict(catalogTheme[@"light_settings"]);
						break;
					}
				}
				hasUnresolvedThemeName = name.length > 0 && !settings;
			} else if ([type isEqualToString:@"chatThemeGift"]) {
				settings = TGASDict(TGASDict(theme[@"gift_theme"])[@"light_settings"]);
			}
			NSDictionary *colours = TGASThemeColoursFromSettings(settings);
			NSDictionary *backgroundRow = settings ? TGASBackgroundRow(TGASDict(settings[@"background"])) : nil;
			NSMutableDictionary *combined = colours ? [colours mutableCopy] : [NSMutableDictionary dictionary];
			if (backgroundRow)
				combined[@"backgroundRow"] = backgroundRow;
			if (hasUnresolvedThemeName)
				combined[@"unresolved"] = @YES;
			completion(combined.count > 0 ? combined : nil);
		}];
}

- (void)setChatThemeName:(NSString *)themeName
				 forChat:(int64_t)chatId
			  completion:(void (^)(BOOL success))completion {
	NSString *name = [themeName isKindOfClass:NSString.class] ? themeName : @"";
	id theme = name.length
		? @{@"@type" : @"inputChatThemeEmoji", @"name" : name}
		: [NSNull null];
	[self request:@{@"@type" : @"setChatTheme",
		@"chat_id" : @(chatId),
		@"theme" : theme}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (NSArray *)emojiChatThemeRows {
	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *theme in TGASEmojiChatThemesCache()) {
		NSString *name = [theme[@"name"] isKindOfClass:NSString.class] ? theme[@"name"] : @"";
		if (!name.length)
			continue;
		NSDictionary *light = TGASDict(theme[@"light_settings"]);
		NSDictionary *backgroundRow = TGASBackgroundRow(TGASDict(light[@"background"]));
		NSMutableDictionary *row = [NSMutableDictionary dictionary];
		row[@"name"] = name;
		if (backgroundRow)
			row[@"backgroundRow"] = backgroundRow;
		NSDictionary *colours = TGASThemeColoursFromSettings(light);
		if (colours)
			[row addEntriesFromDictionary:colours];
		[rows addObject:row];
	}
	return rows;
}

- (void)handleUpdateEmojiChatThemes:(NSDictionary *)update {
	NSArray *themes = [update[@"chat_themes"] isKindOfClass:NSArray.class]
		? update[@"chat_themes"]
		: @[];
	NSMutableArray *cache = TGASEmojiChatThemesCache();
	[cache removeAllObjects];
	for (id theme in themes)
		if ([theme isKindOfClass:NSDictionary.class])
			[cache addObject:theme];
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGChatAppearanceCatalogDidChangeNotification
					  object:nil];
}

#pragma mark - suggested actions

- (void)hideSuggestedActionNamed:(NSString *)name {
	if (name.length == 0)
		return;
	NSMutableDictionary *action = [NSMutableDictionary dictionary];
	action[@"@type"] = name;
	if ([name isEqualToString:@"suggestedActionSetPassword"])
		action[@"authorization_delay"] = @0;
	if ([name isEqualToString:@"suggestedActionSetLoginEmailAddress"])
		action[@"can_be_hidden"] = @YES;
	[self send:@{@"@type" : @"hideSuggestedAction", @"action" : action}];
}

- (void)acceptArchiveAndMuteSuggestion {
	__weak TGClient *weakSelf = self;
	[self request:@{@"@type" : @"getArchiveChatListSettings"} completion:^(NSDictionary *result) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		BOOL keepUnmuted = NO;
		BOOL keepFolders = NO;
		if (!TGResultIsError(result)) {
			keepUnmuted = [result[@"keep_unmuted_chats_archived"] boolValue];
			keepFolders = [result[@"keep_chats_from_folders_archived"] boolValue];
		}
		[strongSelf send:@{@"@type" : @"setArchiveChatListSettings",
			@"settings" : @{@"@type" : @"archiveChatListSettings",
				@"archive_and_mute_new_chats_from_unknown_users" : @YES,
				@"keep_unmuted_chats_archived" : @(keepUnmuted),
				@"keep_chats_from_folders_archived" : @(keepFolders)}}];
		[strongSelf hideSuggestedActionNamed:@"suggestedActionEnableArchiveAndMuteNewChats"];
	}];
}

@end

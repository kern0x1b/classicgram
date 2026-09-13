#import "TGPreferenceFlags.h"
#import "TGDevice.h"
#import "TGLocalization.h"

NSString *const TGPreferenceChatListLayoutChangedNotification =
	@"TGPreferenceChatListLayoutChanged";

static NSString *const TGPreferenceSyncContactsKey = @"TGSyncContacts";
static NSString *const TGPreferenceSecretLinkPreviewsKey = @"TGSecretChatLinkPreviews";
static NSString *const TGPreferenceBadgeCountChatsKey = @"TGBadgeCountUnreadChats";
static NSString *const TGPreferenceBadgeIncludeMutedKey = @"TGBadgeIncludeMuted";
static NSString *const TGPreferenceStoriesEnabledKey = @"TGStoriesEnabled";
static NSString *const TGPreferenceChatListLayoutKey = @"TGChatListLayout";
static NSString *const TGPreferenceSavedMessagesShowsTopicsKey = @"TGSavedMessagesShowsTopics";
static NSString *const TGPreferenceStickerLargeEmojiKey = @"TGStickerLargeEmoji";
static NSString *const TGPreferenceStickerLoopAnimatedKey = @"TGStickerLoopAnimated";
static NSString *const TGPreferenceVoicePlaybackRateKey = @"TGVoicePlaybackRate";

static BOOL TGPreferenceDefaultOnFlag(NSString *key) {
	NSNumber *stored = [[NSUserDefaults standardUserDefaults] objectForKey:key];
	return [stored isKindOfClass:[NSNumber class]] ? [stored boolValue] : YES;
}

static BOOL TGPreferenceDefaultOffFlag(NSString *key) {
	NSNumber *stored = [[NSUserDefaults standardUserDefaults] objectForKey:key];
	return [stored isKindOfClass:[NSNumber class]] ? [stored boolValue] : NO;
}

static void TGPreferenceWriteFlag(NSString *key, BOOL value) {
	[[NSUserDefaults standardUserDefaults] setObject:@(value) forKey:key];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

@implementation TGPreferenceFlags

+ (BOOL)syncContactsEnabled {
	return TGPreferenceDefaultOffFlag(TGPreferenceSyncContactsKey);
}

+ (void)setSyncContactsEnabled:(BOOL)enabled {
	TGPreferenceWriteFlag(TGPreferenceSyncContactsKey, enabled);
}

+ (BOOL)secretChatLinkPreviewsEnabled {
	return TGPreferenceDefaultOnFlag(TGPreferenceSecretLinkPreviewsKey);
}

+ (void)setSecretChatLinkPreviewsEnabled:(BOOL)enabled {
	TGPreferenceWriteFlag(TGPreferenceSecretLinkPreviewsKey, enabled);
}

+ (BOOL)badgeCountsUnreadChats {
	return [[NSUserDefaults standardUserDefaults] boolForKey:TGPreferenceBadgeCountChatsKey];
}

+ (void)setBadgeCountsUnreadChats:(BOOL)enabled {
	[[NSUserDefaults standardUserDefaults] setBool:enabled
											forKey:TGPreferenceBadgeCountChatsKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL)badgeIncludesMuted {
	return [[NSUserDefaults standardUserDefaults] boolForKey:TGPreferenceBadgeIncludeMutedKey];
}

+ (void)setBadgeIncludesMuted:(BOOL)enabled {
	[[NSUserDefaults standardUserDefaults] setBool:enabled
											forKey:TGPreferenceBadgeIncludeMutedKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL)storiesEnabled {
	NSNumber *stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGPreferenceStoriesEnabledKey];
	if (![stored isKindOfClass:[NSNumber class]])
		return [TGDevice tier] >= TGDeviceTierLegacy;
	return [stored boolValue];
}

+ (void)setStoriesEnabled:(BOOL)enabled {
	[[NSUserDefaults standardUserDefaults] setObject:@(enabled)
											  forKey:TGPreferenceStoriesEnabledKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSArray *)chatListLayouts {
	static NSArray *layouts = nil;
	if (!layouts)
		layouts = @[ @"a", @"b" ];
	return layouts;
}

+ (NSArray *)chatListLayoutTitles {
	static NSArray *titles = nil;
	if (!titles)
		titles = @[ TGL(@"ChatList.LayoutChooserInTitle", @"Chooser in the Title"),
			TGL(@"ChatList.LayoutStripUnderTitle", @"Strip Under the Title") ];
	return titles;
}

+ (NSString *)chatListLayout {
	NSString *stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGPreferenceChatListLayoutKey];
	if ([stored isKindOfClass:[NSString class]] && [[TGPreferenceFlags chatListLayouts] containsObject:stored])
		return stored;
	return @"b";
}

+ (BOOL)chatListShowsFolderChooser {
	return [[TGPreferenceFlags chatListLayout]
		isEqualToString:[TGPreferenceFlags chatListLayouts][0]];
}

+ (NSString *)chatListLayoutTitle {
	NSUInteger index = [[TGPreferenceFlags chatListLayouts]
		indexOfObject:[TGPreferenceFlags chatListLayout]];
	if (index == NSNotFound)
		index = 1;
	return [TGPreferenceFlags chatListLayoutTitles][index];
}

+ (void)setChatListLayout:(NSString *)layout {
	if (![[TGPreferenceFlags chatListLayouts] containsObject:layout])
		return;
	[[NSUserDefaults standardUserDefaults] setObject:layout
											  forKey:TGPreferenceChatListLayoutKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGPreferenceChatListLayoutChangedNotification
					  object:nil];
}

+ (BOOL)savedMessagesShowsTopics {
	id stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGPreferenceSavedMessagesShowsTopicsKey];
	if (![stored respondsToSelector:@selector(boolValue)])
		return YES;
	return [stored boolValue];
}

+ (void)setSavedMessagesShowsTopics:(BOOL)showsTopics {
	[[NSUserDefaults standardUserDefaults] setBool:showsTopics
											forKey:TGPreferenceSavedMessagesShowsTopicsKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL)stickersLargeEmojiEnabled {
	id stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGPreferenceStickerLargeEmojiKey];
	if (![stored respondsToSelector:@selector(boolValue)])
		return YES;
	return [stored boolValue];
}

+ (BOOL)stickersLoopAnimatedEnabled {
	return TGPreferenceDefaultOnFlag(TGPreferenceStickerLoopAnimatedKey);
}

+ (float)voicePlaybackRate {
	NSNumber *stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGPreferenceVoicePlaybackRateKey];
	if (![stored isKindOfClass:[NSNumber class]])
		return 1.0f;
	float rate = [stored floatValue];
	return rate > 0.0f ? rate : 1.0f;
}

+ (void)setVoicePlaybackRate:(float)rate {
	[[NSUserDefaults standardUserDefaults] setFloat:rate forKey:TGPreferenceVoicePlaybackRateKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end

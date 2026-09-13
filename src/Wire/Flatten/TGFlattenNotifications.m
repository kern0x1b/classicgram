#import "TGFlattenNotifications.h"
#import "TGClient+Notifications.h"

const NSInteger kNotificationMuteForever = INT32_MAX;

static NSNumber *TGFlatNotifBool(NSDictionary *d, NSString *key) {
	id value = [d isKindOfClass:[NSDictionary class]] ? d[key] : nil;
	return @([value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO);
}

static NSNumber *TGFlatNotifNumber(NSDictionary *d, NSString *key) {
	id value = [d isKindOfClass:[NSDictionary class]] ? d[key] : nil;
	return [value isKindOfClass:[NSNumber class]] ? value : @(0);
}

static NSNumber *TGFlatNotifInt64(NSDictionary *d, NSString *key) {
	id value = [d isKindOfClass:[NSDictionary class]] ? d[key] : nil;
	if (![value isKindOfClass:[NSNumber class]] && ![value isKindOfClass:[NSString class]])
		return @(0);
	return @([value longLongValue]);
}

NSString *TGNotifScopeType(NSString *scope) {
	if ([scope isEqualToString:@"groups"])
		return @"notificationSettingsScopeGroupChats";
	if ([scope isEqualToString:@"channels"])
		return @"notificationSettingsScopeChannelChats";
	return @"notificationSettingsScopePrivateChats";
}

NSString *TGNotifReactionSource(NSString *name) {
	if ([name isEqualToString:@"all"])
		return @"reactionNotificationSourceAll";
	if ([name isEqualToString:@"contacts"])
		return @"reactionNotificationSourceContacts";
	return @"reactionNotificationSourceNone";
}

NSString *TGNotifReactionSourceName(NSDictionary *source) {
	NSString *type = [source isKindOfClass:[NSDictionary class]] ? source[@"@type"] : nil;
	if ([type isEqualToString:@"reactionNotificationSourceAll"])
		return @"all";
	if ([type isEqualToString:@"reactionNotificationSourceContacts"])
		return @"contacts";
	return @"none";
}

NSDictionary *TGNotifReactionSettingsFrom(NSDictionary *settings) {
	if (![settings isKindOfClass:[NSDictionary class]])
		settings = @{};
	return @{
		@"messageSource" : TGNotifReactionSourceName(settings[@"message_reaction_source"]),
		@"storySource" : TGNotifReactionSourceName(settings[@"story_reaction_source"]),
		@"pollVoteSource" : TGNotifReactionSourceName(settings[@"poll_vote_source"]),
		@"soundId" : TGFlatNotifInt64(settings, @"sound_id"),
		@"showPreview" : TGFlatNotifBool(settings, @"show_preview"),
	};
}

NSDictionary *TGNotifReactionSettingsMerged(NSDictionary *current, NSDictionary *changes) {
	NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:
			[current isKindOfClass:[NSDictionary class]] ? current : @{}];
	if ([changes isKindOfClass:[NSDictionary class]])
		[merged addEntriesFromDictionary:changes];
	NSArray *sourceKeys = @[ @"messageSource", @"storySource", @"pollVoteSource" ];
	for (NSString *key in sourceKeys) {
		NSString *value = merged[key];
		if (![value isKindOfClass:[NSString class]] || ![value length])
			merged[key] = @"none";
	}
	if (![merged[@"soundId"] isKindOfClass:[NSNumber class]] &&
		![merged[@"soundId"] isKindOfClass:[NSString class]])
		merged[@"soundId"] = @(0);
	if (![merged[@"showPreview"] respondsToSelector:@selector(boolValue)])
		merged[@"showPreview"] = @YES;
	return merged;
}

NSDictionary *TGNotifReactionSettingsPayload(NSDictionary *settings) {
	NSDictionary *full = TGNotifReactionSettingsMerged(settings, nil);
	return @{
		@"@type" : @"reactionNotificationSettings",
		@"message_reaction_source" : @{@"@type" : TGNotifReactionSource(full[@"messageSource"])},
		@"story_reaction_source" : @{@"@type" : TGNotifReactionSource(full[@"storySource"])},
		@"poll_vote_source" : @{@"@type" : TGNotifReactionSource(full[@"pollVoteSource"])},
		@"sound_id" : @([full[@"soundId"] longLongValue]),
		@"show_preview" : @([full[@"showPreview"] boolValue]),
	};
}

NSDictionary *TGNotifScopeSettingsFrom(NSDictionary *s) {
	return @{
		@"muted" : @([TGFlatNotifNumber(s, @"mute_for") integerValue] > 0),
		@"muteFor" : TGFlatNotifNumber(s, @"mute_for"),
		@"showPreview" : TGFlatNotifBool(s, @"show_preview"),
		@"soundId" : TGFlatNotifInt64(s, @"sound_id"),
		@"useDefaultMuteStories" : TGFlatNotifBool(s, @"use_default_mute_stories"),
		@"muteStories" : TGFlatNotifBool(s, @"mute_stories"),
		@"storySoundId" : TGFlatNotifInt64(s, @"story_sound_id"),
		@"showStoryPoster" : TGFlatNotifBool(s, @"show_story_poster"),
		@"disablePinnedMessageNotifications" :
			TGFlatNotifBool(s, @"disable_pinned_message_notifications"),
		@"disableMentionNotifications" :
			TGFlatNotifBool(s, @"disable_mention_notifications"),
	};
}

NSDictionary *TGNotifChatSettingsFrom(NSDictionary *s, BOOL defaultSilent) {
	return @{
		@"muted" : @([TGFlatNotifNumber(s, @"mute_for") integerValue] > 0),
		@"muteFor" : TGFlatNotifNumber(s, @"mute_for"),
		@"useDefaultMuteFor" : TGFlatNotifBool(s, @"use_default_mute_for"),
		@"showPreview" : TGFlatNotifBool(s, @"show_preview"),
		@"useDefaultShowPreview" : TGFlatNotifBool(s, @"use_default_show_preview"),
		@"soundId" : TGFlatNotifInt64(s, @"sound_id"),
		@"useDefaultSound" : TGFlatNotifBool(s, @"use_default_sound"),
		@"useDefaultMuteStories" : TGFlatNotifBool(s, @"use_default_mute_stories"),
		@"muteStories" : TGFlatNotifBool(s, @"mute_stories"),
		@"useDefaultStorySound" : TGFlatNotifBool(s, @"use_default_story_sound"),
		@"storySoundId" : TGFlatNotifInt64(s, @"story_sound_id"),
		@"useDefaultShowStoryPoster" : TGFlatNotifBool(s, @"use_default_show_story_poster"),
		@"showStoryPoster" : TGFlatNotifBool(s, @"show_story_poster"),
		@"disablePinnedMessageNotifications" :
			TGFlatNotifBool(s, @"disable_pinned_message_notifications"),
		@"useDefaultDisablePinnedMessageNotifications" :
			TGFlatNotifBool(s, @"use_default_disable_pinned_message_notifications"),
		@"disableMentionNotifications" :
			TGFlatNotifBool(s, @"disable_mention_notifications"),
		@"useDefaultDisableMentionNotifications" :
			TGFlatNotifBool(s, @"use_default_disable_mention_notifications"),
		@"defaultDisableNotification" : @(defaultSilent),
	};
}

id TGNotifPick(NSDictionary *changes, NSDictionary *current, NSString *key) {
	id value = [changes isKindOfClass:[NSDictionary class]] ? changes[key] : nil;
	if ([value isKindOfClass:[NSNumber class]])
		return value;
	return current[key] ?: @(0);
}

NSDictionary *TGNotifScopeMutedOverrides(NSDictionary *changes) {
	if (![changes isKindOfClass:[NSDictionary class]])
		return @{};
	if (![changes[@"muted"] isKindOfClass:[NSNumber class]] ||
		[changes[@"muteFor"] isKindOfClass:[NSNumber class]])
		return @{};
	return @{
		@"muteFor" : @([changes[@"muted"] boolValue] ? kNotificationMuteForever : 0),
	};
}

NSDictionary *TGNotifChatMutedOverrides(NSDictionary *changes) {
	if (![changes isKindOfClass:[NSDictionary class]])
		return @{};

	NSMutableDictionary *overrides = [NSMutableDictionary dictionary];

	if ([changes[@"muted"] isKindOfClass:[NSNumber class]] &&
		![changes[@"muteFor"] isKindOfClass:[NSNumber class]]) {
		overrides[@"muteFor"] = @([changes[@"muted"] boolValue] ? kNotificationMuteForever : 0);
		overrides[@"useDefaultMuteFor"] = @NO;
	}
	if ([changes[@"muteFor"] isKindOfClass:[NSNumber class]] &&
		![changes[@"useDefaultMuteFor"] isKindOfClass:[NSNumber class]])
		overrides[@"useDefaultMuteFor"] = @NO;
	if ([changes[@"showPreview"] isKindOfClass:[NSNumber class]] &&
		![changes[@"useDefaultShowPreview"] isKindOfClass:[NSNumber class]])
		overrides[@"useDefaultShowPreview"] = @NO;
	if ([changes[@"soundId"] isKindOfClass:[NSNumber class]] &&
		![changes[@"useDefaultSound"] isKindOfClass:[NSNumber class]])
		overrides[@"useDefaultSound"] = @NO;
	if ([changes[@"muteStories"] isKindOfClass:[NSNumber class]] &&
		![changes[@"useDefaultMuteStories"] isKindOfClass:[NSNumber class]])
		overrides[@"useDefaultMuteStories"] = @NO;
	if ([changes[@"storySoundId"] isKindOfClass:[NSNumber class]] &&
		![changes[@"useDefaultStorySound"] isKindOfClass:[NSNumber class]])
		overrides[@"useDefaultStorySound"] = @NO;
	if ([changes[@"showStoryPoster"] isKindOfClass:[NSNumber class]] &&
		![changes[@"useDefaultShowStoryPoster"] isKindOfClass:[NSNumber class]])
		overrides[@"useDefaultShowStoryPoster"] = @NO;
	if ([changes[@"disablePinnedMessageNotifications"] isKindOfClass:[NSNumber class]] &&
		![changes[@"useDefaultDisablePinnedMessageNotifications"] isKindOfClass:[NSNumber class]])
		overrides[@"useDefaultDisablePinnedMessageNotifications"] = @NO;
	if ([changes[@"disableMentionNotifications"] isKindOfClass:[NSNumber class]] &&
		![changes[@"useDefaultDisableMentionNotifications"] isKindOfClass:[NSNumber class]])
		overrides[@"useDefaultDisableMentionNotifications"] = @NO;

	return overrides;
}

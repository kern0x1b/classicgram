#import "TGClient+ChatState.h"
#import "TGDisappearingMedia.h"
#import "TGClient+Notifications.h"
#import "TGLocalization.h"
#import "TGClient+Private.h"
#import "TGFlattenNotifications.h"
#import "TGAccountManager.h"
#import "TGFlattenMessage.h"
#import "TGPushExtraLine.h"

NSString *const TGScopeNotificationSettingsDidChangeNotification =
	@"TGScopeNotificationSettingsDidChangeNotification";

NSString *const TGNotificationUpdateNotification =
	@"TGNotificationUpdateNotification";
NSString *const TGServiceNotificationDidArriveNotification =
	@"TGServiceNotificationDidArriveNotification";

static NSNumber *TGNotifBool(NSDictionary *d, NSString *key) {
	id value = [d isKindOfClass:[NSDictionary class]] ? d[key] : nil;
	return @([value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO);
}

static NSNumber *TGNotifNumber(NSDictionary *d, NSString *key) {
	id value = [d isKindOfClass:[NSDictionary class]] ? d[key] : nil;
	return [value isKindOfClass:[NSNumber class]] ? value : @(0);
}

static NSNumber *TGNotifInt64(NSDictionary *d, NSString *key) {
	id value = [d isKindOfClass:[NSDictionary class]] ? d[key] : nil;
	if (![value isKindOfClass:[NSNumber class]] && ![value isKindOfClass:[NSString class]])
		return @(0);
	return @([value longLongValue]);
}

static NSString *TGNotifString(NSDictionary *d, NSString *key) {
	id value = [d isKindOfClass:[NSDictionary class]] ? d[key] : nil;
	return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSString *TGNotifActorOrSomeone(NSString *actor) {
	return actor.length ? actor : TGL(@"Premium.GiftedTitle.Someone", @"Someone");
}

static NSString *TGNotifPipeFragment(NSString *localized) {
	NSRange bar = [localized rangeOfString:@"|"];
	return bar.location != NSNotFound ? [localized substringFromIndex:bar.location + 1]
									   : localized;
}

static BOOL TGNotifPushContentIsSelfNarrating(NSDictionary *content) {
	if (![content isKindOfClass:[NSDictionary class]])
		return NO;
	NSString *type = content[@"@type"];
	if ([content[@"is_pinned"] boolValue])
		return YES;
	static NSSet *narrating = nil;
	if (!narrating)
		narrating = [[NSSet alloc] initWithObjects:
				@"pushMessageContentChatAddMembers", @"pushMessageContentChatDeleteMember",
			@"pushMessageContentChatChangeTitle", @"pushMessageContentChatChangePhoto",
			@"pushMessageContentChatJoinByLink", @"pushMessageContentChatJoinByRequest",
			@"pushMessageContentBasicGroupChatCreate", @"pushMessageContentVideoChatStarted",
			@"pushMessageContentVideoChatEnded", @"pushMessageContentScreenshotTaken",
			@"pushMessageContentGameScore", nil];
	return (type.length && [narrating containsObject:type]) ||
		TGPushExtraLineIsSelfNarrating(type);
}

static NSString *TGNotifPinnedDescriptorForPushType(NSString *type) {
	if ([type isEqualToString:@"pushMessageContentPhoto"])
		return TGPinnedDescriptorForContentKind(@"messagePhoto");
	if ([type isEqualToString:@"pushMessageContentVideo"])
		return TGPinnedDescriptorForContentKind(@"messageVideo");
	if ([type isEqualToString:@"pushMessageContentAnimation"])
		return TGPinnedDescriptorForContentKind(@"messageAnimation");
	if ([type isEqualToString:@"pushMessageContentVoiceNote"])
		return TGPinnedDescriptorForContentKind(@"messageVoiceNote");
	if ([type isEqualToString:@"pushMessageContentVideoNote"])
		return TGPinnedDescriptorForContentKind(@"messageVideoNote");
	if ([type isEqualToString:@"pushMessageContentAudio"])
		return TGPinnedDescriptorForContentKind(@"messageAudio");
	if ([type isEqualToString:@"pushMessageContentDocument"])
		return TGPinnedDescriptorForContentKind(@"messageDocument");
	if ([type isEqualToString:@"pushMessageContentSticker"])
		return TGPinnedDescriptorForContentKind(@"messageSticker");
	if ([type isEqualToString:@"pushMessageContentContact"])
		return TGPinnedDescriptorForContentKind(@"messageContact");
	if ([type isEqualToString:@"pushMessageContentLocation"])
		return TGPinnedDescriptorForContentKind(@"messageLocation");
	if ([type isEqualToString:@"pushMessageContentPoll"])
		return TGPinnedDescriptorForContentKind(@"messagePoll");
	if ([type isEqualToString:@"pushMessageContentGame"])
		return TGPinnedDescriptorForContentKind(@"messageGame");
	if ([type isEqualToString:@"pushMessageContentChecklist"])
		return TGPinnedDescriptorForContentKind(@"messageChecklist");
	return nil;
}

static NSString *TGNotifPinnedNoticeForPushContent(NSDictionary *content, NSString *actorName) {
	NSString *type = content[@"@type"];
	NSString *actor = TGNotifActorOrSomeone(actorName);
	NSString *descriptor = TGNotifPinnedDescriptorForPushType(type);
	if (!descriptor.length && [type isEqualToString:@"pushMessageContentText"]) {
		NSString *text = TGNotifString(content, @"text");
		descriptor = text.length
			? [NSString stringWithFormat:@"\"%@\"", text]
			: TGL(@"Chat.PinnedDescriptor.Message", @"a message");
	}
	return descriptor.length
		? TGComposePinnedNotice(actor, descriptor)
		: [NSString stringWithFormat:TGL(@"Message.PinnedGenericMessage", @"%@ pinned a message"),
			actor];
}

static BOOL TGNotifMessageContentIsSelfNarrating(NSString *type) {
	static NSSet *narrating = nil;
	if (!narrating)
		narrating = [[NSSet alloc] initWithObjects:
				@"messageScreenshotTaken", @"messageChatAddMembers", @"messageChatDeleteMember",
			@"messageChatJoinByLink", @"messageChatJoinByRequest", @"messageChatChangeTitle",
			@"messageChatChangePhoto", @"messagePinMessage", nil];
	return type.length && [narrating containsObject:type];
}

@implementation TGClient (Notifications)

#pragma mark - scope settings

- (void)notificationSettingsForScope:(NSString *)scope
						  completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"getScopeNotificationSettings",
		@"scope" : @{@"@type" : TGNotifScopeType(scope)},
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		completion(TGNotifScopeSettingsFrom(result));
	}];
}

- (NSDictionary *)scopeNotificationRequestFor:(NSString *)scope settings:(NSDictionary *)settings {
	return @{
		@"@type" : @"setScopeNotificationSettings",
		@"scope" : @{@"@type" : TGNotifScopeType(scope)},
		@"notification_settings" : @{
			@"@type" : @"scopeNotificationSettings",
			@"mute_for" : settings[@"muteFor"] ?: @(0),
			@"sound_id" : settings[@"soundId"] ?: @(0),
			@"show_preview" : settings[@"showPreview"] ?: @YES,
			@"use_default_mute_stories" : settings[@"useDefaultMuteStories"] ?: @YES,
			@"mute_stories" : settings[@"muteStories"] ?: @NO,
			@"story_sound_id" : settings[@"storySoundId"] ?: @(0),
			@"show_story_poster" : settings[@"showStoryPoster"] ?: @NO,
			@"disable_pinned_message_notifications" :
					settings[@"disablePinnedMessageNotifications"] ?: @NO,
			@"disable_mention_notifications" :
					settings[@"disableMentionNotifications"] ?: @NO,
		},
	};
}

- (void)writeScope:(NSString *)scope settings:(NSDictionary *)settings {
	[self send:[self scopeNotificationRequestFor:scope settings:settings]];
}

- (void)updateScope:(NSString *)scope
			 values:(NSDictionary *)changes
		 completion:(void (^)(BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self notificationSettingsForScope:scope completion:^(NSDictionary *current) {
		if (!current) {
			if (completion)
				completion(NO);
			return;
		}
		NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:current];
		for (NSString *key in [merged allKeys])
			merged[key] = TGNotifPick(changes, current, key);
		[merged addEntriesFromDictionary:TGNotifScopeMutedOverrides(changes)];

		[weakSelf request:[weakSelf scopeNotificationRequestFor:scope settings:merged]
			   completion:^(NSDictionary *result) {
				   if (completion)
					   completion(!TGResultIsError(result));
			   }];
	}];
}

- (void)setScope:(NSString *)scope muteForSeconds:(NSInteger)seconds {
	[self updateScope:scope values:@{@"muteFor" : @(seconds)} completion:nil];
}

#pragma mark - per-chat settings

- (void)notificationSettingsForChat:(int64_t)chatId
						 completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			if (!completion)
				return;
			if (TGResultIsError(chat)) {
				completion(nil);
				return;
			}
			NSDictionary *s = chat[@"notification_settings"];
			if (![s isKindOfClass:[NSDictionary class]])
				s = [NSDictionary dictionary];
			completion(TGNotifChatSettingsFrom(s,
				[chat[@"default_disable_notification"] boolValue]));
		}];
}

- (NSDictionary *)chatNotificationPayloadFrom:(NSDictionary *)settings {
	return @{
		@"@type" : @"chatNotificationSettings",
		@"use_default_mute_for" : settings[@"useDefaultMuteFor"] ?: @NO,
		@"mute_for" : settings[@"muteFor"] ?: @(0),
		@"use_default_sound" : settings[@"useDefaultSound"] ?: @YES,
		@"sound_id" : settings[@"soundId"] ?: @(0),
		@"use_default_show_preview" : settings[@"useDefaultShowPreview"] ?: @YES,
		@"show_preview" : settings[@"showPreview"] ?: @YES,
		@"use_default_mute_stories" : settings[@"useDefaultMuteStories"] ?: @YES,
		@"mute_stories" : settings[@"muteStories"] ?: @NO,
		@"use_default_story_sound" : settings[@"useDefaultStorySound"] ?: @YES,
		@"story_sound_id" : settings[@"storySoundId"] ?: @(0),
		@"use_default_show_story_poster" : settings[@"useDefaultShowStoryPoster"] ?: @YES,
		@"show_story_poster" : settings[@"showStoryPoster"] ?: @NO,
		@"use_default_disable_pinned_message_notifications" :
				settings[@"useDefaultDisablePinnedMessageNotifications"] ?: @YES,
		@"disable_pinned_message_notifications" :
				settings[@"disablePinnedMessageNotifications"] ?: @NO,
		@"use_default_disable_mention_notifications" :
				settings[@"useDefaultDisableMentionNotifications"] ?: @YES,
		@"disable_mention_notifications" :
				settings[@"disableMentionNotifications"] ?: @NO,
	};
}

- (NSDictionary *)chatNotificationRequestFor:(int64_t)chatId settings:(NSDictionary *)settings {
	return @{
		@"@type" : @"setChatNotificationSettings",
		@"chat_id" : @(chatId),
		@"notification_settings" : [self chatNotificationPayloadFrom:settings],
	};
}

- (void)writeChat:(int64_t)chatId settings:(NSDictionary *)settings {
	[self writeChat:chatId settings:settings completion:nil];
}

- (void)writeChat:(int64_t)chatId
		 settings:(NSDictionary *)settings
	   completion:(void (^)(BOOL ok))completion {
	[self request:[self chatNotificationRequestFor:chatId settings:settings]
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)setChat:(int64_t)chatId muteForSeconds:(NSInteger)seconds {
	[self setChat:chatId muteForSeconds:seconds completion:nil];
}

- (void)setChat:(int64_t)chatId
	muteForSeconds:(NSInteger)seconds
		completion:(void (^)(BOOL ok))completion {
	[self updateChat:chatId
			  values:@{@"muteFor" : @(seconds), @"useDefaultMuteFor" : @NO}
		  completion:completion];
}

- (void)updateChat:(int64_t)chatId
			values:(NSDictionary *)changes
		completion:(void (^)(BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self notificationSettingsForChat:chatId completion:^(NSDictionary *current) {
		if (!current) {
			if (completion)
				completion(NO);
			return;
		}
		NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:current];
		for (NSString *key in [merged allKeys])
			merged[key] = TGNotifPick(changes, current, key);
		[merged addEntriesFromDictionary:TGNotifChatMutedOverrides(changes)];

		[weakSelf request:[weakSelf chatNotificationRequestFor:chatId settings:merged]
			   completion:^(NSDictionary *result) {
				   if (completion)
					   completion(!TGResultIsError(result));
			   }];
	}];
}

- (void)resetNotificationSettingsForChat:(int64_t)chatId {
	[self resetNotificationSettingsForChat:chatId completion:nil];
}

- (void)resetNotificationSettingsForChat:(int64_t)chatId
							   completion:(void (^)(BOOL ok))completion {
	[self writeChat:chatId
		   settings:@{
			   @"useDefaultMuteFor" : @YES,
			   @"useDefaultSound" : @YES,
			   @"useDefaultShowPreview" : @YES,
			   @"useDefaultDisablePinnedMessageNotifications" : @YES,
			   @"useDefaultDisableMentionNotifications" : @YES,
		   }
		 completion:completion];
}

- (void)setChat:(int64_t)chatId defaultDisableNotification:(BOOL)silent {
	[self send:@{
		@"@type" : @"toggleChatDefaultDisableNotification",
		@"chat_id" : @(chatId),
		@"default_disable_notification" : @(silent),
	}];
}

#pragma mark - exceptions

- (void)exceptionChatIdsForScope:(NSString *)scope
					compareSound:(BOOL)compareSound
					  completion:(void (^)(NSArray *, BOOL))completion {
	NSMutableDictionary *query = [NSMutableDictionary dictionaryWithDictionary:@{
		@"@type" : @"getChatNotificationSettingsExceptions",
		@"compare_sound" : @(compareSound),
	}];
	query[@"scope"] = scope.length ? (id) @{@"@type" : TGNotifScopeType(scope)} : (id)[NSNull null];

	[self request:query completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion([NSArray array], YES);
			return;
		}
		NSArray *ids = result[@"chat_ids"];
		completion([ids isKindOfClass:[NSArray class]] ? ids : [NSArray array], NO);
	}];
}

- (void)notificationExceptionsForScope:(NSString *)scope
						  compareSound:(BOOL)compareSound
							completion:(void (^)(NSArray *, BOOL))completion {
	__weak typeof(self) weakSelf = self;
	void (^collectRows)(NSArray *, BOOL) = ^(NSArray *chatIds, BOOL failed) {
		if (!completion)
			return;
		if (!chatIds.count) {
			completion([NSArray array], failed);
			return;
		}

		NSMutableArray *rows = [NSMutableArray array];
		__block NSUInteger pending = chatIds.count;
		for (NSNumber *chatId in chatIds) {
			if (![chatId isKindOfClass:[NSNumber class]]) {
				if (--pending == 0)
					completion(rows, NO);
				continue;
			}
			[weakSelf request:@{@"@type" : @"getChat", @"chat_id" : chatId}
				   completion:^(NSDictionary *chat) {
					   if (!TGResultIsError(chat)) {
						   NSDictionary *s = chat[@"notification_settings"];
						   if (![s isKindOfClass:[NSDictionary class]])
							   s = [NSDictionary dictionary];
						   [rows addObject:@{
							   @"id" : chatId,
							   @"title" : TGNotifString(chat, @"title"),
							   @"muted" : @([TGNotifNumber(s, @"mute_for") integerValue] > 0),
							   @"muteFor" : TGNotifNumber(s, @"mute_for"),
							   @"showPreview" : TGNotifBool(s, @"show_preview"),
							   @"customSound" : @(![TGNotifBool(s, @"use_default_sound") boolValue]),
						   }];
					   }
					   if (--pending == 0)
						   completion(rows, NO);
				   }];
		}
	};
	[self exceptionChatIdsForScope:scope compareSound:compareSound completion:collectRows];
}

- (void)clearNotificationExceptionsForScope:(NSString *)scope
								 completion:(void (^)(NSInteger))completion {
	__weak typeof(self) weakSelf = self;
	[self exceptionChatIdsForScope:scope compareSound:YES completion:^(NSArray *chatIds, BOOL failed) {
		NSInteger reset = 0;
		for (NSNumber *chatId in chatIds) {
			if (![chatId isKindOfClass:[NSNumber class]])
				continue;
			[weakSelf resetNotificationSettingsForChat:chatId.longLongValue];
			reset++;
		}
		if (completion)
			completion(reset);
	}];
}

- (void)resetAllNotificationSettingsWithCompletion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"resetAllNotificationSettings"}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

#pragma mark - reactions

NSString *const TGReactionNotificationMessageSourceKey = @"TGReactionNotificationSource";
NSString *const TGReactionNotificationStorySourceKey = @"TGStoryReactionSource";
NSString *const TGReactionNotificationPollVoteSourceKey = @"TGPollVoteNotificationSource";
NSString *const TGReactionNotificationPreviewKey = @"TGReactionNotificationPreview";
NSString *const TGReactionNotificationSoundIdKey = @"TGReactionNotificationSoundId";

static NSString *TGReactionMirrorSource(NSString *base, NSString *fallback) {
	NSString *stored = [[NSUserDefaults standardUserDefaults]
			stringForKey:[TGAccountManager defaultsKey:base]];
	return stored.length ? stored : fallback;
}

- (NSDictionary *)reactionNotificationSettings {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	id preview = [defaults objectForKey:[TGAccountManager defaultsKey:TGReactionNotificationPreviewKey]];
	id soundId = [defaults objectForKey:[TGAccountManager defaultsKey:TGReactionNotificationSoundIdKey]];
	return TGNotifReactionSettingsMerged(@{
		@"messageSource" : TGReactionMirrorSource(TGReactionNotificationMessageSourceKey, @"contacts"),
		@"storySource" : TGReactionMirrorSource(TGReactionNotificationStorySourceKey, @"contacts"),
		@"pollVoteSource" : TGReactionMirrorSource(TGReactionNotificationPollVoteSourceKey, @"contacts"),
		@"soundId" : soundId ?: @(0),
		@"showPreview" : preview ?: @YES,
	}, nil);
}

- (void)rememberReactionNotificationSettings:(NSDictionary *)settings {
	NSDictionary *full = TGNotifReactionSettingsMerged(settings, nil);
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:full[@"messageSource"]
				 forKey:[TGAccountManager defaultsKey:TGReactionNotificationMessageSourceKey]];
	[defaults setObject:full[@"storySource"]
				 forKey:[TGAccountManager defaultsKey:TGReactionNotificationStorySourceKey]];
	[defaults setObject:full[@"pollVoteSource"]
				 forKey:[TGAccountManager defaultsKey:TGReactionNotificationPollVoteSourceKey]];
	[defaults setObject:@([full[@"showPreview"] boolValue])
				 forKey:[TGAccountManager defaultsKey:TGReactionNotificationPreviewKey]];
	[defaults setObject:@([full[@"soundId"] longLongValue])
				 forKey:[TGAccountManager defaultsKey:TGReactionNotificationSoundIdKey]];
	[defaults synchronize];
}

- (void)changeReactionNotificationSettings:(NSDictionary *)changes
								completion:(void (^)(BOOL ok))completion {
	NSDictionary *merged = TGNotifReactionSettingsMerged([self reactionNotificationSettings], changes);
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"setReactionNotificationSettings",
		@"notification_settings" : TGNotifReactionSettingsPayload(merged),
	}
		completion:^(NSDictionary *result) {
			BOOL ok = !TGResultIsError(result);
			if (ok)
				[weakSelf rememberReactionNotificationSettings:merged];
			if (completion)
				completion(ok);
		}];
}

- (void)applyReactionNotificationSettingsUpdate:(NSDictionary *)update {
	[self rememberReactionNotificationSettings:
			TGNotifReactionSettingsFrom(update[@"notification_settings"])];
}

#pragma mark - sounds

static NSDictionary *TGNotifSoundFrom(NSDictionary *sound) {
	NSDictionary *file = sound[@"sound"];
	NSNumber *fileId = [file isKindOfClass:[NSDictionary class]] ? file[@"id"] : nil;
	return @{
		@"id" : TGNotifInt64(sound, @"id"),
		@"title" : TGNotifString(sound, @"title"),
		@"duration" : TGNotifNumber(sound, @"duration"),
		@"date" : TGNotifNumber(sound, @"date"),
		@"fileId" : [fileId isKindOfClass:[NSNumber class]] ? fileId : @(0),
	};
}

- (void)savedNotificationSoundsWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getSavedNotificationSounds"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			NSMutableArray *out = [NSMutableArray array];
			NSArray *sounds = result[@"notification_sounds"];
			if ([sounds isKindOfClass:[NSArray class]]) {
				for (NSDictionary *sound in sounds)
					if ([sound isKindOfClass:[NSDictionary class]])
						[out addObject:TGNotifSoundFrom(sound)];
			}
			completion(out);
		}];
}

- (void)addSavedNotificationSoundAtPath:(NSString *)path
							 completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"addSavedNotificationSound",
		@"sound" : @{@"@type" : @"inputFileLocal", @"path" : path ?: @""},
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGNotifSoundFrom(result));
	}];
}

- (void)removeSavedNotificationSound:(long long)soundId {
	[self send:@{
		@"@type" : @"removeSavedNotificationSound",
		@"notification_sound_id" : @(soundId),
	}];
}

#pragma mark - archive settings

- (void)archiveChatListSettingsWithCompletion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getArchiveChatListSettings"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			completion(@{
				@"archiveAndMuteNewChatsFromUnknownUsers" :
					TGNotifBool(result, @"archive_and_mute_new_chats_from_unknown_users"),
				@"keepUnmutedChatsArchived" :
					TGNotifBool(result, @"keep_unmuted_chats_archived"),
				@"keepChatsFromFoldersArchived" :
					TGNotifBool(result, @"keep_chats_from_folders_archived"),
			});
		}];
}

- (void)updateArchiveChatListSettings:(NSDictionary *)changes
						   completion:(void (^)(BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self archiveChatListSettingsWithCompletion:^(NSDictionary *current) {
		if (!current) {
			if (completion)
				completion(NO);
			return;
		}
		NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:current];
		for (NSString *key in [merged allKeys])
			merged[key] = TGNotifPick(changes, current, key);

		[weakSelf request:@{
			@"@type" : @"setArchiveChatListSettings",
			@"settings" : @{
				@"@type" : @"archiveChatListSettings",
				@"archive_and_mute_new_chats_from_unknown_users" :
					merged[@"archiveAndMuteNewChatsFromUnknownUsers"],
				@"keep_unmuted_chats_archived" :
					merged[@"keepUnmutedChatsArchived"],
				@"keep_chats_from_folders_archived" :
					merged[@"keepChatsFromFoldersArchived"],
			},
		} completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
	}];
}

#pragma mark - local alerts

- (void)removeNotification:(NSInteger)notificationId inGroup:(NSInteger)groupId {
	[self send:@{
		@"@type" : @"removeNotification",
		@"notification_group_id" : @(groupId),
		@"notification_id" : @(notificationId),
	}];
}

- (void)removeNotificationGroup:(NSInteger)groupId
			 upToNotificationId:(NSInteger)maxNotificationId {
	NSInteger max = maxNotificationId;
	if (max > INT32_MAX || max < 0)
		max = INT32_MAX;
	[self send:@{
		@"@type" : @"removeNotificationGroup",
		@"notification_group_id" : @(groupId),
		@"max_notification_id" : @(max),
	}];
}

- (NSString *)previewTextForPushContent:(NSDictionary *)content actorName:(NSString *)actorName {
	if (![content isKindOfClass:[NSDictionary class]])
		return @"";
	NSString *type = content[@"@type"];
	if (![type isKindOfClass:[NSString class]])
		return @"";

	if ([content[@"is_pinned"] boolValue])
		return TGNotifPinnedNoticeForPushContent(content, actorName);

	if ([type isEqualToString:@"pushMessageContentText"])
		return TGNotifString(content, @"text");
	if ([type isEqualToString:@"pushMessageContentPhoto"]) {
		NSString *caption = TGNotifString(content, @"caption");
		if ([content[@"is_secret"] boolValue])
			return TGL(@"SecretImage.Title", @"Disappearing Photo");
		return caption.length ? caption : TGL(@"Message.Photo", @"Photo");
	}
	if ([type isEqualToString:@"pushMessageContentVideo"]) {
		NSString *caption = TGNotifString(content, @"caption");
		if ([content[@"is_secret"] boolValue])
			return TGL(@"SecretVideo.Title", @"Disappearing Video");
		return caption.length ? caption : TGL(@"Message.Video", @"Video");
	}
	if ([type isEqualToString:@"pushMessageContentAnimation"]) {
		NSString *caption = TGNotifString(content, @"caption");
		return caption.length ? caption : TGL(@"Message.Animation", @"GIF");
	}
	if ([type isEqualToString:@"pushMessageContentVoiceNote"])
		return TGL(@"Message.Audio", @"Voice message");
	if ([type isEqualToString:@"pushMessageContentVideoNote"])
		return TGL(@"Message.VideoMessage", @"Video Message");
	if ([type isEqualToString:@"pushMessageContentAudio"])
		return TGL(@"SharedMedia.CategoryOther", @"Audio");
	if ([type isEqualToString:@"pushMessageContentDocument"])
		return TGL(@"Message.File", @"File");
	if ([type isEqualToString:@"pushMessageContentSticker"]) {
		NSString *emoji = TGNotifString(content, @"emoji");
		return emoji.length
			? [NSString stringWithFormat:TGL(@"Message.StickerText", @"Sticker %@"), emoji]
			: TGL(@"Message.Sticker", @"Sticker");
	}
	if ([type isEqualToString:@"pushMessageContentContact"]) {
		NSString *name = TGNotifString(content, @"name");
		return name.length ? name : TGL(@"Message.Contact", @"Contact");
	}
	if ([type isEqualToString:@"pushMessageContentContactRegistered"])
		return TGNotifPipeFragment([NSString stringWithFormat:
					TGL(@"PUSH_CONTACT_JOINED", @"%1$@|joined Telegram!"),
			TGNotifActorOrSomeone(actorName)]);
	if ([type isEqualToString:@"pushMessageContentLocation"])
		return [content[@"is_live"] boolValue] ? TGL(@"Message.LiveLocation", @"Live location")
												: TGL(@"Message.Location", @"Location");
	if ([type isEqualToString:@"pushMessageContentPoll"]) {
		NSString *question = TGNotifString(content, @"question");
		return question.length ? question : TGL(@"Watch.Message.Poll", @"Poll");
	}
	if ([type isEqualToString:@"pushMessageContentGame"]) {
		NSString *title = TGNotifString(content, @"title");
		return title.length ? title : TGL(@"Message.Game", @"Game");
	}
	if ([type isEqualToString:@"pushMessageContentGameScore"]) {
		NSInteger score = [TGNotifNumber(content, @"score") integerValue];
		return [NSString stringWithFormat:TGL(@"Notification.GameScore", @"%@ scored %ld"),
			TGNotifActorOrSomeone(actorName), (long) score];
	}
	if ([type isEqualToString:@"pushMessageContentInvoice"]) {
		NSString *price = TGNotifString(content, @"price");
		return price.length ? price : TGL(@"Watch.Message.Invoice", @"Invoice");
	}
	if ([type isEqualToString:@"pushMessageContentScreenshotTaken"])
		return [NSString stringWithFormat:
					TGL(@"Notification.SecretChatMessageScreenshot", @"%@ took a screenshot!"),
			TGNotifActorOrSomeone(actorName)];
	if ([type isEqualToString:@"pushMessageContentChatAddMembers"]) {
		NSString *name = TGNotifString(content, @"member_name");
		if ([content[@"is_returned"] boolValue])
			return [NSString stringWithFormat:TGL(@"Notification.JoinedChat",
										@"%@ joined the group"),
				TGNotifActorOrSomeone(actorName)];
		return [NSString stringWithFormat:TGL(@"Notification.Invited", @"%@ invited %@"),
			TGNotifActorOrSomeone(actorName),
			name.length ? name : TGL(@"Notification.UnknownUserListLowercase", @"someone")];
	}
	if ([type isEqualToString:@"pushMessageContentChatDeleteMember"]) {
		NSString *name = TGNotifString(content, @"member_name");
		if ([content[@"is_left"] boolValue])
			return [NSString stringWithFormat:TGL(@"Notification.LeftChat",
										@"%@ left the group"),
				TGNotifActorOrSomeone(actorName)];
		return [NSString stringWithFormat:TGL(@"Notification.Kicked", @"%@ removed %@"),
			TGNotifActorOrSomeone(actorName),
			name.length ? name : TGL(@"Notification.UnknownUserListLowercase", @"someone")];
	}
	if ([type isEqualToString:@"pushMessageContentChatChangeTitle"]) {
		NSString *title = TGNotifString(content, @"title");
		return [NSString stringWithFormat:
					TGL(@"Notification.ChangedGroupName", @"%@ changed group name to \"%@\""),
			TGNotifActorOrSomeone(actorName), title];
	}
	if ([type isEqualToString:@"pushMessageContentChatChangePhoto"])
		return [NSString stringWithFormat:TGL(@"Notification.ChangedGroupPhoto",
									@"%@ changed group photo"),
			TGNotifActorOrSomeone(actorName)];
	if ([type isEqualToString:@"pushMessageContentChatJoinByLink"])
		return [NSString stringWithFormat:
					TGL(@"Notification.JoinedGroupByLink",
						@"%@ joined the group via invite link"),
			TGNotifActorOrSomeone(actorName)];
	if ([type isEqualToString:@"pushMessageContentChatJoinByRequest"])
		return [NSString stringWithFormat:
					TGL(@"Notification.JoinedGroupByRequest",
						@"%@ was accepted to the group chat"),
			TGNotifActorOrSomeone(actorName)];
	if ([type isEqualToString:@"pushMessageContentBasicGroupChatCreate"])
		return [NSString stringWithFormat:TGL(@"Notification.CreatedChat",
									@"%@ created a group"),
			TGNotifActorOrSomeone(actorName)];
	if ([type isEqualToString:@"pushMessageContentVideoChatStarted"])
		return [NSString stringWithFormat:TGL(@"Notification.VoiceChatStarted",
									@"%@ started a voice chat"),
			TGNotifActorOrSomeone(actorName)];
	if ([type isEqualToString:@"pushMessageContentVideoChatEnded"])
		return TGNotifPipeFragment([NSString stringWithFormat:
					TGL(@"PUSH_CHAT_VOICECHAT_END", @"%2$@|%1$@ has ended the voice chat"),
			TGNotifActorOrSomeone(actorName), @""]);
	if ([type isEqualToString:@"pushMessageContentMessageForwards"]) {
		NSInteger count = [TGNotifNumber(content, @"total_count") integerValue];
		return TGLPlural(@"PUSH_MESSAGE_FWDS_TEXT", count, @"forwarded you a message",
			@"forwarded you %d messages");
	}
	if ([type isEqualToString:@"pushMessageContentMediaAlbum"]) {
		NSInteger count = [TGNotifNumber(content, @"total_count") integerValue];
		if ([content[@"has_photos"] boolValue])
			return TGLPlural(@"PUSH_MESSAGE_PHOTOS_TEXT", count, @"sent you a photo",
				@"sent you %d photos");
		if ([content[@"has_videos"] boolValue])
			return TGLPlural(@"PUSH_MESSAGE_VIDEOS_TEXT", count, @"sent you a video",
				@"sent you %d videos");
		return TGLPlural(@"PUSH_MESSAGE_FILES_TEXT", count, @"sent you a file",
			@"sent you %d files");
	}
	NSString *extra = TGPushExtraLine(content, actorName);
	if (extra.length)
		return extra;

	return [NSString stringWithFormat:
				TGL(@"PUSH_LOCKED_MESSAGE", @"You have a new message%1$@"),
		@""];
}

- (NSString *)previewTextForMessageContent:(NSDictionary *)content actorName:(NSString *)actorName {
	if (![content isKindOfClass:[NSDictionary class]])
		return @"";
	NSString *type = content[@"@type"];
	if (![type isKindOfClass:[NSString class]])
		return @"";

	if ([type isEqualToString:@"messageText"]) {
		NSDictionary *text = content[@"text"];
		return [text isKindOfClass:[NSDictionary class]] ? TGNotifString(text, @"text") : @"";
	}

	NSString *disappearingLabel = TGMediaContentDisappears(content)
		? TGDisappearingMediaLabel(type)
		: nil;
	if (disappearingLabel)
		return disappearingLabel;

	NSDictionary *caption = content[@"caption"];
	NSString *captionText = [caption isKindOfClass:[NSDictionary class]]
		? TGNotifString(caption, @"text")
		: @"";
	if (captionText.length)
		return captionText;

	if ([type isEqualToString:@"messagePhoto"])
		return TGL(@"Message.Photo", @"Photo");
	if ([type isEqualToString:@"messageVideo"])
		return TGL(@"Message.Video", @"Video");
	if ([type isEqualToString:@"messageAnimation"])
		return TGL(@"Message.Animation", @"GIF");
	if ([type isEqualToString:@"messageVoiceNote"])
		return TGL(@"Message.Audio", @"Voice message");
	if ([type isEqualToString:@"messageVideoNote"])
		return TGL(@"Message.VideoMessage", @"Video Message");
	if ([type isEqualToString:@"messageSticker"]) {
		NSDictionary *sticker = content[@"sticker"];
		NSString *emoji = [sticker isKindOfClass:[NSDictionary class]]
			? TGNotifString(sticker, @"emoji")
			: @"";
		return emoji.length
			? [NSString stringWithFormat:TGL(@"Message.StickerText", @"Sticker %@"), emoji]
			: TGL(@"Message.Sticker", @"Sticker");
	}
	if ([type isEqualToString:@"messageAnimatedEmoji"]) {
		NSString *emoji = TGNotifString(content, @"emoji");
		return emoji.length ? emoji : TGL(@"Message.Emoji", @"Emoji");
	}
	if ([type isEqualToString:@"messageDocument"]) {
		NSDictionary *document = content[@"document"];
		NSString *name = [document isKindOfClass:[NSDictionary class]]
			? TGNotifString(document, @"file_name")
			: @"";
		return name.length ? name : TGL(@"Message.File", @"File");
	}
	if ([type isEqualToString:@"messageAudio"]) {
		NSDictionary *audio = content[@"audio"];
		NSString *title = [audio isKindOfClass:[NSDictionary class]]
			? TGNotifString(audio, @"title")
			: @"";
		return title.length ? title : TGL(@"SharedMedia.CategoryOther", @"Audio");
	}
	if ([type isEqualToString:@"messageContact"])
		return TGL(@"Message.Contact", @"Contact");
	if ([type isEqualToString:@"messageVenue"])
		return TGL(@"Message.Location", @"Location");
	if ([type isEqualToString:@"messageLocation"])
		return [content[@"live_period"] integerValue] > 0
			? TGL(@"Message.LiveLocation", @"Live location")
			: TGL(@"Message.Location", @"Location");
	if ([type isEqualToString:@"messagePoll"]) {
		NSDictionary *poll = content[@"poll"];
		NSDictionary *question = [poll isKindOfClass:[NSDictionary class]]
			? poll[@"question"]
			: nil;
		NSString *text = [question isKindOfClass:[NSDictionary class]]
			? TGNotifString(question, @"text")
			: @"";
		return text.length ? text : TGL(@"Watch.Message.Poll", @"Poll");
	}
	if ([type isEqualToString:@"messageGame"])
		return TGL(@"Message.Game", @"Game");
	if ([type isEqualToString:@"messageInvoice"])
		return TGL(@"Watch.Message.Invoice", @"Invoice");
	if ([type isEqualToString:@"messageCall"])
		return TGL(@"Conversation.Call", @"Call");
	if ([type isEqualToString:@"messageScreenshotTaken"])
		return [NSString stringWithFormat:
					TGL(@"Notification.SecretChatMessageScreenshot", @"%@ took a screenshot!"),
			TGNotifActorOrSomeone(actorName)];
	if ([type isEqualToString:@"messageChatAddMembers"])
		return [NSString stringWithFormat:TGL(@"Notification.Invited", @"%@ invited %@"),
			TGNotifActorOrSomeone(actorName),
			TGL(@"Notification.UnknownUserListLowercase", @"someone")];
	if ([type isEqualToString:@"messageChatDeleteMember"])
		return [NSString stringWithFormat:TGL(@"Notification.LeftChat", @"%@ left the group"),
			TGNotifActorOrSomeone(actorName)];
	if ([type isEqualToString:@"messageChatJoinByLink"])
		return [NSString stringWithFormat:
					TGL(@"Notification.JoinedGroupByLink",
						@"%@ joined the group via invite link"),
			TGNotifActorOrSomeone(actorName)];
	if ([type isEqualToString:@"messageChatJoinByRequest"])
		return [NSString stringWithFormat:
					TGL(@"Notification.JoinedGroupByRequest",
						@"%@ was accepted to the group chat"),
			TGNotifActorOrSomeone(actorName)];
	if ([type isEqualToString:@"messageChatChangeTitle"]) {
		NSString *title = TGNotifString(content, @"title");
		return [NSString stringWithFormat:
					TGL(@"Notification.ChangedGroupName", @"%@ changed group name to \"%@\""),
			TGNotifActorOrSomeone(actorName), title];
	}
	if ([type isEqualToString:@"messageChatChangePhoto"])
		return [NSString stringWithFormat:TGL(@"Notification.ChangedGroupPhoto",
									@"%@ changed group photo"),
			TGNotifActorOrSomeone(actorName)];
	if ([type isEqualToString:@"messagePinMessage"])
		return [NSString stringWithFormat:
					TGL(@"Message.PinnedGenericMessage", @"%@ pinned a message"),
			TGNotifActorOrSomeone(actorName)];

	NSString *kindLabel = TGMessageContentKindLabel(content);
	if (kindLabel.length)
		return kindLabel;

	return [NSString stringWithFormat:
				TGL(@"PUSH_LOCKED_MESSAGE", @"You have a new message%1$@"),
		@""];
}

- (NSString *)titleForChatId:(int64_t)chatId {
	if (!chatId)
		return nil;
	id title = self.chatsById[@(chatId)][@"title"];
	if ([title isKindOfClass:[NSString class]] && [title length])
		return title;
	return [self nameForUserId:chatId];
}

- (NSDictionary *)alertForNotification:(NSDictionary *)notification
							  chatName:(NSString *)chatName {
	if (![notification isKindOfClass:[NSDictionary class]])
		return nil;
	NSDictionary *type = notification[@"type"];
	if (![type isKindOfClass:[NSDictionary class]])
		return nil;

	NSString *typeName = type[@"@type"];
	NSString *title = chatName.length ? chatName : @"Telegram";
	NSString *body = nil;
	int64_t chatId = 0;

	if ([typeName isEqualToString:@"notificationTypeNewPushMessage"]) {
		NSString *sender = TGNotifString(type, @"sender_name");
		if (sender.length && !chatName.length)
			title = sender;
		NSDictionary *pushContent = type[@"content"];
		body = [self previewTextForPushContent:type[@"content"] actorName:sender];
		if (sender.length && chatName.length && ![sender isEqualToString:chatName] &&
			!TGNotifPushContentIsSelfNarrating(pushContent))
			body = [NSString stringWithFormat:@"%@: %@", sender, body];
	} else if ([typeName isEqualToString:@"notificationTypeNewMessage"]) {
		NSDictionary *message = type[@"message"];
		if ([message isKindOfClass:[NSDictionary class]]) {
			chatId = [message[@"chat_id"] longLongValue];
			int64_t senderId = 0;
			NSDictionary *sender = message[@"sender_id"];
			if ([sender isKindOfClass:[NSDictionary class]])
				senderId = [sender[@"user_id"] longLongValue];
			NSString *name = senderId ? [self nameForUserId:senderId] : nil;
			if (![type[@"show_preview"] boolValue]) {
				title = @"Telegram";
				body = [NSString stringWithFormat:
							TGL(@"PUSH_LOCKED_MESSAGE", @"You have a new message%1$@"), @""];
			} else {
				NSDictionary *messageContent = message[@"content"];
				NSString *contentType =
					[messageContent isKindOfClass:[NSDictionary class]] &&
							[messageContent[@"@type"] isKindOfClass:[NSString class]]
						? messageContent[@"@type"]
						: @"";
				NSString *preview = [self previewTextForMessageContent:message[@"content"]
															   actorName:name];
				body = preview.length
					? preview
					: [NSString stringWithFormat:
								TGL(@"PUSH_LOCKED_MESSAGE", @"You have a new message%1$@"), @""];
				if (name.length && chatName.length && ![name isEqualToString:chatName] &&
					!TGNotifMessageContentIsSelfNarrating(contentType))
					body = [NSString stringWithFormat:@"%@: %@", name, body];
				else if (name.length && !chatName.length)
					title = name;
			}
		}
	} else if ([typeName isEqualToString:@"notificationTypeNewSecretChat"]) {
		body = [NSString stringWithFormat:
					TGL(@"PUSH_ENCRYPTION_REQUEST", @"New encryption request%1$@"), @""];
	} else if ([typeName isEqualToString:@"notificationTypeNewCall"]) {
		body = TGL(@"Notification.CallIncoming", @"Incoming Call");
	}

	if (!body.length)
		return nil;
	return @{@"title" : title, @"body" : body, @"chatId" : @(chatId)};
}

@end

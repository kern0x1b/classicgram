#import "TGClient+ChatManagement.h"
#import "TGUserDisplayName.h"
#import "TGClient+SecretChats.h"
#import "TGClient+Private.h"
#import "TGChatListPreviewAuthor.h"
#import "TGChatListOutgoingState.h"
#import "TGFlattenChatState.h"
#import "TGLocalization.h"
#import "TGClient+Network.h"
#import "TGClient+ChatList.h"
#import "TGClient+Notifications.h"
#import "TGClient+Stories.h"
#import "TGClient+Reactions.h"
#import "TGClient+Bots.h"
#import "TGClient+Contacts.h"
#import "TGClient+AppSettings.h"
#import "TGClient+UserStatus.h"
#import "TGClient+Account.h"
#import "TGClient+Messages.h"
#import "TGClient+DirectMessages.h"
#import "TGClient+WebLinks.h"
#import "TGClient+AiWriting.h"
#import "TGFlattenMessage.h"
#import "TGCall.h"
#import "TGBackgroundSession.h"
#import "TGDiskCache.h"
#import "TGAccountManager.h"
#import "TGRemoteImageView.h"
#import "AppDelegate.h"
#import <UIKit/UIKit.h>

NSString *const TGChatProtectedContentDidChangeNotification =
	@"TGChatProtectedContentDidChangeNotification";

@implementation TGClient (ChatState)

#pragma mark - account settings

- (void)setScope:(NSString *)scope muted:(BOOL)muted {
	[self updateScope:scope
			   values:@{@"muteFor" : @(muted ? kNotificationMuteForever : 0)}
		   completion:nil];
}

#pragma mark - effective mute state

- (NSString *)notificationScopeForChatInfo:(NSDictionary *)info {
	return TGScopeForChatFlags([info[@"isChannel"] boolValue], [info[@"isGroup"] boolValue]);
}

- (BOOL)effectiveMutedForChatInfo:(NSDictionary *)info {
	NSString *scope = [self notificationScopeForChatInfo:info];
	long long scopeDefaultMuteFor = [self.scopeMuteForByScope[scope] longLongValue];
	return TGEffectiveChatMuted([info[@"chatUseDefaultMuteFor"] boolValue],
		[info[@"chatMuteFor"] longLongValue], scopeDefaultMuteFor);
}

- (void)recomputeMutedForChatsInScope:(NSString *)scope {
	BOOL changed = NO;
	for (NSMutableDictionary *info in self.chatsById.allValues) {
		if (![info[@"chatUseDefaultMuteFor"] boolValue])
			continue;
		if (![[self notificationScopeForChatInfo:info] isEqualToString:scope])
			continue;
		BOOL muted = [self effectiveMutedForChatInfo:info];
		if ([info[@"isMuted"] boolValue] != muted) {
			info[@"isMuted"] = @(muted);
			changed = YES;
		}
	}
	if (changed)
		[self rebuildChats];
}

- (void)storeScopeDefaultMuteFor:(NSNumber *)muteFor forScope:(NSString *)scope {
	if ([self.scopeMuteForByScope[scope] isEqual:muteFor])
		return;
	self.scopeMuteForByScope[scope] = muteFor;
	[self recomputeMutedForChatsInScope:scope];
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGScopeNotificationSettingsDidChangeNotification
					  object:self
					userInfo:@{@"scope" : scope}];
}

- (void)loadNotificationScopeDefaults {
	for (NSString *scope in @[ @"private", @"groups", @"channels" ]) {
		__weak typeof(self) weakSelf = self;
		[self request:@{
			@"@type" : @"getScopeNotificationSettings",
			@"scope" : @{@"@type" : TGScopeType(scope)},
		} completion:^(NSDictionary *settings) {
			TGClient *strongSelf = weakSelf;
			if (!strongSelf || TGResultIsError(settings))
				return;
			NSNumber *muteFor = [settings[@"mute_for"] isKindOfClass:NSNumber.class]
				? settings[@"mute_for"]
				: @(0);
			[strongSelf storeScopeDefaultMuteFor:muteFor forScope:scope];
		}];
	}
}

- (void)applyScopeNotificationSettingsUpdate:(NSDictionary *)update {
	NSString *scope = TGScopeName(update[@"scope"][@"@type"]);
	NSDictionary *settings = update[@"notification_settings"];
	NSNumber *muteFor = [settings[@"mute_for"] isKindOfClass:NSNumber.class]
		? settings[@"mute_for"]
		: @(0);
	[self storeScopeDefaultMuteFor:muteFor forScope:scope];
}

- (void)accountTtlWithCompletion:(void (^)(BOOL ok, NSInteger days))completion {
	[self request:@{@"@type" : @"getAccountTtl"} completion:^(NSDictionary *ttl) {
		if (!completion)
			return;
		if (TGResultIsError(ttl)) {
			completion(NO, 0);
			return;
		}
		completion(YES, [ttl[@"days"] integerValue]);
	}];
}

- (void)setLanguage:(NSString *)packId {
	[self send:@{
		@"@type" : @"setOption",
		@"name" : @"language_pack_id",
		@"value" : @{@"@type" : @"optionValueString", @"value" : packId ?: @"en"},
	}];
}

- (void)chatWithUsername:(NSString *)username
			  completion:(void (^)(int64_t, NSString *))completion {
	[self request:@{
		@"@type" : @"searchPublicChat",
		@"username" : username ?: @"",
	} completion:^(NSDictionary *chat) {
		if (completion)
			completion([chat[@"id"] longLongValue], chat[@"title"]);
	}];
}

- (void)setChat:(int64_t)chatId muted:(BOOL)muted {
	[self updateChat:chatId
			  values:@{@"muteFor" : @(muted ? kNotificationMuteForever : 0), @"useDefaultMuteFor" : @NO}
		  completion:nil];
}

- (NSNumber *)photoFileIdForChat:(int64_t)chatId {
	for (NSArray *list in @[ self.chats, self.archivedChats ])
		for (NSDictionary *c in list)
			if ([c[@"id"] longLongValue] == chatId)
				return c[@"photoFileId"];
	return nil;
}

- (NSDictionary *)chatInfoForId:(int64_t)chatId {
	return self.chatsById[@(chatId)];
}

- (BOOL)cachedPremiumForChatId:(int64_t)chatId {
	NSDictionary *info = self.chatsById[@(chatId)];
	if (![info[@"isPrivate"] boolValue])
		return NO;
	return [self.userRecordsById[@(chatId)][@"is_premium"] boolValue];
}

- (void)photoFileIdForChat:(int64_t)chatId completion:(void (^)(NSNumber *))completion {
	NSNumber *known = [self photoFileIdForChat:chatId];
	if (known && known.longLongValue > 0) {
		if (completion)
			completion(known);
		return;
	}
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			NSNumber *fileId = nil;
			if (!TGResultIsError(chat)) {
				NSDictionary *photo = chat[@"photo"];
				if ([photo isKindOfClass:NSDictionary.class])
					fileId = photo[@"small"][@"id"];
			}
			if (completion)
				completion([fileId isKindOfClass:NSNumber.class] ? fileId : nil);
		}];
}

- (void)userInfo:(int64_t)userId completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getUser", @"user_id" : @(userId)}
		completion:^(NSDictionary *u) {
			if (completion)
				completion([u[@"@type"] isEqualToString:@"user"] ? u : nil);
		}];
}

- (void)messageCountInChat:(int64_t)chatId filter:(NSString *)filter
				completion:(void (^)(NSInteger))completion {
	[self request:@{
		@"@type" : @"getChatMessageCount",
		@"chat_id" : @(chatId),
		@"filter" : @{@"@type" : filter ?: @"searchMessagesFilterEmpty"},
		@"return_local" : @NO,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"count"]) {
			completion(-1);
			return;
		}
		completion(MAX((NSInteger)0, [result[@"count"] integerValue]));
	}];
}

- (NSString *)nameForUserId:(int64_t)userId {
	return self.usersById[@(userId)];
}

- (NSString *)usernameForUserId:(int64_t)userId {
	return TGActiveUsername(self.userRecordsById[@(userId)]);
}

- (void)memberCountForChat:(int64_t)chatId completion:(void (^)(NSInteger count))completion {
	NSDictionary *known = self.chatsById[@(chatId)];
	NSNumber *basicGroupId = known[@"basicGroupId"];
	NSNumber *supergroupId = known[@"supergroupId"];
	if (!basicGroupId && !supergroupId) {
		[self resolveMemberCountForChat:chatId completion:completion];
		return;
	}
	if (basicGroupId) {
		[self request:@{@"@type" : @"getBasicGroupFullInfo",
			@"basic_group_id" : basicGroupId}
			completion:^(NSDictionary *full) {
				if (completion)
					completion([full[@"members"] count]);
			}];
		return;
	}
	[self request:@{@"@type" : @"getSupergroupFullInfo",
		@"supergroup_id" : supergroupId}
		completion:^(NSDictionary *full) {
			if (completion)
				completion([full[@"member_count"] integerValue]);
		}];
}

- (void)resolveMemberCountForChat:(int64_t)chatId
					   completion:(void (^)(NSInteger count))completion {
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			NSDictionary *type = chat[@"type"];
			NSString *t = type[@"@type"];
			if ([t isEqualToString:@"chatTypeBasicGroup"]) {
				[self request:@{@"@type" : @"getBasicGroupFullInfo",
					@"basic_group_id" : type[@"basic_group_id"]}
					completion:^(NSDictionary *full) {
						if (completion)
							completion([full[@"members"] count]);
					}];
			} else if ([t isEqualToString:@"chatTypeSupergroup"]) {
				[self request:@{@"@type" : @"getSupergroupFullInfo",
					@"supergroup_id" : type[@"supergroup_id"]}
					completion:^(NSDictionary *full) {
						if (completion)
							completion([full[@"member_count"] integerValue]);
					}];
			} else if (completion) {
				completion(0);
			}
		}];
}

- (void)ensureUserName:(int64_t)userId completion:(void (^)(void))completion {
	if (userId == 0 || self.usersById[@(userId)]) {
		if (completion)
			completion();
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getUser", @"user_id" : @(userId)}
		completion:^(NSDictionary *u) {
			TGClient *strongSelf = weakSelf;
			if (strongSelf && [u[@"@type"] isEqualToString:@"user"]) {
				[strongSelf capUserRegistriesIfNeeded];
				NSString *name = TGUserDisplayName(u);
				if (name.length)
					strongSelf.usersById[@(userId)] = name;
				strongSelf.userRecordsById[@(userId)] = u;
				[strongSelf cacheProfilePhoto:u];
			}
			if (completion)
				completion();
		}];
}

- (void)mergeForumFlagFromChat:(NSDictionary *)chat
						  into:(NSMutableDictionary *)info
						chatId:(NSNumber *)chatId {
	NSNumber *supergroupId = chat[@"type"][@"supergroup_id"];
	if (!supergroupId)
		return;

	info[@"supergroupId"] = supergroupId;
	NSNumber *knownForum = self.forumSupergroups[supergroupId];
	NSNumber *knownDirectMessages = self.directMessagesSupergroups[supergroupId];
	if (knownForum && knownDirectMessages) {
		info[@"isForum"] = knownForum;
		info[@"isAdministeredDirectMessagesGroup"] = knownDirectMessages;
		return;
	}

	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getSupergroup",
		@"supergroup_id" : supergroupId}
		completion:^(NSDictionary *group) {
			TGClient *strongSelf = weakSelf;
			if (!strongSelf || !group[@"id"])
				return;
			BOOL isForum = [group[@"is_forum"] boolValue];
			BOOL isAdministeredDirectMessagesGroup =
				[group[@"is_administered_direct_messages_group"] boolValue];
			[strongSelf capSupergroupFlagRegistriesIfNeeded];
			strongSelf.forumSupergroups[group[@"id"]] = @(isForum);
			strongSelf.directMessagesSupergroups[group[@"id"]] = @(isAdministeredDirectMessagesGroup);
			NSMutableDictionary *row = strongSelf.chatsById[chatId];
			row[@"isForum"] = @(isForum);
			row[@"isAdministeredDirectMessagesGroup"] = @(isAdministeredDirectMessagesGroup);
			[strongSelf rebuildChats];
		}];
}

- (void)applySavedMessagesIdentityTo:(NSMutableDictionary *)info {
	int64_t savedId = [self savedMessagesChatId];
	if (savedId == 0 || !info)
		return;
	if ([info[@"id"] longLongValue] != savedId)
		return;
	info[@"title"] = TGSavedMessagesTitle();
	info[@"isSaved"] = @YES;
	[info removeObjectForKey:@"photoFileId"];
}

- (void)mergeChat:(NSDictionary *)chat {
	if (![chat isKindOfClass:NSDictionary.class])
		return;

	NSNumber *chatId = chat[@"id"];
	if (!chatId)
		return;

	[self tgSecretRemember:chat];

	if (!self.chatsConfirmedByServer)
		self.chatsConfirmedByServer = [NSMutableSet set];
	[self.chatsConfirmedByServer addObject:chatId];

	NSMutableDictionary *info = self.chatsById[chatId];
	if (!info) {
		info = [NSMutableDictionary dictionary];
		self.chatsById[chatId] = info;
	}

	info[@"id"] = chatId;
	if (chat[@"title"])
		info[@"title"] = chat[@"title"];

	[self applySavedMessagesIdentityTo:info];
	if (chat[@"unread_count"])
		info[@"unread"] = chat[@"unread_count"];
	if (chat[@"unread_mention_count"])
		info[@"unreadMentionCount"] = chat[@"unread_mention_count"];
	if (chat[@"unread_reaction_count"])
		info[@"unreadReactionCount"] = chat[@"unread_reaction_count"];
	if (chat[@"is_marked_as_unread"])
		info[@"markedUnread"] = @([chat[@"is_marked_as_unread"] boolValue]);
	if (chat[@"is_translatable"])
		info[@"isTranslatable"] = @([chat[@"is_translatable"] boolValue]);

	NSString *chatType = chat[@"type"][@"@type"];
	if (chatType) {
		BOOL isSupergroup = [chatType isEqualToString:@"chatTypeSupergroup"];
		BOOL isChannel = isSupergroup && [chat[@"type"][@"is_channel"] boolValue];
		info[@"isGroup"] = @(![chatType isEqualToString:@"chatTypePrivate"] &&
			![chatType isEqualToString:@"chatTypeSecret"]);
		info[@"isChannel"] = @(isChannel);
		info[@"isPrivate"] = @([chatType isEqualToString:@"chatTypePrivate"]);
		info[@"isSecretChat"] = @([chatType isEqualToString:@"chatTypeSecret"]);
	}
	if (chat[@"type"][@"basic_group_id"])
		info[@"basicGroupId"] = chat[@"type"][@"basic_group_id"];

	NSDictionary *videoChat = chat[@"video_chat"];
	if ([videoChat isKindOfClass:NSDictionary.class]) {
		info[@"videoChatGroupCallId"] = @([videoChat[@"group_call_id"] intValue]);
		info[@"videoChatHasParticipants"] = @([videoChat[@"has_participants"] boolValue]);
	}

	[self mergeForumFlagFromChat:chat into:info chatId:chatId];

	NSArray *chatPositions = [chat[@"positions"] isKindOfClass:NSArray.class]
		? chat[@"positions"]
		: nil;
	if (chatPositions.count) {
		info[@"order"] = @(TGMainListOrder(chatPositions));
		info[@"archiveOrder"] = @(TGArchiveOrder(chatPositions));
		info[@"isPinned"] = @(TGPinnedInMain(chatPositions));
		info[@"isPinnedInArchive"] = @(TGPinnedInArchive(chatPositions));
	}
	if (chat[@"notification_settings"]) {
		info[@"chatUseDefaultMuteFor"] =
			@([chat[@"notification_settings"][@"use_default_mute_for"] boolValue]);
		info[@"chatMuteFor"] = chat[@"notification_settings"][@"mute_for"] ?: @(0);
		info[@"isMuted"] = @([self effectiveMutedForChatInfo:info]);
	}
	if (chat[@"message_auto_delete_time"])
		info[@"autoDeleteSeconds"] = chat[@"message_auto_delete_time"];

	NSDictionary *photo = chat[@"photo"];
	photo = [photo isKindOfClass:NSDictionary.class] ? photo : nil;
	NSNumber *photoFile = photo[@"small"][@"id"];
	if (photoFile)
		info[@"photoFileId"] = photoFile;
	NSString *photoKey = photo[@"small"][@"remote"][@"unique_id"];
	if ([photoKey isKindOfClass:NSString.class] && photoKey.length)
		info[@"photoKey"] = photoKey;
	else if (photoFile)
		[info removeObjectForKey:@"photoKey"];
	NSString *photoMini = photo[@"minithumbnail"][@"data"];
	if ([photoMini isKindOfClass:NSString.class] && photoMini.length)
		info[@"photoMini"] = photoMini;

	info[@"draft"] = TGDraftText(chat[@"draft_message"]);

	if ([chat[@"last_read_inbox_message_id"] isKindOfClass:NSNumber.class])
		info[@"lastReadInboxId"] = chat[@"last_read_inbox_message_id"];

	if (chat[@"last_read_outbox_message_id"] &&
		![chat[@"last_read_outbox_message_id"] isEqual:info[@"lastReadOutboxId"]]) {
		info[@"lastReadOutboxId"] = chat[@"last_read_outbox_message_id"];
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatReadOutboxDidChangeNotification
						  object:chatId];
	}

	NSDictionary *last = chat[@"last_message"];
	if ([last isKindOfClass:NSDictionary.class]) {
		info[@"text"] = [self previewForLastMessage:last inChat:info];
		info[@"date"] = last[@"date"] ?: @(0);
		[self mergeOutgoingStateFromMessage:last into:info];
	}

	[self rebuildChats];
}

- (void)mergeOutgoingStateFromMessage:(NSDictionary *)last into:(NSMutableDictionary *)info {
	info[@"lastMessageId"] = last[@"id"] ?: @(0);

	BOOL hasReader = ![info[@"isSaved"] boolValue] && ![info[@"isChannel"] boolValue];
	NSDictionary *state = TGChatListOutgoingState(last, hasReader);
	info[@"outgoing"] = state[@"outgoing"];
	info[@"sendPending"] = state[@"pending"];
	info[@"sendFailed"] = state[@"failed"];

	[self refreshOutgoingReadStateIn:info];
}

- (long long)lastReadOutgoingMessageInChat:(int64_t)chatId {
	NSDictionary *info = self.chatsById[@(chatId)];
	return [info[@"lastReadOutboxId"] longLongValue];
}

- (long long)lastReadIncomingMessageInChat:(int64_t)chatId {
	NSDictionary *info = self.chatsById[@(chatId)];
	return [info[@"lastReadInboxId"] longLongValue];
}

- (long long)lastMessageIdInChat:(int64_t)chatId {
	NSDictionary *info = self.chatsById[@(chatId)];
	return [info[@"lastMessageId"] longLongValue];
}

- (NSInteger)unreadCountInChat:(int64_t)chatId {
	NSDictionary *info = self.chatsById[@(chatId)];
	return [info[@"unread"] integerValue];
}

- (int32_t)activeVideoChatGroupCallIdForChat:(int64_t)chatId {
	NSDictionary *info = self.chatsById[@(chatId)];
	return [info[@"videoChatGroupCallId"] intValue];
}

- (BOOL)videoChatHasParticipantsForChat:(int64_t)chatId {
	NSDictionary *info = self.chatsById[@(chatId)];
	return [info[@"videoChatHasParticipants"] boolValue];
}

- (void)refreshOutgoingReadStateForChat:(int64_t)chatId
							 completion:(void (^)(long long lastReadId))completion {
	NSNumber *cached = self.chatsById[@(chatId)][@"lastReadOutboxId"];
	if (cached) {
		if (completion)
			completion([cached longLongValue]);
		return;
	}

	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChat", @"chat_id" : [NSNumber numberWithLongLong:chatId]}
		completion:^(NSDictionary *chat) {
			TGClient *strongSelf = weakSelf;
			long long lastRead = [chat[@"last_read_outbox_message_id"] longLongValue];
			if (strongSelf && lastRead != 0) {
				NSMutableDictionary *info = strongSelf.chatsById[@(chatId)];
				if (!info) {
					info = [NSMutableDictionary dictionary];
					info[@"id"] = [NSNumber numberWithLongLong:chatId];
					strongSelf.chatsById[[NSNumber numberWithLongLong:chatId]] = info;
				}
				BOOL changed = ![info[@"lastReadOutboxId"] isEqual:@(lastRead)];
				info[@"lastReadOutboxId"] = @(lastRead);
				[strongSelf refreshOutgoingReadStateIn:info];
				if (changed)
					[[NSNotificationCenter defaultCenter]
						postNotificationName:TGChatReadOutboxDidChangeNotification
									  object:[NSNumber numberWithLongLong:chatId]];
			}
			if (completion)
				completion(lastRead);
		}];
}

- (void)refreshOutgoingReadStateIn:(NSMutableDictionary *)info {
	long long lastId = [info[@"lastMessageId"] longLongValue];
	info[@"outgoingRead"] = @(lastId != 0 &&
		[info[@"lastReadOutboxId"] longLongValue] >= lastId);
}

- (NSString *)previewForLastMessage:(NSDictionary *)last inChat:(NSDictionary *)info {
	NSString *text = TGMessagePreview(last, TGCurrentFlattenContext());
	BOOL isGroup = [info[@"isGroup"] boolValue];
	BOOL isChannelPost = [last[@"is_channel_post"] boolValue];
	if (!isGroup || isChannelPost)
		return text;

	if ([last[@"is_outgoing"] boolValue])
		return TGChatListPreviewWithAuthor(text, isGroup, YES, isChannelPost, nil,
			TGL(@"DialogList.You", @"You"));

	NSDictionary *senderId = last[@"sender_id"];
	int64_t senderUserId = [senderId[@"user_id"] longLongValue];
	if (!senderUserId) {
		int64_t senderChatId = [senderId[@"chat_id"] longLongValue];
		NSString *chatTitle = senderChatId ? self.chatsById[@(senderChatId)][@"title"] : nil;
		return TGChatListPreviewWithAuthor(text, isGroup, NO, isChannelPost, chatTitle, nil);
	}

	NSString *who = [self nameForUserId:senderUserId];
	if (!who.length) {
		__weak typeof(self) weakSelf = self;
		[self ensureUserName:senderUserId completion:^{ [weakSelf rebuildChats]; }];
		return text;
	}
	return TGChatListPreviewWithAuthor(text, isGroup, NO, isChannelPost, who, nil);
}

- (void)applyChatUpdate:(NSDictionary *)update {
	NSNumber *chatId = update[@"chat_id"];
	if (!chatId)
		return;

	if (!self.chatsConfirmedByServer)
		self.chatsConfirmedByServer = [NSMutableSet set];
	[self.chatsConfirmedByServer addObject:chatId];

	NSMutableDictionary *info = self.chatsById[chatId];
	if (!info) {
		info = [NSMutableDictionary dictionary];
		info[@"id"] = chatId;
		self.chatsById[chatId] = info;
	}

	NSString *updateType = update[@"@type"];

	if (update[@"title"])
		info[@"title"] = update[@"title"];
	if (update[@"unread_count"])
		info[@"unread"] = update[@"unread_count"];
	if (update[@"is_marked_as_unread"])
		info[@"markedUnread"] = @([update[@"is_marked_as_unread"] boolValue]);
	if (update[@"is_translatable"]) {
		info[@"isTranslatable"] = @([update[@"is_translatable"] boolValue]);
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatIsTranslatableDidChangeNotification
						  object:chatId];
	}

	if ([update[@"last_read_inbox_message_id"] isKindOfClass:NSNumber.class])
		info[@"lastReadInboxId"] = update[@"last_read_inbox_message_id"];

	if (update[@"last_read_outbox_message_id"]) {
		info[@"lastReadOutboxId"] = update[@"last_read_outbox_message_id"];
		[self refreshOutgoingReadStateIn:info];
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatReadOutboxDidChangeNotification
						  object:chatId];
	}

	if ([updateType isEqualToString:@"updateChatPhoto"]) {
		NSDictionary *photo = update[@"photo"];
		photo = [photo isKindOfClass:NSDictionary.class] ? photo : nil;
		NSNumber *photoFile = photo[@"small"][@"id"];
		if (photoFile && ![info[@"isSaved"] boolValue])
			info[@"photoFileId"] = photoFile;
		else
			[info removeObjectForKey:@"photoFileId"];
	}

	if ([updateType isEqualToString:@"updateChatDraftMessage"]) {
		info[@"draft"] = TGDraftText(update[@"draft_message"]);
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatDraftDidChangeNotification
						  object:chatId];
	}

	if ([updateType isEqualToString:@"updateChatVideoChat"]) {
		NSDictionary *videoChat = update[@"video_chat"];
		videoChat = [videoChat isKindOfClass:NSDictionary.class] ? videoChat : nil;
		info[@"videoChatGroupCallId"] = @([videoChat[@"group_call_id"] intValue]);
		info[@"videoChatHasParticipants"] = @([videoChat[@"has_participants"] boolValue]);
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatVideoChatDidChangeNotification
						  object:chatId];
	}

	if ([updateType isEqualToString:@"updateChatEmojiStatus"]) {
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatEmojiStatusDidChangeNotification
						  object:chatId];
	}

	NSDictionary *last = update[@"last_message"];
	if ([last isKindOfClass:NSDictionary.class]) {
		info[@"text"] = [self previewForLastMessage:last inChat:info];
		info[@"date"] = last[@"date"] ?: @(0);
		[self mergeOutgoingStateFromMessage:last into:info];
	} else if ([updateType isEqualToString:@"updateChatLastMessage"]) {
		info[@"text"] = @"";
		info[@"date"] = @(0);
		info[@"lastMessageId"] = @(0);
		info[@"outgoing"] = @NO;
		info[@"outgoingRead"] = @NO;
		info[@"sendPending"] = @NO;
		info[@"sendFailed"] = @NO;
	}

	if (update[@"notification_settings"]) {
		info[@"chatUseDefaultMuteFor"] =
			@([update[@"notification_settings"][@"use_default_mute_for"] boolValue]);
		info[@"chatMuteFor"] = update[@"notification_settings"][@"mute_for"] ?: @(0);
		info[@"isMuted"] = @([self effectiveMutedForChatInfo:info]);
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatNotificationSettingsDidChangeNotification
						  object:chatId];
	}
	[self applySavedMessagesIdentityTo:info];

	NSArray *updatePositions = [update[@"positions"] isKindOfClass:NSArray.class]
		? update[@"positions"]
		: nil;
	if (updatePositions.count) {
		info[@"order"] = @(TGMainListOrder(updatePositions));
		info[@"archiveOrder"] = @(TGArchiveOrder(updatePositions));
		info[@"isPinned"] = @(TGPinnedInMain(updatePositions));
		info[@"isPinnedInArchive"] = @(TGPinnedInArchive(updatePositions));
	}
	NSDictionary *position = update[@"position"];
	if ([position isKindOfClass:NSDictionary.class]) {
		NSString *listType = position[@"list"][@"@type"];
		if ([listType isEqualToString:@"chatListArchive"]) {
			info[@"archiveOrder"] = @(TGArchiveOrder(@[ position ]));
			info[@"isPinnedInArchive"] = @(TGPinnedInArchive(@[ position ]));
		} else if ([listType isEqualToString:@"chatListMain"]) {
			info[@"order"] = @(TGMainListOrder(@[ position ]));
			info[@"isPinned"] = @(TGPinnedInMain(@[ position ]));
		}
	}

	[self rebuildChats];
}

- (void)rebuildChats {
	NSArray *all = self.chatsById.allValues;

	[self applySavedMessagesIdentityTo:self.chatsById[@([self savedMessagesChatId])]];

	NSComparator byOrder = ^NSComparisonResult(id a, id b) {
		int64_t oa = [a[@"order"] longLongValue];
		int64_t ob = [b[@"order"] longLongValue];
		if (oa == ob)
			return NSOrderedSame;
		return oa > ob ? NSOrderedAscending : NSOrderedDescending;
	};

	NSMutableArray *main = [NSMutableArray array], *archived = [NSMutableArray array];
	for (NSDictionary *c in all) {
		if ([c[@"archiveOrder"] longLongValue] > 0)
			[archived addObject:c];
		else if ([c[@"order"] longLongValue] > 0)
			[main addObject:c];
	}

	self.chats = [main sortedArrayUsingComparator:byOrder];
	self.archivedChats = [archived sortedArrayUsingComparator:
			^NSComparisonResult(id a, id b) {
				int64_t oa = [a[@"archiveOrder"] longLongValue];
				int64_t ob = [b[@"archiveOrder"] longLongValue];
				if (oa == ob)
					return NSOrderedSame;
				return oa > ob ? NSOrderedAscending : NSOrderedDescending;
			}];

	[self scheduleChatsChanged];
}

- (void)scheduleChatsChanged {
	if (self.chatsNotifyScheduled)
		return;
	self.chatsNotifyScheduled = YES;
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		TGClient *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.chatsNotifyScheduled = NO;
		if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
			strongSelf.chatsChangedWhileBackgrounded = YES;
			[strongSelf saveCachedChatsThrottled];
			return;
		}
		strongSelf.chatsChangedWhileBackgrounded = NO;
		[strongSelf postChatsAndArchiveChanged];
		[strongSelf saveCachedChatsThrottled];
	});
}

@end

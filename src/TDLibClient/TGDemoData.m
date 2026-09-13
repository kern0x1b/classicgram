#import "TGDemoData.h"

static const long long kDemoSelfId = 900001;
static const long long kDemoGroupId = -100900101;
static const long long kDemoChannelId = -100900102;

static TGDemoAssetProvider gAssetProvider = nil;

void TGDemoSetAssetProvider(TGDemoAssetProvider provider) {
	gAssetProvider = [provider copy];
}

static NSString *TGDemoAssetPath(NSString *key) {
	return gAssetProvider ? gAssetProvider(key) : nil;
}

static double TGDemoNow(void) {
	return floor([[NSDate date] timeIntervalSince1970]);
}

static NSDictionary *TGDemoFile(NSString *assetKey, int fileId) {
	NSString *path = TGDemoAssetPath(assetKey) ?: @"";
	NSNumber *size = @(0);
	if (path.length) {
		NSDictionary *attributes = [[NSFileManager defaultManager]
			attributesOfItemAtPath:path error:NULL];
		size = attributes[NSFileSize] ?: @(0);
	}
	return @{
		@"@type" : @"file",
		@"id" : @(fileId),
		@"size" : size,
		@"expected_size" : size,
		@"local" : @{@"@type" : @"localFile",
			@"path" : path,
			@"can_be_downloaded" : @YES,
			@"can_be_deleted" : @NO,
			@"is_downloading_active" : @NO,
			@"is_downloading_completed" : @(path.length > 0),
			@"download_offset" : @(0),
			@"downloaded_prefix_size" : size,
			@"downloaded_size" : size},
		@"remote" : @{@"@type" : @"remoteFile",
			@"id" : [NSString stringWithFormat:@"demo-remote-%d", fileId],
			@"unique_id" : [NSString stringWithFormat:@"demo-unique-%d", fileId],
			@"is_uploading_active" : @NO,
			@"is_uploading_completed" : @YES,
			@"uploaded_size" : size}
	};
}

static NSString *TGDemoAssetKeyForFileId(int fileId) {
	if (fileId >= 100 && fileId < 110)
		return [NSString stringWithFormat:@"avatar-%d", fileId - 100];
	if (fileId >= 200 && fileId < 210)
		return [NSString stringWithFormat:@"thumb-%d", fileId - 200];
	if (fileId >= 300 && fileId < 310)
		return [NSString stringWithFormat:@"photo-%d", fileId - 300];
	if (fileId == 400)
		return @"voice";
	if (fileId == 401)
		return @"document";
	return nil;
}

static NSDictionary *TGDemoProfilePhoto(NSUInteger index) {
	NSString *key = [NSString stringWithFormat:@"avatar-%lu", (unsigned long)index];
	if (!TGDemoAssetPath(key))
		return nil;
	NSDictionary *file = TGDemoFile(key, (int)(100 + index));
	return @{@"@type" : @"profilePhoto",
		@"id" : @(700 + index),
		@"small" : file,
		@"big" : file,
		@"has_animation" : @NO,
		@"is_personal" : @NO};
}

static NSDictionary *TGDemoChatPhoto(NSUInteger index) {
	NSString *key = [NSString stringWithFormat:@"avatar-%lu", (unsigned long)index];
	if (!TGDemoAssetPath(key))
		return nil;
	NSDictionary *file = TGDemoFile(key, (int)(100 + index));
	return @{@"@type" : @"chatPhotoInfo",
		@"small" : file,
		@"big" : file,
		@"has_animation" : @NO,
		@"is_personal" : @NO};
}

static NSDictionary *TGDemoText(NSString *text) {
	return @{@"@type" : @"messageText",
		@"text" : @{@"@type" : @"formattedText", @"text" : text, @"entities" : @[]}};
}

static NSDictionary *TGDemoPhotoContent(NSUInteger index, NSString *caption) {
	NSString *photoKey = [NSString stringWithFormat:@"photo-%lu", (unsigned long)index];
	NSString *thumbKey = [NSString stringWithFormat:@"thumb-%lu", (unsigned long)index];
	NSMutableArray *sizes = [NSMutableArray array];
	if (TGDemoAssetPath(thumbKey))
		[sizes addObject:@{@"@type" : @"photoSize", @"type" : @"m",
			@"photo" : TGDemoFile(thumbKey, (int)(200 + index)),
			@"width" : @(90), @"height" : @(90), @"progressive_sizes" : @[]}];
	if (TGDemoAssetPath(photoKey))
		[sizes addObject:@{@"@type" : @"photoSize", @"type" : @"x",
			@"photo" : TGDemoFile(photoKey, (int)(300 + index)),
			@"width" : @(640), @"height" : @(960), @"progressive_sizes" : @[]}];
	return @{@"@type" : @"messagePhoto",
		@"photo" : @{@"@type" : @"photo", @"has_stickers" : @NO, @"sizes" : sizes},
		@"caption" : @{@"@type" : @"formattedText", @"text" : caption ?: @"", @"entities" : @[]},
		@"show_caption_above_media" : @NO,
		@"is_secret" : @NO};
}

static NSDictionary *TGDemoVoiceContent(NSInteger duration) {
	return @{@"@type" : @"messageVoiceNote",
		@"voice_note" : @{@"@type" : @"voiceNote",
			@"duration" : @(duration),
			@"waveform" : @"AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8g",
			@"mime_type" : @"audio/ogg",
			@"voice" : TGDemoFile(@"voice", 400)},
		@"caption" : @{@"@type" : @"formattedText", @"text" : @"", @"entities" : @[]},
		@"is_listened" : @NO};
}

static NSDictionary *TGDemoDocumentContent(void) {
	return @{@"@type" : @"messageDocument",
		@"document" : @{@"@type" : @"document",
			@"file_name" : @"Schedule.txt",
			@"mime_type" : @"text/plain",
			@"document" : TGDemoFile(@"document", 401)},
		@"caption" : @{@"@type" : @"formattedText",
			@"text" : @"Timings for Saturday", @"entities" : @[]}};
}

static NSDictionary *TGDemoLocationContent(void) {
	return @{@"@type" : @"messageLocation",
		@"location" : @{@"@type" : @"location",
			@"latitude" : @(50.4501), @"longitude" : @(30.5234),
			@"horizontal_accuracy" : @(12.0)},
		@"live_period" : @(0), @"expires_in" : @(0),
		@"heading" : @(0), @"proximity_alert_radius" : @(0)};
}

static NSDictionary *TGDemoCallContent(BOOL missed, NSInteger duration) {
	return @{@"@type" : @"messageCall",
		@"is_video" : @NO,
		@"discard_reason" : @{@"@type" : missed ? @"callDiscardReasonMissed"
											   : @"callDiscardReasonHungUp"},
		@"duration" : @(duration)};
}

static NSDictionary *TGDemoPollContent(void) {
	return @{@"@type" : @"messagePoll",
		@"poll" : @{@"@type" : @"poll",
			@"id" : @"9001",
			@"question" : @{@"@type" : @"formattedText",
				@"text" : @"Which device still gets daily use?", @"entities" : @[]},
			@"options" : @[
				@{@"@type" : @"pollOption",
					@"text" : @{@"@type" : @"formattedText", @"text" : @"iPhone 4S", @"entities" : @[]},
					@"voter_count" : @(14), @"vote_percentage" : @(58),
					@"is_chosen" : @YES, @"is_being_chosen" : @NO},
				@{@"@type" : @"pollOption",
					@"text" : @{@"@type" : @"formattedText", @"text" : @"iPad 2", @"entities" : @[]},
					@"voter_count" : @(10), @"vote_percentage" : @(42),
					@"is_chosen" : @NO, @"is_being_chosen" : @NO}],
			@"total_voter_count" : @(24),
			@"recent_voter_ids" : @[],
			@"is_anonymous" : @YES,
			@"type" : @{@"@type" : @"pollTypeRegular", @"allow_multiple_answers" : @NO},
			@"open_period" : @(0), @"close_date" : @(0), @"is_closed" : @NO}};
}

static NSDictionary *TGDemoJoinContent(long long userId) {
	return @{@"@type" : @"messageChatAddMembers", @"member_user_ids" : @[@(userId)]};
}

static NSDictionary *TGDemoUser(long long userId, NSString *first, NSString *last,
	NSString *username, NSInteger minutesSinceOnline, NSUInteger avatarIndex) {
	NSMutableDictionary *user = [@{
		@"@type" : @"user",
		@"id" : @(userId),
		@"first_name" : first,
		@"last_name" : last,
		@"phone_number" : @"",
		@"type" : @{@"@type" : @"userTypeRegular"},
		@"is_contact" : @YES,
		@"is_mutual_contact" : @YES,
		@"have_access" : @YES
	} mutableCopy];
	if (username.length)
		user[@"usernames"] = @{@"@type" : @"usernames",
			@"active_usernames" : @[username],
			@"disabled_usernames" : @[],
			@"editable_username" : username};
	NSDictionary *photo = TGDemoProfilePhoto(avatarIndex);
	if (photo)
		user[@"profile_photo"] = photo;
	if (minutesSinceOnline <= 0)
		user[@"status"] = @{@"@type" : @"userStatusOnline",
			@"expires" : @((long long)TGDemoNow() + 300)};
	else
		user[@"status"] = @{@"@type" : @"userStatusOffline",
			@"was_online" : @((long long)TGDemoNow() - minutesSinceOnline * 60)};
	return user;
}

NSDictionary *TGDemoMe(void) {
	NSMutableDictionary *me = [TGDemoUser(kDemoSelfId, @"Demo", @"Account", @"demoaccount", 0, 4)
		mutableCopy];
	me[@"phone_number"] = @"99966173741";
	return me;
}

NSArray<NSDictionary *> *TGDemoUsers(void) {
	NSMutableArray *users = [NSMutableArray array];
	[users addObject:TGDemoMe()];
	[users addObject:TGDemoUser(900002, @"Nikolai", @"Orlov", @"norlov", 0, 0)];
	[users addObject:TGDemoUser(900003, @"Marta", @"Weiss", @"martaw", 14, 1)];
	[users addObject:TGDemoUser(900004, @"Sam", @"Okafor", @"samok", 180, 2)];
	[users addObject:TGDemoUser(900005, @"Ines", @"Ferreira", @"inesf", 2880, 3)];
	return users;
}

static NSDictionary *TGDemoMessage(long long messageId, long long chatId, long long senderId,
	BOOL outgoing, NSInteger minutesAgo, NSDictionary *content) {
	return @{
		@"@type" : @"message",
		@"id" : @(messageId),
		@"chat_id" : @(chatId),
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @(senderId)},
		@"is_outgoing" : @(outgoing),
		@"is_pinned" : @NO,
		@"can_be_deleted_for_all_users" : @YES,
		@"can_be_forwarded" : @YES,
		@"date" : @((long long)TGDemoNow() - minutesAgo * 60),
		@"edit_date" : @(0),
		@"content" : content
	};
}

static NSDictionary *TGDemoChat(long long chatId, NSDictionary *type, NSString *title,
	NSUInteger avatarIndex, NSDictionary *lastMessage, NSInteger unread, BOOL muted,
	BOOL pinned, NSInteger order) {
	NSMutableDictionary *chat = [@{
		@"@type" : @"chat",
		@"id" : @(chatId),
		@"type" : type,
		@"title" : title,
		@"last_message" : lastMessage,
		@"unread_count" : @(unread),
		@"is_marked_as_unread" : @NO,
		@"can_be_deleted_only_for_self" : @YES,
		@"last_read_inbox_message_id" : lastMessage[@"id"] ?: @(0),
		@"last_read_outbox_message_id" : lastMessage[@"id"] ?: @(0),
		@"notification_settings" : @{@"@type" : @"chatNotificationSettings",
			@"use_default_mute_for" : @NO,
			@"mute_for" : @(muted ? 2147483647 : 0)},
		@"positions" : @[@{@"@type" : @"chatPosition",
			@"list" : @{@"@type" : @"chatListMain"},
			@"order" : [NSString stringWithFormat:@"%d", (int)(1000000 - order)],
			@"is_pinned" : @(pinned)}]
	} mutableCopy];
	NSDictionary *photo = TGDemoChatPhoto(avatarIndex);
	if (photo)
		chat[@"photo"] = photo;
	return chat;
}

static NSDictionary *TGDemoPrivateType(long long userId) {
	return @{@"@type" : @"chatTypePrivate", @"user_id" : @(userId)};
}

NSArray<NSDictionary *> *TGDemoChats(void) {
	NSMutableArray *chats = [NSMutableArray array];
	[chats addObject:TGDemoChat(900002, TGDemoPrivateType(900002), @"Nikolai Orlov", 0,
		TGDemoMessage(3001, 900002, 900002, NO, 3,
			TGDemoText(@"The 4S survived the drop, screen and all")),
		2, NO, YES, 1)];
	[chats addObject:TGDemoChat(kDemoGroupId, @{@"@type" : @"chatTypeSupergroup",
		@"supergroup_id" : @900101, @"is_channel" : @NO}, @"Old Hardware Club", 1,
		TGDemoMessage(3002, kDemoGroupId, 900004, NO, 26,
			TGDemoPhotoContent(1, @"Found this in a drawer, still charges")),
		7, NO, NO, 2)];
	[chats addObject:TGDemoChat(900003, TGDemoPrivateType(900003), @"Marta Weiss", 1,
		TGDemoMessage(3003, 900003, kDemoSelfId, YES, 55,
			TGDemoText(@"Sending the photos tonight")),
		0, NO, NO, 3)];
	[chats addObject:TGDemoChat(kDemoChannelId, @{@"@type" : @"chatTypeSupergroup",
		@"supergroup_id" : @900102, @"is_channel" : @YES}, @"Telegram Classic", 2,
		TGDemoMessage(3004, kDemoChannelId, 900005, NO, 240,
			TGDemoPhotoContent(2, @"Build 1.16: faster chat list, fixed voice bubbles")),
		1, YES, NO, 4)];
	[chats addObject:TGDemoChat(900004, TGDemoPrivateType(900004), @"Sam Okafor", 2,
		TGDemoMessage(3005, 900004, 900004, NO, 420, TGDemoVoiceContent(7)),
		0, NO, NO, 5)];
	[chats addObject:TGDemoChat(900005, TGDemoPrivateType(900005), @"Ines Ferreira", 3,
		TGDemoMessage(3006, 900005, kDemoSelfId, YES, 1500,
			TGDemoText(@"See you Thursday")),
		0, NO, NO, 6)];
	[chats addObject:TGDemoChat(kDemoSelfId, TGDemoPrivateType(kDemoSelfId), @"Saved Messages", 4,
		TGDemoMessage(3007, kDemoSelfId, kDemoSelfId, YES, 2600, TGDemoDocumentContent()),
		0, NO, NO, 7)];
	return chats;
}

NSArray<NSDictionary *> *TGDemoHistoryForChat(long long chatId) {
	if (chatId == 900002)
		return @[
			TGDemoMessage(3001, 900002, 900002, NO, 3,
				TGDemoText(@"The 4S survived the drop, screen and all")),
			TGDemoMessage(2999, 900002, kDemoSelfId, YES, 9, TGDemoText(@"Case or no case?")),
			TGDemoMessage(2998, 900002, 900002, NO, 12, TGDemoPhotoContent(0, @"No case. Landed on the corner")),
			TGDemoMessage(2997, 900002, kDemoSelfId, YES, 40, TGDemoVoiceContent(4)),
			TGDemoMessage(2996, 900002, 900002, NO, 44,
				TGDemoText(@"Two days idle, most of a day if I actually use it")),
			TGDemoMessage(2995, 900002, kDemoSelfId, YES, 90, TGDemoLocationContent()),
			TGDemoMessage(2994, 900002, 900002, NO, 130, TGDemoCallContent(NO, 184)),
			TGDemoMessage(2993, 900002, kDemoSelfId, YES, 260,
				TGDemoText(@"That is better than my current phone"))
		];
	if (chatId == kDemoGroupId)
		return @[
			TGDemoMessage(3002, kDemoGroupId, 900004, NO, 26,
				TGDemoPhotoContent(1, @"Found this in a drawer, still charges")),
			TGDemoMessage(2990, kDemoGroupId, 900003, NO, 33, TGDemoPollContent()),
			TGDemoMessage(2989, kDemoGroupId, kDemoSelfId, YES, 47,
				TGDemoText(@"4S as a second phone. The keyboard still beats anything modern")),
			TGDemoMessage(2988, kDemoGroupId, 900005, NO, 60, TGDemoDocumentContent()),
			TGDemoMessage(2987, kDemoGroupId, 900002, NO, 90, TGDemoJoinContent(900005))
		];
	if (chatId == kDemoChannelId)
		return @[
			TGDemoMessage(3004, kDemoChannelId, 900005, NO, 240,
				TGDemoPhotoContent(2, @"Build 1.16: faster chat list, fixed voice bubbles")),
			TGDemoMessage(2980, kDemoChannelId, 900005, NO, 1400,
				TGDemoText(@"Demo mode ships this week, so screenshots stop needing a real account"))
		];
	if (chatId == 900003)
		return @[
			TGDemoMessage(3003, 900003, kDemoSelfId, YES, 55, TGDemoText(@"Sending the photos tonight")),
			TGDemoMessage(2970, 900003, 900003, NO, 70, TGDemoPhotoContent(3, @"")),
			TGDemoMessage(2969, 900003, kDemoSelfId, YES, 120, TGDemoCallContent(YES, 0))
		];
	if (chatId == 900004)
		return @[
			TGDemoMessage(3005, 900004, 900004, NO, 420, TGDemoVoiceContent(7)),
			TGDemoMessage(2960, 900004, kDemoSelfId, YES, 500, TGDemoText(@"Got it, thanks"))
		];
	if (chatId == kDemoSelfId)
		return @[TGDemoMessage(3007, kDemoSelfId, kDemoSelfId, YES, 2600, TGDemoDocumentContent())];
	if (chatId == 900005)
		return @[TGDemoMessage(3006, 900005, kDemoSelfId, YES, 1500, TGDemoText(@"See you Thursday"))];
	return @[];
}

static NSDictionary *TGDemoChatById(long long chatId) {
	for (NSDictionary *chat in TGDemoChats()) {
		if ([chat[@"id"] longLongValue] == chatId)
			return chat;
	}
	return nil;
}

static NSDictionary *TGDemoUserById(long long userId) {
	for (NSDictionary *user in TGDemoUsers()) {
		if ([user[@"id"] longLongValue] == userId)
			return user;
	}
	return nil;
}

NSArray<NSDictionary *> *TGDemoStartupUpdates(void) {
	NSMutableArray *updates = [NSMutableArray array];
	[updates addObject:@{@"@type" : @"updateAuthorizationState",
		@"authorization_state" : @{@"@type" : @"authorizationStateReady"}}];
	[updates addObject:@{@"@type" : @"updateConnectionState",
		@"state" : @{@"@type" : @"connectionStateReady"}}];
	for (NSDictionary *user in TGDemoUsers())
		[updates addObject:@{@"@type" : @"updateUser", @"user" : user}];
	for (NSDictionary *chat in TGDemoChats()) {
		[updates addObject:@{@"@type" : @"updateNewChat", @"chat" : chat}];
		NSDictionary *position = [chat[@"positions"] firstObject];
		if (position)
			[updates addObject:@{@"@type" : @"updateChatPosition",
				@"chat_id" : chat[@"id"], @"position" : position}];
	}
	return updates;
}

static NSDictionary *TGDemoUserFullInfo(long long userId) {
	NSDictionary *user = TGDemoUserById(userId);
	if (!user)
		return nil;
	NSString *bio = (userId == kDemoSelfId) ? @"This account exists only in demo mode."
											: @"Keeps old hardware running.";
	return @{@"@type" : @"userFullInfo",
		@"bio" : @{@"@type" : @"formattedText", @"text" : bio, @"entities" : @[]},
		@"can_be_called" : @YES,
		@"supports_video_calls" : @NO,
		@"has_private_calls" : @NO,
		@"need_phone_number_privacy_exception" : @NO,
		@"group_in_common_count" : @(userId == kDemoSelfId ? 0 : 1)};
}

static NSDictionary *TGDemoOk(void) {
	return @{@"@type" : @"ok"};
}

NSDictionary *TGDemoResponseForRequest(NSDictionary *request) {
	NSString *type = request[@"@type"];
	if (![type isKindOfClass:NSString.class])
		return nil;

	if ([type isEqualToString:@"getAuthorizationState"])
		return @{@"@type" : @"authorizationStateReady"};

	if ([type isEqualToString:@"getMe"])
		return TGDemoMe();

	if ([type isEqualToString:@"getChats"] || [type isEqualToString:@"loadChats"]) {
		NSString *list = request[@"chat_list"][@"@type"];
		if ([list isKindOfClass:NSString.class] && ![list isEqualToString:@"chatListMain"])
			return @{@"@type" : @"chats", @"total_count" : @(0), @"chat_ids" : @[]};
		NSMutableArray *ids = [NSMutableArray array];
		for (NSDictionary *chat in TGDemoChats())
			[ids addObject:chat[@"id"]];
		return @{@"@type" : @"chats", @"total_count" : @(ids.count), @"chat_ids" : ids};
	}

	if ([type isEqualToString:@"getChat"] || [type isEqualToString:@"createPrivateChat"]) {
		long long chatId = [request[@"chat_id"] longLongValue];
		if (!chatId)
			chatId = [request[@"user_id"] longLongValue];
		return TGDemoChatById(chatId);
	}

	if ([type isEqualToString:@"getUser"])
		return TGDemoUserById([request[@"user_id"] longLongValue]);

	if ([type isEqualToString:@"getUserFullInfo"])
		return TGDemoUserFullInfo([request[@"user_id"] longLongValue]);

	if ([type isEqualToString:@"getContacts"]) {
		NSMutableArray *ids = [NSMutableArray array];
		for (NSDictionary *user in TGDemoUsers()) {
			if ([user[@"id"] longLongValue] != kDemoSelfId)
				[ids addObject:user[@"id"]];
		}
		return @{@"@type" : @"users", @"total_count" : @(ids.count), @"user_ids" : ids};
	}

	if ([type isEqualToString:@"getChatHistory"] ||
		[type isEqualToString:@"getMessageThreadHistory"]) {
		NSArray *history = TGDemoHistoryForChat([request[@"chat_id"] longLongValue]);
		long long fromId = [request[@"from_message_id"] longLongValue];
		if (fromId > 0) {
			NSMutableArray *older = [NSMutableArray array];
			BOOL passed = NO;
			for (NSDictionary *message in history) {
				if (passed)
					[older addObject:message];
				if ([message[@"id"] longLongValue] == fromId)
					passed = YES;
			}
			history = older;
		}
		return @{@"@type" : @"messages",
			@"total_count" : @(history.count), @"messages" : history};
	}

	if ([type isEqualToString:@"searchCallMessages"]) {
		NSMutableArray *calls = [NSMutableArray array];
		for (NSDictionary *message in TGDemoHistoryForChat(900002)) {
			if ([message[@"content"][@"@type"] isEqualToString:@"messageCall"])
				[calls addObject:message];
		}
		for (NSDictionary *message in TGDemoHistoryForChat(900003)) {
			if ([message[@"content"][@"@type"] isEqualToString:@"messageCall"])
				[calls addObject:message];
		}
		return @{@"@type" : @"foundMessages", @"total_count" : @(calls.count),
			@"messages" : calls, @"next_offset" : @""};
	}

	if ([type isEqualToString:@"downloadFile"] || [type isEqualToString:@"getFile"]) {
		int fileId = [request[@"file_id"] intValue];
		NSString *key = TGDemoAssetKeyForFileId(fileId);
		return key ? TGDemoFile(key, fileId) : nil;
	}

	if ([type isEqualToString:@"setTdlibParameters"] ||
		[type isEqualToString:@"setLogVerbosityLevel"] ||
		[type isEqualToString:@"setOption"] ||
		[type isEqualToString:@"viewMessages"] ||
		[type isEqualToString:@"openChat"] ||
		[type isEqualToString:@"closeChat"] ||
		[type isEqualToString:@"checkDatabaseEncryptionKey"])
		return TGDemoOk();

	return nil;
}

NSDictionary *TGDemoFileUpdateForRequest(NSDictionary *request) {
	NSString *type = request[@"@type"];
	if (![type isKindOfClass:NSString.class])
		return nil;
	if (![type isEqualToString:@"downloadFile"] && ![type isEqualToString:@"getFile"])
		return nil;
	int fileId = [request[@"file_id"] intValue];
	NSString *key = TGDemoAssetKeyForFileId(fileId);
	if (!key)
		return nil;
	return @{@"@type" : @"updateFile", @"file" : TGDemoFile(key, fileId)};
}

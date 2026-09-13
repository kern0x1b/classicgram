#import "TGClient+Forums.h"
#import "TGClient+Private.h"
#import "TGClient+ChatState.h"
#import "TGFlattenForums.h"

static NSNumber *TGForumsInt64(id value) {
	if ([value isKindOfClass:NSNumber.class])
		return value;
	if ([value isKindOfClass:NSString.class])
		return [NSNumber numberWithLongLong:[value longLongValue]];
	return [NSNumber numberWithLongLong:0];
}

static NSString *TGForumsTopicSettingsKey(int64_t chatId, int32_t topicId) {
	return [NSString stringWithFormat:@"%lld:%d", chatId, topicId];
}

@implementation TGClient (Forums)

- (void)cacheForumTopicNotificationSettingsForChat:(int64_t)chatId
											  topic:(int32_t)topicId
										 useDefault:(BOOL)useDefault
											muteFor:(long long)muteFor {
	if (!topicId)
		return;
	self.topicNotificationSettingsByKey[TGForumsTopicSettingsKey(chatId, topicId)] = @{
		@"useDefaultMuteFor" : @(useDefault),
		@"muteFor" : @(muteFor),
	};
}

- (void)cacheForumTopicNotificationSettingsFromRawTopic:(NSDictionary *)topic chatId:(int64_t)chatId {
	NSDictionary *info = [topic[@"info"] isKindOfClass:NSDictionary.class] ? topic[@"info"] : nil;
	int32_t topicId = (int32_t)[info[@"forum_topic_id"] longLongValue];
	if (!topicId)
		return;
	NSDictionary *settings = [topic[@"notification_settings"] isKindOfClass:NSDictionary.class]
		? topic[@"notification_settings"]
		: nil;
	[self cacheForumTopicNotificationSettingsForChat:chatId
												topic:topicId
										   useDefault:[settings[@"use_default_mute_for"] boolValue]
											  muteFor:[settings[@"mute_for"] longLongValue]];
}

- (BOOL)isForumTopicMuted:(int32_t)topicId inChat:(int64_t)chatId {
	if (!topicId)
		return NO;
	NSDictionary *settings = self.topicNotificationSettingsByKey[TGForumsTopicSettingsKey(chatId, topicId)];
	if (!settings)
		return NO;
	if (![settings[@"useDefaultMuteFor"] boolValue])
		return [settings[@"muteFor"] longLongValue] > 0;
	return [self effectiveMutedForChatInfo:[self chatInfoForId:chatId]];
}

- (void)runForumOk:(NSDictionary *)request completion:(void (^)(BOOL))completion {
	[self request:request completion:^(NSDictionary *result) {
		BOOL ok = ![result[@"@type"] isEqualToString:@"error"];
		if (!ok)
			NSLog(@"TGClient: %@ failed: %@", request[@"@type"], result[@"message"]);
		if (completion)
			completion(ok);
	}];
}

#pragma mark - listing

- (void)forumTopicsForChat:(int64_t)chatId
					 query:(NSString *)query
				offsetDate:(NSInteger)offsetDate
		   offsetMessageId:(int64_t)offsetMessageId
			 offsetTopicId:(int32_t)offsetTopicId
					 limit:(NSInteger)limit
				completion:(void (^)(NSArray *, NSDictionary *, NSInteger))completion {
	if (limit <= 0)
		limit = 100;
	[self request:@{
		@"@type" : @"getForumTopics",
		@"chat_id" : @(chatId),
		@"query" : query ?: @"",
		@"offset_date" : @(offsetDate),
		@"offset_message_id" : @(offsetMessageId),
		@"offset_forum_topic_id" : @(offsetTopicId),
		@"limit" : @(limit),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSArray *topics = result[@"topics"];
		if (![topics isKindOfClass:NSArray.class]) {
			NSLog(@"TGClient: getForumTopics -> %@", result[@"@type"]);
			completion(@[], nil, 0);
			return;
		}
		NSMutableArray *out = [NSMutableArray arrayWithCapacity:topics.count];
		for (NSDictionary *topic in topics) {
			NSDictionary *flat = TGForumsFlattenTopic(topic, chatId);
			if (flat) {
				[out addObject:flat];
				[self cacheForumTopicNotificationSettingsFromRawTopic:topic chatId:chatId];
			}
		}
		NSDictionary *next = nil;
		if (out.count)
			next = @{
				@"date" : result[@"next_offset_date"] ?: @(0),
				@"messageId" : result[@"next_offset_message_id"] ?: @(0),
				@"topicId" : result[@"next_offset_forum_topic_id"] ?: @(0),
			};
		NSInteger total = [result[@"total_count"] integerValue];
		NSLog(@"TGClient: %lu forum topics of %ld",
			(unsigned long)out.count, (long)total);
		completion(out, next, total);
	}];
}

- (void)forumTopicRowsForChat:(int64_t)chatId
				   completion:(void (^)(NSArray *))completion {
	[self forumTopicsForChat:chatId query:nil offsetDate:0 offsetMessageId:0
			   offsetTopicId:0
					   limit:100
				  completion:^(NSArray *topics, NSDictionary *next, NSInteger total) {
					  if (completion)
						  completion(topics);
				  }];
}

- (void)searchForumTopicsInChat:(int64_t)chatId
						  query:(NSString *)query
					 completion:(void (^)(NSArray *))completion {
	[self forumTopicsForChat:chatId query:query offsetDate:0 offsetMessageId:0
			   offsetTopicId:0
					   limit:100
				  completion:^(NSArray *topics, NSDictionary *next, NSInteger total) {
					  if (completion)
						  completion(topics);
				  }];
}

- (void)forumTopic:(int32_t)topicId
			inChat:(int64_t)chatId
		completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"getForumTopic",
		@"chat_id" : @(chatId),
		@"forum_topic_id" : @(topicId),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if ([result[@"@type"] isEqualToString:@"error"]) {
			NSLog(@"TGClient: getForumTopic -> %@", result[@"message"]);
			completion(nil);
			return;
		}
		[self cacheForumTopicNotificationSettingsFromRawTopic:result chatId:chatId];
		completion(TGForumsFlattenTopic(result, chatId));
	}];
}

- (void)forumTopicHistoryForChat:(int64_t)chatId
						   topic:(int32_t)topicId
					 fromMessage:(int64_t)fromMessageId
						   limit:(NSInteger)limit
					  completion:(void (^)(NSArray *))completion {
	if (limit <= 0)
		limit = 50;
	[self request:@{
		@"@type" : @"getForumTopicHistory",
		@"chat_id" : @(chatId),
		@"forum_topic_id" : @(topicId),
		@"from_message_id" : @(fromMessageId),
		@"offset" : @(0),
		@"limit" : @(limit),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSArray *messages = result[@"messages"];
		if (![messages isKindOfClass:NSArray.class]) {
			NSLog(@"TGClient: getForumTopicHistory -> %@", result[@"@type"]);
			completion(@[]);
			return;
		}
		NSMutableArray *out = [NSMutableArray arrayWithCapacity:messages.count];
		for (NSDictionary *m in [[messages reverseObjectEnumerator] allObjects]) {
			if (![m isKindOfClass:NSDictionary.class])
				continue;
			NSDictionary *sender = m[@"sender_id"];
			if (![sender isKindOfClass:NSDictionary.class])
				sender = [NSDictionary dictionary];
			BOOL senderIsChat = [sender[@"@type"] isEqualToString:@"messageSenderChat"];
			NSNumber *senderId = senderIsChat ? sender[@"chat_id"] : sender[@"user_id"];
			[out addObject:@{
				@"id" : m[@"id"] ?: @(0),
				@"text" : TGForumsMessagePreview(m) ?: @"",
				@"date" : m[@"date"] ?: @(0),
				@"outgoing" : @([m[@"is_outgoing"] boolValue]),
				@"senderId" : senderId ?: @(0),
				@"senderIsChat" : @(senderIsChat),
			}];
		}
		completion(out);
	}];
}

#pragma mark - create and edit

- (NSArray *)forumTopicIconColors {
	return @[ @(0x6FB9F0), @(0xFFD67E), @(0xCB86DB),
		@(0x8EEE98), @(0xFF93B2), @(0xFB6F5F) ];
}

- (void)createForumTopicInChat:(int64_t)chatId
						  name:(NSString *)name
					 iconColor:(NSInteger)iconColor
				   iconEmojiId:(int64_t)iconEmojiId
					completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"createForumTopic",
		@"chat_id" : @(chatId),
		@"name" : name ?: @"",
		@"is_name_implicit" : @NO,
		@"icon" : @{
			@"@type" : @"forumTopicIcon",
			@"color" : @(iconColor),
			@"custom_emoji_id" : @(iconEmojiId),
		},
	} completion:^(NSDictionary *result) {
		if ([result[@"@type"] isEqualToString:@"error"])
			NSLog(@"TGClient: createForumTopic -> %@", result[@"message"]);
		if (!completion)
			return;
		if ([result[@"@type"] isEqualToString:@"error"]) {
			completion(nil);
			return;
		}
		completion(TGForumsFlattenTopic(@{@"info" : result ?: @{}}, chatId));
	}];
}

- (void)editForumTopicInChat:(int64_t)chatId
					   topic:(int32_t)topicId
						name:(NSString *)name
				  changeIcon:(BOOL)changeIcon
				 iconEmojiId:(int64_t)iconEmojiId
				  completion:(void (^)(BOOL))completion {
	[self runForumOk:@{
		@"@type" : @"editForumTopic",
		@"chat_id" : @(chatId),
		@"forum_topic_id" : @(topicId),
		@"name" : name ?: @"",
		@"edit_icon_custom_emoji" : @(changeIcon),
		@"icon_custom_emoji_id" : @(changeIcon ? iconEmojiId : 0),
	}
		  completion:completion];
}

- (void)setForumTopicInChat:(int64_t)chatId
					  topic:(int32_t)topicId
					 closed:(BOOL)closed
				 completion:(void (^)(BOOL))completion {
	[self runForumOk:@{
		@"@type" : @"toggleForumTopicIsClosed",
		@"chat_id" : @(chatId),
		@"forum_topic_id" : @(topicId),
		@"is_closed" : @(closed),
	}
		  completion:completion];
}

- (void)setGeneralForumTopicInChat:(int64_t)chatId
							hidden:(BOOL)hidden
						completion:(void (^)(BOOL))completion {
	[self runForumOk:@{
		@"@type" : @"toggleGeneralForumTopicIsHidden",
		@"chat_id" : @(chatId),
		@"is_hidden" : @(hidden),
	}
		  completion:completion];
}

- (void)setForumTopicInChat:(int64_t)chatId
					  topic:(int32_t)topicId
					 pinned:(BOOL)pinned
				 completion:(void (^)(BOOL))completion {
	[self runForumOk:@{
		@"@type" : @"toggleForumTopicIsPinned",
		@"chat_id" : @(chatId),
		@"forum_topic_id" : @(topicId),
		@"is_pinned" : @(pinned),
	}
		  completion:completion];
}

- (void)setPinnedForumTopicsInChat:(int64_t)chatId
						  topicIds:(NSArray *)topicIds
						completion:(void (^)(BOOL))completion {
	NSMutableArray *ids = [NSMutableArray array];
	if ([topicIds isKindOfClass:NSArray.class]) {
		for (id one in topicIds) {
			if ([one isKindOfClass:NSNumber.class])
				[ids addObject:@([one intValue])];
		}
	}
	[self runForumOk:@{
		@"@type" : @"setPinnedForumTopics",
		@"chat_id" : @(chatId),
		@"forum_topic_ids" : ids,
	}
		  completion:completion];
}

- (void)deleteForumTopicInChat:(int64_t)chatId
						 topic:(int32_t)topicId
					completion:(void (^)(BOOL))completion {
	[self runForumOk:@{
		@"@type" : @"deleteForumTopic",
		@"chat_id" : @(chatId),
		@"forum_topic_id" : @(topicId),
	}
		  completion:completion];
}

#pragma mark - per-topic housekeeping

- (void)setForumTopicInChat:(int64_t)chatId
					  topic:(int32_t)topicId
				   mutedFor:(NSInteger)seconds
				 completion:(void (^)(BOOL))completion {
	BOOL useDefault = seconds < 0;
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"getForumTopic",
		@"chat_id" : @(chatId),
		@"forum_topic_id" : @(topicId),
	} completion:^(NSDictionary *result) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if ([result[@"@type"] isEqualToString:@"error"]) {
			NSLog(@"TGClient: getForumTopic -> %@", result[@"message"]);
			if (completion)
				completion(NO);
			return;
		}
		NSDictionary *current = [result[@"notification_settings"] isKindOfClass:NSDictionary.class]
			? result[@"notification_settings"]
			: @{};
		NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:current];
		merged[@"@type"] = @"chatNotificationSettings";
		merged[@"use_default_mute_for"] = @(useDefault);
		merged[@"mute_for"] = @(useDefault ? 0 : seconds);
		[strongSelf runForumOk:@{
			@"@type" : @"setForumTopicNotificationSettings",
			@"chat_id" : @(chatId),
			@"forum_topic_id" : @(topicId),
			@"notification_settings" : merged,
		}
					 completion:completion];
	}];
}

- (void)markForumTopicReadInChat:(int64_t)chatId
						   topic:(int32_t)topicId
					  completion:(void (^)(BOOL))completion {
	[self send:@{
		@"@type" : @"readAllForumTopicMentions",
		@"chat_id" : @(chatId),
		@"forum_topic_id" : @(topicId),
	}];
	[self send:@{
		@"@type" : @"readAllForumTopicReactions",
		@"chat_id" : @(chatId),
		@"forum_topic_id" : @(topicId),
	}];
	[self send:@{
		@"@type" : @"readAllForumTopicPollVotes",
		@"chat_id" : @(chatId),
		@"forum_topic_id" : @(topicId),
	}];
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"getForumTopic",
		@"chat_id" : @(chatId),
		@"forum_topic_id" : @(topicId),
	} completion:^(NSDictionary *result) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf || [result[@"@type"] isEqualToString:@"error"]) {
			NSLog(@"TGClient: getForumTopic -> %@", result[@"message"]);
			if (completion)
				completion(NO);
			return;
		}
		NSDictionary *last = result[@"last_message"];
		NSNumber *messageId = [last isKindOfClass:NSDictionary.class] ? last[@"id"] : nil;
		if (![messageId isKindOfClass:NSNumber.class] || [messageId longLongValue] == 0) {
			if (completion)
				completion(YES);
			return;
		}
		[strongSelf runForumOk:@{
			@"@type" : @"viewMessages",
			@"chat_id" : @(chatId),
			@"message_ids" : @[ messageId ],
			@"source" : @{@"@type" : @"messageSourceForumTopicHistory"},
			@"force_read" : @YES,
		}
				completion:completion];
	}];
}

- (void)unpinAllMessagesInForumTopicInChat:(int64_t)chatId
									 topic:(int32_t)topicId
								completion:(void (^)(BOOL))completion {
	[self runForumOk:@{
		@"@type" : @"unpinAllForumTopicMessages",
		@"chat_id" : @(chatId),
		@"forum_topic_id" : @(topicId),
	}
		  completion:completion];
}

- (void)forumTopicLinkInChat:(int64_t)chatId
					   topic:(int32_t)topicId
				  completion:(void (^)(NSString *))completion {
	[self request:@{
		@"@type" : @"getForumTopicLink",
		@"chat_id" : @(chatId),
		@"forum_topic_id" : @(topicId),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSString *link = result[@"link"];
		if (![link isKindOfClass:NSString.class] || !link.length) {
			NSLog(@"TGClient: getForumTopicLink -> %@", result[@"@type"]);
			completion(nil);
			return;
		}
		completion(link);
	}];
}

#pragma mark - icons

- (void)forumTopicDefaultIconsWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getForumTopicDefaultIcons"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			NSArray *stickers = result[@"stickers"];
			if (![stickers isKindOfClass:NSArray.class]) {
				NSLog(@"TGClient: getForumTopicDefaultIcons -> %@", result[@"@type"]);
				completion(@[]);
				return;
			}
			NSMutableArray *out = [NSMutableArray arrayWithCapacity:stickers.count];
			for (NSDictionary *sticker in stickers) {
				if (![sticker isKindOfClass:NSDictionary.class])
					continue;
				NSDictionary *fullType = sticker[@"full_type"];
				if (![fullType isKindOfClass:NSDictionary.class])
					fullType = [NSDictionary dictionary];
				NSDictionary *thumb = sticker[@"thumbnail"];
				if (![thumb isKindOfClass:NSDictionary.class])
					thumb = [NSDictionary dictionary];
				NSDictionary *thumbFile = thumb[@"file"];
				if (![thumbFile isKindOfClass:NSDictionary.class])
					thumbFile = [NSDictionary dictionary];
				NSDictionary *file = sticker[@"sticker"];
				if (![file isKindOfClass:NSDictionary.class])
					file = [NSDictionary dictionary];
				NSString *emoji = sticker[@"emoji"];
				if (![emoji isKindOfClass:NSString.class])
					emoji = @"";
				[out addObject:@{
					@"emojiId" : TGForumsInt64(fullType[@"custom_emoji_id"]),
					@"emoji" : emoji,
					@"thumbFileId" : thumbFile[@"id"] ?: @(0),
					@"fileId" : file[@"id"] ?: @(0),
				}];
			}
			completion(out);
		}];
}

#pragma mark - forum mode

- (void)setSupergroup:(int64_t)supergroupId
			  isForum:(BOOL)isForum
			  hasTabs:(BOOL)hasTabs
		   completion:(void (^)(BOOL))completion {
	[self runForumOk:@{
		@"@type" : @"toggleSupergroupIsForum",
		@"supergroup_id" : @(supergroupId),
		@"is_forum" : @(isForum),
		@"has_forum_tabs" : @(hasTabs),
	}
		  completion:completion];
}

- (void)setChat:(int64_t)chatId
	viewAsTopics:(BOOL)viewAsTopics
	  completion:(void (^)(BOOL))completion {
	[self runForumOk:@{
		@"@type" : @"toggleChatViewAsTopics",
		@"chat_id" : @(chatId),
		@"view_as_topics" : @(viewAsTopics),
	}
		  completion:completion];
}

@end

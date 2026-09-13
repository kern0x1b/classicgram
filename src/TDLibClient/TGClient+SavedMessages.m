#import "TGClient+ChatManagement.h"
#import "TGClient+SavedMessages.h"
#import "TGMessageTopic.h"
#import "TGClient+Private.h"
#import "TGClient+ChatList.h"
#import "TGClient+Messages.h"
#import "TGFlattenSavedMessages.h"
#import "TGFlattenReactions.h"
#import <objc/runtime.h>

static NSMutableDictionary *TGSavedTopics(void) {
	static NSMutableDictionary *topics = nil;
	if (!topics)
		topics = [[NSMutableDictionary alloc] init];
	return topics;
}

static NSInteger TGSavedTopicCount = 0;
static void (^TGSavedTopicsChanged)(void) = nil;

NSString *const TGSavedMessagesTagsDidChangeNotification = @"TGSavedMessagesTagsDidChangeNotification";
NSString *const TGSavedMessagesTagsTopicIdKey = @"TGSavedMessagesTagsTopicIdKey";

static NSMutableDictionary *TGSavedTagLabels(void) {
	static NSMutableDictionary *labels = nil;
	if (!labels)
		labels = [[NSMutableDictionary alloc] init];
	return labels;
}

static void TGSavedSetTagLabelCache(NSString *emoji, int64_t customEmojiId, NSString *label) {
	NSString *key = TGSavedMessagesTagLookupKey(emoji, customEmojiId);
	if (!key)
		return;
	if (label.length)
		[TGSavedTagLabels() setObject:label forKey:key];
	else
		[TGSavedTagLabels() removeObjectForKey:key];
}

static void TGSavedUpdateTagLabelsCache(NSArray *rawTags, int64_t topicId) {
	if (topicId != 0)
		return;
	if (![rawTags isKindOfClass:NSArray.class])
		return;
	for (NSDictionary *entry in rawTags) {
		if (![entry isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *tag = [entry[@"tag"] isKindOfClass:NSDictionary.class] ? entry[@"tag"] : nil;
		NSString *emoji = [tag[@"emoji"] isKindOfClass:NSString.class] ? tag[@"emoji"] : nil;
		NSNumber *customEmojiId = emoji.length ? nil : TGSavedTagCustomEmojiId(tag);
		NSString *label = [entry[@"label"] isKindOfClass:NSString.class] ? entry[@"label"] : @"";
		TGSavedSetTagLabelCache(emoji, [customEmojiId longLongValue], label);
	}
}

static NSMutableSet *TGSavedTitleLookups(void) {
	static NSMutableSet *pending = nil;
	if (!pending)
		pending = [[NSMutableSet alloc] init];
	return pending;
}

static NSDictionary *TGSavedFlattenMessage(NSDictionary *m) {
	if (![m isKindOfClass:NSDictionary.class])
		return nil;
	NSDictionary *sender = m[@"sender_id"];
	if (![sender isKindOfClass:NSDictionary.class])
		sender = [NSDictionary dictionary];

	NSNumber *messageId = m[@"id"];
	if (![messageId isKindOfClass:NSNumber.class])
		messageId = @(0);

	return [NSDictionary dictionaryWithObjectsAndKeys:
			messageId, @"id",
		TGSavedPreview(m) ?: @"", @"text",
		m[@"date"] ?: @(0), @"date",
		@([m[@"is_outgoing"] boolValue]), @"outgoing",
		sender[@"user_id"] ?: @(0), @"senderId",
		sender[@"chat_id"] ?: @(0), @"senderChatId",
		@([m[@"is_pinned"] boolValue]), @"isPinned",
		TGSavedMessageTags(m), @"tags",
		nil];
}

static void TGSavedResolveTopicTitle(NSDictionary *flat) {
	if (![flat isKindOfClass:NSDictionary.class])
		return;
	NSString *title = flat[@"title"];
	if ([title isKindOfClass:NSString.class] && title.length)
		return;
	int64_t chatId = [flat[@"chatId"] longLongValue];
	if (chatId == 0)
		return;

	id topicId = flat[@"id"];
	if (![topicId isKindOfClass:NSNumber.class])
		return;
	if ([TGSavedTitleLookups() containsObject:topicId])
		return;
	[TGSavedTitleLookups() addObject:topicId];

	[[TGClient shared] titleForChatId:chatId completion:^(NSString *resolved) {
		[TGSavedTitleLookups() removeObject:topicId];
		if (![resolved isKindOfClass:NSString.class] || !resolved.length)
			return;
		NSDictionary *current = [TGSavedTopics() objectForKey:topicId];
		if (![current isKindOfClass:NSDictionary.class])
			return;
		NSString *existing = current[@"title"];
		if ([existing isKindOfClass:NSString.class] && existing.length)
			return;
		NSMutableDictionary *updated = [current mutableCopy];
		[updated setObject:resolved forKey:@"title"];
		[TGSavedTopics() setObject:updated forKey:topicId];
		if (TGSavedTopicsChanged)
			TGSavedTopicsChanged();
	}];
}

static NSDictionary *TGSavedReactionType(NSString *emoji) {
	return [NSDictionary dictionaryWithObjectsAndKeys:
			@"reactionTypeEmoji", @"@type",
		emoji ?: @"", @"emoji",
		nil];
}

static NSDictionary *TGSavedCustomEmojiReactionType(long long customEmojiId) {
	return [NSDictionary dictionaryWithObjectsAndKeys:
			@"reactionTypeCustomEmoji", @"@type",
		@(customEmojiId), @"custom_emoji_id",
		nil];
}

@interface TGClient (SavedMessagesSwizzle)
- (void)handleUpdate:(NSDictionary *)obj;
- (void)tgsm_handleUpdate:(NSDictionary *)obj;
@end

@implementation TGClient (SavedMessages)

+ (void)load {
	Method original = class_getInstanceMethod(self, @selector(handleUpdate:));
	Method replacement = class_getInstanceMethod(self, @selector(tgsm_handleUpdate:));
	if (original && replacement)
		method_exchangeImplementations(original, replacement);
}

- (void)tgsm_handleUpdate:(NSDictionary *)obj {
	if ([obj isKindOfClass:NSDictionary.class] && ![obj[@"@extra"] isKindOfClass:NSString.class]) {
		NSString *type = obj[@"@type"];

		if ([type isEqualToString:@"updateSavedMessagesTopic"]) {
			NSDictionary *flat = TGSavedFlattenTopic(obj[@"topic"], ^NSString *(int64_t chatId) {
				return [[TGClient shared] cachedTitleForChatId:chatId];
			});
			if (flat) {
				BOOL isEmptyAndUnpinned = [flat[@"order"] longLongValue] == 0 &&
					![flat[@"isPinned"] boolValue];
				if (isEmptyAndUnpinned)
					[TGSavedTopics() removeObjectForKey:flat[@"id"]];
				else
					[TGSavedTopics() setObject:flat forKey:flat[@"id"]];
				if (TGSavedTopicsChanged)
					TGSavedTopicsChanged();
				if (!isEmptyAndUnpinned)
					TGSavedResolveTopicTitle(flat);
			}
		} else if ([type isEqualToString:@"updateSavedMessagesTopicCount"]) {
			NSNumber *count = obj[@"topic_count"];
			if ([count isKindOfClass:NSNumber.class])
				TGSavedTopicCount = [count integerValue];
			if (TGSavedTopicsChanged)
				TGSavedTopicsChanged();
		} else if ([type isEqualToString:@"updateSavedMessagesTags"]) {
			NSDictionary *tagsBox = [obj[@"tags"] isKindOfClass:NSDictionary.class] ? obj[@"tags"] : nil;
			NSNumber *topicId = obj[@"saved_messages_topic_id"];
			TGSavedUpdateTagLabelsCache(tagsBox[@"tags"],
				[topicId isKindOfClass:NSNumber.class] ? topicId.longLongValue : 0);
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGSavedMessagesTagsDidChangeNotification
							  object:self
							userInfo:@{TGSavedMessagesTagsTopicIdKey :
									([topicId isKindOfClass:NSNumber.class] ? topicId : @0)}];
		}
	}
	[self tgsm_handleUpdate:obj];
}

- (void)runSavedOk:(NSDictionary *)request completion:(void (^)(BOOL))completion {
	[self request:request completion:^(NSDictionary *result) {
		BOOL ok = ![result[@"@type"] isEqualToString:@"error"];
		if (!ok)
			NSLog(@"TGClient: %@ failed: %@", request[@"@type"], result[@"message"]);
		if (completion)
			completion(ok);
	}];
}

#pragma mark - topics list

- (NSArray *)cachedSavedMessagesTopics {
	NSArray *all = [TGSavedTopics() allValues];
	return [all sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
		BOOL pinnedA = [a[@"isPinned"] boolValue];
		BOOL pinnedB = [b[@"isPinned"] boolValue];
		if (pinnedA != pinnedB)
			return pinnedA ? NSOrderedAscending : NSOrderedDescending;
		long long orderA = [a[@"order"] longLongValue];
		long long orderB = [b[@"order"] longLongValue];
		if (orderA == orderB)
			return NSOrderedSame;
		return orderA > orderB ? NSOrderedAscending : NSOrderedDescending;
	}];
}

- (NSDictionary *)cachedSavedMessagesTopic:(int64_t)topicId {
	return [TGSavedTopics() objectForKey:@(topicId)];
}

- (NSInteger)savedMessagesTopicCount {
	return TGSavedTopicCount;
}

- (void)setSavedMessagesTopicsChangedHandler:(void (^)(void))handler {
	TGSavedTopicsChanged = [handler copy];
}

- (void)resetSavedMessagesTopicsCache {
	[TGSavedTopics() removeAllObjects];
	TGSavedTopicCount = 0;
}

- (void)loadSavedMessagesTopicsWithLimit:(NSInteger)limit
							  completion:(void (^)(NSArray *))completion {
	if (limit <= 0)
		limit = 100;
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"loadSavedMessagesTopics",
		@"limit" : @(limit),
	} completion:^(NSDictionary *result) {
		if ([result[@"@type"] isEqualToString:@"error"])
			NSLog(@"TGClient: loadSavedMessagesTopics -> %@", result[@"message"]);
		if (!completion)
			return;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{
				TGClient *strongSelf = weakSelf;
				completion(strongSelf ? [strongSelf cachedSavedMessagesTopics] : [NSArray array]);
			});
	}];
}

#pragma mark - topic history

- (void)savedMessagesTopic:(int64_t)topicId
			 messageAtDate:(NSInteger)date
				completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"getSavedMessagesTopicMessageByDate",
		@"saved_messages_topic_id" : @(topicId),
		@"date" : @(date),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"message"]) {
			completion(nil);
			return;
		}
		completion(TGSavedFlattenMessage(result));
	}];
}

- (void)savedMessagesSparsePositionsForTopic:(int64_t)topicId
								 fromMessage:(int64_t)fromMessageId
									   limit:(NSInteger)limit
								  completion:(void (^)(NSArray *, NSInteger))completion {
	if (limit <= 0)
		limit = 100;
	int64_t chatId = [self savedMessagesChatId];
	[self request:@{
		@"@type" : @"getChatSparseMessagePositions",
		@"chat_id" : @(chatId),
		@"filter" : @{@"@type" : @"searchMessagesFilterEmpty"},
		@"from_message_id" : @(fromMessageId),
		@"limit" : @(limit),
		@"saved_messages_topic_id" : @(topicId),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSArray *positions = result[@"positions"];
		if (![positions isKindOfClass:NSArray.class]) {
			NSLog(@"TGClient: getChatSparseMessagePositions -> %@", result[@"message"]);
			completion([NSArray array], 0);
			return;
		}
		NSMutableArray *out = [NSMutableArray arrayWithCapacity:positions.count];
		for (NSDictionary *p in positions) {
			if (![p isKindOfClass:NSDictionary.class])
				continue;
			[out addObject:@{
				@"position" : p[@"position"] ?: @(0),
				@"messageId" : p[@"message_id"] ?: @(0),
				@"date" : p[@"date"] ?: @(0),
			}];
		}
		completion(out, [result[@"total_count"] integerValue]);
	}];
}

#pragma mark - pinning topics

- (void)setSavedMessagesTopic:(int64_t)topicId
					   pinned:(BOOL)pinned
				   completion:(void (^)(BOOL))completion {
	[self runSavedOk:@{
		@"@type" : @"toggleSavedMessagesTopicIsPinned",
		@"saved_messages_topic_id" : @(topicId),
		@"is_pinned" : @(pinned),
	}
		  completion:completion];
}

- (void)setPinnedSavedMessagesTopics:(NSArray *)topicIds
						  completion:(void (^)(BOOL))completion {
	NSMutableArray *ids = [NSMutableArray array];
	for (id value in topicIds) {
		if ([value isKindOfClass:NSNumber.class])
			[ids addObject:value];
	}
	[self runSavedOk:@{
		@"@type" : @"setPinnedSavedMessagesTopics",
		@"saved_messages_topic_ids" : ids,
	}
		  completion:completion];
}

#pragma mark - deleting

- (void)deleteSavedMessagesTopic:(int64_t)topicId
					  completion:(void (^)(BOOL))completion {
	[self runSavedOk:@{
		@"@type" : @"deleteSavedMessagesTopicHistory",
		@"saved_messages_topic_id" : @(topicId),
	} completion:^(BOOL ok) {
		if (ok)
			[TGSavedTopics() removeObjectForKey:@(topicId)];
		if (completion)
			completion(ok);
	}];
}

- (void)deleteSavedMessagesTopic:(int64_t)topicId
					messagesFrom:(NSInteger)minDate
							  to:(NSInteger)maxDate
					  completion:(void (^)(BOOL))completion {
	[self runSavedOk:@{
		@"@type" : @"deleteSavedMessagesTopicMessagesByDate",
		@"saved_messages_topic_id" : @(topicId),
		@"min_date" : @(minDate),
		@"max_date" : @(maxDate),
	}
		  completion:completion];
}

#pragma mark - tags

- (void)setSavedMessagesTagLabel:(NSString *)label
						forEmoji:(NSString *)emoji
					  completion:(void (^)(BOOL))completion {
	[self runSavedOk:@{
		@"@type" : @"setSavedMessagesTagLabel",
		@"tag" : TGSavedReactionType(emoji),
		@"label" : label ?: @"",
	}
		  completion:^(BOOL ok) {
			  if (ok)
				  TGSavedSetTagLabelCache(emoji, 0, label);
			  if (completion)
				  completion(ok);
		  }];
}

- (void)setSavedMessagesTagLabel:(NSString *)label
				forCustomEmojiId:(long long)customEmojiId
					  completion:(void (^)(BOOL))completion {
	[self runSavedOk:@{
		@"@type" : @"setSavedMessagesTagLabel",
		@"tag" : TGSavedCustomEmojiReactionType(customEmojiId),
		@"label" : label ?: @"",
	}
		  completion:^(BOOL ok) {
			  if (ok)
				  TGSavedSetTagLabelCache(nil, customEmojiId, label);
			  if (completion)
				  completion(ok);
		  }];
}

- (NSString *)cachedSavedMessagesTagLabelForEmoji:(NSString *)emoji
									 customEmojiId:(int64_t)customEmojiId {
	NSString *key = TGSavedMessagesTagLookupKey(emoji, customEmojiId);
	if (!key)
		return nil;
	NSString *label = [TGSavedTagLabels() objectForKey:key];
	return label.length ? label : nil;
}

#pragma mark - pinned message inside Saved Messages

- (void)unpinAllMessagesInSavedTopic:(int64_t)topicId completion:(void (^)(BOOL))completion {
	int64_t chatId = [self savedMessagesChatId];
	[self pinnedMessagesForChat:chatId thread:0 savedTopic:topicId completion:^(NSArray *pinned) {
		if (!pinned) {
			if (completion)
				completion(NO);
			return;
		}
		if (!pinned.count) {
			if (completion)
				completion(YES);
			return;
		}
		dispatch_group_t group = dispatch_group_create();
		__block BOOL allOk = YES;
		for (NSDictionary *message in pinned) {
			int64_t messageId = [message[@"id"] longLongValue];
			if (!messageId)
				continue;
			dispatch_group_enter(group);
			[self unpinMessage:messageId inChat:chatId completion:^(BOOL ok) {
				if (!ok)
					allOk = NO;
				dispatch_group_leave(group);
			}];
		}
		dispatch_group_notify(group, dispatch_get_main_queue(), ^{
			if (completion)
				completion(allOk);
		});
	}];
}

#pragma mark - per-topic drafts

- (void)setSavedMessagesTopic:(int64_t)topicId
					draftText:(NSString *)text
				   completion:(void (^)(BOOL))completion {
	NSMutableDictionary *request = [NSMutableDictionary dictionaryWithDictionary:@{
		@"@type" : @"setChatDraftMessage",
		@"chat_id" : @([self savedMessagesChatId]),
		@"topic_id" : TGTopicDictionary(0, 0, topicId, NO),
	}];
	if (text.length) {
		[request setObject:@{
			@"@type" : @"draftMessage",
			@"date" : @((NSInteger)[[NSDate date] timeIntervalSince1970]),
			@"content" : @{
				@"@type" : @"draftMessageContentText",
				@"text" : @{@"@type" : @"formattedText", @"text" : text, @"entities" : @[]},
			},
		}
					forKey:@"draft_message"];
	}
	[self runSavedOk:request completion:completion];
}

#pragma mark - links

- (void)savedMessagesTagsForTopic:(int64_t)topicId
					   completion:(void (^)(NSArray *tags))completion {
	[self request:@{@"@type" : @"getSavedMessagesTags",
		@"saved_messages_topic_id" : @(topicId)}
		completion:^(NSDictionary *result) {
			NSArray *tags = [result[@"tags"] isKindOfClass:NSArray.class] ? result[@"tags"] : @[];
			TGSavedUpdateTagLabelsCache(tags, topicId);
			if (completion)
				completion(tags);
		}];
}

- (void)searchSavedMessagesWithQuery:(NSString *)query
							tagEmoji:(NSString *)tagEmoji
					tagCustomEmojiId:(int64_t)tagCustomEmojiId
							 topicId:(int64_t)topicId
					   fromMessageId:(int64_t)fromMessageId
							   limit:(NSInteger)limit
						  completion:(void (^)(NSArray *messages, int64_t nextFromMessageId))completion {
	NSMutableDictionary *request = [NSMutableDictionary dictionaryWithDictionary:
			@{@"@type" : @"searchSavedMessages",
				@"saved_messages_topic_id" : @(topicId),
				@"query" : (query ?: @""),
				@"from_message_id" : @(fromMessageId),
				@"offset" : @0,
				@"limit" : @(limit)}];
	if (tagCustomEmojiId)
		request[@"tag"] = TGSavedCustomEmojiReactionType(tagCustomEmojiId);
	else if (tagEmoji.length)
		request[@"tag"] = @{@"@type" : @"reactionTypeEmoji", @"emoji" : tagEmoji};

	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSArray *messages = [result[@"messages"] isKindOfClass:NSArray.class]
			? result[@"messages"]
			: @[];
		completion(messages, [result[@"next_from_message_id"] longLongValue]);
	}];
}

#pragma mark - account switch

- (void)resetSavedMessagesCachesForAccountSwitch {
	[self resetSavedMessagesTopicsCache];
	[TGSavedTagLabels() removeAllObjects];
	[TGSavedTitleLookups() removeAllObjects];
}

@end

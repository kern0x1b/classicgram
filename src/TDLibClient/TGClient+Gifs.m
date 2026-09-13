#import "TGClient+Private.h"
#import "TGMessageReply.h"
#import "TGClient+Gifs.h"
#import "TGClient+Stickers.h"
#import "TGFlattenGifs.h"
#import "TGFlattenMessages.h"
#import "TGMessageTopic.h"

static BOOL TGGifChatIsForum(TGClient *client, int64_t chatId) {
	id value = client.chatsById[@(chatId)][@"isForum"];
	return [value isKindOfClass:NSNumber.class] && [value boolValue];
}

static NSArray *TGGifArray(id value) {
	return [value isKindOfClass:[NSArray class]] ? value : nil;
}

static NSDictionary *TGGifDict(id value) {
	return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static NSString *TGGifString(id value) {
	return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSNumber *TGGifNumber(id value) {
	if ([value isKindOfClass:[NSNumber class]])
		return value;
	if ([value isKindOfClass:[NSString class]])
		return [NSNumber numberWithLongLong:[value longLongValue]];
	return @0;
}

@implementation TGClient (Gifs)

#pragma mark - the saved list

- (void)savedGifsWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getSavedAnimations"} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (id entry in TGGifArray(result[@"animations"])) {
			NSDictionary *flat = TGFlattenAnimation(entry);
			if (flat)
				[out addObject:flat];
		}
		completion(out);
	}];
}

- (void)saveGifWithFileId:(long long)fileId completion:(void (^)(BOOL))completion {
	if (fileId <= 0) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"addSavedAnimation",
		@"animation" : @{@"@type" : @"inputFileId", @"id" : @(fileId)},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)unsaveGifWithFileId:(long long)fileId completion:(void (^)(BOOL))completion {
	if (fileId <= 0) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"removeSavedAnimation",
		@"animation" : @{@"@type" : @"inputFileId", @"id" : @(fileId)},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)isGifSavedWithFileId:(long long)fileId completion:(void (^)(BOOL))completion {
	if (!completion)
		return;
	if (fileId <= 0) {
		completion(NO);
		return;
	}
	[self savedGifsWithCompletion:^(NSArray *gifs) {
		BOOL found = NO;
		for (NSDictionary *gif in gifs) {
			if ([gif[@"fileId"] longLongValue] == fileId) {
				found = YES;
				break;
			}
		}
		completion(found);
	}];
}

#pragma mark - trending and search

static int64_t TGGifCachedSearchBotId = 0;

- (void)resetGifSearchBotCacheForAccountSwitch {
	TGGifCachedSearchBotId = 0;
}

- (void)gif_searchBotWithCompletion:(void (^)(int64_t botUserId))completion {
	if (TGGifCachedSearchBotId != 0) {
		if (completion)
			completion(TGGifCachedSearchBotId);
		return;
	}
	[self request:@{@"@type" : @"getOption",
		@"name" : @"animation_search_bot_username"}
		completion:^(NSDictionary *result) {
			NSString *username = TGGifString(result[@"value"]);
			if (!username.length) {
				if (completion)
					completion(0);
				return;
			}
			[self request:@{@"@type" : @"searchPublicChat", @"username" : username}
				completion:^(NSDictionary *chat) {
					if (TGResultIsError(chat)) {
						if (completion)
							completion(0);
						return;
					}
					NSDictionary *type = TGGifDict(chat[@"type"]);
					int64_t userId = [TGGifNumber(type[@"user_id"]) longLongValue];
					if (userId == 0)
						userId = [TGGifNumber(chat[@"id"]) longLongValue];
					if (userId > 0)
						TGGifCachedSearchBotId = userId;
					if (completion)
						completion(userId);
				}];
		}];
}

- (void)searchGifs:(NSString *)query
			offset:(NSString *)offset
		completion:(void (^)(NSArray *, NSString *))completion {
	[self gif_searchBotWithCompletion:^(int64_t botUserId) {
		if (botUserId == 0) {
			if (completion)
				completion(nil, @"");
			return;
		}
		[self request:@{
			@"@type" : @"getInlineQueryResults",
			@"bot_user_id" : @(botUserId),
			@"chat_id" : @0,
			@"query" : query ?: @"",
			@"offset" : offset ?: @"",
		} completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil, @"");
				return;
			}
			NSNumber *queryId = TGGifNumber(result[@"inline_query_id"]);
			NSMutableArray *out = [NSMutableArray array];
			for (id entry in TGGifArray(result[@"results"])) {
				NSDictionary *item = TGGifDict(entry);
				if (![TGGifString(item[@"@type"])
						isEqualToString:@"inlineQueryResultAnimation"])
					continue;
				NSDictionary *flat = TGFlattenAnimation(item[@"animation"]);
				if (!flat)
					continue;
				NSMutableDictionary *gif = [flat mutableCopy];
				gif[@"queryId"] = queryId;
				gif[@"resultId"] = TGGifString(item[@"id"]) ?: @"";
				if ([TGGifString(item[@"title"]) length] > 0)
					gif[@"title"] = TGGifString(item[@"title"]);
				[out addObject:gif];
			}
			completion(out, TGGifString(result[@"next_offset"]) ?: @"");
		}];
	}];
}

- (void)trendingGifsWithCompletion:(void (^)(NSArray *, NSString *))completion {
	[self searchGifs:@"" offset:nil completion:completion];
}

- (void)gifSearchCategoriesWithCompletion:(void (^)(NSArray *))completion {
	[self emojiCategoriesForStickers:NO completion:completion];
}

#pragma mark - sending

- (void)sendGif:(NSDictionary *)gif
		 toChat:(int64_t)chatId
		 thread:(int64_t)threadId
directMessagesTopic:(int64_t)directMessagesTopicId
	 savedTopic:(int64_t)savedTopicId
		replyTo:(int64_t)replyToId
		options:(NSDictionary *)options {
	if (![gif isKindOfClass:[NSDictionary class]])
		return;

	NSString *resultId = TGGifString(gif[@"resultId"]);
	NSNumber *queryId = [gif[@"queryId"] isKindOfClass:[NSNumber class]]
		? gif[@"queryId"]
		: nil;

	NSMutableDictionary *request = nil;
	if (resultId.length > 0 && [queryId longLongValue] != 0) {
		request = [@{
			@"@type" : @"sendInlineQueryResultMessage",
			@"chat_id" : @(chatId),
			@"options" : TGMsgSendOptions(options),
			@"query_id" : queryId,
			@"result_id" : resultId,
			@"hide_via_bot" : @YES,
		} mutableCopy];
	} else {
		long long fileId = [gif[@"fileId"] longLongValue];
		if (fileId <= 0)
			return;
		request = [@{
			@"@type" : @"sendMessage",
			@"chat_id" : @(chatId),
			@"options" : TGMsgSendOptions(options),
			@"input_message_content" : @{
				@"@type" : @"inputMessageAnimation",
				@"animation" : @{
					@"@type" : @"inputAnimation",
					@"animation" : @{@"@type" : @"inputFileId",
						@"id" : @(fileId)},
					@"duration" : @([gif[@"duration"] intValue]),
					@"width" : @([gif[@"width"] intValue]),
					@"height" : @([gif[@"height"] intValue]),
				},
				@"caption" : @{@"@type" : @"formattedText",
					@"text" : @"",
					@"entities" : @[]},
			},
		} mutableCopy];
	}

	NSDictionary *topic = TGTopicDictionary(threadId, directMessagesTopicId, savedTopicId,
		TGGifChatIsForum(self, chatId));
	if (topic)
		request[@"topic_id"] = topic;
	NSDictionary *replyTo = TGReplyToDictionary(replyToId, nil, nil, 0);
	if (replyTo)
		request[@"reply_to"] = replyTo;

	[self send:request];
}

@end

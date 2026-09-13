#import "TGClient+Private.h"
#import "TGLocalization.h"
#import "TGFlattenMessage.h"
#import "TGFlattenHistory.h"
#import "TGMessageTopic.h"
#import "AppDelegate.h"

static BOOL TGHistoryChatIsForum(TGClient *client, int64_t chatId) {
	id value = client.chatsById[@(chatId)][@"isForum"];
	return [value isKindOfClass:NSNumber.class] && [value boolValue];
}

@implementation TGClient (History)

- (void)historyForChat:(int64_t)chatId
				thread:(int64_t)threadId
				 limit:(NSInteger)limit
			 onlyLocal:(BOOL)onlyLocal
			completion:(void (^)(NSArray *))completion {
	[self historyForChat:chatId thread:threadId limit:limit onlyLocal:onlyLocal
				progress:nil
			  completion:completion];
}

- (void)historyForChat:(int64_t)chatId
				thread:(int64_t)threadId
				 limit:(NSInteger)limit
			 onlyLocal:(BOOL)onlyLocal
			  progress:(void (^)(NSArray *))progress
			completion:(void (^)(NSArray *))completion {
	if (threadId == 0) {
		[self historyForChat:chatId limit:limit onlyLocal:onlyLocal
					progress:progress
				  completion:completion];
		return;
	}
	if (onlyLocal) {
		if (completion)
			completion(@[]);
		return;
	}
	[self historyForChat:chatId thread:threadId limit:limit completion:completion];
}

- (NSDictionary *)historyRequestForChat:(int64_t)chatId
								 thread:(int64_t)threadId
								   from:(int64_t)fromMessageId
								 offset:(NSInteger)offset
								  limit:(NSInteger)limit
							  onlyLocal:(BOOL)onlyLocal {
	if (threadId != 0)
		return @{
			@"@type" : @"getMessageThreadHistory",
			@"chat_id" : @(chatId),
			@"message_id" : @(threadId),
			@"from_message_id" : @(fromMessageId),
			@"offset" : @(offset),
			@"limit" : @(limit),
		};
	return @{
		@"@type" : @"getChatHistory",
		@"chat_id" : @(chatId),
		@"from_message_id" : @(fromMessageId),
		@"offset" : @(offset),
		@"limit" : @(limit),
		@"only_local" : @(onlyLocal),
	};
}

- (void)historyForChat:(int64_t)chatId
				thread:(int64_t)threadId
				 limit:(NSInteger)limit
			completion:(void (^)(NSArray *))completion {
	if (threadId == 0) {
		[self historyForChat:chatId limit:limit completion:completion];
		return;
	}

	[self request:@{
		@"@type" : @"getMessageThreadHistory",
		@"chat_id" : @(chatId),
		@"message_id" : @(threadId),
		@"from_message_id" : @(0),
		@"offset" : @(0),
		@"limit" : @(limit),
	} completion:^(NSDictionary *result) {
		NSArray *msgs = result[@"messages"];
		if (![msgs isKindOfClass:NSArray.class]) {
			NSLog(@"TGClient: thread history -> %@", result[@"@type"]);
			if (completion)
				completion(nil);
			return;
		}
		NSMutableArray *out = [NSMutableArray arrayWithCapacity:msgs.count];
		for (NSDictionary *m in [[msgs reverseObjectEnumerator] allObjects])
			[out addObject:TGFlattenMessage(m, TGCurrentFlattenContext())];
		if (completion)
			completion(out);
	}];
}

- (void)historyForSavedTopic:(int64_t)savedTopicId
					   limit:(NSInteger)limit
				  completion:(void (^)(NSArray *))completion {
	if (savedTopicId == 0) {
		if (completion)
			completion(@[]);
		return;
	}

	[self request:@{
		@"@type" : @"getSavedMessagesTopicHistory",
		@"saved_messages_topic_id" : @(savedTopicId),
		@"from_message_id" : @(0),
		@"offset" : @(0),
		@"limit" : @(limit > 0 ? limit : 50),
	} completion:^(NSDictionary *result) {
		NSArray *msgs = result[@"messages"];
		if (![msgs isKindOfClass:NSArray.class]) {
			NSLog(@"TGClient: getSavedMessagesTopicHistory -> %@", result[@"message"]);
			if (completion)
				completion(nil);
			return;
		}
		NSMutableArray *out = [NSMutableArray arrayWithCapacity:msgs.count];
		for (NSDictionary *m in [[msgs reverseObjectEnumerator] allObjects]) {
			NSDictionary *flat = TGFlattenMessage(m, TGCurrentFlattenContext());
			if (flat)
				[out addObject:flat];
		}
		if (completion)
			completion(out);
	}];
}

- (void)historyForDirectMessagesTopic:(int64_t)topicId
							   inChat:(int64_t)chatId
								limit:(NSInteger)limit
						   completion:(void (^)(NSArray *))completion {
	if (topicId == 0 || chatId == 0) {
		if (completion)
			completion(@[]);
		return;
	}

	[self request:@{
		@"@type" : @"getDirectMessagesChatTopicHistory",
		@"chat_id" : @(chatId),
		@"topic_id" : @(topicId),
		@"from_message_id" : @(0),
		@"offset" : @(0),
		@"limit" : @(limit > 0 ? limit : 50),
	} completion:^(NSDictionary *result) {
		NSArray *msgs = result[@"messages"];
		if (![msgs isKindOfClass:NSArray.class]) {
			NSLog(@"TGClient: getDirectMessagesChatTopicHistory -> %@", result[@"message"]);
			if (completion)
				completion(nil);
			return;
		}
		NSMutableArray *out = [NSMutableArray arrayWithCapacity:msgs.count];
		for (NSDictionary *m in [[msgs reverseObjectEnumerator] allObjects]) {
			NSDictionary *flat = TGFlattenMessage(m, TGCurrentFlattenContext());
			if (flat)
				[out addObject:flat];
		}
		if (completion)
			completion(out);
	}];
}

- (void)searchMessages:(NSString *)query completion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"searchMessages",
		@"query" : query ?: @"",
		@"limit" : @(50),
		@"offset" : @"",
	} completion:^(NSDictionary *result) {
		TGClient *strongSelf = weakSelf;
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *m in result[@"messages"]) {
			NSMutableDictionary *flat = [TGFlattenMessage(m, TGCurrentFlattenContext()) mutableCopy];
			if (!flat)
				continue;
			int64_t chatId = [m[@"chat_id"] longLongValue];
			flat[@"chatId"] = @(chatId);
			flat[@"chatTitle"] = [strongSelf titleForChat:chatId] ?: @"";
			[out addObject:flat];
		}
		if (completion)
			completion(out);
	}];
}

- (void)searchInChat:(int64_t)chatId
				query:(NSString *)query
			 threadId:(int64_t)threadId
 directMessagesTopic:(int64_t)directMessagesTopicId
		   savedTopic:(int64_t)savedTopicId
		fromMessageId:(int64_t)fromMessageId
				limit:(NSInteger)limit
		   completion:(void (^)(NSArray *, int64_t, NSInteger))completion {
	NSMutableDictionary *request = [@{
		@"@type" : @"searchChatMessages",
		@"chat_id" : @(chatId),
		@"query" : query ?: @"",
		@"from_message_id" : @(fromMessageId),
		@"offset" : @(0),
		@"limit" : @(limit > 0 ? limit : 50),
	} mutableCopy];
	NSDictionary *topic = TGTopicDictionary(threadId, directMessagesTopicId, savedTopicId,
		TGHistoryChatIsForum(self, chatId));
	if (topic)
		request[@"topic_id"] = topic;

	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *m in result[@"messages"]) {
			NSDictionary *flat = TGFlattenMessage(m, TGCurrentFlattenContext());
			if (flat)
				[out addObject:flat];
		}
		completion(out, [result[@"next_from_message_id"] longLongValue],
			[result[@"total_count"] integerValue]);
	}];
}

- (void)searchInSecretChat:(int64_t)chatId
					  query:(NSString *)query
					 offset:(NSString *)offset
					  limit:(NSInteger)limit
				 completion:(void (^)(NSArray *, NSString *, NSInteger))completion {
	[self request:@{
		@"@type" : @"searchSecretMessages",
		@"chat_id" : @(chatId),
		@"query" : query ?: @"",
		@"offset" : offset ?: @"",
		@"limit" : @(limit > 0 ? limit : 50),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *m in result[@"messages"]) {
			NSDictionary *flat = TGFlattenMessage(m, TGCurrentFlattenContext());
			if (flat)
				[out addObject:flat];
		}
		NSString *next = result[@"next_offset"];
		completion(out, [next isKindOfClass:NSString.class] ? next : @"",
			[result[@"total_count"] integerValue]);
	}];
}

- (NSString *)titleForChat:(int64_t)chatId {
	for (NSDictionary *c in self.chats)
		if ([c[@"id"] longLongValue] == chatId)
			return c[@"title"];
	for (NSDictionary *c in self.archivedChats)
		if ([c[@"id"] longLongValue] == chatId)
			return c[@"title"];
	return nil;
}

- (void)historyForChat:(int64_t)chatId
				 limit:(NSInteger)limit
			completion:(void (^)(NSArray *))completion {
	[self historyForChat:chatId limit:limit onlyLocal:NO completion:completion];
}

- (void)historyForChat:(int64_t)chatId
				 limit:(NSInteger)limit
			 onlyLocal:(BOOL)onlyLocal
			completion:(void (^)(NSArray *))completion {
	[self historyForChat:chatId limit:limit onlyLocal:onlyLocal
				progress:nil
			  completion:completion];
}

- (void)historyForChat:(int64_t)chatId
				 limit:(NSInteger)limit
			 onlyLocal:(BOOL)onlyLocal
			  progress:(void (^)(NSArray *))progress
			completion:(void (^)(NSArray *))completion {
	int64_t head = [self.chatsById[@(chatId)][@"lastMessageId"] longLongValue];
	if (head != 0) {
		[self pipelinedHistoryForChat:chatId head:head limit:limit
							onlyLocal:onlyLocal
							 progress:progress
						   completion:completion];
		return;
	}

	[self fetchHistoryChunkForChat:chatId
					 fromMessageId:0
							 limit:limit
						 onlyLocal:onlyLocal
						 collected:[NSMutableArray array]
						  progress:progress
						completion:completion];
}

- (void)pipelinedHistoryForChat:(int64_t)chatId
						   head:(int64_t)head
						  limit:(NSInteger)limit
					  onlyLocal:(BOOL)onlyLocal
					   progress:(void (^)(NSArray *))progress
					 completion:(void (^)(NSArray *))completion {
	__block NSArray *newest = nil;
	__block NSArray *below = nil;
	__block BOOL newestFailed = NO;
	__block BOOL belowFailed = NO;
	__block BOOL finished = NO;
	__weak typeof(self) weakSelf = self;

	void (^join)(void) = ^{
		if (finished)
			return;
		BOOL enough = newest && (NSInteger)newest.count >= limit;
		if (!enough && (!newest || !below))
			return;
		finished = YES;
		TGClient *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (newestFailed && belowFailed) {
			if (completion)
				completion(nil);
			return;
		}
		[strongSelf finishPipelinedHistoryForChat:chatId head:head
								   newest:(newest ?: @[])
			below:(below ?: @[])
			limit:limit
								onlyLocal:onlyLocal
								 progress:progress
							   completion:completion];
	};

	[self request:@{
		@"@type" : @"getChatHistory",
		@"chat_id" : @(chatId),
		@"from_message_id" : @(0),
		@"offset" : @(0),
		@"limit" : @(limit),
		@"only_local" : @(onlyLocal),
	} completion:^(NSDictionary *result) {
		NSArray *msgs = result[@"messages"];
		if ([msgs isKindOfClass:NSArray.class]) {
			newest = msgs;
		} else {
			newest = @[];
			newestFailed = YES;
		}
		TGMarkOpenStage([NSString stringWithFormat:@"getChatHistory(%@) head of %lu",
			onlyLocal ? @"local" : @"net", (unsigned long)newest.count]);
		join();
	}];

	[self request:@{
		@"@type" : @"getChatHistory",
		@"chat_id" : @(chatId),
		@"from_message_id" : @(head),
		@"offset" : @(0),
		@"limit" : @(limit),
		@"only_local" : @(onlyLocal),
	} completion:^(NSDictionary *result) {
		NSArray *msgs = result[@"messages"];
		if ([msgs isKindOfClass:NSArray.class]) {
			below = msgs;
		} else {
			below = @[];
			belowFailed = YES;
		}
		TGMarkOpenStage([NSString stringWithFormat:@"getChatHistory(%@) page of %lu",
			onlyLocal ? @"local" : @"net", (unsigned long)below.count]);
		join();
	}];
}

- (void)finishPipelinedHistoryForChat:(int64_t)chatId
								 head:(int64_t)head
							   newest:(NSArray *)newest
								below:(NSArray *)below
								limit:(NSInteger)limit
							onlyLocal:(BOOL)onlyLocal
							 progress:(void (^)(NSArray *))progress
						   completion:(void (^)(NSArray *))completion {
	int64_t reached = newest.count ? [[newest lastObject][@"id"] longLongValue] : head;
	NSArray *merged = reached > head ? newest : TGMergeRawMessages(newest, below);

	NSMutableArray *collected = [NSMutableArray arrayWithCapacity:merged.count];
	for (NSDictionary *m in merged)
		[collected addObject:TGFlattenMessage(m, TGCurrentFlattenContext())];

	int64_t oldest = merged.count ? [[merged lastObject][@"id"] longLongValue] : 0;
	if ((NSInteger)collected.count >= limit || oldest == 0) {
		if (completion)
			completion(TGHistoryOldestFirst(collected, limit));
		return;
	}

	NSArray *soFar = progress ? TGHistoryOldestFirst(collected, limit) : nil;
	[self fetchHistoryChunkForChat:chatId
					 fromMessageId:oldest
							 limit:limit
						 onlyLocal:onlyLocal
						 collected:collected
						  progress:progress
						completion:completion];
	if (progress)
		progress(soFar);
}

- (void)fetchHistoryChunkForChat:(int64_t)chatId
				   fromMessageId:(int64_t)fromMessageId
						   limit:(NSInteger)limit
					   onlyLocal:(BOOL)onlyLocal
					   collected:(NSMutableArray *)collected
						progress:(void (^)(NSArray *))progress
					  completion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	NSInteger requestLimit = limit - (NSInteger)collected.count;
	[self request:@{
		@"@type" : @"getChatHistory",
		@"chat_id" : @(chatId),
		@"from_message_id" : @(fromMessageId),
		@"offset" : @(0),
		@"limit" : @(requestLimit),
		@"only_local" : @(onlyLocal),
	} completion:^(NSDictionary *result) {
		TGClient *strongSelf = weakSelf;
		NSArray *msgs = result[@"messages"];

		TGMarkOpenStage([NSString stringWithFormat:@"getChatHistory(%@) chunk of %lu",
			onlyLocal ? @"local" : @"net",
			(unsigned long)([msgs isKindOfClass:NSArray.class] ? msgs.count : 0)]);

		if (!strongSelf || ![msgs isKindOfClass:NSArray.class]) {
			if (completion)
				completion(collected.count ? TGHistoryOldestFirst(collected, 0) : nil);
			return;
		}
		if (msgs.count == 0) {
			if (completion)
				completion(TGHistoryOldestFirst(collected, 0));
			return;
		}

		for (NSDictionary *m in msgs)
			[collected addObject:TGFlattenMessage(m, TGCurrentFlattenContext())];

		int64_t oldest = [[msgs lastObject][@"id"] longLongValue];
		if ((NSInteger)collected.count >= limit || oldest == 0) {
			if (completion)
				completion(TGHistoryOldestFirst(collected, 0));
			return;
		}

		NSArray *soFar = progress ? TGHistoryOldestFirst(collected, 0) : nil;
		[strongSelf fetchHistoryChunkForChat:chatId
					   fromMessageId:oldest
							   limit:limit
						   onlyLocal:onlyLocal
						   collected:collected
							progress:progress
						  completion:completion];
		if (progress)
			progress(soFar);
	}];
}

- (void)historyForChat:(int64_t)chatId
				thread:(int64_t)threadId
		 aroundMessage:(int64_t)anchorMessageId
				 newer:(NSInteger)newerWanted
				 limit:(NSInteger)limit
			 onlyLocal:(BOOL)onlyLocal
			  progress:(void (^)(NSArray *))progress
			completion:(void (^)(NSArray *))completion {
	if (anchorMessageId == 0 || limit <= 1) {
		[self historyForChat:chatId thread:threadId limit:limit onlyLocal:onlyLocal
					progress:progress
				  completion:completion];
		return;
	}
	if (threadId != 0 && onlyLocal) {
		if (completion)
			completion(@[]);
		return;
	}

	NSInteger newer = newerWanted;
	if (newer > limit - 1)
		newer = limit - 1;
	if (newer < 0)
		newer = 0;
	NSInteger older = limit - newer;

	__block NSArray *above = nil;
	__block NSArray *below = nil;
	__block BOOL waitingAbove = (newer > 0);
	__block BOOL waitingBelow = YES;
	__weak typeof(self) weakSelf = self;

	void (^join)(void) = ^{
		if (waitingAbove || waitingBelow)
			return;
		TGClient *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf finishAnchoredHistoryForChat:chatId thread:threadId
								   above:(above ?: @[])below:(below ?: @[])
			limit:limit
							   onlyLocal:onlyLocal
								progress:progress
							  completion:completion];
	};

	if (newer > 0)
		[self request:[self historyRequestForChat:chatId thread:threadId
											 from:anchorMessageId
										   offset:-newer
											limit:newer
										onlyLocal:onlyLocal]
			completion:^(NSDictionary *result) {
				NSArray *msgs = result[@"messages"];
				above = [msgs isKindOfClass:NSArray.class] ? msgs : @[];
				TGMarkOpenStage([NSString stringWithFormat:
						@"getChatHistory(%@) %lu newer than the anchor",
					onlyLocal ? @"local" : @"net", (unsigned long)above.count]);
				waitingAbove = NO;
				join();
			}];

	[self request:[self historyRequestForChat:chatId thread:threadId
										 from:anchorMessageId
									   offset:0
										limit:older
									onlyLocal:onlyLocal]
		completion:^(NSDictionary *result) {
			NSArray *msgs = result[@"messages"];
			below = [msgs isKindOfClass:NSArray.class] ? msgs : @[];
			TGMarkOpenStage([NSString stringWithFormat:
					@"getChatHistory(%@) %lu at and under the anchor",
				onlyLocal ? @"local" : @"net", (unsigned long)below.count]);
			waitingBelow = NO;
			join();
		}];
}

- (void)finishAnchoredHistoryForChat:(int64_t)chatId
							  thread:(int64_t)threadId
							   above:(NSArray *)above
							   below:(NSArray *)below
							   limit:(NSInteger)limit
						   onlyLocal:(BOOL)onlyLocal
							progress:(void (^)(NSArray *))progress
						  completion:(void (^)(NSArray *))completion {
	NSArray *merged = TGMergeRawMessages(above, below);
	if (!merged.count) {
		[self historyForChat:chatId thread:threadId limit:limit onlyLocal:onlyLocal
					progress:progress
				  completion:completion];
		return;
	}

	NSMutableArray *collected = [NSMutableArray arrayWithCapacity:merged.count];
	for (NSDictionary *m in merged)
		[collected addObject:TGFlattenMessage(m, TGCurrentFlattenContext())];

	int64_t oldest = [[merged lastObject][@"id"] longLongValue];
	if ((NSInteger)collected.count >= limit || oldest == 0 || threadId != 0) {
		if (completion)
			completion(TGHistoryOldestFirst(collected, 0));
		return;
	}

	NSArray *soFar = progress ? TGHistoryOldestFirst(collected, 0) : nil;
	[self fetchHistoryChunkForChat:chatId
					 fromMessageId:oldest
							 limit:limit
						 onlyLocal:onlyLocal
						 collected:collected
						  progress:progress
						completion:completion];
	if (progress)
		progress(soFar);
}

static NSMutableDictionary *TGChatOpenPrefetchSlots(void) {
	static NSMutableDictionary *slots = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ slots = [NSMutableDictionary dictionary]; });
	return slots;
}

static NSString *TGChatOpenPrefetchKey(int64_t chatId, int64_t anchorMessageId,
	NSInteger newerWanted, NSInteger limit) {
	return [NSString stringWithFormat:@"%lld/%lld/%ld/%ld", chatId, anchorMessageId,
		(long)newerWanted, (long)limit];
}

- (void)prefetchLocalHistoryForChat:(int64_t)chatId
					  aroundMessage:(int64_t)anchorMessageId
							  newer:(NSInteger)newerWanted
							  limit:(NSInteger)limit {
	NSString *key = TGChatOpenPrefetchKey(chatId, anchorMessageId, newerWanted, limit);
	NSMutableDictionary *slots = TGChatOpenPrefetchSlots();
	if (slots[key])
		return;

	NSMutableDictionary *slot = [NSMutableDictionary dictionary];
	slot[@"waiters"] = [NSMutableArray array];
	slots[key] = slot;

	[self historyForChat:chatId thread:0 aroundMessage:anchorMessageId newer:newerWanted
				   limit:limit
			   onlyLocal:YES
				progress:nil completion:^(NSArray *messages) {
					slot[@"messages"] = messages ?: @[];
					NSArray *waiters = [slot[@"waiters"] copy];
					[slot[@"waiters"] removeAllObjects];
					for (void (^waiter)(NSArray *) in waiters)
						waiter(messages);
				}];
}

- (BOOL)attachToPrefetchedHistoryForChat:(int64_t)chatId
						   aroundMessage:(int64_t)anchorMessageId
								   newer:(NSInteger)newerWanted
								   limit:(NSInteger)limit
							  completion:(void (^)(NSArray *))completion {
	NSString *key = TGChatOpenPrefetchKey(chatId, anchorMessageId, newerWanted, limit);
	NSMutableDictionary *slots = TGChatOpenPrefetchSlots();
	NSMutableDictionary *slot = slots[key];
	if (!slot)
		return NO;

	[slots removeObjectForKey:key];
	NSArray *messages = slot[@"messages"];
	if (messages) {
		if (completion)
			completion(messages);
		return YES;
	}
	if (completion)
		[slot[@"waiters"] addObject:[completion copy]];
	slots[key] = slot;
	return YES;
}

- (void)resetHistoryPrefetchCachesForAccountSwitch {
	[TGChatOpenPrefetchSlots() removeAllObjects];
}

@end

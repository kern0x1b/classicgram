#import "TGClient+ChatManagement.h"
#import "TGClient+ChatState.h"
#import "TGClient+Private.h"
#import "TGClient+Reactions.h"
#import "TGClient+Files.h"
#import "TGClient+Premium.h"
#import "TGClient+SavedMessages.h"
#import "TGClient+UserStatus.h"
#import "TGFlattenReactions.h"
#import "TGMessageTopic.h"
#import "TGAccountManager.h"

@interface TGClient (ReactionsWatchInternal)
- (void)tgStartReactionWatchTimer;
- (void)tgReactionWatchTick:(NSTimer *)timer;
@end

static BOOL TGReactionsChatIsForum(TGClient *client, int64_t chatId) {
	id value = client.chatsById[@(chatId)][@"isForum"];
	return [value isKindOfClass:NSNumber.class] && [value boolValue];
}

static NSString *const TGReactionPlaceholder = @"\U00002B50";
static NSString *const TGQuickReactionDefaultsKey = @"TGQuickReactionEmoji";
static NSString *TGQuickReaction = nil;

static NSDictionary *TGReactionTypeEmoji(NSString *emoji) {
	return @{@"@type" : @"reactionTypeEmoji", @"emoji" : emoji ?: @""};
}

static NSDictionary *TGReactionSender(int64_t senderId) {
	if (senderId < 0)
		return @{@"@type" : @"messageSenderChat",
			@"chat_id" : @(senderId)};
	return @{@"@type" : @"messageSenderUser",
		@"user_id" : @(senderId)};
}

NSString *const TGReactionCustomEmojiResolvedNotification =
	@"TGReactionCustomEmojiResolvedNotification";

static NSString *const TGReactionPaidGlyph = @"\U00002B50";

static NSMutableDictionary *TGReactionCustomEmojiCache = nil;
static NSMutableDictionary *TGReactionCustomEmojiIconCache = nil;
static NSMutableDictionary *TGReactionCustomEmojiIconCallbacks = nil;
static NSMutableSet *TGReactionCustomEmojiPending = nil;

static NSString *TGReactionCustomEmojiKey(NSDictionary *type) {
	id raw = type[@"custom_emoji_id"];
	if ([raw isKindOfClass:NSString.class])
		return [raw length] ? raw : nil;
	if ([raw isKindOfClass:NSNumber.class])
		return [NSString stringWithFormat:@"%lld", [raw longLongValue]];
	return nil;
}

static void TGReactionResolveCustomEmojiIcon(NSString *key, void (^completion)(NSDictionary *icon)) {
	if (!key.length) {
		if (completion)
			completion(nil);
		return;
	}
	NSDictionary *known = TGReactionCustomEmojiIconCache[key];
	if (known) {
		if (completion)
			completion(known);
		return;
	}
	if (completion) {
		if (!TGReactionCustomEmojiIconCallbacks)
			TGReactionCustomEmojiIconCallbacks = [NSMutableDictionary dictionary];
		NSMutableArray *waiters = TGReactionCustomEmojiIconCallbacks[key];
		if (!waiters) {
			waiters = [NSMutableArray array];
			TGReactionCustomEmojiIconCallbacks[key] = waiters;
		}
		[waiters addObject:[completion copy]];
	}

	if (!TGReactionCustomEmojiPending)
		TGReactionCustomEmojiPending = [NSMutableSet set];
	if ([TGReactionCustomEmojiPending containsObject:key])
		return;
	[TGReactionCustomEmojiPending addObject:key];

	[[TGClient shared] customEmojiIconsForIds:@[ key ] completion:^(NSDictionary *icons) {
		NSDictionary *resolved = [icons isKindOfClass:NSDictionary.class] ? icons[key] : nil;
		BOOL learned = NO;
		if ([resolved isKindOfClass:NSDictionary.class]) {
			NSString *emoji = resolved[@"emoji"];
			if ([emoji isKindOfClass:NSString.class] && emoji.length) {
				if (!TGReactionCustomEmojiCache)
					TGReactionCustomEmojiCache = [NSMutableDictionary dictionary];
				TGReactionCustomEmojiCache[key] = emoji;
				learned = YES;
			}
			if (!TGReactionCustomEmojiIconCache)
				TGReactionCustomEmojiIconCache = [NSMutableDictionary dictionary];
			TGReactionCustomEmojiIconCache[key] = resolved;
		}
		[TGReactionCustomEmojiPending removeObject:key];
		NSArray *waiters = TGReactionCustomEmojiIconCallbacks[key];
		[TGReactionCustomEmojiIconCallbacks removeObjectForKey:key];
		for (void (^waiter)(NSDictionary *) in waiters)
			waiter(resolved);
		if (learned)
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGReactionCustomEmojiResolvedNotification
							  object:nil];
	}];
}

static void TGReactionResolveCustomEmoji(NSString *key) {
	TGReactionResolveCustomEmojiIcon(key, nil);
}

static NSString *TGReactionEmoji(NSDictionary *type) {
	if (![type isKindOfClass:NSDictionary.class])
		return TGReactionPlaceholder;

	NSString *kind = type[@"@type"];

	if ([kind isEqualToString:@"reactionTypePaid"])
		return TGReactionPaidGlyph;

	NSString *emoji = type[@"emoji"];
	if ([emoji isKindOfClass:NSString.class] && emoji.length)
		return emoji;

	if ([kind isEqualToString:@"reactionTypeCustomEmoji"]) {
		NSString *key = TGReactionCustomEmojiKey(type);
		NSString *known = key ? TGReactionCustomEmojiCache[key] : nil;
		if (known.length)
			return known;
		TGReactionResolveCustomEmoji(key);
	}
	return TGReactionPlaceholder;
}

static BOOL TGReactionIsCustom(NSDictionary *type) {
	if (![type isKindOfClass:NSDictionary.class])
		return NO;
	NSString *t = type[@"@type"];
	return [t isEqualToString:@"reactionTypeCustomEmoji"] ||
		[t isEqualToString:@"reactionTypePaid"];
}

static void TGAppendReactionEmoji(NSArray *list, NSMutableArray *out, NSMutableSet *premiumOut) {
	if (![list isKindOfClass:NSArray.class])
		return;
	for (NSDictionary *r in list) {
		if (![r isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *type = r[@"type"];
		if (TGReactionIsCustom(type))
			continue;
		NSString *emoji = TGReactionEmoji(type);
		if (emoji.length && ![emoji isEqualToString:TGReactionPlaceholder]) {
			[out addObject:emoji];
			if ([r[@"needs_premium"] boolValue] && premiumOut)
				[premiumOut addObject:emoji];
		}
	}
}

static NSMutableDictionary *TGReactionIconPaths = nil;
static NSMutableDictionary *TGReactionWatches = nil;
static NSTimer *TGReactionWatchTimer = nil;
static NSTimeInterval TGReactionWatchInterval = 5.0;

static NSString *TGReactionWatchKey(int64_t chatId, int64_t messageId) {
	return [NSString stringWithFormat:@"%lld:%lld", chatId, messageId];
}

static NSMutableSet *TGReactionsInFlight = nil;
static NSTimeInterval TGReactionInFlightTimeout = 5.0;

static NSString *TGReactionInFlightKey(int64_t chatId, int64_t messageId, NSString *emoji) {
	return [NSString stringWithFormat:@"%lld:%lld:%@", chatId, messageId, emoji ?: @""];
}

static NSString *TGReactionSenderName(TGClient *client, int64_t senderId) {
	if (!client || senderId == 0)
		return @"";
	if (senderId > 0)
		return [client nameForUserId:senderId] ?: @"";
	for (NSDictionary *c in client.chats) {
		if ([c[@"id"] longLongValue] == senderId)
			return c[@"title"] ?: @"";
	}
	for (NSDictionary *c in client.archivedChats) {
		if ([c[@"id"] longLongValue] == senderId)
			return c[@"title"] ?: @"";
	}
	return @"";
}

@implementation TGClient (Reactions)

#pragma mark - sending

- (void)addReaction:(NSString *)emoji
		  toMessage:(int64_t)messageId
			 inChat:(int64_t)chatId
				big:(BOOL)big
		 completion:(void (^)(BOOL ok))completion {
	if (!emoji.length) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"addMessageReaction",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"reaction_type" : TGReactionTypeEmoji(emoji),
		@"is_big" : @(big),
		@"update_recent_reactions" : @YES,
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)removeReaction:(NSString *)emoji
		   fromMessage:(int64_t)messageId
				inChat:(int64_t)chatId
			completion:(void (^)(BOOL ok))completion {
	if (!emoji.length) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"removeMessageReaction",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"reaction_type" : TGReactionTypeEmoji(emoji),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (BOOL)isReactionInFlightForMessage:(int64_t)messageId
							   inChat:(int64_t)chatId
								emoji:(NSString *)emoji {
	if (!TGReactionsInFlight)
		return NO;
	return [TGReactionsInFlight containsObject:TGReactionInFlightKey(chatId, messageId, emoji)];
}

- (void)toggleReaction:(NSString *)emoji
			 onMessage:(int64_t)messageId
				inChat:(int64_t)chatId
				   big:(BOOL)big
			completion:(void (^)(BOOL nowChosen, BOOL succeeded))completion {
	if (!emoji.length) {
		if (completion)
			completion(NO, NO);
		return;
	}

	if (!TGReactionsInFlight)
		TGReactionsInFlight = [NSMutableSet set];
	NSString *inFlightKey = TGReactionInFlightKey(chatId, messageId, emoji);
	[TGReactionsInFlight addObject:inFlightKey];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(TGReactionInFlightTimeout * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			[TGReactionsInFlight removeObject:inFlightKey];
		});

	__weak typeof(self) weakSelf = self;
	[self reactionChipsForMessage:messageId inChat:chatId
					   completion:^(NSArray *chips) {
						   TGClient *strongSelf = weakSelf;
						   if (!strongSelf) {
							   [TGReactionsInFlight removeObject:inFlightKey];
							   if (completion)
								   completion(NO, NO);
							   return;
						   }
						   BOOL chosen = NO;
						   NSMutableArray *otherChosen = [NSMutableArray array];
						   for (NSDictionary *chip in chips) {
							   if (![chip[@"chosen"] boolValue])
								   continue;
							   NSString *chipEmoji = chip[@"emoji"];
							   if (![chipEmoji isKindOfClass:NSString.class] || !chipEmoji.length)
								   continue;
							   if ([chipEmoji isEqualToString:emoji])
								   chosen = YES;
							   else
								   [otherChosen addObject:chipEmoji];
						   }
						   void (^afterToggle)(BOOL) = ^(BOOL ok) {
							   [TGReactionsInFlight removeObject:inFlightKey];
							   if (completion)
								   completion(ok ? !chosen : chosen, ok);
						   };
						   if (chosen) {
							   [strongSelf removeReaction:emoji fromMessage:messageId inChat:chatId completion:afterToggle];
							   return;
						   }
						   NSInteger quota = TGReactionUserQuota([strongSelf isPremiumAccount]);
						   if (quota > 0 && otherChosen.count >= (NSUInteger)quota) {
							   NSString *toReplace = otherChosen.firstObject;
							   [strongSelf removeReaction:toReplace fromMessage:messageId inChat:chatId
												completion:^(BOOL __unused removeOk) {
													[strongSelf addReaction:emoji toMessage:messageId inChat:chatId big:big completion:afterToggle];
												}];
							   return;
						   }
						   [strongSelf addReaction:emoji toMessage:messageId inChat:chatId big:big completion:afterToggle];
					   }];
}

- (void)setReactions:(NSArray *)emojis
		   onMessage:(int64_t)messageId
			  inChat:(int64_t)chatId
				 big:(BOOL)big {
	NSMutableArray *types = [NSMutableArray array];
	for (NSString *emoji in emojis) {
		if ([emoji isKindOfClass:NSString.class] && emoji.length)
			[types addObject:TGReactionTypeEmoji(emoji)];
	}
	[self send:@{
		@"@type" : @"setMessageReactions",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"reaction_types" : types,
		@"is_big" : @(big),
	}];
}

- (NSString *)quickReactionEmoji {
	if (!TGQuickReaction.length) {
		NSString *stored = [[NSUserDefaults standardUserDefaults]
			stringForKey:[TGAccountManager defaultsKey:TGQuickReactionDefaultsKey]];
		if (stored.length)
			TGQuickReaction = [stored copy];
	}
	return TGQuickReaction.length ? TGQuickReaction : @"\U0001F44D";
}

- (void)setQuickReactionEmoji:(NSString *)emoji {
	[self setQuickReactionEmoji:emoji completion:nil];
}

- (void)setQuickReactionEmoji:(NSString *)emoji completion:(void (^)(BOOL ok))completion {
	if (!emoji.length) {
		if (completion)
			completion(NO);
		return;
	}
	NSString *previous = TGQuickReaction;
	TGQuickReaction = [emoji copy];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *defaultsKey = [TGAccountManager defaultsKey:TGQuickReactionDefaultsKey];
	[defaults setObject:TGQuickReaction forKey:defaultsKey];
	[defaults synchronize];
	[self request:@{
		@"@type" : @"setDefaultReactionType",
		@"reaction_type" : TGReactionTypeEmoji(emoji),
	}
		completion:^(NSDictionary *result) {
			BOOL ok = !TGResultIsError(result);
			if (!ok) {
				TGQuickReaction = previous;
				[defaults setObject:TGQuickReaction forKey:defaultsKey];
				[defaults synchronize];
			}
			if (completion)
				completion(ok);
		}];
}

- (void)applyServerDefaultReactionType:(NSDictionary *)reactionType {
	NSString *emoji = TGReactionEmoji(reactionType);
	if (!emoji.length || [emoji isEqualToString:TGReactionPlaceholder])
		return;
	if ([emoji isEqualToString:TGQuickReaction])
		return;
	TGQuickReaction = [emoji copy];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:TGQuickReaction forKey:[TGAccountManager defaultsKey:TGQuickReactionDefaultsKey]];
	[defaults synchronize];
}

- (void)clearRecentReactions {
	[self send:@{@"@type" : @"clearRecentReactions"}];
}

#pragma mark - reading

+ (NSArray *)reactionChipsFromInteractionInfo:(NSDictionary *)info chatId:(int64_t)chatId {
	if (![info isKindOfClass:NSDictionary.class])
		return @[];
	NSDictionary *box = info[@"reactions"];
	if (![box isKindOfClass:NSDictionary.class])
		return @[];
	NSArray *reactions = box[@"reactions"];
	if (![reactions isKindOfClass:NSArray.class])
		return @[];

	BOOL canGetAddedReactions = [box[@"can_get_added_reactions"] boolValue];
	BOOL useSavedTagLabels = TGChatIsSavedMessages(chatId, [[TGClient shared] savedMessagesChatId]);

	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *r in reactions) {
		if (![r isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *type = r[@"type"];
		NSNumber *count = [r[@"total_count"] isKindOfClass:NSNumber.class]
			? r[@"total_count"]
			: @(0);
		NSString *customId = [type[@"@type"] isEqualToString:@"reactionTypeCustomEmoji"]
			? TGReactionCustomEmojiKey(type)
			: nil;
		NSMutableDictionary *chip = [NSMutableDictionary dictionaryWithDictionary:@{
			@"emoji" : TGReactionEmoji(type),
			@"count" : count,
			@"chosen" : @([r[@"is_chosen"] boolValue]),
			@"custom" : @(TGReactionIsCustom(type)),
			@"paid" : @([type[@"@type"] isEqualToString:@"reactionTypePaid"]),
			@"customEmojiId" : customId ?: @"",
			@"canGetAddedReactions" : @(canGetAddedReactions),
		}];
		if (useSavedTagLabels) {
			NSString *plainEmoji = [type[@"emoji"] isKindOfClass:NSString.class] ? type[@"emoji"] : nil;
			NSString *label = [[TGClient shared] cachedSavedMessagesTagLabelForEmoji:plainEmoji
																	  customEmojiId:[customId longLongValue]];
			if (label.length)
				chip[@"label"] = label;
		}
		[out addObject:chip];
	}
	return out;
}

+ (NSArray *)reactionChipsFromMessage:(NSDictionary *)message chatId:(int64_t)chatId {
	if (![message isKindOfClass:NSDictionary.class])
		return @[];

	id ready = message[@"reactionChips"];
	if ([ready isKindOfClass:NSArray.class])
		return ready;

	return [self reactionChipsFromInteractionInfo:message[@"interaction_info"] chatId:chatId];
}

+ (NSArray *)resolvedChips:(NSArray *)chips {
	if (![chips isKindOfClass:NSArray.class] || !chips.count)
		return chips;

	NSMutableArray *out = nil;
	for (NSInteger i = 0; i < chips.count; i++) {
		NSDictionary *chip = chips[i];
		if (![chip isKindOfClass:NSDictionary.class])
			continue;
		NSString *key = chip[@"customEmojiId"];
		if (![key isKindOfClass:NSString.class] || !key.length)
			continue;
		NSString *known = TGReactionCustomEmojiCache[key];
		if (!known.length || [known isEqualToString:chip[@"emoji"]])
			continue;
		if (!out)
			out = [chips mutableCopy];
		NSMutableDictionary *fixed = [chip mutableCopy];
		fixed[@"emoji"] = known;
		out[i] = fixed;
	}
	return out ?: chips;
}

+ (NSString *)reactionSummaryFromChips:(NSArray *)chips {
	if (![chips isKindOfClass:NSArray.class] || !chips.count)
		return @"";
	NSMutableArray *parts = [NSMutableArray array];
	for (NSDictionary *chip in chips) {
		if (![chip isKindOfClass:NSDictionary.class])
			continue;
		[parts addObject:[NSString stringWithFormat:@"%@ %ld",
							 chip[@"emoji"] ?: TGReactionPlaceholder,
							 (long)[chip[@"count"] integerValue]]];
	}
	return [parts componentsJoinedByString:@"  "];
}

- (void)reactionChipsForMessage:(int64_t)messageId
						 inChat:(int64_t)chatId
					 completion:(void (^)(NSArray *chips))completion {
	[self request:@{
		@"@type" : @"getMessage",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(@[]);
			return;
		}
		completion([TGClient reactionChipsFromMessage:result chatId:chatId]);
	}];
}

- (void)availableReactionsForMessage:(int64_t)messageId
							  inChat:(int64_t)chatId
						  completion:(void (^)(NSDictionary *info))completion {
	[self request:@{
		@"@type" : @"getMessageAvailableReactions",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"row_size" : @(7),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSMutableArray *top = [NSMutableArray array];
		NSMutableArray *recent = [NSMutableArray array];
		NSMutableArray *popular = [NSMutableArray array];
		NSMutableSet *needsPremium = [NSMutableSet set];
		TGAppendReactionEmoji(result[@"top_reactions"], top, needsPremium);
		TGAppendReactionEmoji(result[@"recent_reactions"], recent, needsPremium);
		TGAppendReactionEmoji(result[@"popular_reactions"], popular, needsPremium);

		NSMutableArray *all = [NSMutableArray array];
		for (NSArray *list in [NSArray arrayWithObjects:top, recent, popular, nil]) {
			for (NSString *emoji in list) {
				if (![all containsObject:emoji])
					[all addObject:emoji];
			}
		}
		completion(@{
			@"top" : top,
			@"recent" : recent,
			@"popular" : popular,
			@"allEmoji" : all,
			@"needsPremiumEmoji" : needsPremium.allObjects,
			@"reason" : TGReactionUnavailability(result[@"unavailability_reason"]),
		});
	}];
}

- (void)addedReactionsForMessage:(int64_t)messageId
						  inChat:(int64_t)chatId
						   emoji:(NSString *)emoji
						  offset:(NSString *)offset
						   limit:(NSInteger)limit
					  completion:(void (^)(NSArray *reactors,
									 NSString *nextOffset,
									 NSInteger totalCount))completion {
	NSMutableDictionary *req = [NSMutableDictionary dictionaryWithDictionary:@{
		@"@type" : @"getMessageAddedReactions",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"offset" : offset.length ? offset : @"",
		@"limit" : @(limit > 0 ? limit : 50),
	}];
	if (emoji.length)
		[req setObject:TGReactionTypeEmoji(emoji) forKey:@"reaction_type"];

	__weak typeof(self) weakSelf = self;
	[self request:req completion:^(NSDictionary *result) {
		if (!completion)
			return;
		TGClient *strongSelf = weakSelf;
		if (!strongSelf || TGResultIsError(result)) {
			completion(@[], @"", 0);
			return;
		}
		NSArray *added = result[@"reactions"];
		NSMutableArray *out = [NSMutableArray array];
		if ([added isKindOfClass:NSArray.class]) {
			for (NSDictionary *r in added) {
				if (![r isKindOfClass:NSDictionary.class])
					continue;
				int64_t senderId = TGReactionSenderId(r[@"sender_id"]);
				NSDictionary *type = [r[@"type"] isKindOfClass:NSDictionary.class] ? r[@"type"] : nil;
				NSString *customId = [type[@"@type"] isEqualToString:@"reactionTypeCustomEmoji"]
					? TGReactionCustomEmojiKey(type)
					: nil;
				[out addObject:@{
					@"senderId" : @(senderId),
					@"name" : TGReactionSenderName(strongSelf, senderId),
					@"emoji" : TGReactionEmoji(r[@"type"]),
					@"customEmojiId" : customId ?: @"",
					@"date" : r[@"date"] ?: @(0),
				}];
			}
		}
		NSString *next = result[@"next_offset"];
		if (![next isKindOfClass:NSString.class])
			next = @"";
		completion(out, next, [result[@"total_count"] integerValue]);
	}];
}

- (void)emojiReactionInfo:(NSString *)emoji
			   completion:(void (^)(NSDictionary *info))completion {
	if (!emoji.length) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{@"@type" : @"getEmojiReaction", @"emoji" : emoji}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			NSDictionary *icon = result[@"static_icon"];
			NSNumber *fileId = nil;
			if ([icon isKindOfClass:NSDictionary.class]) {
				NSDictionary *file = icon[@"sticker"];
				if ([file isKindOfClass:NSDictionary.class] &&
					[file[@"id"] isKindOfClass:NSNumber.class])
					fileId = file[@"id"];
			}
			completion(@{
				@"emoji" : result[@"emoji"] ?: emoji,
				@"title" : result[@"title"] ?: @"",
				@"isActive" : @([result[@"is_active"] boolValue]),
				@"iconFileId" : fileId ?: [NSNull null],
			});
		}];
}

+ (NSArray *)paidReactorsFromMessage:(NSDictionary *)message {
	if (![message isKindOfClass:NSDictionary.class])
		return @[];
	NSDictionary *info = message[@"interaction_info"];
	if (![info isKindOfClass:NSDictionary.class])
		return @[];
	NSDictionary *box = info[@"reactions"];
	if (![box isKindOfClass:NSDictionary.class])
		return @[];
	NSArray *reactors = box[@"paid_reactors"];
	if (![reactors isKindOfClass:NSArray.class])
		return @[];

	TGClient *client = [TGClient shared];
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *r in reactors) {
		if (![r isKindOfClass:NSDictionary.class])
			continue;
		int64_t senderId = TGReactionSenderId(r[@"sender_id"]);
		BOOL anonymous = [r[@"is_anonymous"] boolValue];
		[out addObject:@{
			@"senderId" : @(anonymous ? 0 : senderId),
			@"name" : anonymous ? @"Anonymous"
								: TGReactionSenderName(client, senderId),
			@"stars" : r[@"star_count"] ?: @(0),
			@"isTop" : @([r[@"is_top"] boolValue]),
			@"isAnonymous" : @(anonymous),
		}];
	}
	return out;
}

- (void)paidReactorsForMessage:(int64_t)messageId
						inChat:(int64_t)chatId
					completion:(void (^)(NSArray *reactors))completion {
	if (!completion)
		return;
	[self request:@{@"@type" : @"getMessage",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId)}
		completion:^(NSDictionary *result) {
			if (TGResultIsError(result)) {
				completion(@[]);
				return;
			}
			completion([TGClient paidReactorsFromMessage:result]);
		}];
}

- (void)reactionUsageForMessage:(int64_t)messageId
						 inChat:(int64_t)chatId
					 completion:(void (^)(NSArray *chosenEmoji,
									NSArray *existingReactionTypes,
									NSInteger usedCount,
									NSInteger maxCount,
									BOOL canAddMore))completion {
	if (!completion)
		return;
	__weak typeof(self) weakSelf = self;
	[self reactionChipsForMessage:messageId inChat:chatId completion:^(NSArray *chips) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf) {
			completion(@[], @[], 0, 1, YES);
			return;
		}
		NSMutableArray *chosen = [NSMutableArray array];
		NSMutableArray *existingTypes = [NSMutableArray array];
		for (NSDictionary *chip in chips) {
			if (![chip isKindOfClass:NSDictionary.class])
				continue;
			NSString *emoji = chip[@"emoji"];
			if (![emoji isKindOfClass:NSString.class] || !emoji.length)
				continue;
			[existingTypes addObject:emoji];
			if ([chip[@"chosen"] boolValue])
				[chosen addObject:emoji];
		}
		NSInteger totalDistinctOnMessage = (NSInteger)chips.count;
		BOOL premium = [strongSelf isPremiumAccount];
		[strongSelf availableReactionsInChat:chatId
						  completion:^(NSArray *emojis, BOOL allowsAll, NSInteger maxCount,
										 BOOL __unused hasAnyReactionsAllowed) {
							  NSInteger max = maxCount > 0 ? maxCount : 1;
							  NSInteger used = (NSInteger)chosen.count;
							  BOOL room = TGReactionHasRoomForMore(used, totalDistinctOnMessage, max, premium);
							  completion(chosen, existingTypes, used, max, room);
						  }];
	}];
}

- (void)reactionIconPathForEmoji:(NSString *)emoji
					  completion:(void (^)(NSString *path))completion {
	if (!completion)
		return;
	if (!emoji.length) {
		completion(nil);
		return;
	}
	if (!TGReactionIconPaths)
		TGReactionIconPaths = [[NSMutableDictionary alloc] init];
	NSString *cached = TGReactionIconPaths[emoji];
	if ([cached isKindOfClass:NSString.class] && cached.length) {
		completion(cached);
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self emojiReactionInfo:emoji completion:^(NSDictionary *info) {
		TGClient *strongSelf = weakSelf;
		NSNumber *fileId = nil;
		if ([info isKindOfClass:NSDictionary.class] &&
			[info[@"iconFileId"] isKindOfClass:NSNumber.class])
			fileId = info[@"iconFileId"];
		if (!strongSelf || !fileId) {
			completion(nil);
			return;
		}
		[strongSelf downloadFile:[fileId longLongValue] completion:^(NSString *path) {
			if ([path isKindOfClass:NSString.class] && path.length)
				[TGReactionIconPaths setObject:path forKey:emoji];
			completion([path isKindOfClass:NSString.class] && path.length ? path : nil);
		}];
	}];
}

- (void)reactionIconPathForCustomEmojiId:(NSString *)customEmojiId
							  completion:(void (^)(NSString *path))completion {
	if (!completion)
		return;
	if (!customEmojiId.length) {
		completion(nil);
		return;
	}
	__weak typeof(self) weakSelf = self;
	TGReactionResolveCustomEmojiIcon(customEmojiId, ^(NSDictionary *icon) {
		TGClient *strongSelf = weakSelf;
		NSNumber *fileId = nil;
		if ([icon isKindOfClass:NSDictionary.class]) {
			if ([icon[@"thumbFileId"] isKindOfClass:NSNumber.class])
				fileId = icon[@"thumbFileId"];
			else if ([icon[@"stickerFileId"] isKindOfClass:NSNumber.class])
				fileId = icon[@"stickerFileId"];
		}
		if (!strongSelf || !fileId) {
			completion(nil);
			return;
		}
		[strongSelf downloadFile:[fileId longLongValue] completion:completion];
	});
}

#pragma mark - live chip updates

- (void)watchReactionsForMessage:(int64_t)messageId
						  inChat:(int64_t)chatId
						onChange:(void (^)(NSArray *chips))onChange {
	if (!onChange)
		return;
	if (!TGReactionWatches)
		TGReactionWatches = [[NSMutableDictionary alloc] init];

	NSString *key = TGReactionWatchKey(chatId, messageId);
	NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
			@(chatId), @"chatId",
		@(messageId), @"messageId",
		[onChange copy], @"block",
		@"", @"signature", nil];
	[TGReactionWatches setObject:entry forKey:key];

	[self reactionChipsForMessage:messageId inChat:chatId completion:^(NSArray *chips) {
		NSMutableDictionary *live = [TGReactionWatches objectForKey:key];
		if ([live isKindOfClass:NSDictionary.class])
			[live setObject:TGReactionChipSignature(chips) forKey:@"signature"];
	}];

	[self tgStartReactionWatchTimer];
}

- (void)unwatchReactionsForMessage:(int64_t)messageId inChat:(int64_t)chatId {
	if (!TGReactionWatches)
		return;
	[TGReactionWatches removeObjectForKey:TGReactionWatchKey(chatId, messageId)];
	if (TGReactionWatches.count == 0)
		[self unwatchAllReactions];
}

- (void)unwatchAllReactions {
	[TGReactionWatches removeAllObjects];
	[TGReactionWatchTimer invalidate];
	TGReactionWatchTimer = nil;
}

- (void)resetReactionCachesForAccountSwitch {
	TGQuickReaction = nil;
	[TGReactionsInFlight removeAllObjects];
	[self unwatchAllReactions];
}

- (void)setReactionWatchInterval:(NSTimeInterval)seconds {
	TGReactionWatchInterval = seconds < 2.0 ? 2.0 : seconds;
}

- (void)tgStartReactionWatchTimer {
	if (TGReactionWatchTimer)
		return;
	TGReactionWatchTimer = [NSTimer scheduledTimerWithTimeInterval:TGReactionWatchInterval target:self selector:@selector(tgReactionWatchTick:) userInfo:nil repeats:YES];
}

- (void)tgReactionWatchTick:(NSTimer *)timer {
	if (TGReactionWatches.count == 0) {
		[self unwatchAllReactions];
		return;
	}
	for (NSString *key in [TGReactionWatches allKeys]) {
		NSMutableDictionary *entry = [TGReactionWatches objectForKey:key];
		if (![entry isKindOfClass:NSDictionary.class])
			continue;
		int64_t chatId = [entry[@"chatId"] longLongValue];
		int64_t messageId = [entry[@"messageId"] longLongValue];
		[self reactionChipsForMessage:messageId inChat:chatId completion:^(NSArray *chips) {
			NSMutableDictionary *live = [TGReactionWatches objectForKey:key];
			if (![live isKindOfClass:NSDictionary.class])
				return;
			NSString *signature = TGReactionChipSignature(chips);
			NSString *previous = live[@"signature"];
			if ([previous isKindOfClass:NSString.class] &&
				[previous isEqualToString:signature])
				return;
			[live setObject:signature forKey:@"signature"];
			void (^block)(NSArray *) = live[@"block"];
			if (block)
				block(chips);
		}];
	}
}

#pragma mark - unread reactions

- (void)unreadReactionsInChat:(int64_t)chatId
				fromMessageId:(int64_t)fromMessageId
						limit:(NSInteger)limit
				   completion:(void (^)(NSArray *messageIds))completion {
	[self unreadReactionsInChat:chatId
						 threadId:0
			  directMessagesTopic:0
					   savedTopic:0
					fromMessageId:fromMessageId
							limit:limit
					   completion:completion];
}

- (void)unreadReactionsInChat:(int64_t)chatId
					 threadId:(int64_t)threadId
		  directMessagesTopic:(int64_t)directMessagesTopicId
				   savedTopic:(int64_t)savedTopicId
				fromMessageId:(int64_t)fromMessageId
						limit:(NSInteger)limit
				   completion:(void (^)(NSArray *messageIds))completion {
	NSMutableDictionary *request = [@{
		@"@type" : @"searchChatMessages",
		@"chat_id" : @(chatId),
		@"query" : @"",
		@"from_message_id" : @(fromMessageId),
		@"offset" : @(0),
		@"limit" : @(limit > 0 ? limit : 50),
		@"filter" : @{@"@type" : @"searchMessagesFilterUnreadReaction"},
	} mutableCopy];
	NSDictionary *topic = TGTopicDictionary(threadId, directMessagesTopicId, savedTopicId,
		TGReactionsChatIsForum(self, chatId));
	if (topic)
		request[@"topic_id"] = topic;

	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (![result isKindOfClass:NSDictionary.class]) {
			completion(@[]);
			return;
		}
		NSArray *messages = result[@"messages"];
		if (![messages isKindOfClass:NSArray.class]) {
			completion(@[]);
			return;
		}
		NSMutableArray *ids = [NSMutableArray array];
		for (NSDictionary *m in messages) {
			if ([m isKindOfClass:NSDictionary.class] && m[@"id"])
				[ids addObject:m[@"id"]];
		}
		completion([[ids reverseObjectEnumerator] allObjects]);
	}];
}

- (void)markReactionsReadInChat:(int64_t)chatId {
	[self send:@{@"@type" : @"readAllChatReactions", @"chat_id" : @(chatId)}];
}

- (void)markReactionsReadInChat:(int64_t)chatId forumTopicId:(int64_t)topicId {
	if (topicId == 0) {
		[self markReactionsReadInChat:chatId];
		return;
	}
	[self send:@{
		@"@type" : @"readAllForumTopicReactions",
		@"chat_id" : @(chatId),
		@"forum_topic_id" : @(topicId),
	}];
}

#pragma mark - moderation

- (void)reactionPermissionsForMessage:(int64_t)messageId
							   inChat:(int64_t)chatId
						   completion:(void (^)(BOOL canDelete,
										  BOOL canReport))completion {
	[self request:@{
		@"@type" : @"getMessageProperties",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, NO);
			return;
		}
		completion([result[@"can_delete_reactions"] boolValue],
			[result[@"can_report_reactions"] boolValue]);
	}];
}

- (void)deleteReactionsFromSender:(int64_t)senderId
						onMessage:(int64_t)messageId
						   inChat:(int64_t)chatId {
	[self deleteReactionsFromSender:senderId onMessage:messageId inChat:chatId completion:nil];
}

- (void)deleteReactionsFromSender:(int64_t)senderId
						onMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
					   completion:(void (^)(BOOL ok))completion {
	if (senderId == 0) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"deleteMessageReactionsFromSender",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"sender_id" : TGReactionSender(senderId),
	}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)deleteAllRecentReactionsFromSender:(int64_t)senderId
									inChat:(int64_t)chatId {
	[self deleteAllRecentReactionsFromSender:senderId inChat:chatId completion:nil];
}

- (void)deleteAllRecentReactionsFromSender:(int64_t)senderId
									inChat:(int64_t)chatId
								 completion:(void (^)(BOOL ok))completion {
	if (senderId == 0) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"deleteAllRecentMessageReactionsFromSender",
		@"chat_id" : @(chatId),
		@"sender_id" : TGReactionSender(senderId),
	}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)reportReactionsFromSender:(int64_t)senderId
						onMessage:(int64_t)messageId
						   inChat:(int64_t)chatId {
	[self reportReactionsFromSender:senderId onMessage:messageId inChat:chatId completion:nil];
}

- (void)reportReactionsFromSender:(int64_t)senderId
						onMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
					   completion:(void (^)(BOOL ok))completion {
	if (senderId == 0) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"reportMessageReactions",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"sender_id" : TGReactionSender(senderId),
	}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

#pragma mark - chat settings

- (void)availableReactionsInChat:(int64_t)chatId
					  completion:(void (^)(NSArray *emojis,
									 BOOL allowsAll,
									 NSInteger maxCount,
									 BOOL hasAnyReactionsAllowed))completion {
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			if (!completion)
				return;
			if (![chat isKindOfClass:NSDictionary.class]) {
				completion(@[], NO, 1, NO);
				return;
			}
			NSDictionary *available = chat[@"available_reactions"];
			if (![available isKindOfClass:NSDictionary.class]) {
				completion(@[], NO, 1, NO);
				return;
			}
			NSInteger maxCount = [available[@"max_reaction_count"] integerValue];
			if (maxCount < 1)
				maxCount = 1;
			if ([available[@"@type"] isEqualToString:@"chatAvailableReactionsAll"]) {
				completion(@[], YES, maxCount, YES);
				return;
			}
			NSMutableArray *emojis = [NSMutableArray array];
			NSArray *types = available[@"reactions"];
			BOOL hasAnyReactionsAllowed = NO;
			if ([types isKindOfClass:NSArray.class]) {
				hasAnyReactionsAllowed = types.count > 0;
				for (NSDictionary *type in types) {
					if (TGReactionIsCustom(type))
						continue;
					NSString *emoji = TGReactionEmoji(type);
					if (emoji.length && ![emoji isEqualToString:TGReactionPlaceholder])
						[emojis addObject:emoji];
				}
			}
			completion(emojis, NO, maxCount, hasAnyReactionsAllowed);
		}];
}

- (void)setAvailableReactionsInChat:(int64_t)chatId
							 emojis:(NSArray *)emojis
						   maxCount:(NSInteger)maxCount {
	if (maxCount < 1)
		maxCount = 1;
	NSDictionary *available = nil;
	if (!emojis) {
		available = @{
			@"@type" : @"chatAvailableReactionsAll",
			@"max_reaction_count" : @(maxCount),
		};
	} else {
		NSMutableArray *types = [NSMutableArray array];
		for (NSString *emoji in emojis) {
			if ([emoji isKindOfClass:NSString.class] && emoji.length)
				[types addObject:TGReactionTypeEmoji(emoji)];
		}
		available = @{
			@"@type" : @"chatAvailableReactionsSome",
			@"reactions" : types,
			@"max_reaction_count" : @(maxCount),
		};
	}
	[self send:@{
		@"@type" : @"setChatAvailableReactions",
		@"chat_id" : @(chatId),
		@"available_reactions" : available,
	}];
}

#pragma mark - message effects

- (void)messageEffect:(int64_t)effectId completion:(void (^)(NSDictionary *))completion {
	if (!effectId) {
		if (completion)
			completion(nil);
		return;
	}
	if (!self.effectCache)
		self.effectCache = [NSMutableDictionary dictionary];
	NSDictionary *cached = self.effectCache[@(effectId)];
	if (cached) {
		if (completion)
			completion(cached);
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getMessageEffect", @"effect_id" : @(effectId)}
		completion:^(NSDictionary *result) {
			if (TGResultIsError(result)) {
				if (completion)
					completion(nil);
				return;
			}
			NSDictionary *typeInfo = [result[@"type"] isKindOfClass:NSDictionary.class] ? result[@"type"] : nil;
			NSString *typeName = [typeInfo[@"@type"] isKindOfClass:NSString.class] ? typeInfo[@"@type"] : @"";
			NSString *emoji = [result[@"emoji"] isKindOfClass:NSString.class] ? result[@"emoji"] : @"";
			if (!emoji.length && [typeName isEqualToString:@"messageEffectTypePremiumSticker"]) {
				NSDictionary *sticker = [typeInfo[@"sticker"] isKindOfClass:NSDictionary.class] ? typeInfo[@"sticker"] : nil;
				NSString *stickerEmoji = [sticker[@"emoji"] isKindOfClass:NSString.class] ? sticker[@"emoji"] : @"";
				emoji = stickerEmoji.length ? stickerEmoji : @"✨";
			}
			NSDictionary *effect = @{
				@"id" : @(effectId),
				@"emoji" : emoji,
				@"isPremium" : result[@"is_premium"] ?: @NO,
			};
			typeof(self) strongSelf = weakSelf;
			if (strongSelf)
				strongSelf.effectCache[@(effectId)] = effect;
			if (completion)
				completion(effect);
		}];
}

- (void)availableMessageEffectsWithCompletion:(void (^)(NSArray *))completion {
	NSMutableArray *ids = [NSMutableArray array];
	[ids addObjectsFromArray:self.availableEffectReactionIds ?: @[]];
	[ids addObjectsFromArray:self.availableEffectStickerIds ?: @[]];
	if (!ids.count) {
		if (completion)
			completion(@[]);
		return;
	}
	NSMutableArray *results = [NSMutableArray arrayWithCapacity:ids.count];
	for (NSInteger i = 0; i < ids.count; i++)
		[results addObject:[NSNull null]];
	__block NSInteger remaining = (NSInteger)ids.count;
	for (NSInteger i = 0; i < ids.count; i++) {
		NSNumber *effectId = ids[i];
		NSInteger index = i;
		[self messageEffect:[effectId longLongValue] completion:^(NSDictionary *effect) {
			if (effect)
				results[index] = effect;
			remaining--;
			if (remaining <= 0 && completion) {
				NSMutableArray *cleaned = [NSMutableArray arrayWithCapacity:results.count];
				for (id item in results)
					if ([item isKindOfClass:NSDictionary.class])
						[cleaned addObject:item];
				completion(cleaned);
			}
		}];
	}
}

@end

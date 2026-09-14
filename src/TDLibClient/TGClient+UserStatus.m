#import "TGClient+ChatState.h"
#import "TGClient+Private.h"
#import "TGClient+UserStatus.h"
#import "TGFlattenUserStatus.h"
#import "TGLocalization.h"

static NSDictionary *TGUSDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSArray *TGUSArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : nil;
}

static NSString *TGUSString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static long long TGUSInt64(id value) {
	if ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class])
		return [value longLongValue];
	return 0;
}

static NSString *TGUSErrorText(NSDictionary *result, NSString *fallback) {
	NSString *message = TGResultIsError(result) ? TGUSString(result[@"message"]) : nil;
	return message.length ? message : fallback;
}

@implementation TGClient (UserStatus)

#pragma mark - chat lifecycle

- (void)openChat:(int64_t)chatId {
	self.openChatId = chatId;
	[self send:@{@"@type" : @"openChat", @"chat_id" : @(chatId)}];
}

- (void)closeChat:(int64_t)chatId {
	if (self.openChatId == chatId)
		self.openChatId = 0;
	[self send:@{@"@type" : @"closeChat", @"chat_id" : @(chatId)}];
}

#pragma mark - last seen

+ (NSDictionary *)statusInfoForUserStatus:(NSDictionary *)status {
	NSDictionary *s = TGUSDict(status);
	NSString *type = TGUSString(s[@"@type"]);
	BOOL hidden = [s[@"by_my_privacy_settings"] boolValue];
	long long was = TGUSInt64(s[@"was_online"]);
	return TGUSStatusInfoForType(type, was, hidden);
}

- (void)statusInfoForUser:(int64_t)userId
			   completion:(void (^)(NSDictionary *))completion {
	if (!completion)
		return;
	[self request:@{@"@type" : @"getUser", @"user_id" : @(userId)}
		completion:^(NSDictionary *user) {
			NSDictionary *info;
			if (TGResultIsError(user))
				info = [TGClient statusInfoForUserStatus:nil];
			else
				info = [TGClient statusInfoForUserStatus:TGUSDict(user[@"status"])];

			NSMutableDictionary *out = [NSMutableDictionary dictionaryWithDictionary:info];
			out[@"userId"] = @(userId);
			completion(out);
		}];
}

+ (NSString *)hiddenStatusHintForStatusInfo:(NSDictionary *)info {
	NSDictionary *i = TGUSDict(info);
	if (![i[@"isApproximate"] boolValue])
		return nil;
	if ([i[@"hiddenByMyPrivacy"] boolValue])
		return TGL(@"Profile.LastSeenHiddenByYourPrivacy",
			@"You cannot see the exact last seen time because you hide yours. Allow others to see your Last Seen in Privacy settings to see theirs."
			 "Allow others to see your Last Seen in Privacy settings to see theirs.");
	return TGL(@"Profile.LastSeenHiddenByTheirPrivacy",
		@"This user hides the exact time they were last online.");
}

- (void)setSelfOnline:(BOOL)online {
	[self send:@{
		@"@type" : @"setOption",
		@"name" : @"online",
		@"value" : @{@"@type" : @"optionValueBoolean", @"value" : @(online)},
	}];
}

static const NSUInteger kUSOnlineProbeLimit = 20;
static const NSTimeInterval kUSOnlineCacheTtl = 60.0;

static NSMutableDictionary *TGUSOnlineCache(void) {
	static NSMutableDictionary *cache = nil;
	if (!cache)
		cache = [[NSMutableDictionary alloc] init];
	return cache;
}

- (void)countOnlineAmong:(NSArray *)userIds
				   index:(NSUInteger)index
				 running:(NSInteger)running
			  completion:(void (^)(NSInteger online))completion {
	if (index >= userIds.count || index >= kUSOnlineProbeLimit) {
		completion(running);
		return;
	}
	int64_t userId = TGUSInt64(userIds[index]);
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getUser", @"user_id" : @(userId)}
		completion:^(NSDictionary *user) {
			NSInteger next = running;
			if (!TGResultIsError(user)) {
				NSDictionary *info = [TGClient statusInfoForUserStatus:TGUSDict(user[@"status"])];
				if ([info[@"isOnline"] boolValue])
					next++;
			}
			[weakSelf countOnlineAmong:userIds index:index + 1 running:next completion:completion];
		}];
}

- (void)groupOnlineSummaryForChat:(int64_t)chatId
					   completion:(void (^)(NSString *, NSInteger, NSInteger))completion {
	if (!completion)
		return;
	__weak typeof(self) weakSelf = self;

	NSDictionary *cached = TGUSDict(TGUSOnlineCache()[@(chatId)]);
	if (cached &&
		[[NSDate date] timeIntervalSinceReferenceDate] -
				[cached[@"at"] doubleValue] <
			kUSOnlineCacheTtl) {
		completion(TGUSString(cached[@"text"]),
			[cached[@"members"] integerValue],
			[cached[@"online"] integerValue]);
		return;
	}

	void (^answer)(NSInteger, NSArray *) = ^(NSInteger members, NSArray *memberIds) {
		[weakSelf countOnlineAmong:(memberIds ?: @[])
							 index:0
						   running:0
						completion:^(NSInteger online) {
							NSString *membersText = TGLPlural(@"Conversation.StatusMembers",
								members, @"1 member", @"%d members");
							NSString *onlineText = TGLPlural(@"Conversation.StatusOnline",
								online, @"1 online", @"%d online");
							NSString *text = online > 0
								? [NSString stringWithFormat:@"%@, %@", membersText, onlineText]
								: membersText;
							TGUSOnlineCache()[@(chatId)] = @{
								@"text" : text,
								@"members" : @(members),
								@"online" : @(online),
								@"at" : @([[NSDate date] timeIntervalSinceReferenceDate]),
							};
							completion(text, members, online);
						}];
	};

	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			if (TGResultIsError(chat)) {
				completion(@"", 0, 0);
				return;
			}
			NSDictionary *type = TGUSDict(chat[@"type"]);
			NSString *kind = TGUSString(type[@"@type"]);

			if ([kind isEqualToString:@"chatTypeBasicGroup"]) {
				[weakSelf request:@{@"@type" : @"getBasicGroupFullInfo",
					@"basic_group_id" : type[@"basic_group_id"] ?: @(0)}
					completion:^(NSDictionary *full) {
						if (TGResultIsError(full)) {
							completion(@"", 0, 0);
							return;
						}
						NSArray *members = TGUSArray(TGUSDict(full)[@"members"]);
						NSMutableArray *ids = [NSMutableArray array];
						for (id member in members ?: @[]) {
							id memberId = TGUSDict(TGUSDict(member)[@"member_id"])[@"user_id"];
							if (memberId)
								[ids addObject:@(TGUSInt64(memberId))];
						}
						answer((NSInteger)ids.count, ids);
					}];
				return;
			}

			if ([kind isEqualToString:@"chatTypeSupergroup"]) {
				id supergroupId = type[@"supergroup_id"] ?: @(0);
				[weakSelf request:@{@"@type" : @"getSupergroupFullInfo",
					@"supergroup_id" : supergroupId}
					   completion:^(NSDictionary *full) {
						   if (TGResultIsError(full)) {
							   completion(@"", 0, 0);
							   return;
						   }
						   NSInteger members = [TGUSDict(full)[@"member_count"] integerValue];
						   [weakSelf request:@{@"@type" : @"getSupergroupMembers",
							   @"supergroup_id" : supergroupId,
							   @"filter" : @{@"@type" : @"supergroupMembersFilterRecent"},
							   @"offset" : @(0),
							   @"limit" : @(50)}
							   completion:^(NSDictionary *result) {
								   NSMutableArray *ids = [NSMutableArray array];
								   for (id member in TGUSArray(TGUSDict(result)[@"members"]) ?: @[]) {
									   id memberId = TGUSDict(TGUSDict(member)[@"member_id"])[@"user_id"];
									   if (memberId)
										   [ids addObject:@(TGUSInt64(memberId))];
								   }
								   answer(members, ids);
							   }];
					   }];
				return;
			}
			completion(@"", 0, 0);
		}];
}

#pragma mark - emoji status

- (void)iconForEmojiStatus:(NSDictionary *)emojiStatus
				completion:(void (^)(NSDictionary *))completion {
	NSDictionary *status = TGUSDict(emojiStatus);
	NSDictionary *type = TGUSDict(status[@"type"]);
	NSString *kind = TGUSString(type[@"@type"]);
	long long expires = TGUSInt64(status[@"expiration_date"]);

	long long customEmojiId = 0;
	BOOL isGift = NO;
	NSString *giftTitle = @"";

	if ([kind isEqualToString:@"emojiStatusTypeCustomEmoji"]) {
		customEmojiId = TGUSInt64(type[@"custom_emoji_id"]);
	} else if ([kind isEqualToString:@"emojiStatusTypeUpgradedGift"]) {
		customEmojiId = TGUSInt64(type[@"model_custom_emoji_id"]);
		isGift = YES;
		giftTitle = TGUSString(type[@"gift_title"]);
	}
	if (!customEmojiId) {
		completion(nil);
		return;
	}

	[self request:@{@"@type" : @"getCustomEmojiStickers",
		@"custom_emoji_ids" : @[ [NSString stringWithFormat:@"%lld", customEmojiId] ]}
		completion:^(NSDictionary *result) {
			NSArray *stickers = TGUSArray(TGUSDict(result)[@"stickers"]);
			NSDictionary *sticker = stickers.count ? TGUSDict(stickers[0]) : nil;
			completion(TGUSFlatEmojiStatusIcon(sticker, customEmojiId, expires, isGift, giftTitle));
		}];
}

#pragma mark - bot verification badge

- (void)iconForBotVerification:(NSDictionary *)verification
					completion:(void (^)(NSDictionary *))completion {
	NSDictionary *v = TGUSDict(verification);
	long long customEmojiId = TGUSInt64(v[@"icon_custom_emoji_id"]);
	long long botUserId = TGUSInt64(v[@"bot_user_id"]);
	NSString *description = TGUSString(TGUSDict(v[@"custom_description"])[@"text"]);
	if (!customEmojiId || !botUserId) {
		completion(nil);
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getCustomEmojiStickers",
		@"custom_emoji_ids" : @[ [NSString stringWithFormat:@"%lld", customEmojiId] ]}
		completion:^(NSDictionary *result) {
			NSArray *stickers = TGUSArray(TGUSDict(result)[@"stickers"]);
			NSDictionary *sticker = stickers.count ? TGUSDict(stickers[0]) : nil;
			NSMutableDictionary *icon = [TGUSFlatEmojiStatusIcon(sticker, customEmojiId, 0, NO, @"")
				mutableCopy];
			icon[@"botUserId"] = @(botUserId);
			icon[@"verificationDescription"] = description ?: @"";
			NSString *botName = [weakSelf nameForUserId:botUserId];
			icon[@"botName"] = botName.length ? botName : @"";
			completion(icon);
		}];
}

- (void)botVerificationForUser:(int64_t)userId
					completion:(void (^)(NSDictionary *))completion {
	if (!completion)
		return;
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getUserFullInfo", @"user_id" : @(userId)}
		completion:^(NSDictionary *full) {
			if (TGResultIsError(full)) {
				completion(nil);
				return;
			}
			[weakSelf iconForBotVerification:TGUSDict(full[@"bot_verification"])
								  completion:completion];
		}];
}

- (void)botVerificationForChat:(int64_t)chatId
					completion:(void (^)(NSDictionary *))completion {
	if (!completion)
		return;
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			if (TGResultIsError(chat)) {
				completion(nil);
				return;
			}
			NSDictionary *type = TGUSDict(chat[@"type"]);
			long long supergroupId = [TGUSString(type[@"@type"])
										 isEqualToString:@"chatTypeSupergroup"]
				? TGUSInt64(type[@"supergroup_id"])
				: 0;
			if (!supergroupId) {
				completion(nil);
				return;
			}
			[weakSelf request:@{@"@type" : @"getSupergroupFullInfo",
				@"supergroup_id" : @(supergroupId)}
				completion:^(NSDictionary *full) {
					if (TGResultIsError(full)) {
						completion(nil);
						return;
					}
					[weakSelf iconForBotVerification:TGUSDict(full[@"bot_verification"])
										  completion:completion];
				}];
		}];
}

- (void)emojiStatusForUser:(int64_t)userId
				completion:(void (^)(NSDictionary *))completion {
	if (!completion)
		return;
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getUser", @"user_id" : @(userId)}
		completion:^(NSDictionary *user) {
			if (TGResultIsError(user)) {
				completion(nil);
				return;
			}
			[weakSelf iconForEmojiStatus:TGUSDict(user[@"emoji_status"]) completion:completion];
		}];
}

- (void)emojiStatusForChat:(int64_t)chatId
				completion:(void (^)(NSDictionary *))completion {
	if (!completion)
		return;
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			if (TGResultIsError(chat)) {
				completion(nil);
				return;
			}
			[weakSelf iconForEmojiStatus:TGUSDict(chat[@"emoji_status"]) completion:completion];
		}];
}

- (void)customEmojiIconsForIds:(NSArray *)ids
					completion:(void (^)(NSDictionary *))completion {
	if (!completion)
		return;
	NSMutableArray *strings = [NSMutableArray array];
	for (id one in TGUSArray(ids) ?: @[]) {
		long long value = TGUSInt64(one);
		if (value)
			[strings addObject:[NSString stringWithFormat:@"%lld", value]];
	}
	if (!strings.count) {
		completion(@{});
		return;
	}
	[self request:@{@"@type" : @"getCustomEmojiStickers",
		@"custom_emoji_ids" : strings}
		completion:^(NSDictionary *result) {
			NSMutableDictionary *out = [NSMutableDictionary dictionary];
			for (id entry in TGUSArray(TGUSDict(result)[@"stickers"]) ?: @[]) {
				NSDictionary *sticker = TGUSDict(entry);
				NSDictionary *fullType = TGUSDict(sticker[@"full_type"]);
				long long emojiId = TGUSInt64(fullType[@"custom_emoji_id"]);
				if (!emojiId)
					continue;
				out[[NSString stringWithFormat:@"%lld", emojiId]] =
					TGUSFlatEmojiStatusIcon(sticker, emojiId, 0, NO, @"");
			}
			completion(out);
		}];
}

- (void)pickableEmojiStatusIconsWithCompletion:(void (^)(NSArray *))completion {
	if (!completion)
		return;
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getThemedEmojiStatuses"} completion:^(NSDictionary *themedResult) {
		NSMutableArray *themedIds = [NSMutableArray array];
		for (id entry in TGUSArray(TGUSDict(themedResult)[@"custom_emoji_ids"]) ?: @[]) {
			long long emojiId = TGUSInt64(entry);
			if (emojiId)
				[themedIds addObject:@(emojiId)];
		}
		[weakSelf request:@{@"@type" : @"getRecentEmojiStatuses"} completion:^(NSDictionary *recentResult) {
			NSMutableArray *recentIds = [NSMutableArray array];
			for (id entry in TGUSArray(TGUSDict(recentResult)[@"emoji_statuses"]) ?: @[]) {
				NSDictionary *type = TGUSDict(TGUSDict(entry)[@"type"]);
				long long emojiId = TGUSInt64(type[@"custom_emoji_id"]);
				if (emojiId)
					[recentIds addObject:@(emojiId)];
			}
			[weakSelf request:@{@"@type" : @"getDefaultEmojiStatuses"}
				   completion:^(NSDictionary *defaultResult) {
					   NSMutableArray *defaultIds = [NSMutableArray array];
					   for (id entry in TGUSArray(TGUSDict(defaultResult)[@"custom_emoji_ids"]) ?: @[]) {
						   long long emojiId = TGUSInt64(entry);
						   if (emojiId)
							   [defaultIds addObject:@(emojiId)];
					   }
					   NSArray<NSNumber *> *ids = TGUSMergePickableEmojiStatusIds(themedIds, recentIds, defaultIds, 40);
					   if (!ids.count) {
						   completion(@[]);
						   return;
					   }
					   NSMutableArray *strings = [NSMutableArray array];
					   for (NSNumber *emojiId in ids)
						   [strings addObject:[emojiId stringValue]];
					   [weakSelf request:@{@"@type" : @"getCustomEmojiStickers",
						   @"custom_emoji_ids" : strings}
							  completion:^(NSDictionary *stickerResult) {
								  NSMutableDictionary *byId = [NSMutableDictionary dictionary];
								  for (id entry in TGUSArray(TGUSDict(stickerResult)[@"stickers"]) ?: @[]) {
									  NSDictionary *sticker = TGUSDict(entry);
									  NSDictionary *fullType = TGUSDict(sticker[@"full_type"]);
									  long long emojiId = TGUSInt64(fullType[@"custom_emoji_id"]);
									  if (emojiId)
										  byId[@(emojiId)] = sticker;
								  }
								  NSMutableArray *icons = [NSMutableArray array];
								  for (NSNumber *emojiId in ids) {
									  NSDictionary *sticker = byId[emojiId];
									  if (sticker)
										  [icons addObject:TGUSFlatEmojiStatusIcon(sticker, [emojiId longLongValue], 0, NO, @"")];
								  }
								  completion(icons);
							  }];
				   }];
		}];
	}];
}

- (void)pickableChatEmojiStatusIconsForChat:(int64_t)chatId
								  completion:(void (^)(NSArray *))completion {
	if (!completion)
		return;
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getThemedChatEmojiStatuses"} completion:^(NSDictionary *themedResult) {
		NSMutableArray *themedIds = [NSMutableArray array];
		for (id entry in TGUSArray(TGUSDict(themedResult)[@"custom_emoji_ids"]) ?: @[]) {
			long long emojiId = TGUSInt64(entry);
			if (emojiId)
				[themedIds addObject:@(emojiId)];
		}
		[weakSelf request:@{@"@type" : @"getDefaultChatEmojiStatuses"}
			   completion:^(NSDictionary *defaultResult) {
					NSMutableArray *defaultIds = [NSMutableArray array];
					for (id entry in TGUSArray(TGUSDict(defaultResult)[@"custom_emoji_ids"]) ?: @[]) {
						long long emojiId = TGUSInt64(entry);
						if (emojiId)
							[defaultIds addObject:@(emojiId)];
					}
					[weakSelf request:@{@"@type" : @"getDisallowedChatEmojiStatuses"}
						   completion:^(NSDictionary *disallowedResult) {
								NSMutableSet *disallowedIds = [NSMutableSet set];
								for (id entry in TGUSArray(TGUSDict(disallowedResult)[@"custom_emoji_ids"]) ?: @[]) {
									long long emojiId = TGUSInt64(entry);
									if (emojiId)
										[disallowedIds addObject:@(emojiId)];
								}
								NSArray<NSNumber *> *merged = TGUSMergePickableEmojiStatusIds(themedIds, @[], defaultIds, 40);
								NSMutableArray<NSNumber *> *ids = [NSMutableArray array];
								for (NSNumber *emojiId in merged) {
									if (![disallowedIds containsObject:emojiId])
										[ids addObject:emojiId];
								}
								if (!ids.count) {
									completion(@[]);
									return;
								}
								NSMutableArray *strings = [NSMutableArray array];
								for (NSNumber *emojiId in ids)
									[strings addObject:[emojiId stringValue]];
								[weakSelf request:@{@"@type" : @"getCustomEmojiStickers",
									@"custom_emoji_ids" : strings}
									   completion:^(NSDictionary *stickerResult) {
											NSMutableDictionary *byId = [NSMutableDictionary dictionary];
											for (id entry in TGUSArray(TGUSDict(stickerResult)[@"stickers"]) ?: @[]) {
												NSDictionary *sticker = TGUSDict(entry);
												NSDictionary *fullType = TGUSDict(sticker[@"full_type"]);
												long long emojiId = TGUSInt64(fullType[@"custom_emoji_id"]);
												if (emojiId)
													byId[@(emojiId)] = sticker;
											}
											NSMutableArray *icons = [NSMutableArray array];
											for (NSNumber *emojiId in ids) {
												NSDictionary *sticker = byId[emojiId];
												if (sticker)
													[icons addObject:TGUSFlatEmojiStatusIcon(sticker, [emojiId longLongValue], 0, NO, @"")];
											}
											completion(icons);
									   }];
						   }];
			   }];
	}];
}

- (void)setMyEmojiStatusCustomEmojiId:(int64_t)customEmojiId
					   expirationDate:(int32_t)expirationDate
						   completion:(void (^)(BOOL, NSString *))completion {
	id status = customEmojiId
		? @{
			  @"@type" : @"emojiStatus",
			  @"type" : @{
				  @"@type" : @"emojiStatusTypeCustomEmoji",
				  @"custom_emoji_id" : @(customEmojiId),
			  },
			  @"expiration_date" : @(expirationDate),
		  }
		: [NSNull null];
	[self request:@{@"@type" : @"setEmojiStatus", @"emoji_status" : status}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result), TGUSErrorText(result, nil));
		}];
}

- (void)setChatEmojiStatusCustomEmojiId:(int64_t)customEmojiId
						 expirationDate:(int32_t)expirationDate
								forChat:(int64_t)chatId
							 completion:(void (^)(BOOL, NSString *))completion {
	id status = customEmojiId
		? @{
			  @"@type" : @"emojiStatus",
			  @"type" : @{
				  @"@type" : @"emojiStatusTypeCustomEmoji",
				  @"custom_emoji_id" : @(customEmojiId),
			  },
			  @"expiration_date" : @(expirationDate),
		  }
		: [NSNull null];
	[self request:@{@"@type" : @"setChatEmojiStatus", @"chat_id" : @(chatId), @"emoji_status" : status}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result), TGUSErrorText(result, nil));
		}];
}

#pragma mark - badges

- (void)badgesForUser:(int64_t)userId
		   completion:(void (^)(NSDictionary *))completion {
	if (!completion)
		return;
	[self request:@{@"@type" : @"getUser", @"user_id" : @(userId)}
		completion:^(NSDictionary *user) {
			NSDictionary *verification = TGUSDict(TGUSDict(user)[@"verification_status"]);
			NSString *userType = TGUSString(TGUSDict(TGUSDict(user)[@"type"])[@"@type"]);
			completion(@{
				@"isPremium" : @([TGUSDict(user)[@"is_premium"] boolValue]),
				@"isSupport" : @([TGUSDict(user)[@"is_support"] boolValue]),
				@"isVerified" : @([verification[@"is_verified"] boolValue]),
				@"isScam" : @([verification[@"is_scam"] boolValue]),
				@"isFake" : @([verification[@"is_fake"] boolValue]),
				@"isBot" : @([userType isEqualToString:@"userTypeBot"]),
			});
		}];
}

- (void)badgesForChat:(int64_t)chatId
		   completion:(void (^)(NSDictionary *))completion {
	if (!completion)
		return;
	NSDictionary *empty = @{@"isVerified" : @NO, @"isScam" : @NO, @"isFake" : @NO, @"isPremium" : @NO};
	__weak typeof(self) weakSelf = self;

	void (^answer)(NSDictionary *, BOOL) = ^(NSDictionary *verification, BOOL isPremium) {
		completion(@{
			@"isVerified" : @([TGUSDict(verification)[@"is_verified"] boolValue]),
			@"isScam" : @([TGUSDict(verification)[@"is_scam"] boolValue]),
			@"isFake" : @([TGUSDict(verification)[@"is_fake"] boolValue]),
			@"isPremium" : @(isPremium),
		});
	};

	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			if (TGResultIsError(chat)) {
				completion(empty);
				return;
			}
			NSDictionary *type = TGUSDict(chat[@"type"]);
			NSString *kind = TGUSString(type[@"@type"]);

			if ([kind isEqualToString:@"chatTypeSupergroup"]) {
				[weakSelf request:@{@"@type" : @"getSupergroup",
					@"supergroup_id" : type[@"supergroup_id"] ?: @(0)}
					completion:^(NSDictionary *supergroup) {
						answer(TGUSDict(TGUSDict(supergroup)[@"verification_status"]), NO);
					}];
				return;
			}
			if ([kind isEqualToString:@"chatTypePrivate"] ||
				[kind isEqualToString:@"chatTypeSecret"]) {
				[weakSelf request:@{@"@type" : @"getUser",
					@"user_id" : type[@"user_id"] ?: @(0)}
					completion:^(NSDictionary *user) {
						NSDictionary *userDict = TGUSDict(user);
						answer(TGUSDict(userDict[@"verification_status"]),
							[userDict[@"is_premium"] boolValue]);
					}];
				return;
			}
			completion(empty);
		}];
}

#pragma mark - accent colours

NSString *const TGAccentColorCatalogDidChangeNotification =
	@"TGAccentColorCatalogDidChangeNotification";

static NSMutableDictionary *TGAccentColorRGBCache(void) {
	static NSMutableDictionary *cache = nil;
	if (!cache)
		cache = [NSMutableDictionary dictionary];
	return cache;
}

static NSMutableArray *TGAccentColorAvailableIdsCache(void) {
	static NSMutableArray *ids = nil;
	if (!ids)
		ids = [NSMutableArray array];
	return ids;
}

static NSMutableDictionary *TGProfileAccentColorGradientCache(void) {
	static NSMutableDictionary *cache = nil;
	if (!cache)
		cache = [NSMutableDictionary dictionary];
	return cache;
}

static NSMutableArray *TGProfileAccentColorAvailableIdsCache(void) {
	static NSMutableArray *ids = nil;
	if (!ids)
		ids = [NSMutableArray array];
	return ids;
}

- (void)handleUpdateAccentColors:(NSDictionary *)update {
	NSMutableDictionary *cache = TGAccentColorRGBCache();
	for (id item in TGUSArray(update[@"colors"]) ?: @[]) {
		NSDictionary *colour = TGUSDict(item);
		NSArray *light = TGUSArray(colour[@"light_theme_colors"]);
		if (!colour || !light.count)
			continue;
		cache[@([colour[@"id"] integerValue])] = light[0];
	}
	NSArray *ids = TGUSArray(update[@"available_accent_color_ids"]);
	if (ids.count) {
		NSMutableArray *available = TGAccentColorAvailableIdsCache();
		[available removeAllObjects];
		[available addObjectsFromArray:ids];
	}
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGAccentColorCatalogDidChangeNotification
					  object:nil];
}

- (void)handleUpdateProfileAccentColors:(NSDictionary *)update {
	NSMutableDictionary *cache = TGProfileAccentColorGradientCache();
	for (id item in TGUSArray(update[@"colors"]) ?: @[]) {
		NSDictionary *colour = TGUSDict(item);
		NSDictionary *light = TGUSDict(colour[@"light_theme_colors"]);
		NSArray *background = TGUSArray(light[@"background_colors"]);
		if (!colour || background.count < 1)
			continue;
		cache[@([colour[@"id"] integerValue])] =
			background.count >= 2 ? @[ background[0], background[1] ]
								  : @[ background[0], background[0] ];
	}
	NSArray *ids = TGUSArray(update[@"available_accent_color_ids"]);
	if (ids.count) {
		NSMutableArray *available = TGProfileAccentColorAvailableIdsCache();
		[available removeAllObjects];
		[available addObjectsFromArray:ids];
	}
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGAccentColorCatalogDidChangeNotification
					  object:nil];
}

+ (NSNumber *)rgbForAccentColorId:(NSInteger)colorId {
	NSNumber *pushed = TGAccentColorRGBCache()[@(colorId)];
	if (pushed)
		return pushed;
	static const NSInteger builtIn[7] = {
		0xCC5049, 0xD67722, 0x955CDB, 0x40A920, 0x309EBA, 0x368AD1, 0xC7508B};
	NSInteger index = colorId < 0 ? 0 : colorId % 7;
	return @(builtIn[index]);
}

+ (NSArray *)profileGradientForColorId:(NSInteger)colorId {
	if (colorId < 0)
		return nil;
	NSArray *pushed = TGProfileAccentColorGradientCache()[@(colorId)];
	if (pushed.count == 2)
		return pushed;
	static const NSInteger tops[7] = {
		0xE15052, 0xE0802B, 0xA05FF3, 0x27A910, 0x27ACCE, 0x3391D4, 0xDD4371};
	static const NSInteger bottoms[7] = {
		0xF41C2F, 0xFAC534, 0xF48FFF, 0xA7DC57, 0x82E8D6, 0x7DD3F0, 0xF9BFC8};
	NSInteger index = colorId % 7;
	return @[ @(tops[index]), @(bottoms[index]) ];
}

+ (NSArray *)pickableAccentColorIds {
	NSArray *pushed = TGAccentColorAvailableIdsCache();
	if (pushed.count)
		return pushed;
	return @[ @0, @1, @2, @3, @4, @5, @6 ];
}

+ (NSArray *)pickableProfileAccentColorIds {
	NSArray *pushed = TGProfileAccentColorAvailableIdsCache();
	if (pushed.count)
		return pushed;
	return @[ @0, @1, @2, @3, @4, @5, @6 ];
}

- (NSDictionary *)accentInfoFromPeer:(NSDictionary *)peer {
	NSDictionary *p = TGUSDict(peer);
	NSInteger accentId = [p[@"accent_color_id"] integerValue];
	NSInteger profileId = p[@"profile_accent_color_id"]
		? [p[@"profile_accent_color_id"] integerValue]
		: -1;

	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	out[@"colorId"] = @(accentId);
	out[@"rgb"] = [TGClient rgbForAccentColorId:accentId];
	out[@"profileColorId"] = @(profileId);
	NSArray *gradient = [TGClient profileGradientForColorId:profileId];
	if (gradient)
		out[@"profileColors"] = gradient;
	out[@"backgroundCustomEmojiId"] = @(TGUSInt64(p[@"background_custom_emoji_id"]));
	out[@"profileBackgroundCustomEmojiId"] =
		@(TGUSInt64(p[@"profile_background_custom_emoji_id"]));
	return out;
}

- (void)accentColorsForChat:(int64_t)chatId
				 completion:(void (^)(NSDictionary *))completion {
	if (!completion)
		return;
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			completion([weakSelf accentInfoFromPeer:TGResultIsError(chat) ? nil : chat]);
		}];
}

- (void)myAccentColorsWithCompletion:(void (^)(NSDictionary *))completion {
	if (!completion)
		return;
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getMe"} completion:^(NSDictionary *me) {
		completion([weakSelf accentInfoFromPeer:TGResultIsError(me) ? nil : me]);
	}];
}

- (void)setMyAccentColorId:(NSInteger)colorId
	backgroundCustomEmojiId:(int64_t)customEmojiId
				 completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setAccentColor",
		@"accent_color_id" : @(colorId),
		@"background_custom_emoji_id" : @(customEmojiId),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)setMyProfileAccentColorId:(NSInteger)colorId
		  backgroundCustomEmojiId:(int64_t)customEmojiId
					   completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setProfileAccentColor",
		@"profile_accent_color_id" : @(colorId),
		@"profile_background_custom_emoji_id" : @(customEmojiId),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)setChatAccentColorId:(NSInteger)colorId
	 backgroundCustomEmojiId:(int64_t)customEmojiId
					 forChat:(int64_t)chatId
				  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setChatAccentColor",
		@"chat_id" : @(chatId),
		@"accent_color_id" : @(colorId),
		@"background_custom_emoji_id" : @(customEmojiId),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)setChatProfileAccentColorId:(NSInteger)colorId
			backgroundCustomEmojiId:(int64_t)customEmojiId
							forChat:(int64_t)chatId
						 completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setChatProfileAccentColor",
		@"chat_id" : @(chatId),
		@"profile_accent_color_id" : @(colorId),
		@"profile_background_custom_emoji_id" : @(customEmojiId),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - account switch

- (void)resetUserStatusCachesForAccountSwitch {
	[TGUSOnlineCache() removeAllObjects];
	[TGAccentColorRGBCache() removeAllObjects];
	[TGAccentColorAvailableIdsCache() removeAllObjects];
	[TGProfileAccentColorGradientCache() removeAllObjects];
	[TGProfileAccentColorAvailableIdsCache() removeAllObjects];
}

@end

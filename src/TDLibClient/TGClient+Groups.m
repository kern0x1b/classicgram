#import "TGClient+ChatState.h"
#import "TGStringTruncation.h"
#import "TGClient+Private.h"
#import "TGClient+Groups.h"
#import "TGClient+Privacy.h"
#import "TGClient+ChatList.h"
#import "TGFlattenGroups.h"

static NSDictionary *TGDict(id value) {
	return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static NSArray *TGArray(id value) {
	return [value isKindOfClass:[NSArray class]] ? value : @[];
}

static NSString *TGString(id value) {
	return [value isKindOfClass:[NSString class]] ? value : @"";
}

static BOOL TGChatPermissionsRestricted(NSDictionary *chat) {
	NSDictionary *permissions = TGDict(chat[@"permissions"]);
	if (!permissions)
		return NO;
	static NSArray *keys = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		keys = @[ @"can_send_basic_messages", @"can_send_audios", @"can_send_documents",
			@"can_send_photos", @"can_send_videos", @"can_send_video_notes",
			@"can_send_voice_notes", @"can_send_polls", @"can_send_other_messages",
			@"can_add_link_previews" ];
	});
	for (NSString *key in keys) {
		if (![permissions[key] boolValue])
			return YES;
	}
	return NO;
}

@interface TGClient (GroupsPrivate)
- (NSDictionary *)tg_flattenMember:(NSDictionary *)member;
- (NSArray *)tg_flattenMembers:(NSArray *)members;
- (void)tg_group:(int64_t)chatId
	  completion:(void (^)(NSString *kind, NSNumber *groupId, NSDictionary *chat))completion;
- (void)tg_send:(NSDictionary *)request completion:(void (^)(BOOL ok))completion;
- (void)tg_supergroupToggle:(NSString *)method
					   chat:(int64_t)chatId
					 fields:(NSDictionary *)fields
				 completion:(void (^)(BOOL ok))completion;
- (void)tg_setStatus:(NSDictionary *)status
			  ofUser:(int64_t)userId
			 inGroup:(int64_t)chatId
		  completion:(void (^)(BOOL ok))completion;
- (void)tg_link:(NSDictionary *)request completion:(void (^)(NSDictionary *link))completion;
@end

@implementation TGClient (Groups)

- (NSDictionary *)tg_flattenMember:(NSDictionary *)member {
	if (!TGDict(member))
		return nil;
	NSDictionary *identity = TGFlattenMemberIdentity(TGDict(member[@"member_id"]));
	BOOL isChat = [identity[@"isChat"] boolValue];
	int64_t userId = [identity[@"userId"] longLongValue];
	int64_t chatId = [identity[@"chatId"] longLongValue];
	NSDictionary *status = TGDict(member[@"status"]) ?: @{};
	NSString *type = TGString(status[@"@type"]);
	NSInteger untilDate = 0;
	if ([type isEqualToString:@"chatMemberStatusRestricted"])
		untilDate = [status[@"restricted_until_date"] integerValue];
	else if ([type isEqualToString:@"chatMemberStatusBanned"])
		untilDate = [status[@"banned_until_date"] integerValue];
	else if ([type isEqualToString:@"chatMemberStatusMember"])
		untilDate = [status[@"member_until_date"] integerValue];

	NSString *name = TGStatusName(type);
	NSDictionary *rights = TGDict(status[@"rights"]);
	NSDictionary *userRecord = isChat ? nil : TGDict(self.userRecordsById[@(userId)]);
	NSDictionary *presence = userRecord ? TGUserStatusInfo(TGDict(userRecord[@"status"])) : nil;
	NSString *displayName = isChat ? ([self cachedTitleForChatId:chatId] ?: @"")
									: ([self nameForUserId:userId] ?: @"");
	return @{
		@"id" : @(isChat ? chatId : userId),
		@"isChat" : @(isChat),
		@"name" : displayName,
		@"status" : name,
		@"customTitle" : TGString(member[@"tag"]),
		@"isOwner" : @([name isEqualToString:@"creator"]),
		@"isAdmin" : @([name isEqualToString:@"creator"] ||
			[name isEqualToString:@"administrator"]),
		@"untilDate" : @(untilDate),
		@"inviterUserId" : member[@"inviter_user_id"] ?: @(0),
		@"joinedDate" : member[@"joined_chat_date"] ?: @(0),
		@"canBeEdited" : @([status[@"can_be_edited"] boolValue]),
		@"rights" : rights ? TGReadFlags(rights, TGAdminRightKeys()) : @{},
		@"permissions" : TGDict(status[@"permissions"]) ? TGReadFlags(status[@"permissions"], TGPermissionKeys()) : @{},
		@"presenceText" : TGString(presence[@"text"]),
		@"presenceIsOnline" : @([presence[@"isOnline"] boolValue]),
	};
}

- (NSArray *)tg_flattenMembers:(NSArray *)members {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *member in TGArray(members)) {
		NSDictionary *flat = [self tg_flattenMember:member];
		if (flat && [flat[@"id"] longLongValue])
			[out addObject:flat];
	}
	return out;
}

- (void)tg_group:(int64_t)chatId
	  completion:(void (^)(NSString *kind, NSNumber *groupId, NSDictionary *chat))completion {
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			if (TGResultIsError(chat)) {
				completion(nil, nil, nil);
				return;
			}
			NSDictionary *type = TGDict(chat[@"type"]) ?: @{};
			NSString *kind = TGString(type[@"@type"]);
			if ([kind isEqualToString:@"chatTypeSupergroup"])
				completion(@"super", type[@"supergroup_id"], chat);
			else if ([kind isEqualToString:@"chatTypeBasicGroup"])
				completion(@"basic", type[@"basic_group_id"], chat);
			else
				completion(nil, nil, chat);
		}];
}

- (void)tg_send:(NSDictionary *)request completion:(void (^)(BOOL ok))completion {
	[self request:request completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)tg_supergroupToggle:(NSString *)method
					   chat:(int64_t)chatId
					 fields:(NSDictionary *)fields
				 completion:(void (^)(BOOL ok))completion {
	__weak typeof(self) weakSelf = self;
	[self tg_group:chatId completion:^(NSString *kind, NSNumber *groupId, NSDictionary *chat) {
		if (![kind isEqualToString:@"super"]) {
			if (completion)
				completion(NO);
			return;
		}
		NSMutableDictionary *request = [NSMutableDictionary dictionary];
		request[@"@type"] = method;
		request[@"supergroup_id"] = groupId;
		[request addEntriesFromDictionary:fields ?: @{}];
		[weakSelf tg_send:request completion:completion];
	}];
}

#pragma mark - creating groups

- (void)createBasicGroupWithTitle:(NSString *)title
						  userIds:(NSArray *)userIds
					   completion:(void (^)(int64_t, NSArray *))completion {
	[self request:@{
		@"@type" : @"createNewBasicGroupChat",
		@"user_ids" : userIds ?: @[],
		@"title" : title ?: @"",
		@"message_auto_delete_time" : @(0),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(0, @[]);
			return;
		}
		NSMutableArray *failed = [NSMutableArray array];
		NSDictionary *failure = TGDict(result[@"failed_to_add_members"]);
		for (NSDictionary *entry in TGArray(failure[@"failed_to_add_members"])) {
			if (TGDict(entry) && entry[@"user_id"])
				[failed addObject:entry[@"user_id"]];
		}
		completion([result[@"chat_id"] longLongValue], failed);
	}];
}

- (void)createSupergroupWithTitle:(NSString *)title
					  description:(NSString *)description
						isChannel:(BOOL)isChannel
						  isForum:(BOOL)isForum
					   completion:(void (^)(int64_t))completion {
	[self request:@{
		@"@type" : @"createNewSupergroupChat",
		@"title" : title ?: @"",
		@"is_forum" : @(isForum),
		@"is_channel" : @(isChannel),
		@"description" : description ?: @"",
		@"message_auto_delete_time" : @(0),
		@"for_import" : @NO,
	} completion:^(NSDictionary *chat) {
		if (completion)
			completion(TGResultIsError(chat) ? 0 : [chat[@"id"] longLongValue]);
	}];
}

- (void)upgradeBasicGroupToSupergroup:(int64_t)chatId
						   completion:(void (^)(int64_t))completion {
	[self request:@{@"@type" : @"upgradeBasicGroupChatToSupergroupChat",
		@"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			if (completion)
				completion(TGResultIsError(chat) ? 0 : [chat[@"id"] longLongValue]);
		}];
}

#pragma mark - group info

- (void)groupInfoForChat:(int64_t)chatId
			  completion:(void (^)(NSDictionary *))completion {
	__weak typeof(self) weakSelf = self;
	[self tg_group:chatId completion:^(NSString *kind, NSNumber *groupId, NSDictionary *chat) {
		if (!kind) {
			if (completion)
				completion(nil);
			return;
		}
		NSString *title = TGString(chat[@"title"]);
		BOOL canBeEdited = [chat[@"can_be_edited"] boolValue];
		NSDictionary *videoChat = TGDict(chat[@"video_chat"]);
		NSNumber *videoChatGroupCallId = @([videoChat[@"group_call_id"] intValue]);
		NSNumber *videoChatHasParticipants = @([videoChat[@"has_participants"] boolValue]);
		NSNumber *hasRestrictedSendPermissions = @(TGChatPermissionsRestricted(chat));

		if ([kind isEqualToString:@"basic"]) {
			[weakSelf request:@{@"@type" : @"getBasicGroupFullInfo",
				@"basic_group_id" : groupId}
				   completion:^(NSDictionary *full) {
					   [weakSelf request:@{@"@type" : @"getBasicGroup",
						   @"basic_group_id" : groupId}
							  completion:^(NSDictionary *group) {
								  if (!completion)
									  return;
								  NSDictionary *link = TGFlattenInviteLink(TGDict(full[@"invite_link"]));
								  NSNumber *memberCount = TGResultIsError(group) ? @(TGArray(full[@"members"]).count) : (group[@"member_count"] ?: @(0));
								  NSString *myStatus = TGResultIsError(group) ? @"member" : TGStatusName(TGString(TGDict(group[@"status"])[@"@type"]));
								  completion(@{
									  @"id" : @(chatId),
									  @"title" : title,
									  @"description" : TGString(full[@"description"]),
									  @"isSupergroup" : @NO,
									  @"isChannel" : @NO,
									  @"isForum" : @NO,
									  @"isBroadcastGroup" : @NO,
									  @"memberCount" : memberCount,
									  @"adminCount" : @(0),
									  @"restrictedCount" : @(0),
									  @"bannedCount" : @(0),
									  @"slowModeDelay" : @(0),
									  @"username" : @"",
									  @"inviteLink" : link[@"link"] ?: @"",
									  @"linkedChatId" : @(0),
									  @"stickerSetId" : @(0),
									  @"isAllHistoryAvailable" : @YES,
									  @"hasHiddenMembers" : @NO,
									  @"canHideMembers" : @([full[@"can_hide_members"] boolValue]),
									  @"hasAggressiveAntiSpam" : @NO,
									  @"canToggleAggressiveAntiSpam" :
										  @([full[@"can_toggle_aggressive_anti_spam"] boolValue]),
									  @"hasDirectMessagesGroup" : @NO,
									  @"directMessagesStarCount" : @(0),
									  @"directMessagesChatId" : @(0),
									  @"canSetStickerSet" : @NO,
									  @"canGetMembers" : @YES,
									  @"pendingJoinRequests" : @(0),
									  @"myStatus" : myStatus,
									  @"canBeEdited" : @(canBeEdited),
									  @"upgradedFromBasicGroup" : @(0),
									  @"unrestrictBoostCount" : @(0),
									  @"hasRestrictedSendPermissions" : hasRestrictedSendPermissions,
									  @"hasAutomaticTranslation" : @NO,
									  @"mainProfileTab" : @"",
									  @"activeUsernames" : @[],
									  @"disabledUsernames" : @[],
									  @"editableUsername" : @"",
									  @"videoChatGroupCallId" : videoChatGroupCallId,
									  @"videoChatHasParticipants" : videoChatHasParticipants,
									  @"restrictionReason" : @"",
								  });
							  }];
				   }];
			return;
		}

		[weakSelf request:@{@"@type" : @"getSupergroup", @"supergroup_id" : groupId}
			   completion:^(NSDictionary *group) {
				   [weakSelf request:@{@"@type" : @"getSupergroupFullInfo",
					   @"supergroup_id" : groupId}
						  completion:^(NSDictionary *full) {
							  if (!completion)
								  return;
							  NSDictionary *link = TGFlattenInviteLink(TGDict(full[@"invite_link"]));
							  NSArray *usernames = TGArray(TGDict(group[@"usernames"])[@"active_usernames"]);
							  NSString *username = usernames.count &&
									  [usernames[0] isKindOfClass:[NSString class]]
								  ? usernames[0]
								  : @"";
							  completion(@{
								  @"id" : @(chatId),
								  @"title" : title,
								  @"description" : TGString(full[@"description"]),
								  @"isSupergroup" : @YES,
								  @"isChannel" : @([group[@"is_channel"] boolValue]),
								  @"isForum" : @([group[@"is_forum"] boolValue]),
								  @"isBroadcastGroup" : @([group[@"is_broadcast_group"] boolValue]),
								  @"memberCount" : full[@"member_count"] ?: (group[@"member_count"] ?: @(0)),
								  @"adminCount" : full[@"administrator_count"] ?: @(0),
								  @"restrictedCount" : full[@"restricted_count"] ?: @(0),
								  @"bannedCount" : full[@"banned_count"] ?: @(0),
								  @"slowModeDelay" : full[@"slow_mode_delay"] ?: @(0),
								  @"username" : username,
								  @"inviteLink" : link[@"link"] ?: @"",
								  @"linkedChatId" : full[@"linked_chat_id"] ?: @(0),
								  @"stickerSetId" : full[@"sticker_set_id"] ?: @(0),
								  @"isAllHistoryAvailable" : @([full[@"is_all_history_available"] boolValue]),
								  @"hasHiddenMembers" : @([full[@"has_hidden_members"] boolValue]),
								  @"canHideMembers" : @([full[@"can_hide_members"] boolValue]),
								  @"hasAggressiveAntiSpam" :
									  @([full[@"has_aggressive_anti_spam_enabled"] boolValue]),
								  @"canToggleAggressiveAntiSpam" :
									  @([full[@"can_toggle_aggressive_anti_spam"] boolValue]),
								  @"hasDirectMessagesGroup" :
									  @([group[@"has_direct_messages_group"] boolValue]),
								  @"directMessagesStarCount" : group[@"paid_message_star_count"] ?: @(0),
								  @"directMessagesChatId" : full[@"direct_messages_chat_id"] ?: @(0),
								  @"canSetStickerSet" : @([full[@"can_set_sticker_set"] boolValue]),
								  @"canGetMembers" : @([full[@"can_get_members"] boolValue]),
								  @"pendingJoinRequests" : link[@"pendingJoinRequestCount"] ?: @(0),
								  @"myStatus" : TGStatusName(TGString(TGDict(group[@"status"])[@"@type"])),
								  @"canBeEdited" : @(canBeEdited),
								  @"upgradedFromBasicGroup" : full[@"upgraded_from_basic_group_id"] ?: @(0),
								  @"unrestrictBoostCount" : full[@"unrestrict_boost_count"] ?: @(0),
								  @"hasRestrictedSendPermissions" : hasRestrictedSendPermissions,
								  @"hasAutomaticTranslation" :
									  @([group[@"has_automatic_translation"] boolValue]),
								  @"mainProfileTab" : TGGroupProfileTabName(full[@"main_profile_tab"]),
								  @"activeUsernames" : usernames,
								  @"disabledUsernames" :
									  TGArray(TGDict(group[@"usernames"])[@"disabled_usernames"]),
								  @"editableUsername" :
									  TGString(TGDict(group[@"usernames"])[@"editable_username"]),
								  @"videoChatGroupCallId" : videoChatGroupCallId,
								  @"videoChatHasParticipants" : videoChatHasParticipants,
								  @"restrictionReason" : TGString(TGDict(group[@"restriction_info"])[@"restriction_reason"]),
							  });
						  }];
			   }];
	}];
}

- (void)setGroupChat:(int64_t)chatId title:(NSString *)title
		  completion:(void (^)(BOOL))completion {
	[self tg_send:@{@"@type" : @"setChatTitle",
		@"chat_id" : @(chatId),
		@"title" : title ?: @""}
		completion:completion];
}

- (void)setGroupChat:(int64_t)chatId description:(NSString *)description
		  completion:(void (^)(BOOL))completion {
	[self tg_send:@{@"@type" : @"setChatDescription",
		@"chat_id" : @(chatId),
		@"description" : description ?: @""}
		completion:completion];
}

- (void)setGroupChat:(int64_t)chatId photoAtPath:(NSString *)path
		  completion:(void (^)(BOOL))completion {
	NSMutableDictionary *request = [NSMutableDictionary dictionary];
	request[@"@type"] = @"setChatPhoto";
	request[@"chat_id"] = @(chatId);
	if (path.length)
		request[@"photo"] = @{
			@"@type" : @"inputChatPhotoStatic",
			@"photo" : @{@"@type" : @"inputFileLocal", @"path" : path},
		};
	[self tg_send:request completion:completion];
}

#pragma mark - members

- (void)membersInGroup:(int64_t)chatId
				filter:(NSString *)filter
				offset:(NSInteger)offset
				 limit:(NSInteger)limit
			completion:(void (^)(NSArray *, NSInteger))completion {
	__weak typeof(self) weakSelf = self;
	NSInteger wanted = limit > 0 ? limit : 50;
	[self tg_group:chatId completion:^(NSString *kind, NSNumber *groupId, NSDictionary *chat) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf || !kind) {
			if (completion)
				completion(nil, 0);
			return;
		}
		if ([kind isEqualToString:@"super"]) {
			[strongSelf request:@{
				@"@type" : @"getSupergroupMembers",
				@"supergroup_id" : groupId,
				@"filter" : TGSupergroupFilter(filter, nil),
				@"offset" : @(offset),
				@"limit" : @(wanted),
			} completion:^(NSDictionary *result) {
				if (!completion)
					return;
				if (TGResultIsError(result)) {
					completion(nil, 0);
					return;
				}
				completion([strongSelf tg_flattenMembers:result[@"members"]],
					[result[@"total_count"] integerValue]);
			}];
			return;
		}
		[strongSelf request:@{@"@type" : @"getBasicGroupFullInfo", @"basic_group_id" : groupId}
			completion:^(NSDictionary *full) {
				if (!completion)
					return;
				if (TGResultIsError(full)) {
					completion(nil, 0);
					return;
				}
				NSArray *all = [strongSelf tg_flattenMembers:TGDict(full) ? full[@"members"] : nil];
				NSMutableArray *filtered = [NSMutableArray array];
				for (NSDictionary *member in all) {
					if ([filter isEqualToString:@"administrators"] &&
						![member[@"isAdmin"] boolValue])
						continue;
					if ([filter isEqualToString:@"banned"] ||
						[filter isEqualToString:@"restricted"])
						continue;
					[filtered addObject:member];
				}
				NSInteger total = (NSInteger)filtered.count;
				if (offset > 0 && offset < (NSInteger)filtered.count)
					filtered = [[filtered subarrayWithRange:
							NSMakeRange(offset, filtered.count - offset)] mutableCopy];
				else if (offset > 0)
					filtered = [NSMutableArray array];
				if ((NSInteger)filtered.count > wanted)
					filtered = [[filtered subarrayWithRange:NSMakeRange(0, wanted)] mutableCopy];
				completion(filtered, total);
			}];
	}];
}

- (void)searchMembersInGroup:(int64_t)chatId
					   query:(NSString *)query
					  filter:(NSString *)filter
					   limit:(NSInteger)limit
				  completion:(void (^)(NSArray *, BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"searchChatMembers",
		@"chat_id" : @(chatId),
		@"query" : query ?: @"",
		@"limit" : @(limit > 0 ? limit : 50),
		@"filter" : TGChatMembersFilter(filter),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		TGClient *strongSelf = weakSelf;
		if (!strongSelf || TGResultIsError(result)) {
			completion(@[], YES);
			return;
		}
		completion([strongSelf tg_flattenMembers:result[@"members"]], NO);
	}];
}

- (void)mentionCandidatesInGroup:(int64_t)chatId
						   query:(NSString *)query
						   limit:(NSInteger)limit
					  completion:(void (^)(NSArray *))completion {
	NSInteger wanted = limit > 0 ? limit : 8;
	__weak typeof(self) weakSelf = self;
	__block int64_t myUserId = 0;
	__block NSArray *rawMembers = nil;
	dispatch_group_t group = dispatch_group_create();

	dispatch_group_enter(group);
	[self request:@{@"@type" : @"getMe"} completion:^(NSDictionary *me) {
		if (!TGResultIsError(me))
			myUserId = [me[@"id"] longLongValue];
		dispatch_group_leave(group);
	}];

	dispatch_group_enter(group);
	[self searchMembersInGroup:chatId query:(query ?: @"") filter:nil limit:wanted
					 completion:^(NSArray *foundMembers, BOOL foundFailed) {
		(void)foundFailed;
		rawMembers = foundMembers;
		dispatch_group_leave(group);
	}];

	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		TGClient *strongSelf = weakSelf;
		if (!completion)
			return;
		NSMutableArray *members = [NSMutableArray arrayWithCapacity:rawMembers.count];
		for (NSDictionary *member in rawMembers) {
			if (myUserId && [member[@"id"] longLongValue] == myUserId)
				continue;
			[members addObject:member];
		}
		if (!strongSelf || !members.count) {
			completion(@[]);
			return;
		}

		NSMutableArray *candidates = [NSMutableArray arrayWithCapacity:members.count];
		for (NSInteger i = 0; i < members.count; i++)
			[candidates addObject:[NSNull null]];

		__block NSUInteger left = members.count;
		void (^finish)(void) = ^{
			NSMutableArray *out = [NSMutableArray arrayWithCapacity:candidates.count];
			for (id value in candidates)
				if (![value isKindOfClass:NSNull.class])
					[out addObject:value];
			completion(out);
		};

		[members enumerateObjectsUsingBlock:^(NSDictionary *member, NSUInteger idx, BOOL *stop) {
			int64_t userId = [member[@"id"] longLongValue];
			if (!userId) {
				if (--left == 0)
					finish();
				return;
			}
			NSDictionary *known = strongSelf.userRecordsById[@(userId)];
			if (known) {
				candidates[idx] = TGMentionCandidate(userId, TGActiveUsername(known),
					known[@"first_name"], known[@"last_name"], member[@"name"]);
				if (--left == 0)
					finish();
				return;
			}
			[strongSelf request:@{@"@type" : @"getUser", @"user_id" : @(userId)}
				completion:^(NSDictionary *u) {
					TGClient *innerSelf = weakSelf;
					if (innerSelf && [u[@"@type"] isEqualToString:@"user"]) {
						[innerSelf capUserRegistriesIfNeeded];
						innerSelf.userRecordsById[@(userId)] = u;
						candidates[idx] = TGMentionCandidate(userId, TGActiveUsername(u),
							u[@"first_name"], u[@"last_name"], member[@"name"]);
					} else {
						candidates[idx] = TGMentionCandidate(userId, nil, nil, nil, member[@"name"]);
					}
					if (--left == 0 && innerSelf)
						finish();
				}];
		}];
	});
}

- (void)memberStatusOfUser:(int64_t)userId
				   inGroup:(int64_t)chatId
				completion:(void (^)(NSDictionary *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChatMember",
		@"chat_id" : @(chatId),
		@"member_id" : TGUserSender(userId)}
		completion:^(NSDictionary *member) {
			if (!completion)
				return;
			TGClient *strongSelf = weakSelf;
			completion((strongSelf && !TGResultIsError(member)) ? [strongSelf tg_flattenMember:member] : nil);
		}];
}

- (NSArray *)administratorRightKeys {
	return TGAdminRightKeys();
}

- (NSArray *)memberPermissionKeys {
	return TGPermissionKeys();
}

- (void)administratorRightsOfUser:(int64_t)userId
						  inGroup:(int64_t)chatId
					   completion:(void (^)(NSDictionary *, NSString *, BOOL, NSString *))completion {
	[self request:@{@"@type" : @"getChatMember",
		@"chat_id" : @(chatId),
		@"member_id" : TGUserSender(userId)}
		completion:^(NSDictionary *member) {
			if (!completion)
				return;
			if (TGResultIsError(member)) {
				completion(nil, nil, NO, nil);
				return;
			}
			NSDictionary *status = TGDict(member[@"status"]) ?: @{};
			NSString *type = TGString(status[@"@type"]);
			NSString *name = TGStatusName(type);
			BOOL canBeEdited = [status[@"can_be_edited"] boolValue];
			NSString *tag = TGString(member[@"tag"]);
			NSArray *keys = TGAdminRightKeys();
			NSMutableDictionary *rights = [NSMutableDictionary dictionaryWithCapacity:keys.count];
			if ([type isEqualToString:@"chatMemberStatusCreator"]) {
				for (NSString *key in keys)
					rights[key] = @YES;
				rights[@"is_anonymous"] = @([status[@"is_anonymous"] boolValue]);
			} else if ([type isEqualToString:@"chatMemberStatusAdministrator"]) {
				NSDictionary *raw = TGDict(status[@"rights"]) ?: @{};
				for (NSString *key in keys)
					rights[key] = @([raw[key] boolValue]);
			} else {
				for (NSString *key in keys)
					rights[key] = @NO;
			}
			completion(rights, name, canBeEdited, tag);
		}];
}

- (void)permissionsOfUser:(int64_t)userId
				  inGroup:(int64_t)chatId
			   completion:(void (^)(NSDictionary *, BOOL, NSInteger))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChatMember",
		@"chat_id" : @(chatId),
		@"member_id" : TGUserSender(userId)}
		completion:^(NSDictionary *member) {
			if (!completion)
				return;
			TGClient *strongSelf = weakSelf;
			if (!strongSelf || TGResultIsError(member)) {
				completion(nil, NO, 0);
				return;
			}
			NSDictionary *restriction = TGFlattenMemberRestriction(member[@"status"]);
			if (![restriction[@"usesChatDefaults"] boolValue]) {
				completion(TGReadFlags(TGDict(restriction[@"permissions"]), TGPermissionKeys()),
					[restriction[@"isRestricted"] boolValue],
					[restriction[@"untilDate"] integerValue]);
				return;
			}
			[strongSelf defaultPermissionsInGroup:chatId completion:^(NSDictionary *permissions) {
				completion(permissions, NO, 0);
			}];
		}];
}

- (void)myAdministratorRightsInGroup:(int64_t)chatId
						  completion:(void (^)(NSDictionary *, NSString *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getMe"} completion:^(NSDictionary *user) {
		if (!completion)
			return;
		TGClient *strongSelf = weakSelf;
		int64_t myId = TGResultIsError(user) ? 0 : [user[@"id"] longLongValue];
		if (!strongSelf || !myId) {
			completion(nil, nil);
			return;
		}
		[strongSelf administratorRightsOfUser:myId
							  inGroup:chatId
						   completion:^(NSDictionary *rights, NSString *status,
							   BOOL canBeEdited, NSString *customTitle) {
							   completion(rights, status);
						   }];
	}];
}

- (void)groupMemberCount:(int64_t)chatId completion:(void (^)(NSInteger))completion {
	[self groupInfoForChat:chatId completion:^(NSDictionary *info) {
		if (completion)
			completion([info[@"memberCount"] integerValue]);
	}];
}

- (void)addMembers:(NSArray *)userIds
		   toGroup:(int64_t)chatId
		completion:(void (^)(NSArray *, NSString *))completion {
	if (userIds.count == 0) {
		if (completion)
			completion(@[], nil);
		return;
	}
	NSDictionary *request;
	if (userIds.count == 1)
		request = @{@"@type" : @"addChatMember",
			@"chat_id" : @(chatId),
			@"user_id" : userIds[0],
			@"forward_limit" : @(100)};
	else
		request = @{@"@type" : @"addChatMembers",
			@"chat_id" : @(chatId),
			@"user_ids" : userIds};
	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, TGResultErrorMessage(result));
			return;
		}
		NSMutableArray *failed = [NSMutableArray array];
		for (NSDictionary *entry in TGArray(result[@"failed_to_add_members"])) {
			if (TGDict(entry) && entry[@"user_id"])
				[failed addObject:entry[@"user_id"]];
		}
		completion(failed, nil);
	}];
}

- (void)tg_setStatus:(NSDictionary *)status
			  ofUser:(int64_t)userId
			 inGroup:(int64_t)chatId
		  completion:(void (^)(BOOL ok))completion {
	[self tg_send:@{@"@type" : @"setChatMemberStatus",
		@"chat_id" : @(chatId),
		@"member_id" : TGUserSender(userId),
		@"status" : status}
		completion:completion];
}

- (void)removeMember:(int64_t)userId
		   fromGroup:(int64_t)chatId
		  completion:(void (^)(BOOL))completion {
	[self tg_setStatus:@{@"@type" : @"chatMemberStatusLeft"}
				ofUser:userId
			   inGroup:chatId
			completion:completion];
}

- (void)banMember:(int64_t)userId
		   inGroup:(int64_t)chatId
		 untilDate:(NSInteger)untilDate
	revokeMessages:(BOOL)revokeMessages
		completion:(void (^)(BOOL))completion {
	[self tg_send:@{
		@"@type" : @"banChatMember",
		@"chat_id" : @(chatId),
		@"member_id" : TGUserSender(userId),
		@"banned_until_date" : @(untilDate),
		@"revoke_messages" : @(revokeMessages),
	}
		completion:completion];
}

- (void)unbanMember:(int64_t)userId
			inGroup:(int64_t)chatId
		 completion:(void (^)(BOOL))completion {
	[self tg_setStatus:@{@"@type" : @"chatMemberStatusLeft"}
				ofUser:userId
			   inGroup:chatId
			completion:completion];
}

- (void)deleteAllMessagesFromUser:(int64_t)userId
						   inGroup:(int64_t)chatId
						completion:(void (^)(BOOL))completion {
	[self tg_send:@{@"@type" : @"deleteChatMessagesBySender",
		@"chat_id" : @(chatId),
		@"sender_id" : TGUserSender(userId)}
		completion:completion];
}

- (void)restrictMember:(int64_t)userId
			   inGroup:(int64_t)chatId
		   permissions:(NSDictionary *)permissions
			 untilDate:(NSInteger)untilDate
			completion:(void (^)(BOOL))completion {
	[self tg_setStatus:@{
		@"@type" : @"chatMemberStatusRestricted",
		@"is_member" : @YES,
		@"restricted_until_date" : @(untilDate),
		@"permissions" : TGBuildFlags(permissions ?: @{}, TGPermissionKeys(),
			@"chatPermissions"),
	}
				ofUser:userId
			   inGroup:chatId
			completion:completion];
}

#pragma mark - administrators

- (void)administratorsInGroup:(int64_t)chatId
				   completion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChatAdministrators", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			TGClient *strongSelf = weakSelf;
			if (!strongSelf || TGResultIsError(result)) {
				completion(nil);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			for (NSDictionary *admin in TGArray(result[@"administrators"])) {
				if (!TGDict(admin))
					continue;
				int64_t userId = [admin[@"user_id"] longLongValue];
				NSDictionary *flat = @{
					@"id" : @(userId),
					@"name" : [strongSelf nameForUserId:userId] ?: @"",
					@"customTitle" : TGString(admin[@"custom_title"]),
					@"isOwner" : @([admin[@"is_owner"] boolValue]),
					@"canBeEdited" : @([admin[@"can_be_edited"] boolValue]),
				};
				if ([admin[@"is_owner"] boolValue])
					[out insertObject:flat atIndex:0];
				else
					[out addObject:flat];
			}
			completion(out);
		}];
}

- (void)promoteMember:(int64_t)userId
			  inGroup:(int64_t)chatId
			   rights:(NSDictionary *)rights
		  customTitle:(NSString *)customTitle
		   completion:(void (^)(BOOL statusOk, BOOL tagOk))completion {
	__weak typeof(self) weakSelf = self;
	[self tg_setStatus:@{
		@"@type" : @"chatMemberStatusAdministrator",
		@"can_be_edited" : @YES,
		@"rights" : TGBuildFlags(rights ?: @{}, TGAdminRightKeys(),
			@"chatAdministratorRights"),
	}
				ofUser:userId
			   inGroup:chatId completion:^(BOOL statusOk) {
				   if (!statusOk || !customTitle) {
					   if (completion)
						   completion(statusOk, YES);
					   return;
				   }
				   [weakSelf setMemberTag:customTitle forUser:userId inGroup:chatId
							   completion:^(BOOL tagOk) {
								   if (completion)
									   completion(statusOk, tagOk);
							   }];
			   }];
}

- (void)setMemberTag:(NSString *)tag
			 forUser:(int64_t)userId
			 inGroup:(int64_t)chatId
		  completion:(void (^)(BOOL))completion {
	NSString *value = tag ?: @"";
	if (value.length > 16)
		value = TGSafeSubstringToIndex(value, 16);
	[self tg_send:@{@"@type" : @"setChatMemberTag",
		@"chat_id" : @(chatId),
		@"user_id" : @(userId),
		@"tag" : value}
		completion:completion];
}

- (void)dismissAdmin:(int64_t)userId
			 inGroup:(int64_t)chatId
		  completion:(void (^)(BOOL))completion {
	[self tg_setStatus:@{@"@type" : @"chatMemberStatusMember",
		@"member_until_date" : @(0)}
				ofUser:userId
			   inGroup:chatId
			completion:completion];
}

- (void)transferOwnershipOfGroup:(int64_t)chatId
						  toUser:(int64_t)userId
						password:(NSString *)password
					  completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{@"@type" : @"transferChatOwnership",
		@"chat_id" : @(chatId),
		@"user_id" : @(userId),
		@"password" : password ?: @""}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(NO, TGResultErrorMessage(result));
				return;
			}
			completion(YES, nil);
		}];
}

- (void)canTransferOwnershipWithCompletion:(void (^)(NSString *, NSInteger))completion {
	[self request:@{@"@type" : @"canTransferOwnership"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(@"ok", 0);
				return;
			}
			NSString *type = TGString(TGDict(result)[@"@type"]);
			if ([type isEqualToString:@"canTransferOwnershipResultPasswordNeeded"]) {
				completion(@"passwordNeeded", 0);
			} else if ([type isEqualToString:@"canTransferOwnershipResultPasswordTooFresh"]) {
				completion(@"passwordTooFresh", [result[@"retry_after"] integerValue]);
			} else if ([type isEqualToString:@"canTransferOwnershipResultSessionTooFresh"]) {
				completion(@"sessionTooFresh", [result[@"retry_after"] integerValue]);
			} else {
				completion(@"ok", 0);
			}
		}];
}

- (void)ownerAfterLeavingGroup:(int64_t)chatId
					completion:(void (^)(NSString *name))completion {
	[self request:@{@"@type" : @"getChatOwnerAfterLeaving", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (![result[@"@type"] isEqualToString:@"user"]) {
				completion(nil);
				return;
			}
			NSString *name = [[NSString stringWithFormat:@"%@ %@",
				result[@"first_name"] ?: @"", result[@"last_name"] ?: @""]
				stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			completion(name.length ? name : nil);
		}];
}

#pragma mark - default permissions

- (void)defaultPermissionsInGroup:(int64_t)chatId
					   completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			if (!completion)
				return;
			if (TGResultIsError(chat)) {
				completion(nil);
				return;
			}
			completion(TGReadFlags(TGDict(chat[@"permissions"]) ?: @{}, TGPermissionKeys()));
		}];
}

- (void)setDefaultPermissions:(NSDictionary *)permissions
					  inGroup:(int64_t)chatId
				   completion:(void (^)(BOOL))completion {
	[self tg_send:@{@"@type" : @"setChatPermissions",
		@"chat_id" : @(chatId),
		@"permissions" : TGBuildFlags(permissions ?: @{}, TGPermissionKeys(),
			@"chatPermissions")}
		completion:completion];
}

#pragma mark - public groups

- (void)checkGroupUsername:(NSString *)username
				   forChat:(int64_t)chatId
				completion:(void (^)(NSString *))completion {
	[self request:@{@"@type" : @"checkChatUsername",
		@"chat_id" : @(chatId),
		@"username" : username ?: @""}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			NSString *type = TGString(TGDict(result)[@"@type"]);
			if ([type isEqualToString:@"checkChatUsernameResultOk"])
				completion(@"ok");
			else if ([type isEqualToString:@"checkChatUsernameResultUsernameInvalid"])
				completion(@"invalid");
			else if ([type isEqualToString:@"checkChatUsernameResultUsernameOccupied"])
				completion(@"occupied");
			else if ([type isEqualToString:@"checkChatUsernameResultUsernamePurchasable"])
				completion(@"purchasable");
			else if ([type isEqualToString:@"checkChatUsernameResultPublicChatsTooMany"])
				completion(@"too-many");
			else if ([type isEqualToString:@"checkChatUsernameResultPublicGroupsUnavailable"])
				completion(@"unavailable");
			else
				completion(@"error");
		}];
}

- (void)setGroupChat:(int64_t)chatId username:(NSString *)username
		  completion:(void (^)(BOOL))completion {
	[self tg_supergroupToggle:@"setSupergroupUsername"
						 chat:chatId
					   fields:@{@"username" : username ?: @""}
				   completion:completion];
}

- (void)setGroupChat:(int64_t)chatId username:(NSString *)username
			  active:(BOOL)active
		  completion:(void (^)(BOOL ok, NSString *errorMessage))completion {
	__weak typeof(self) weakSelf = self;
	[self tg_group:chatId completion:^(NSString *kind, NSNumber *groupId, NSDictionary *chat) {
		if (![kind isEqualToString:@"super"]) {
			if (completion)
				completion(NO, nil);
			return;
		}
		[weakSelf request:@{
			@"@type" : @"toggleSupergroupUsernameIsActive",
			@"supergroup_id" : groupId,
			@"username" : username ?: @"",
			@"is_active" : @(active),
		} completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(NO, TGResultErrorMessage(result));
				return;
			}
			completion(YES, nil);
		}];
	}];
}

- (void)reorderUsernames:(NSArray *)usernames forGroup:(int64_t)chatId
			  completion:(void (^)(BOOL ok, NSString *errorMessage))completion {
	__weak typeof(self) weakSelf = self;
	[self tg_group:chatId completion:^(NSString *kind, NSNumber *groupId, NSDictionary *chat) {
		if (![kind isEqualToString:@"super"]) {
			if (completion)
				completion(NO, nil);
			return;
		}
		[weakSelf request:@{
			@"@type" : @"reorderSupergroupActiveUsernames",
			@"supergroup_id" : groupId,
			@"usernames" : usernames ?: @[],
		} completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(NO, TGResultErrorMessage(result));
				return;
			}
			completion(YES, nil);
		}];
	}];
}

- (void)setGroup:(int64_t)chatId unrestrictBoostCount:(NSInteger)count
			  completion:(void (^)(BOOL))completion {
	NSInteger clamped = count < 0 ? 0 : (count > 8 ? 8 : count);
	[self tg_supergroupToggle:@"setSupergroupUnrestrictBoostCount"
						 chat:chatId
					   fields:@{@"unrestrict_boost_count" : @(clamped)}
				   completion:completion];
}

- (void)setGroup:(int64_t)chatId hasAutomaticTranslation:(BOOL)enabled
				 completion:(void (^)(BOOL))completion {
	[self tg_supergroupToggle:@"toggleSupergroupHasAutomaticTranslation"
						 chat:chatId
					   fields:@{@"has_automatic_translation" : @(enabled)}
				   completion:completion];
}

- (void)setGroup:(int64_t)chatId mainProfileTab:(NSString *)tab
		completion:(void (^)(BOOL))completion {
	NSString *name = tab.lowercaseString;
	if (!name.length) {
		if (completion)
			completion(NO);
		return;
	}
	NSString *type = [NSString stringWithFormat:@"profileTab%@",
		TGStringWithFirstCharacterUppercased(name)];
	[self tg_supergroupToggle:@"setSupergroupMainProfileTab"
						 chat:chatId
					   fields:@{@"main_profile_tab" : @{@"@type" : type}}
				   completion:completion];
}

- (void)createdPublicChatsWithCompletion:(void (^)(NSArray *, BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getCreatedPublicChats",
		@"type" : @{@"@type" : @"publicChatTypeHasUsername"}}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			TGClient *strongSelf = weakSelf;
			if (!strongSelf || TGResultIsError(result)) {
				completion(@[], YES);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			for (NSNumber *chatId in TGArray(result[@"chat_ids"])) {
				NSDictionary *info = strongSelf.chatsById[chatId];
				[out addObject:@{@"id" : chatId,
					@"title" : TGString(info[@"title"])}];
			}
			completion(out, NO);
		}];
}

#pragma mark - invite links

- (void)tg_link:(NSDictionary *)request completion:(void (^)(NSDictionary *link))completion {
	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSDictionary *flat = TGFlattenInviteLink(result);
		if (!flat) {
			NSArray *links = TGArray(result[@"invite_links"]);
			flat = links.count ? TGFlattenInviteLink(links[0]) : nil;
		}
		completion(flat);
	}];
}

- (void)primaryInviteLinkForGroup:(int64_t)chatId
					   completion:(void (^)(NSDictionary *))completion {
	__weak typeof(self) weakSelf = self;
	[self groupInfoForChat:chatId completion:^(NSDictionary *info) {
		NSString *existing = TGString(info[@"inviteLink"]);
		if (existing.length) {
			if (completion)
				completion(@{@"link" : existing,
					@"isPrimary" : @YES});
			return;
		}
		[weakSelf tg_link:@{@"@type" : @"replacePrimaryChatInviteLink",
			@"chat_id" : @(chatId)}
			   completion:completion];
	}];
}

- (void)replacePrimaryInviteLinkForGroup:(int64_t)chatId
							  completion:(void (^)(NSDictionary *))completion {
	[self tg_link:@{@"@type" : @"replacePrimaryChatInviteLink", @"chat_id" : @(chatId)}
		completion:completion];
}

- (void)editInviteLink:(NSString *)inviteLink
			   inGroup:(int64_t)chatId
				  name:(NSString *)name
		expirationDate:(NSInteger)expirationDate
		   memberLimit:(NSInteger)memberLimit
	createsJoinRequest:(BOOL)createsJoinRequest
			completion:(void (^)(NSDictionary *))completion {
	[self tg_link:@{
		@"@type" : @"editChatInviteLink",
		@"chat_id" : @(chatId),
		@"invite_link" : inviteLink ?: @"",
		@"name" : name ?: @"",
		@"expiration_date" : @(expirationDate),
		@"member_limit" : @(createsJoinRequest ? 0 : memberLimit),
		@"creates_join_request" : @(createsJoinRequest),
	}
		completion:completion];
}

- (void)revokeInviteLink:(NSString *)inviteLink
				 inGroup:(int64_t)chatId
			  completion:(void (^)(NSDictionary *))completion {
	[self tg_link:@{@"@type" : @"revokeChatInviteLink",
		@"chat_id" : @(chatId),
		@"invite_link" : inviteLink ?: @""}
		completion:completion];
}

- (void)membersJoinedViaInviteLink:(NSString *)inviteLink
						   inGroup:(int64_t)chatId
							 limit:(NSInteger)limit
						completion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"getChatInviteLinkMembers",
		@"chat_id" : @(chatId),
		@"invite_link" : inviteLink ?: @"",
		@"only_with_expired_subscription" : @NO,
		@"limit" : @(limit > 0 ? limit : 50),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		TGClient *strongSelf = weakSelf;
		NSMutableArray *out = [NSMutableArray array];
		if (strongSelf && !TGResultIsError(result)) {
			for (NSDictionary *member in TGArray(result[@"members"])) {
				if (!TGDict(member))
					continue;
				int64_t userId = [member[@"user_id"] longLongValue];
				[out addObject:@{
					@"id" : @(userId),
					@"name" : [strongSelf nameForUserId:userId] ?: @"",
					@"joinedDate" : member[@"joined_chat_date"] ?: @(0),
					@"approverUserId" : member[@"approver_user_id"] ?: @(0),
				}];
			}
		}
		completion(out);
	}];
}

- (void)inviteLinkCountsInGroup:(int64_t)chatId
					 completion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChatInviteLinkCounts", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			TGClient *strongSelf = weakSelf;
			NSMutableArray *out = [NSMutableArray array];
			if (strongSelf && !TGResultIsError(result)) {
				int64_t myId = [strongSelf.me[@"id"] longLongValue];
				for (NSDictionary *entry in TGArray(result[@"invite_link_counts"])) {
					if (!TGDict(entry))
						continue;
					int64_t userId = [entry[@"user_id"] longLongValue];
					[out addObject:@{
						@"id" : @(userId),
						@"isMe" : @(userId == myId),
						@"name" : [strongSelf nameForUserId:userId] ?: @"",
						@"linkCount" : entry[@"invite_link_count"] ?: @(0),
						@"revokedLinkCount" : entry[@"revoked_invite_link_count"] ?: @(0),
					}];
				}
			}
			completion(out);
		}];
}

#pragma mark - joining

- (void)processJoinRequestFromUser:(int64_t)userId
						   inGroup:(int64_t)chatId
						   approve:(BOOL)approve
						completion:(void (^)(BOOL))completion {
	[self tg_send:@{@"@type" : @"processChatJoinRequest",
		@"chat_id" : @(chatId),
		@"user_id" : @(userId),
		@"approve" : @(approve)}
		completion:completion];
}

#pragma mark - group settings

- (void)setGroup:(int64_t)chatId allHistoryAvailable:(BOOL)available
			 completion:(void (^)(BOOL))completion {
	[self tg_supergroupToggle:@"toggleSupergroupIsAllHistoryAvailable"
						 chat:chatId
					   fields:@{@"is_all_history_available" : @(available)}
				   completion:completion];
}

- (void)setGroup:(int64_t)chatId hiddenMembers:(BOOL)hidden
	   completion:(void (^)(BOOL))completion {
	[self tg_supergroupToggle:@"toggleSupergroupHasHiddenMembers"
						 chat:chatId
					   fields:@{@"has_hidden_members" : @(hidden)}
				   completion:completion];
}

- (void)setGroup:(int64_t)chatId aggressiveAntiSpam:(BOOL)enabled
			completion:(void (^)(BOOL))completion {
	[self tg_supergroupToggle:@"toggleSupergroupHasAggressiveAntiSpamEnabled"
						 chat:chatId
					   fields:@{@"has_aggressive_anti_spam_enabled" : @(enabled)}
				   completion:completion];
}

- (void)reportSpamMessages:(NSArray *)messageIds inGroup:(int64_t)chatId
				completion:(void (^)(BOOL ok))completion {
	if (messageIds.count == 0) {
		if (completion)
			completion(NO);
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self tg_group:chatId completion:^(NSString *kind, NSNumber *groupId, NSDictionary *chat) {
		if (![kind isEqualToString:@"super"]) {
			if (completion)
				completion(NO);
			return;
		}
		[weakSelf tg_send:@{@"@type" : @"reportSupergroupSpam",
			@"supergroup_id" : groupId,
			@"message_ids" : messageIds}
			   completion:completion];
	}];
}

- (void)setGroup:(int64_t)chatId signMessages:(BOOL)sign
	  completion:(void (^)(BOOL))completion {
	[self tg_supergroupToggle:@"toggleSupergroupSignMessages"
						 chat:chatId
					   fields:@{@"sign_messages" : @(sign),
						   @"show_message_sender" : @(sign)}
				   completion:completion];
}

- (void)setGroup:(int64_t)chatId joinToSend:(BOOL)joinToSend
	joinByRequest:(BOOL)joinByRequest
	   completion:(void (^)(BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self tg_supergroupToggle:@"toggleSupergroupJoinToSendMessages"
						 chat:chatId
					   fields:@{@"join_to_send_messages" : @(joinToSend)}
				   completion:^(BOOL ok) {
					   [weakSelf tg_supergroupToggle:@"toggleSupergroupJoinByRequest"
						   chat:chatId
						   fields:@{@"join_by_request" : @(joinByRequest),
							   @"guard_bot_user_id" : @(0),
							   @"apply_to_invite_links" : @NO}
						   completion:^(BOOL second) {
							   if (completion)
								   completion(ok && second);
						   }];
				   }];
}

- (void)setGroup:(int64_t)chatId isForum:(BOOL)isForum
	  completion:(void (^)(BOOL))completion {
	[self tg_supergroupToggle:@"toggleSupergroupIsForum"
						 chat:chatId
					   fields:@{@"is_forum" : @(isForum),
						   @"has_forum_tabs" : @(isForum)}
				   completion:completion];
}

- (void)convertGroupToBroadcastGroup:(int64_t)chatId
						  completion:(void (^)(BOOL))completion {
	[self tg_supergroupToggle:@"toggleSupergroupIsBroadcastGroup"
						 chat:chatId
					   fields:nil
				   completion:completion];
}

- (void)setGroup:(int64_t)chatId stickerSetName:(NSString *)name
		completion:(void (^)(BOOL))completion {
	__weak typeof(self) weakSelf = self;
	if (name.length == 0) {
		[self tg_supergroupToggle:@"setSupergroupStickerSet"
							 chat:chatId
						   fields:@{@"sticker_set_id" : @(0)}
					   completion:completion];
		return;
	}
	[self request:@{@"@type" : @"searchStickerSet",
		@"name" : name,
		@"ignore_cache" : @NO}
		completion:^(NSDictionary *set) {
			if (TGResultIsError(set) || !set[@"id"]) {
				if (completion)
					completion(NO);
				return;
			}
			[weakSelf tg_supergroupToggle:@"setSupergroupStickerSet"
									 chat:chatId
								   fields:@{@"sticker_set_id" : set[@"id"]}
							   completion:completion];
		}];
}

#pragma mark - recent actions

#pragma mark - reporting

- (void)reportGroup:(int64_t)chatId
		   optionId:(NSString *)optionId
			   text:(NSString *)text
		 completion:(void (^)(NSString *, NSString *, NSArray *, NSString *, BOOL))completion {
	[self reportChat:chatId
		  messageIds:@[]
			optionId:optionId
				text:text
		  completion:^(NSDictionary *result) {
			  if (!completion)
				  return;
			  NSString *status = TGString(TGDict(result)[@"status"]);
			  if ([status isEqualToString:@"ok"]) {
				  completion(@"ok", nil, @[], nil, NO);
				  return;
			  }
			  if ([status isEqualToString:@"options"]) {
				  completion(@"options", TGString(result[@"title"]), TGArray(result[@"options"]), nil, NO);
				  return;
			  }
			  if ([status isEqualToString:@"text"]) {
				  completion(@"text", nil, @[], TGString(result[@"optionId"]), [result[@"optional"] boolValue]);
				  return;
			  }
			  if ([status isEqualToString:@"messages"]) {
				  completion(@"messagesRequired", nil, @[], nil, NO);
				  return;
			  }
			  completion(@"error", nil, @[], nil, NO);
		  }];
}

@end

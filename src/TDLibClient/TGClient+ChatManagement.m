#import "TGClient+ChatState.h"
#import "TGFlattenBusiness.h"
#import "TGChatPositions.h"
#import "TGTDLibInt64.h"
#import "TGClient+ChatManagement.h"
#import "TGMessageTopic.h"
#import "TGClient+Contacts.h"
#import "TGClient+Groups.h"
#import "TGClient+Forums.h"
#import "TGClient+Private.h"
#import "TGClient+SecretChats.h"
#import "TGDateUtils.h"
#import "TGFlattenChatManagement.h"
#import "TGFlattenContacts.h"
#import "TGFlattenForums.h"
#import "TGFlattenMessage.h"
#import "TGLocalization.h"
#import "TGRightsDiff.h"

static BOOL TGCMFailed(NSDictionary *result) {
	return ![result isKindOfClass:NSDictionary.class] ||
		[result[@"@type"] isEqualToString:@"error"];
}

static NSDictionary *TGCMDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSArray *TGCMArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : [NSArray array];
}

static BOOL TGCMChatIsForum(TGClient *client, int64_t chatId) {
	id value = client.chatsById[@(chatId)][@"isForum"];
	return [value isKindOfClass:NSNumber.class] && [value boolValue];
}

static NSString *TGCMString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSNumber *TGCMNumber(id value) {
	return [value isKindOfClass:NSNumber.class] ? value : [NSNumber numberWithInt:0];
}

static BOOL TGCMBool(id value) {
	return [value isKindOfClass:NSNumber.class] && [value boolValue];
}

static int64_t TGCMInt64(id value) {
	return TGTDLibInt64(value);
}

static NSDictionary *TGCMPermissionFields(void) {
	static NSDictionary *fields = nil;
	if (!fields)
		fields = @{
			@"sendMessages" : @"can_send_basic_messages",
			@"sendAudios" : @"can_send_audios",
			@"sendDocuments" : @"can_send_documents",
			@"sendPhotos" : @"can_send_photos",
			@"sendVideos" : @"can_send_videos",
			@"sendVideoNotes" : @"can_send_video_notes",
			@"sendVoiceNotes" : @"can_send_voice_notes",
			@"sendPolls" : @"can_send_polls",
			@"sendOther" : @"can_send_other_messages",
			@"addLinkPreviews" : @"can_add_link_previews",
			@"reactToMessages" : @"can_react_to_messages",
			@"editTag" : @"can_edit_tag",
			@"changeInfo" : @"can_change_info",
			@"inviteUsers" : @"can_invite_users",
			@"pinMessages" : @"can_pin_messages",
			@"createTopics" : @"can_create_topics",
		};
	return fields;
}

static NSDictionary *TGCMEventFilterFields(void) {
	static NSDictionary *fields = nil;
	if (!fields)
		fields = @{
			@"messageEdits" : @"message_edits",
			@"messageDeletions" : @"message_deletions",
			@"messagePins" : @"message_pins",
			@"memberJoins" : @"member_joins",
			@"memberLeaves" : @"member_leaves",
			@"memberInvites" : @"member_invites",
			@"memberPromotions" : @"member_promotions",
			@"memberRestrictions" : @"member_restrictions",
			@"memberTagChanges" : @"member_tag_changes",
			@"infoChanges" : @"info_changes",
			@"settingChanges" : @"setting_changes",
			@"inviteLinkChanges" : @"invite_link_changes",
			@"videoChatChanges" : @"video_chat_changes",
			@"forumChanges" : @"forum_changes",
			@"subscriptionExtensions" : @"subscription_extensions",
		};
	return fields;
}

@implementation TGClient (ChatManagement)

#pragma mark - shared plumbing

- (void)cm_run:(NSDictionary *)request completion:(void (^)(BOOL ok))completion {
	[self request:request completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGCMFailed(result));
	}];
}

- (void)cm_supergroupForChat:(int64_t)chatId
				  completion:(void (^)(int64_t supergroupId, NSDictionary *chat))completion {
	[self request:@{@"@type" : @"getChat", @"chat_id" : [NSNumber numberWithLongLong:chatId]}
		completion:^(NSDictionary *chat) {
			if (TGCMFailed(chat)) {
				if (completion)
					completion(0, nil);
				return;
			}
			NSDictionary *type = TGCMDict(chat[@"type"]);
			int64_t supergroupId = 0;
			if ([TGCMString(type[@"@type"]) isEqualToString:@"chatTypeSupergroup"])
				supergroupId = [TGCMNumber(type[@"supergroup_id"]) longLongValue];
			if (completion)
				completion(supergroupId, chat);
		}];
}

- (void)cm_toggleSupergroup:(NSString *)method
					   chat:(int64_t)chatId
					 fields:(NSDictionary *)fields
				 completion:(void (^)(BOOL ok))completion {
	__weak typeof(self) weakSelf = self;
	[self cm_supergroupForChat:chatId completion:^(int64_t supergroupId, NSDictionary *chat) {
		if (!supergroupId) {
			if (completion)
				completion(NO);
			return;
		}
		NSMutableDictionary *request = [NSMutableDictionary dictionaryWithDictionary:fields];
		request[@"@type"] = method;
		request[@"supergroup_id"] = [NSNumber numberWithLongLong:supergroupId];
		[weakSelf cm_run:request completion:completion];
	}];
}

#pragma mark - title, description, photo

- (void)setTitle:(NSString *)title forChat:(int64_t)chatId
	  completion:(void (^)(BOOL ok))completion {
	[self cm_run:@{
		@"@type" : @"setChatTitle",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"title" : title ?: @"",
	}
		completion:completion];
}

- (void)setDescription:(NSString *)description forChat:(int64_t)chatId
			completion:(void (^)(BOOL ok))completion {
	[self cm_run:@{
		@"@type" : @"setChatDescription",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"description" : description ?: @"",
	}
		completion:completion];
}

- (void)setPhotoAtPath:(NSString *)path forChat:(int64_t)chatId
			completion:(void (^)(BOOL ok))completion {
	if (!path.length) {
		if (completion)
			completion(NO);
		return;
	}
	[self cm_run:@{
		@"@type" : @"setChatPhoto",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"photo" : @{
			@"@type" : @"inputChatPhotoStatic",
			@"photo" : @{@"@type" : @"inputFileLocal", @"path" : path},
		},
	}
		completion:completion];
}

- (void)removePhotoForChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion {
	[self cm_run:@{
		@"@type" : @"setChatPhoto",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
	}
		completion:completion];
}

#pragma mark - management snapshot

- (void)managementInfoForChat:(int64_t)chatId
				   completion:(void (^)(NSDictionary *info))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChat", @"chat_id" : [NSNumber numberWithLongLong:chatId]}
		completion:^(NSDictionary *chat) {
			if (!completion)
				return;
			NSMutableDictionary *info = [NSMutableDictionary dictionary];
			info[@"isChannel"] = @NO;
			info[@"isSupergroup"] = @NO;
			info[@"isBasicGroup"] = @NO;
			info[@"supergroupId"] = @0;
			info[@"title"] = @"";
			info[@"description"] = @"";
			info[@"username"] = @"";
			info[@"inviteLink"] = @"";
			info[@"members"] = @0;
			info[@"admins"] = @0;
			info[@"restricted"] = @0;
			info[@"banned"] = @0;
			info[@"slowModeDelay"] = @0;
			info[@"isAllHistoryAvailable"] = @YES;
			info[@"hasHiddenMembers"] = @NO;
			info[@"canHideMembers"] = @NO;
			info[@"hasAntiSpam"] = @NO;
			info[@"canToggleAntiSpam"] = @NO;
			info[@"hasProtectedContent"] = @NO;
			info[@"signMessages"] = @NO;
			info[@"showMessageSender"] = @NO;
			info[@"joinByRequest"] = @NO;
			info[@"joinToSendMessages"] = @NO;
			info[@"isForum"] = @NO;
			info[@"pendingJoinRequests"] = @0;

			if (TGCMFailed(chat)) {
				completion(info);
				return;
			}
			info[@"title"] = TGCMString(chat[@"title"]);
			info[@"hasProtectedContent"] = @([TGCMNumber(chat[@"has_protected_content"]) boolValue]);
			NSDictionary *pending = TGCMDict(chat[@"pending_join_requests"]);
			if (pending)
				info[@"pendingJoinRequests"] = TGCMNumber(pending[@"total_count"]);

			NSDictionary *type = TGCMDict(chat[@"type"]);
			NSString *kind = TGCMString(type[@"@type"]);

			if ([kind isEqualToString:@"chatTypeBasicGroup"]) {
				info[@"isBasicGroup"] = @YES;
				NSNumber *groupId = TGCMNumber(type[@"basic_group_id"]);
				[weakSelf request:@{@"@type" : @"getBasicGroupFullInfo",
					@"basic_group_id" : groupId}
					   completion:^(NSDictionary *full) {
						   if (!TGCMFailed(full)) {
							   info[@"description"] = TGCMString(full[@"description"]);
							   info[@"canHideMembers"] = @([TGCMNumber(full[@"can_hide_members"]) boolValue]);
							   info[@"canToggleAntiSpam"] =
								   @([TGCMNumber(full[@"can_toggle_aggressive_anti_spam"]) boolValue]);
							   NSDictionary *link = TGCMDict(full[@"invite_link"]);
							   info[@"inviteLink"] = TGCMString(link[@"invite_link"]);
						   }
						   completion(info);
					   }];
				return;
			}

			if (![kind isEqualToString:@"chatTypeSupergroup"]) {
				completion(info);
				return;
			}

			info[@"isSupergroup"] = @YES;
			NSNumber *supergroupId = TGCMNumber(type[@"supergroup_id"]);
			info[@"supergroupId"] = supergroupId;
			[weakSelf request:@{@"@type" : @"getSupergroup", @"supergroup_id" : supergroupId}
				   completion:^(NSDictionary *group) {
					   if (!TGCMFailed(group)) {
						   info[@"isChannel"] = @([TGCMNumber(group[@"is_channel"]) boolValue]);
						   info[@"isForum"] = @([TGCMNumber(group[@"is_forum"]) boolValue]);
						   info[@"signMessages"] = @([TGCMNumber(group[@"sign_messages"]) boolValue]);
						   info[@"showMessageSender"] = @([TGCMNumber(group[@"show_message_sender"]) boolValue]);
						   info[@"joinByRequest"] = @([TGCMNumber(group[@"join_by_request"]) boolValue]);
						   info[@"joinToSendMessages"] = @([TGCMNumber(group[@"join_to_send_messages"]) boolValue]);
						   NSArray *usernames = TGCMArray(TGCMDict(group[@"usernames"])[@"active_usernames"]);
						   if (usernames.count && [usernames[0] isKindOfClass:NSString.class])
							   info[@"username"] = usernames[0];
					   }
					   [weakSelf request:@{@"@type" : @"getSupergroupFullInfo",
						   @"supergroup_id" : supergroupId}
							  completion:^(NSDictionary *full) {
								  if (!TGCMFailed(full)) {
									  info[@"description"] = TGCMString(full[@"description"]);
									  info[@"members"] = TGCMNumber(full[@"member_count"]);
									  info[@"admins"] = TGCMNumber(full[@"administrator_count"]);
									  info[@"restricted"] = TGCMNumber(full[@"restricted_count"]);
									  info[@"banned"] = TGCMNumber(full[@"banned_count"]);
									  info[@"slowModeDelay"] = TGCMNumber(full[@"slow_mode_delay"]);
									  info[@"isAllHistoryAvailable"] =
										  @([TGCMNumber(full[@"is_all_history_available"]) boolValue]);
									  info[@"hasHiddenMembers"] =
										  @([TGCMNumber(full[@"has_hidden_members"]) boolValue]);
									  info[@"canHideMembers"] =
										  @([TGCMNumber(full[@"can_hide_members"]) boolValue]);
									  info[@"hasAntiSpam"] =
										  @([TGCMNumber(full[@"has_aggressive_anti_spam_enabled"]) boolValue]);
									  info[@"canToggleAntiSpam"] =
										  @([TGCMNumber(full[@"can_toggle_aggressive_anti_spam"]) boolValue]);
									  NSDictionary *link = TGCMDict(full[@"invite_link"]);
									  info[@"inviteLink"] = TGCMString(link[@"invite_link"]);
								  }
								  completion(info);
							  }];
				   }];
		}];
}

#pragma mark - permissions

+ (NSArray *)permissionKeys {
	return @[ @"sendMessages", @"sendAudios", @"sendDocuments", @"sendPhotos",
		@"sendVideos", @"sendVideoNotes", @"sendVoiceNotes", @"sendPolls",
		@"sendOther", @"addLinkPreviews", @"reactToMessages", @"editTag",
		@"changeInfo", @"inviteUsers", @"pinMessages", @"createTopics" ];
}

- (void)permissionsForChat:(int64_t)chatId
				completion:(void (^)(NSDictionary *permissions, BOOL failed))completion {
	[self request:@{@"@type" : @"getChat", @"chat_id" : [NSNumber numberWithLongLong:chatId]}
		completion:^(NSDictionary *chat) {
			if (!completion)
				return;
			if (TGCMFailed(chat)) {
				completion(@{}, YES);
				return;
			}
			NSDictionary *raw = TGCMDict(chat[@"permissions"]);
			NSDictionary *fields = TGCMPermissionFields();
			NSMutableDictionary *out = [NSMutableDictionary dictionary];
			for (NSString *key in fields)
				out[key] = @([TGCMNumber(raw[fields[key]]) boolValue]);
			completion(out, NO);
		}];
}

- (void)setPermissions:(NSDictionary *)permissions forChat:(int64_t)chatId
			completion:(void (^)(BOOL ok))completion {
	NSDictionary *fields = TGCMPermissionFields();
	NSMutableDictionary *value = [NSMutableDictionary dictionary];
	value[@"@type"] = @"chatPermissions";
	for (NSString *key in fields)
		value[fields[key]] = @([TGCMNumber(permissions[key]) boolValue]);

	[self cm_run:@{
		@"@type" : @"setChatPermissions",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"permissions" : value,
	}
		completion:completion];
}

#pragma mark - slow mode

+ (NSArray *)slowModePresets {
	return @[ @0, @5, @10, @30, @60, @300, @900, @3600 ];
}

- (void)setSlowModeDelay:(NSInteger)seconds forChat:(int64_t)chatId
			  completion:(void (^)(BOOL ok))completion {
	NSInteger allowed = 0;
	for (NSNumber *preset in [TGClient slowModePresets]) {
		if ([preset integerValue] <= seconds)
			allowed = [preset integerValue];
	}
	[self cm_run:@{
		@"@type" : @"setChatSlowModeDelay",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"slow_mode_delay" : @(allowed),
	}
		completion:completion];
}

#pragma mark - supergroup switches

- (void)setChat:(int64_t)chatId allHistoryAvailable:(BOOL)available
			 completion:(void (^)(BOOL ok))completion {
	[self cm_toggleSupergroup:@"toggleSupergroupIsAllHistoryAvailable"
						 chat:chatId
					   fields:@{@"is_all_history_available" : @(available)}
				   completion:completion];
}

- (void)setChat:(int64_t)chatId joinByRequest:(BOOL)joinByRequest
	   completion:(void (^)(BOOL ok))completion {
	[self cm_toggleSupergroup:@"toggleSupergroupJoinByRequest"
						 chat:chatId
					   fields:@{@"join_by_request" : @(joinByRequest),
						   @"apply_to_invite_links" : @YES}
				   completion:completion];
}

- (void)setChat:(int64_t)chatId joinToSendMessages:(BOOL)joinToSend
			completion:(void (^)(BOOL ok))completion {
	[self cm_toggleSupergroup:@"toggleSupergroupJoinToSendMessages"
						 chat:chatId
					   fields:@{@"join_to_send_messages" : @(joinToSend)}
				   completion:completion];
}

- (void)setChat:(int64_t)chatId signMessages:(BOOL)sign showSender:(BOOL)showSender
	  completion:(void (^)(BOOL ok))completion {
	[self cm_toggleSupergroup:@"toggleSupergroupSignMessages"
						 chat:chatId
					   fields:@{@"sign_messages" : @(sign),
						   @"show_message_sender" : @(sign && showSender)}
				   completion:completion];
}

- (void)setChat:(int64_t)chatId protectedContent:(BOOL)protectedContent
		  completion:(void (^)(BOOL ok))completion {
	[self cm_run:@{
		@"@type" : @"toggleChatHasProtectedContent",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"has_protected_content" : @(protectedContent),
	}
		completion:completion];
}

- (void)setChat:(int64_t)chatId hiddenMembers:(BOOL)hidden
	   completion:(void (^)(BOOL ok))completion {
	[self cm_toggleSupergroup:@"toggleSupergroupHasHiddenMembers"
						 chat:chatId
					   fields:@{@"has_hidden_members" : @(hidden)}
				   completion:completion];
}

- (void)setChat:(int64_t)chatId antiSpamEnabled:(BOOL)enabled
		 completion:(void (^)(BOOL ok))completion {
	[self cm_toggleSupergroup:@"toggleSupergroupHasAggressiveAntiSpamEnabled"
						 chat:chatId
					   fields:@{@"has_aggressive_anti_spam_enabled" : @(enabled)}
				   completion:completion];
}

- (void)reportNotSpamMessages:(NSArray *)messageIds inChat:(int64_t)chatId
				   completion:(void (^)(NSArray *succeededMessageIds))completion {
	NSMutableArray *ids = [NSMutableArray array];
	for (id raw in TGCMArray(messageIds)) {
		if ([raw isKindOfClass:NSNumber.class])
			[ids addObject:raw];
	}
	if (!ids.count) {
		if (completion)
			completion(@[]);
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self cm_supergroupForChat:chatId completion:^(int64_t supergroupId, NSDictionary *chat) {
		if (!supergroupId) {
			if (completion)
				completion(@[]);
			return;
		}
		__block NSInteger remaining = (NSInteger)ids.count;
		NSMutableArray *succeeded = [NSMutableArray array];
		for (NSNumber *messageId in ids) {
			[weakSelf cm_run:@{
				@"@type" : @"reportSupergroupAntiSpamFalsePositive",
				@"supergroup_id" : [NSNumber numberWithLongLong:supergroupId],
				@"message_id" : [NSNumber numberWithLongLong:[messageId longLongValue]],
			} completion:^(BOOL ok) {
				if (ok)
					[succeeded addObject:messageId];
				remaining--;
				if (remaining <= 0 && completion)
					completion(succeeded);
			}];
		}
	}];
}

- (void)reportAntiSpamFalsePositiveForMessage:(int64_t)messageId
									   inChat:(int64_t)chatId
								   completion:(void (^)(BOOL ok))completion {
	[self cm_toggleSupergroup:@"reportSupergroupAntiSpamFalsePositive"
						 chat:chatId
					   fields:@{@"message_id" : [NSNumber numberWithLongLong:messageId]}
				   completion:completion];
}

#pragma mark - administrators and own rights

- (void)administratorsForChat:(int64_t)chatId
				   completion:(void (^)(NSArray *administrators))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChatAdministrators",
		@"chat_id" : [NSNumber numberWithLongLong:chatId]}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGCMFailed(result)) {
				completion(@[]);
				return;
			}
			NSMutableArray *owners = [NSMutableArray array];
			NSMutableArray *others = [NSMutableArray array];
			for (id raw in TGCMArray(result[@"administrators"])) {
				NSDictionary *entry = TGCMDict(raw);
				if (!entry)
					continue;
				NSNumber *userId = TGCMNumber(entry[@"user_id"]);
				BOOL isOwner = [TGCMNumber(entry[@"is_owner"]) boolValue];
				NSDictionary *flat = @{
					@"userId" : userId,
					@"name" : [weakSelf nameForUserId:[userId longLongValue]] ?: @"",
					@"customTitle" : TGCMString(entry[@"custom_title"]),
					@"isOwner" : @(isOwner),
					@"canBeEdited" : @([TGCMNumber(entry[@"can_be_edited"]) boolValue]),
				};
				[(isOwner ? owners : others) addObject:flat];
			}
			[owners addObjectsFromArray:others];
			completion(owners);
		}];
}

- (void)myRightsInChat:(int64_t)chatId
			completion:(void (^)(NSDictionary *rights))completion {
	int64_t myId = [TGCMNumber(self.me[@"id"]) longLongValue];
	if (!myId) {
		if (completion)
			completion(TGCMFlatRights(nil, NO, NO, @""));
		return;
	}
	[self request:@{
		@"@type" : @"getChatMember",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"member_id" : @{@"@type" : @"messageSenderUser",
			@"user_id" : [NSNumber numberWithLongLong:myId]},
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGCMFailed(result)) {
			completion(TGCMFlatRights(nil, NO, NO, @""));
			return;
		}
		NSDictionary *status = TGCMDict(result[@"status"]);
		NSString *type = TGCMString(status[@"@type"]);
		NSString *title = TGCMString(result[@"tag"]);
		if ([type isEqualToString:@"chatMemberStatusCreator"]) {
			completion(TGCMFlatRights(status, YES, YES, title));
			return;
		}
		if ([type isEqualToString:@"chatMemberStatusAdministrator"]) {
			completion(TGCMFlatRights(TGCMDict(status[@"rights"]), NO, YES, title));
			return;
		}
		BOOL isMember = [type isEqualToString:@"chatMemberStatusMember"] ||
			[type isEqualToString:@"chatMemberStatusRestricted"];
		NSMutableDictionary *out =
			[NSMutableDictionary dictionaryWithDictionary:TGCMFlatRights(nil, NO, NO, title)];
		out[@"isMember"] = @(isMember);
		completion(out);
	}];
}

- (void)canManageInviteLinksInChat:(int64_t)chatId
						completion:(void (^)(BOOL canManage))completion {
	[self myRightsInChat:chatId completion:^(NSDictionary *rights) {
		if (!completion)
			return;
		BOOL owner = [TGCMNumber(rights[@"isOwner"]) boolValue];
		BOOL invite = [TGCMNumber(rights[@"canInviteUsers"]) boolValue];
		completion(owner || invite);
	}];
}

- (void)convertChatToBroadcastGroup:(int64_t)chatId
						 completion:(void (^)(BOOL ok))completion {
	[self cm_toggleSupergroup:@"toggleSupergroupIsBroadcastGroup"
						 chat:chatId
					   fields:@{}
				   completion:completion];
}

#pragma mark - invite links

static NSDictionary *TGCMFlatInviteLink(id value) {
	NSDictionary *link = TGCMDict(value);
	if (!link)
		return nil;
	NSDictionary *pricing = TGCMDict(link[@"subscription_pricing"]);
	NSMutableDictionary *out = [@{
		@"link" : TGCMString(link[@"invite_link"]),
		@"name" : TGCMString(link[@"name"]),
		@"creatorId" : TGCMNumber(link[@"creator_user_id"]),
		@"date" : TGCMNumber(link[@"date"]),
		@"editDate" : TGCMNumber(link[@"edit_date"]),
		@"expirationDate" : TGCMNumber(link[@"expiration_date"]),
		@"memberLimit" : TGCMNumber(link[@"member_limit"]),
		@"memberCount" : TGCMNumber(link[@"member_count"]),
		@"pendingRequests" : TGCMNumber(link[@"pending_join_request_count"]),
		@"requiresApproval" : @([TGCMNumber(link[@"creates_join_request"]) boolValue]),
		@"isPrimary" : @([TGCMNumber(link[@"is_primary"]) boolValue]),
		@"isRevoked" : @([TGCMNumber(link[@"is_revoked"]) boolValue]),
	} mutableCopy];
	if (pricing) {
		out[@"subscriptionStarCount"] = TGCMNumber(pricing[@"star_count"]);
		out[@"subscriptionPeriod"] = TGCMNumber(pricing[@"period"]);
	}
	return out;
}

- (void)cm_requestLink:(NSDictionary *)request
			completion:(void (^)(NSDictionary *link))completion {
	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGCMFailed(result)) {
			completion(nil);
			return;
		}
		completion(TGCMFlatInviteLink(result));
	}];
}

- (void)primaryInviteLinkForChat:(int64_t)chatId
					  completion:(void (^)(NSString *link))completion {
	[self managementInfoForChat:chatId completion:^(NSDictionary *info) {
		if (completion)
			completion(TGCMString(info[@"inviteLink"]));
	}];
}

- (void)replacePrimaryInviteLinkForChat:(int64_t)chatId
							 completion:(void (^)(NSDictionary *link))completion {
	[self cm_requestLink:@{@"@type" : @"replacePrimaryChatInviteLink",
		@"chat_id" : [NSNumber numberWithLongLong:chatId]}
			  completion:completion];
}

- (void)inviteLinksForChat:(int64_t)chatId revoked:(BOOL)revoked
				completion:(void (^)(NSArray *links))completion {
	NSNumber *creator = TGCMNumber(self.me[@"id"]);
	[self request:@{
		@"@type" : @"getChatInviteLinks",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"creator_user_id" : creator,
		@"is_revoked" : @(revoked),
		@"offset_date" : @0,
		@"offset_invite_link" : @"",
		@"limit" : @100,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGCMFailed(result)) {
			completion(nil);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (id raw in TGCMArray(result[@"invite_links"])) {
			NSDictionary *flat = TGCMFlatInviteLink(raw);
			if (flat)
				[out addObject:flat];
		}
		completion(out);
	}];
}

- (void)createInviteLinkForChat:(int64_t)chatId
						   name:(NSString *)name
				 expirationDate:(NSInteger)expirationDate
					memberLimit:(NSInteger)memberLimit
			   requiresApproval:(BOOL)requiresApproval
					 completion:(void (^)(NSDictionary *link))completion {
	NSInteger limit = requiresApproval ? 0 : memberLimit;
	[self cm_requestLink:@{
		@"@type" : @"createChatInviteLink",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"name" : name ?: @"",
		@"expiration_date" : @(expirationDate),
		@"member_limit" : @(limit),
		@"creates_join_request" : @(requiresApproval),
	}
			  completion:completion];
}

- (void)editInviteLink:(NSString *)link
				inChat:(int64_t)chatId
				  name:(NSString *)name
		expirationDate:(NSInteger)expirationDate
		   memberLimit:(NSInteger)memberLimit
	  requiresApproval:(BOOL)requiresApproval
			completion:(void (^)(NSDictionary *link))completion {
	if (!link.length) {
		if (completion)
			completion(nil);
		return;
	}
	NSInteger limit = requiresApproval ? 0 : memberLimit;
	[self cm_requestLink:@{
		@"@type" : @"editChatInviteLink",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"invite_link" : link,
		@"name" : name ?: @"",
		@"expiration_date" : @(expirationDate),
		@"member_limit" : @(limit),
		@"creates_join_request" : @(requiresApproval),
	}
			  completion:completion];
}

- (void)createSubscriptionInviteLinkForChat:(int64_t)chatId
									   name:(NSString *)name
								  starCount:(int64_t)starCount
								 completion:(void (^)(NSDictionary *link))completion {
	[self cm_requestLink:@{
		@"@type" : @"createChatSubscriptionInviteLink",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"name" : name ?: @"",
		@"subscription_pricing" : @{
			@"@type" : @"starSubscriptionPricing",
			@"period" : @(2592000),
			@"star_count" : [NSNumber numberWithLongLong:starCount],
		},
	}
			  completion:completion];
}

- (void)editSubscriptionInviteLink:(NSString *)link
							inChat:(int64_t)chatId
							  name:(NSString *)name
						completion:(void (^)(NSDictionary *link))completion {
	if (!link.length) {
		if (completion)
			completion(nil);
		return;
	}
	[self cm_requestLink:@{
		@"@type" : @"editChatSubscriptionInviteLink",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"invite_link" : link,
		@"name" : name ?: @"",
	}
			  completion:completion];
}

- (void)inviteLink:(NSString *)link inChat:(int64_t)chatId
		completion:(void (^)(NSDictionary *info))completion {
	if (!link.length) {
		if (completion)
			completion(nil);
		return;
	}
	[self cm_requestLink:@{@"@type" : @"getChatInviteLink",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"invite_link" : link}
			  completion:completion];
}

- (void)revokeInviteLink:(NSString *)link inChat:(int64_t)chatId
			  completion:(void (^)(BOOL ok))completion {
	if (!link.length) {
		if (completion)
			completion(NO);
		return;
	}
	[self cm_run:@{@"@type" : @"revokeChatInviteLink",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"invite_link" : link}
		completion:completion];
}

- (void)deleteRevokedInviteLink:(NSString *)link inChat:(int64_t)chatId
					 completion:(void (^)(BOOL ok))completion {
	if (!link.length) {
		if (completion)
			completion(NO);
		return;
	}
	[self cm_run:@{@"@type" : @"deleteRevokedChatInviteLink",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"invite_link" : link}
		completion:completion];
}

- (void)deleteAllRevokedInviteLinksInChat:(int64_t)chatId
							   completion:(void (^)(BOOL ok))completion {
	[self cm_run:@{@"@type" : @"deleteAllRevokedChatInviteLinks",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"creator_user_id" : TGCMNumber(self.me[@"id"])}
		completion:completion];
}

- (void)membersJoinedViaInviteLink:(NSString *)link
							inChat:(int64_t)chatId
							 limit:(NSInteger)limit
						completion:(void (^)(NSArray *members, NSInteger total))completion {
	[self membersJoinedViaInviteLink:link
							 inChat:chatId
					   afterUserId:0
					  afterJoinDate:0
							  limit:limit
						 completion:completion];
}

- (void)membersJoinedViaInviteLink:(NSString *)link
							inChat:(int64_t)chatId
					   afterUserId:(int64_t)afterUserId
					 afterJoinDate:(NSInteger)afterJoinDate
							 limit:(NSInteger)limit
						completion:(void (^)(NSArray *members, NSInteger total))completion {
	if (!link.length) {
		if (completion)
			completion(@[], 0);
		return;
	}
	NSMutableDictionary *query = [NSMutableDictionary dictionaryWithDictionary:@{
		@"@type" : @"getChatInviteLinkMembers",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"invite_link" : link,
		@"only_with_expired_subscription" : @NO,
		@"limit" : @(limit > 0 ? limit : 50),
	}];
	if (afterUserId != 0)
		query[@"offset_member"] = @{
			@"@type" : @"chatInviteLinkMember",
			@"user_id" : [NSNumber numberWithLongLong:afterUserId],
			@"joined_chat_date" : @(afterJoinDate),
			@"approver_user_id" : @0,
		};
	__weak typeof(self) weakSelf = self;
	[self request:query completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGCMFailed(result)) {
			completion(@[], 0);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (id raw in TGCMArray(result[@"members"])) {
			NSDictionary *entry = TGCMDict(raw);
			if (!entry)
				continue;
			NSNumber *userId = TGCMNumber(entry[@"user_id"]);
			[out addObject:@{
				@"userId" : userId,
				@"name" : [weakSelf nameForUserId:[userId longLongValue]] ?: @"",
				@"date" : TGCMNumber(entry[@"joined_chat_date"]),
				@"approverId" : TGCMNumber(entry[@"approver_user_id"]),
			}];
		}
		completion(out, [TGCMNumber(result[@"total_count"]) integerValue]);
	}];
}

- (void)membersJoinedViaPrimaryInviteLinkInChat:(int64_t)chatId
										  limit:(NSInteger)limit
									 completion:(void (^)(NSArray *members, NSInteger total))completion {
	__weak typeof(self) weakSelf = self;
	[self primaryInviteLinkForChat:chatId completion:^(NSString *link) {
		if (!link.length) {
			if (completion)
				completion(@[], 0);
			return;
		}
		[weakSelf membersJoinedViaInviteLink:link inChat:chatId limit:limit completion:completion];
	}];
}

#pragma mark - joining by link

- (void)previewInviteLink:(NSString *)link
			   completion:(void (^)(NSDictionary *info))completion {
	if (!link.length) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{@"@type" : @"checkChatInviteLink", @"invite_link" : link}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGCMFailed(result)) {
				completion(nil);
				return;
			}
			NSString *kind = TGCMString(TGCMDict(result[@"type"])[@"@type"]);
			BOOL isChannel = [kind isEqualToString:@"inviteLinkChatTypeChannel"];
			NSMutableDictionary *info = [NSMutableDictionary dictionary];
			info[@"chatId"] = TGCMNumber(result[@"chat_id"]);
			info[@"title"] = TGCMString(result[@"title"]);
			info[@"description"] = TGCMString(result[@"description"]);
			info[@"memberCount"] = TGCMNumber(result[@"member_count"]);
			info[@"requiresApproval"] = @([TGCMNumber(result[@"creates_join_request"]) boolValue]);
			info[@"isPublic"] = @([TGCMNumber(result[@"is_public"]) boolValue]);
			info[@"isChannel"] = @(isChannel);
			NSNumber *photoId = TGCMDict(TGCMDict(result[@"photo"])[@"small"])[@"id"];
			if ([photoId isKindOfClass:NSNumber.class])
				info[@"photoFileId"] = photoId;
			completion(info);
		}];
}

- (void)joinChatByInviteLink:(NSString *)link
				  completion:(void (^)(int64_t chatId, BOOL requestSent, NSString *errorCode))completion {
	if (!link.length) {
		if (completion)
			completion(0, NO, nil);
		return;
	}
	[self request:@{@"@type" : @"joinChatByInviteLink", @"invite_link" : link}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGCMFailed(result)) {
				completion(0, NO, TGCMString(result[@"message"]));
				return;
			}
			NSString *kind = TGCMString(result[@"@type"]);
			if ([kind isEqualToString:@"chatJoinResultRequestSent"]) {
				completion(0, YES, nil);
				return;
			}
			if ([kind isEqualToString:@"chatJoinResultGuardBotApprovalRequired"]) {
				completion(0, NO, @"GUARD_BOT_REQUIRED");
				return;
			}
			if ([kind isEqualToString:@"chatJoinResultDeclined"]) {
				completion(0, NO, @"GUARD_BOT_DECLINED");
				return;
			}
			completion([TGCMNumber(result[@"chat_id"]) longLongValue], NO, nil);
		}];
}

- (void)inactiveSupergroupChatsWithCompletion:(void (^)(NSArray *chats))completion {
	[self request:@{@"@type" : @"getInactiveSupergroupChats"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGCMFailed(result)) {
				completion(@[]);
				return;
			}
			NSArray *ids = TGCMArray(result[@"chat_ids"]);
			if (!ids.count) {
				completion(@[]);
				return;
			}
			NSMutableArray *chats = [NSMutableArray arrayWithCapacity:ids.count];
			for (NSInteger i = 0; i < ids.count; i++)
				[chats addObject:[NSNull null]];
			__block NSInteger remaining = (NSInteger)ids.count;
			for (NSInteger i = 0; i < ids.count; i++) {
				NSNumber *targetId = ids[i];
				NSInteger index = i;
				[self request:@{@"@type" : @"getChat", @"chat_id" : targetId}
					completion:^(NSDictionary *chat) {
						if (!TGCMFailed(chat)) {
							NSDictionary *supergroup = TGCMDict(chat[@"type"]);
							int64_t supergroupId = TGCMInt64(supergroup[@"supergroup_id"]);
							NSDictionary *lastMessage = TGCMDict(chat[@"last_message"]);
							chats[index] = @{
								@"id" : chat[@"id"] ?: targetId,
								@"title" : TGCMString(chat[@"title"]),
								@"supergroupId" : @(supergroupId),
								@"isChannel" : @(![supergroup[@"is_channel"] isKindOfClass:NSNull.class] &&
									[supergroup[@"is_channel"] boolValue]),
								@"lastActivityDate" : lastMessage[@"date"] ?: @0,
								@"memberCount" : chat[@"member_count"] ?: @0,
							};
						}
						remaining--;
						if (remaining <= 0 && completion) {
							NSMutableArray *cleaned = [NSMutableArray arrayWithCapacity:chats.count];
							for (id entry in chats)
								if ([entry isKindOfClass:NSDictionary.class])
									[cleaned addObject:entry];
							completion(cleaned);
						}
					}];
			}
		}];
}

- (void)leaveChatForJoinLimit:(int64_t)chatId completion:(void (^)(BOOL ok))completion {
	[self request:@{@"@type" : @"leaveChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGCMFailed(result));
		}];
}

#pragma mark - join requests

- (void)joinRequestsForChat:(int64_t)chatId
				 inviteLink:(NSString *)inviteLink
					  query:(NSString *)query
			  offsetRequest:(NSDictionary *)offsetRequest
					  limit:(NSInteger)limit
				 completion:(void (^)(NSArray *requests, NSInteger total, NSDictionary *nextOffset))completion {
	__weak typeof(self) weakSelf = self;
	NSMutableDictionary *payload = [@{
		@"@type" : @"getChatJoinRequests",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"invite_link" : inviteLink ?: @"",
		@"query" : query ?: @"",
		@"limit" : @(limit > 0 ? limit : 50),
	} mutableCopy];
	if (offsetRequest) {
		payload[@"offset_request"] = @{
			@"@type" : @"chatJoinRequest",
			@"user_id" : offsetRequest[@"userId"] ?: @0,
			@"date" : offsetRequest[@"date"] ?: @0,
			@"bio" : offsetRequest[@"bio"] ?: @"",
		};
	}
	[self request:payload completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGCMFailed(result)) {
			completion(nil, 0, nil);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (id raw in TGCMArray(result[@"requests"])) {
			NSDictionary *entry = TGCMDict(raw);
			if (!entry)
				continue;
			NSNumber *userId = TGCMNumber(entry[@"user_id"]);
			[out addObject:@{
				@"userId" : userId,
				@"name" : [weakSelf nameForUserId:[userId longLongValue]] ?: @"",
				@"bio" : TGCMString(entry[@"bio"]),
				@"date" : TGCMNumber(entry[@"date"]),
			}];
		}
		completion(out, [TGCMNumber(result[@"total_count"]) integerValue], out.lastObject);
	}];
}

- (void)processJoinRequestFromUser:(int64_t)userId
							inChat:(int64_t)chatId
						   approve:(BOOL)approve
						completion:(void (^)(BOOL ok))completion {
	[self cm_run:@{
		@"@type" : @"processChatJoinRequest",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"user_id" : [NSNumber numberWithLongLong:userId],
		@"approve" : @(approve),
	}
		completion:completion];
}

- (void)processAllJoinRequestsInChat:(int64_t)chatId
						  inviteLink:(NSString *)inviteLink
							 approve:(BOOL)approve
						  completion:(void (^)(BOOL ok))completion {
	[self cm_run:@{
		@"@type" : @"processChatJoinRequests",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"invite_link" : inviteLink ?: @"",
		@"approve" : @(approve),
	}
		completion:completion];
}

- (void)pendingJoinRequestCountForChat:(int64_t)chatId
							completion:(void (^)(NSInteger count, BOOL failed))completion {
	[self request:@{@"@type" : @"getChat", @"chat_id" : [NSNumber numberWithLongLong:chatId]}
		completion:^(NSDictionary *chat) {
			if (!completion)
				return;
			if (TGCMFailed(chat)) {
				completion(0, YES);
				return;
			}
			NSDictionary *pending = TGCMDict(chat[@"pending_join_requests"]);
			completion([TGCMNumber(pending[@"total_count"]) integerValue], NO);
		}];
}

#pragma mark - event log

static NSInteger TGCMAdminRightsDiffCount(NSDictionary *oldRights, NSDictionary *newRights) {
	return TGRightsDiffCount(oldRights, newRights, TGAdminRightsDiffFields());
}

static NSInteger TGCMPermissionsDiffCount(NSDictionary *oldPermissions, NSDictionary *newPermissions) {
	return TGRightsDiffCount(oldPermissions, newPermissions, [TGCMPermissionFields() allValues]);
}

static NSString *TGCMEventTargetName(TGClient *client, NSString *action, NSDictionary *body) {
	int64_t targetUserId = 0;
	BOOL targetIsChat = NO;
	if ([action isEqualToString:@"MemberInvited"] ||
		[action isEqualToString:@"MemberPromoted"] ||
		[action isEqualToString:@"MemberTagChanged"]) {
		targetUserId = TGCMInt64(body[@"user_id"]);
	} else if ([action isEqualToString:@"MemberRestricted"]) {
		[client parseMessageSender:TGCMDict(body[@"member_id"]) senderId:&targetUserId isChat:&targetIsChat];
	} else if ([action isEqualToString:@"VideoChatParticipantIsMutedToggled"] ||
		[action isEqualToString:@"VideoChatParticipantVolumeLevelChanged"]) {
		[client parseMessageSender:TGCMDict(body[@"participant_id"]) senderId:&targetUserId isChat:&targetIsChat];
	} else {
		return nil;
	}
	if (targetIsChat || !targetUserId)
		return nil;
	NSString *name = [client nameForUserId:targetUserId];
	return name.length ? name : nil;
}

static NSString *TGCMFillActorAndTarget(NSString *pattern, NSString *actor, NSString *target) {
	NSString *filled = [pattern stringByReplacingOccurrencesOfString:@"{actor}" withString:actor ?: @""];
	return [filled stringByReplacingOccurrencesOfString:@"{target}" withString:target ?: @""];
}

static NSString *TGCMEventText(NSString *action, NSDictionary *body, NSString *who, NSString *target) {
	NSString *targetName = target.length ? target : @"a member";
	if ([action isEqualToString:@"MessageEdited"]) {
		NSString *oldText = TGForumsMessagePreview(TGCMDict(body[@"old_message"]));
		NSString *newText = TGForumsMessagePreview(TGCMDict(body[@"new_message"]));
		if (oldText.length && newText.length && ![oldText isEqualToString:newText])
			return [NSString stringWithFormat:TGL(@"ChatEvents.EditedAMessageFromTo", @"%@ edited a message from \"%@\" to \"%@\""),
				who, oldText, newText];
		return [NSString stringWithFormat:TGL(@"ChatEvents.EditedAMessage", @"%@ edited a message"), who];
	}
	if ([action isEqualToString:@"MessageDeleted"]) {
		NSString *text = TGForumsMessagePreview(TGCMDict(body[@"message"]));
		if (text.length)
			return [NSString stringWithFormat:TGL(@"ChatEvents.DeletedAMessageWithText", @"%@ deleted a message: \"%@\""), who, text];
		return [NSString stringWithFormat:TGL(@"ChatEvents.DeletedAMessage", @"%@ deleted a message"), who];
	}
	if ([action isEqualToString:@"MessagePinned"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.PinnedAMessage", @"%@ pinned a message"), who];
	if ([action isEqualToString:@"MessageUnpinned"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.UnpinnedAMessage", @"%@ unpinned a message"), who];
	if ([action isEqualToString:@"PollStopped"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.StoppedAPoll", @"%@ stopped a poll"), who];
	if ([action isEqualToString:@"MemberJoined"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.Joined", @"%@ joined"), who];
	if ([action isEqualToString:@"MemberJoinedByInviteLink"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.JoinedViaAnInviteLink", @"%@ joined via an invite link"), who];
	if ([action isEqualToString:@"MemberJoinedByRequest"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.JoinedAfterApproval", @"%@ joined after approval"), who];
	if ([action isEqualToString:@"MemberLeft"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.Left", @"%@ left"), who];
	if ([action isEqualToString:@"MemberInvited"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.Invited", @"%@ invited %@"), who, targetName];
	if ([action isEqualToString:@"MemberPromoted"]) {
		NSDictionary *oldStatus = TGCMDict(body[@"old_status"]);
		NSDictionary *newStatus = TGCMDict(body[@"new_status"]);
		BOOL wasAdmin = [TGCMString(oldStatus[@"@type"]) isEqualToString:@"chatMemberStatusAdministrator"];
		BOOL isAdmin = [TGCMString(newStatus[@"@type"]) isEqualToString:@"chatMemberStatusAdministrator"];
		if (isAdmin && !wasAdmin)
			return [NSString stringWithFormat:TGL(@"ChatEvents.PromotedToAdmin", @"%@ promoted %@ to admin"), who, targetName];
		if (wasAdmin && !isAdmin)
			return [NSString stringWithFormat:TGL(@"ChatEvents.Demoted", @"%@ demoted %@"), who, targetName];
		if (isAdmin && wasAdmin) {
			NSInteger changed = TGCMAdminRightsDiffCount(TGCMDict(oldStatus[@"rights"]), TGCMDict(newStatus[@"rights"]));
			if (changed > 0)
				return TGCMFillActorAndTarget(TGLPlural(@"ChatEvents.AdjustedAdminRights", changed,
					@"{actor} adjusted {target}'s admin rights (1 permission changed)",
					@"{actor} adjusted {target}'s admin rights (%d permissions changed)"), who, targetName);
		}
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedAdminRights", @"%@ changed %@'s admin rights"), who, targetName];
	}
	if ([action isEqualToString:@"MemberRestricted"]) {
		NSDictionary *oldStatus = TGCMDict(body[@"old_status"]);
		NSDictionary *newStatus = TGCMDict(body[@"new_status"]);
		NSString *oldType = TGCMString(oldStatus[@"@type"]);
		NSString *newType = TGCMString(newStatus[@"@type"]);
		BOOL wasBanned = [oldType isEqualToString:@"chatMemberStatusBanned"];
		BOOL isBanned = [newType isEqualToString:@"chatMemberStatusBanned"];
		BOOL wasRestricted = [oldType isEqualToString:@"chatMemberStatusRestricted"];
		BOOL isRestricted = [newType isEqualToString:@"chatMemberStatusRestricted"];
		if (isBanned && !wasBanned) {
			int64_t untilDate = TGCMInt64(newStatus[@"banned_until_date"]);
			if (untilDate)
				return [NSString stringWithFormat:TGL(@"ChatEvents.BannedUntil", @"%@ banned %@ until %@"),
					who, targetName, [TGDateUtils stringForUntil:(int)untilDate]];
			return [NSString stringWithFormat:TGL(@"ChatEvents.Banned", @"%@ banned %@"), who, targetName];
		}
		if (wasBanned && !isBanned)
			return [NSString stringWithFormat:TGL(@"ChatEvents.Unbanned", @"%@ unbanned %@"), who, targetName];
		if (isRestricted && !wasRestricted)
			return [NSString stringWithFormat:TGL(@"ChatEvents.Restricted", @"%@ restricted %@"), who, targetName];
		if (wasRestricted && !isRestricted)
			return [NSString stringWithFormat:TGL(@"ChatEvents.RemovedRestrictions", @"%@ removed %@'s restrictions"), who, targetName];
		if (isRestricted && wasRestricted) {
			NSInteger changed = TGCMPermissionsDiffCount(TGCMDict(oldStatus[@"permissions"]), TGCMDict(newStatus[@"permissions"]));
			if (changed > 0)
				return TGCMFillActorAndTarget(TGLPlural(@"ChatEvents.ChangedRestrictions", changed,
					@"{actor} changed {target}'s restrictions (1 permission changed)",
					@"{actor} changed {target}'s restrictions (%d permissions changed)"), who, targetName);
		}
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedMembershipStatus", @"%@ changed %@'s membership status"), who, targetName];
	}
	if ([action isEqualToString:@"TitleChanged"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedTheTitleTo", @"%@ changed the title to \"%@\""),
			who, TGCMString(body[@"new_title"])];
	if ([action isEqualToString:@"DescriptionChanged"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedTheDescription", @"%@ changed the description"), who];
	if ([action isEqualToString:@"PhotoChanged"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedThePhoto", @"%@ changed the photo"), who];
	if ([action isEqualToString:@"UsernameChanged"] ||
		[action isEqualToString:@"ActiveUsernamesChanged"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedThePublicLink", @"%@ changed the public link"), who];
	if ([action isEqualToString:@"PermissionsChanged"]) {
		NSInteger changed = TGCMPermissionsDiffCount(TGCMDict(body[@"old_permissions"]), TGCMDict(body[@"new_permissions"]));
		if (changed > 0)
			return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedThePermissionsCount", @"%@ changed the permissions (%ld changed)"), who, (long)changed];
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedThePermissions", @"%@ changed the permissions"), who];
	}
	if ([action isEqualToString:@"SlowModeDelayChanged"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedSlowModeToS", @"%@ changed slow mode to %@s"),
			who, TGCMNumber(body[@"new_slow_mode_delay"])];
	if ([action isEqualToString:@"InvitesToggled"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedWhoMayInvite", @"%@ changed who may invite"), who];
	if ([action isEqualToString:@"SignMessagesToggled"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedSignatures", @"%@ changed signatures"), who];
	if ([action isEqualToString:@"IsAllHistoryAvailableToggled"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedHistoryVisibility", @"%@ changed history visibility"), who];
	if ([action isEqualToString:@"HasProtectedContentToggled"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedContentProtection", @"%@ changed content protection"), who];
	if ([action isEqualToString:@"HasAggressiveAntiSpamEnabledToggled"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedAntiSpam", @"%@ changed anti-spam"), who];
	if ([action isEqualToString:@"InviteLinkEdited"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.EditedAnInviteLink", @"%@ edited an invite link"), who];
	if ([action isEqualToString:@"InviteLinkRevoked"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.RevokedAnInviteLink", @"%@ revoked an invite link"), who];
	if ([action isEqualToString:@"InviteLinkDeleted"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.DeletedAnInviteLink", @"%@ deleted an invite link"), who];
	if ([action isEqualToString:@"LinkedChatChanged"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedTheLinkedChat", @"%@ changed the linked chat"), who];
	if ([action isEqualToString:@"LocationChanged"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedTheLocation", @"%@ changed the location"), who];
	if ([action isEqualToString:@"StickerSetChanged"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedTheStickerSet", @"%@ changed the sticker set"), who];
	if ([action isEqualToString:@"AvailableReactionsChanged"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedTheReactions", @"%@ changed the reactions"), who];
	if ([action isEqualToString:@"IsForumToggled"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedTopics", @"%@ changed topics"), who];
	if ([action isEqualToString:@"MessageAutoDeleteTimeChanged"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedTheAutoDeleteTimer", @"%@ changed the auto-delete timer"), who];
	if ([action isEqualToString:@"MemberTagChanged"]) {
		NSString *newTag = TGCMString(body[@"new_tag"]);
		if (newTag.length)
			return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedTagTo", @"%@ changed %@'s tag to \"%@\""), who, targetName, newTag];
		return [NSString stringWithFormat:TGL(@"ChatEvents.RemovedTag", @"%@ removed %@'s tag"), who, targetName];
	}
	if ([action isEqualToString:@"MemberSubscriptionExtended"]) {
		NSDictionary *newStatus = TGCMDict(body[@"new_status"]);
		int64_t untilDate = [TGCMString(newStatus[@"@type"]) isEqualToString:@"chatMemberStatusMember"]
			? TGCMInt64(newStatus[@"member_until_date"]) : 0;
		if (untilDate)
			return [NSString stringWithFormat:TGL(@"ChatEvents.ExtendedTheirSubscriptionUntil", @"%@ extended their subscription until %@"),
				who, [TGDateUtils stringForUntil:(int)untilDate]];
		return [NSString stringWithFormat:TGL(@"ChatEvents.ExtendedTheirSubscription", @"%@ extended their subscription"), who];
	}
	if ([action isEqualToString:@"BackgroundChanged"])
		return [NSString stringWithFormat:(TGCMDict(body[@"new_background"])
			? TGL(@"ChatEvents.ChangedTheBackground", @"%@ changed the background")
			: TGL(@"ChatEvents.RemovedTheBackground", @"%@ removed the background")), who];
	if ([action isEqualToString:@"EmojiStatusChanged"])
		return [NSString stringWithFormat:(TGCMDict(body[@"new_emoji_status"])
			? TGL(@"ChatEvents.ChangedTheEmojiStatus", @"%@ changed the emoji status")
			: TGL(@"ChatEvents.RemovedTheEmojiStatus", @"%@ removed the emoji status")), who];
	if ([action isEqualToString:@"CustomEmojiStickerSetChanged"])
		return [NSString stringWithFormat:(TGCMInt64(body[@"new_sticker_set_id"])
			? TGL(@"ChatEvents.ChangedTheCustomEmojiStickerSet", @"%@ changed the custom emoji sticker set")
			: TGL(@"ChatEvents.RemovedTheCustomEmojiStickerSet", @"%@ removed the custom emoji sticker set")), who];
	if ([action isEqualToString:@"AccentColorChanged"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedTheAccentColor", @"%@ changed the accent color"), who];
	if ([action isEqualToString:@"ProfileAccentColorChanged"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedTheProfileColor", @"%@ changed the profile color"), who];
	if ([action isEqualToString:@"ShowMessageSenderToggled"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedMessageSenderVisibility", @"%@ changed message sender visibility"), who];
	if ([action isEqualToString:@"AutomaticTranslationToggled"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedAutomaticTranslation", @"%@ changed automatic translation"), who];
	if ([action isEqualToString:@"VideoChatCreated"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.StartedAVoiceChat", @"%@ started a voice chat"), who];
	if ([action isEqualToString:@"VideoChatEnded"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.EndedTheVoiceChat", @"%@ ended the voice chat"), who];
	if ([action isEqualToString:@"VideoChatMuteNewParticipantsToggled"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedNewParticipantMuting", @"%@ changed new participant muting"), who];
	if ([action isEqualToString:@"VideoChatParticipantIsMutedToggled"])
		return [NSString stringWithFormat:(TGCMBool(body[@"is_muted"])
			? TGL(@"ChatEvents.MutedInTheVoiceChat", @"%@ muted %@ in the voice chat")
			: TGL(@"ChatEvents.UnmutedInTheVoiceChat", @"%@ unmuted %@ in the voice chat")),
			who, targetName];
	if ([action isEqualToString:@"VideoChatParticipantVolumeLevelChanged"])
		return [NSString stringWithFormat:TGL(@"ChatEvents.ChangedVolumeTo", @"%@ changed %@'s volume to %ld%%"),
			who, targetName, (long)(TGCMInt64(body[@"volume_level"]) / 100)];
	if ([action isEqualToString:@"ForumTopicCreated"]) {
		NSDictionary *topic = TGCMDict(body[@"topic_info"]);
		return [NSString stringWithFormat:TGL(@"ChatEvents.CreatedTheTopic", @"%@ created the topic \"%@\""), who, TGCMString(topic[@"name"])];
	}
	if ([action isEqualToString:@"ForumTopicEdited"]) {
		NSDictionary *oldTopic = TGCMDict(body[@"old_topic_info"]);
		NSDictionary *newTopic = TGCMDict(body[@"new_topic_info"]);
		NSString *oldName = TGCMString(oldTopic[@"name"]);
		NSString *newName = TGCMString(newTopic[@"name"]);
		if (newName.length && ![newName isEqualToString:oldName])
			return [NSString stringWithFormat:TGL(@"ChatEvents.RenamedTheTopicTo", @"%@ renamed the topic \"%@\" to \"%@\""), who, oldName, newName];
		return [NSString stringWithFormat:TGL(@"ChatEvents.EditedTheTopic", @"%@ edited the topic \"%@\""), who, newName.length ? newName : oldName];
	}
	if ([action isEqualToString:@"ForumTopicToggleIsClosed"]) {
		NSDictionary *topic = TGCMDict(body[@"topic_info"]);
		return [NSString stringWithFormat:(TGCMBool(topic[@"is_closed"])
			? TGL(@"ChatEvents.ClosedTheTopic", @"%@ closed the topic \"%@\"")
			: TGL(@"ChatEvents.ReopenedTheTopic", @"%@ reopened the topic \"%@\"")),
			who, TGCMString(topic[@"name"])];
	}
	if ([action isEqualToString:@"ForumTopicToggleIsHidden"]) {
		NSDictionary *topic = TGCMDict(body[@"topic_info"]);
		return [NSString stringWithFormat:(TGCMBool(topic[@"is_hidden"])
			? TGL(@"ChatEvents.HidTheTopic", @"%@ hid the topic \"%@\"")
			: TGL(@"ChatEvents.UnhidTheTopic", @"%@ unhid the topic \"%@\"")),
			who, TGCMString(topic[@"name"])];
	}
	if ([action isEqualToString:@"ForumTopicDeleted"]) {
		NSDictionary *topic = TGCMDict(body[@"topic_info"]);
		return [NSString stringWithFormat:TGL(@"ChatEvents.DeletedTheTopic", @"%@ deleted the topic \"%@\""), who, TGCMString(topic[@"name"])];
	}
	if ([action isEqualToString:@"ForumTopicPinned"]) {
		NSDictionary *newTopic = TGCMDict(body[@"new_topic_info"]);
		if (newTopic)
			return [NSString stringWithFormat:TGL(@"ChatEvents.PinnedTheTopic", @"%@ pinned the topic \"%@\""), who, TGCMString(newTopic[@"name"])];
		NSDictionary *oldTopic = TGCMDict(body[@"old_topic_info"]);
		return [NSString stringWithFormat:TGL(@"ChatEvents.UnpinnedTheTopic", @"%@ unpinned the topic \"%@\""), who, TGCMString(oldTopic[@"name"])];
	}

	NSMutableString *words = [NSMutableString string];
	for (NSInteger i = 0; i < action.length; i++) {
		unichar c = [action characterAtIndex:i];
		if (i && c >= 'A' && c <= 'Z')
			[words appendString:@" "];
		[words appendFormat:@"%C", c];
	}
	return [NSString stringWithFormat:TGL(@"ChatEvents.Text", @"%@: %@"), who, [words lowercaseString]];
}

- (void)eventLogForChat:(int64_t)chatId
				  query:(NSString *)query
			fromEventId:(int64_t)fromEventId
				  limit:(NSInteger)limit
				filters:(NSArray *)filters
				userIds:(NSArray *)userIds
			 completion:(void (^)(NSArray *events))completion {
	NSDictionary *fields = TGCMEventFilterFields();
	NSMutableDictionary *filter = [NSMutableDictionary dictionary];
	filter[@"@type"] = @"chatEventLogFilters";
	for (NSString *key in fields)
		filter[fields[key]] = @(!filters || [filters containsObject:key]);

	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"getChatEventLog",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"query" : query ?: @"",
		@"from_event_id" : [NSNumber numberWithLongLong:fromEventId],
		@"limit" : @(limit > 0 ? limit : 50),
		@"filters" : filter,
		@"user_ids" : userIds ?: @[],
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGCMFailed(result)) {
			completion(nil);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (id raw in TGCMArray(result[@"events"])) {
			NSDictionary *event = TGCMDict(raw);
			if (!event)
				continue;

			NSDictionary *sender = TGCMDict(event[@"member_id"]);
			int64_t userId = 0;
			if ([TGCMString(sender[@"@type"]) isEqualToString:@"messageSenderUser"])
				userId = [TGCMNumber(sender[@"user_id"]) longLongValue];
			NSString *name = userId ? [weakSelf nameForUserId:userId] : nil;
			if (!name.length)
				name = TGL(@"Premium.GiftedTitle.Someone", @"Someone");

			NSDictionary *body = TGCMDict(event[@"action"]);
			NSString *action = TGCMString(body[@"@type"]);
			if ([action hasPrefix:@"chatEvent"])
				action = [action substringFromIndex:9];

			NSDictionary *message = TGCMDict(body[@"message"]);
			if (!message)
				message = TGCMDict(body[@"new_message"]);

			NSDictionary *messageSender = TGCMDict(message[@"sender_id"]);
			int64_t messageAuthorId = 0;
			if ([TGCMString(messageSender[@"@type"]) isEqualToString:@"messageSenderUser"])
				messageAuthorId = [TGCMNumber(messageSender[@"user_id"]) longLongValue];
			NSString *messageAuthorName = messageAuthorId ? [weakSelf nameForUserId:messageAuthorId] : nil;
			NSString *targetName = TGCMEventTargetName(weakSelf, action, body);

			[out addObject:@{
				@"eventId" : TGCMNumber(event[@"id"]),
				@"date" : TGCMNumber(event[@"date"]),
				@"userId" : [NSNumber numberWithLongLong:userId],
				@"name" : name,
				@"action" : action,
				@"text" : TGCMEventText(action, body, name, targetName),
				@"messageId" : TGCMNumber(message[@"id"]),
				@"messageAuthorId" : [NSNumber numberWithLongLong:messageAuthorId],
				@"messageAuthorName" : messageAuthorName ?: @"",
				@"canReportNotSpam" :
					@([TGCMNumber(body[@"can_report_anti_spam_false_positive"]) boolValue]),
			}];
		}
		completion(out);
	}];
}

#pragma mark - send as

- (BOOL)parseMessageSender:(NSDictionary *)sender
				   senderId:(int64_t *)outSenderId
					 isChat:(BOOL *)outIsChat {
	NSDictionary *dict = TGCMDict(sender);
	NSString *type = TGCMString(dict[@"@type"]);
	if ([type isEqualToString:@"messageSenderChat"]) {
		if (outSenderId)
			*outSenderId = TGCMInt64(dict[@"chat_id"]);
		if (outIsChat)
			*outIsChat = YES;
		return YES;
	}
	if ([type isEqualToString:@"messageSenderUser"]) {
		if (outSenderId)
			*outSenderId = TGCMInt64(dict[@"user_id"]);
		if (outIsChat)
			*outIsChat = NO;
		return YES;
	}
	if (outSenderId)
		*outSenderId = 0;
	if (outIsChat)
		*outIsChat = NO;
	return NO;
}

- (void)availableMessageSendersForChat:(int64_t)chatId
							completion:(void (^)(NSArray *))completion {
	if (!completion)
		return;
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChatAvailableMessageSenders", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *result) {
			NSArray *raw = TGCMArray(result[@"senders"]);
			if (!raw.count) {
				completion(@[]);
				return;
			}
			NSMutableArray *out = [NSMutableArray arrayWithCapacity:raw.count];
			for (NSInteger i = 0; i < raw.count; i++)
				[out addObject:[NSNull null]];
			__block NSInteger remaining = (NSInteger)raw.count;

			for (NSInteger i = 0; i < raw.count; i++) {
				NSDictionary *entry = TGCMDict(raw[i]);
				NSDictionary *sender = TGCMDict(entry[@"sender"]);
				BOOL needsPremium = TGCMBool(entry[@"needs_premium"]);
				NSString *type = TGCMString(sender[@"@type"]);
				NSInteger index = i;

				void (^store)(int64_t, NSString *, BOOL) = ^(int64_t senderId, NSString *name, BOOL isChat) {
					out[index] = @{
						@"senderId" : [NSNumber numberWithLongLong:senderId],
						@"name" : name.length ? name : (isChat
							? TGL(@"Chat.SendAsChannelFallback", @"Channel")
							: TGL(@"Chat.SendAsMyAccountFallback", @"My Account")),
						@"isChat" : @(isChat),
						@"needsPremium" : @(needsPremium),
					};
					remaining--;
					if (remaining <= 0) {
						NSMutableArray *cleaned = [NSMutableArray arrayWithCapacity:out.count];
						for (id one in out)
							if ([one isKindOfClass:NSDictionary.class])
								[cleaned addObject:one];
						completion(cleaned);
					}
				};

				if ([type isEqualToString:@"messageSenderChat"]) {
					int64_t senderChatId = TGCMInt64(sender[@"chat_id"]);
					[self request:@{@"@type" : @"getChat",
						@"chat_id" : @(senderChatId)}
						completion:^(NSDictionary *chat) {
							store(senderChatId, TGCMString(chat[@"title"]), YES);
						}];
				} else {
					int64_t senderUserId = TGCMInt64(sender[@"user_id"]);
					store(senderUserId, [weakSelf nameForUserId:senderUserId], NO);
				}
			}
		}];
}

- (void)currentMessageSenderForChat:(int64_t)chatId
						 completion:(void (^)(int64_t, BOOL))completion {
	if (!completion)
		return;
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			if (TGCMFailed(chat)) {
				completion(0, NO);
				return;
			}
			int64_t senderId = 0;
			BOOL isChat = NO;
			[self parseMessageSender:chat[@"message_sender_id"] senderId:&senderId isChat:&isChat];
			completion(senderId, isChat);
		}];
}

- (void)setMessageSenderId:(int64_t)senderId
					isChat:(BOOL)isChat
				   forChat:(int64_t)chatId
				completion:(void (^)(BOOL))completion {
	NSDictionary *sender = isChat
		? @{@"@type" : @"messageSenderChat", @"chat_id" : @(senderId)}
		: @{@"@type" : @"messageSenderUser", @"user_id" : @(senderId)};
	[self request:@{
		@"@type" : @"setChatMessageSender",
		@"chat_id" : @(chatId),
		@"message_sender_id" : sender,
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGCMFailed(result));
	}];
}

#pragma mark - moved from TGClient.m core

#pragma mark - maintenance

#pragma mark - chats

- (void)loadChats {
	if (self.chatListComplete)
		return;
	self.chatsAtLastLoad = self.chatsById.count;
	NSLog(@"TGClient: loadChats attempt %lu (have %lu)",
		(unsigned long)self.loadChatsAttempts + 1,
		(unsigned long)self.chatsById.count);
	__weak typeof(self) weakLoader = self;
	[self request:@{
		@"@type" : @"loadChats",
		@"chat_list" : @{@"@type" : @"chatListMain"},
		@"limit" : @(50),
	} completion:^(NSDictionary *result) {
		TGClient *loader = weakLoader;
		if (!loader)
			return;
		if ([result[@"@type"] isEqualToString:@"error"] &&
			[result[@"code"] intValue] == 404) {
			loader.chatListComplete = YES;
			NSLog(@"TGClient: chat list complete (%lu)",
				(unsigned long)loader.chatsById.count);
			[loader dropChatsMissingFromServerList];
		}
	}];
	[self request:@{
		@"@type" : @"loadChats",
		@"chat_list" : @{@"@type" : @"chatListArchive"},
		@"limit" : @(50),
	} completion:^(NSDictionary *result) { (void)result; }];

	self.loadChatsAttempts++;
	if (self.loadChatsAttempts > 12)
		return;

	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			TGClient *strongSelf = weakSelf;
			if (strongSelf && !strongSelf.chatListComplete)
				[strongSelf loadChats];
		});
}

NSString *TGDraftText(id draftMessage) {
	if (![draftMessage isKindOfClass:NSDictionary.class])
		return @"";
	id text = ((NSDictionary *)draftMessage)[@"content"][@"text"][@"text"];
	return [text isKindOfClass:NSString.class] ? text : @"";
}

- (void)cacheProfilePhoto:(NSDictionary *)user {
	if (self.userPhotosById.count > 2000 || self.userPhotoKeysById.count > 2000) {
		[self.userPhotosById removeAllObjects];
		[self.userPhotoKeysById removeAllObjects];
	}

	NSDictionary *small = TGCMDict(TGCMDict(user[@"profile_photo"])[@"small"]);
	NSNumber *fileId = small[@"id"];
	if (user[@"id"] && fileId)
		self.userPhotosById[user[@"id"]] = fileId;

	NSString *uniqueId = TGCMDict(small[@"remote"])[@"unique_id"];
	if (user[@"id"] && [uniqueId isKindOfClass:NSString.class] && uniqueId.length)
		self.userPhotoKeysById[user[@"id"]] = uniqueId;
}

- (int64_t)savedMessagesChatId {
	int64_t ownId = [self.me[@"id"] longLongValue];
	if (ownId != 0)
		return ownId;
	id remembered = [[NSUserDefaults standardUserDefaults] objectForKey:TGSavedMessagesChatIdKey()];
	return [remembered isKindOfClass:NSNumber.class] ? [remembered longLongValue] : 0;
}

- (void)statusForUser:(int64_t)userId completion:(void (^)(NSString *))completion {
	[self request:@{@"@type" : @"getUser", @"user_id" : @(userId)}
		completion:^(NSDictionary *user) {
			if (completion)
				completion(TGUserStatusInfo(user[@"status"])[@"text"]);
		}];
}

- (NSNumber *)photoFileIdForUserId:(int64_t)userId {
	return self.userPhotosById[@(userId)];
}

- (void)resolvePhotoFileIdForUserId:(int64_t)userId
						 completion:(void (^)(NSNumber *fileId))completion {
	NSNumber *known = self.userPhotosById[@(userId)];
	if (known) {
		if (completion)
			completion(known);
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getUser", @"user_id" : @(userId)}
		completion:^(NSDictionary *user) {
			TGClient *strongSelf = weakSelf;
			if (!strongSelf) {
				if (completion)
					completion(nil);
				return;
			}
			if ([user isKindOfClass:[NSDictionary class]])
				[strongSelf cacheProfilePhoto:user];
			if (completion)
				completion(strongSelf.userPhotosById[@(userId)]);
		}];
}

- (NSString *)photoKeyForUserId:(int64_t)userId {
	return self.userPhotoKeysById[@(userId)];
}

- (void)membersOfChat:(int64_t)chatId completion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			NSDictionary *type = chat[@"type"];
			NSString *kind = type[@"@type"];

			void (^collect)(NSArray *) = ^(NSArray *members) {
				TGClient *strongSelf = weakSelf;
				NSMutableArray *out = [NSMutableArray array];
				for (NSDictionary *member in members) {
					int64_t userId = [member[@"member_id"][@"user_id"] longLongValue];
					if (!userId)
						continue;
					[out addObject:@{
						@"id" : @(userId),
						@"name" : [strongSelf nameForUserId:userId] ?: @"",
						@"status" : TGCMStatusName(member[@"status"][@"@type"]),
					}];
				}
				if (completion)
					completion(out);
			};

			if ([kind isEqualToString:@"chatTypeBasicGroup"]) {
				[weakSelf request:@{
					@"@type" : @"getBasicGroupFullInfo",
					@"basic_group_id" : type[@"basic_group_id"],
				} completion:^(NSDictionary *full) { collect(full[@"members"]); }];
				return;
			}
			if ([kind isEqualToString:@"chatTypeSupergroup"]) {
				[weakSelf request:@{
					@"@type" : @"getSupergroupMembers",
					@"supergroup_id" : type[@"supergroup_id"],
					@"filter" : @{@"@type" : @"supergroupMembersFilterRecent"},
					@"offset" : @(0),
					@"limit" : @(50),
				} completion:^(NSDictionary *result) { collect(result[@"members"]); }];
				return;
			}
			if (completion)
				completion(@[]);
		}];
}

- (void)canSendInChat:(int64_t)chatId
			completion:(void (^)(BOOL canSend, BOOL isChannel, NSDictionary *permissions))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			TGClient *strongSelf = weakSelf;
			if (!strongSelf) {
				if (completion)
					completion(NO, NO, TGCMFlatComposerPermissions(nil, NO, YES, 0, 0));
				return;
			}
			NSDictionary *type = chat[@"type"];
			NSString *kind = type[@"@type"];
			BOOL isChannel = [kind isEqualToString:@"chatTypeSupergroup"] &&
				[type[@"is_channel"] boolValue];

			if ([kind isEqualToString:@"chatTypePrivate"]) {
				int64_t peerUserId = [TGCMNumber(type[@"user_id"]) longLongValue];
				[strongSelf isUserBlocked:peerUserId completion:^(BOOL blocked) {
					if (completion)
						completion(!blocked, NO, TGCMFlatComposerPermissions(nil, !blocked, YES, 0, 0));
				}];
				return;
			}

			if ([kind isEqualToString:@"chatTypeSecret"]) {
				[strongSelf canSendInSecretChat:chatId completion:^(BOOL canSend, NSString *secretState) {
					if (completion)
						completion(canSend, NO, TGCMFlatComposerPermissions(nil, canSend, YES, 0, 0));
				}];
				return;
			}

			[strongSelf myRightsInChat:chatId completion:^(NSDictionary *rights) {
				TGClient *innerSelf = weakSelf;
				if (!innerSelf) {
					if (completion)
						completion(NO, isChannel, TGCMFlatComposerPermissions(nil, NO, YES, 0, 0));
					return;
				}
				if ([TGCMNumber(rights[@"isOwner"]) boolValue]) {
					if (completion)
						completion(YES, isChannel, TGCMFlatComposerPermissions(nil, YES, YES, 0, 0));
					return;
				}
				if ([TGCMNumber(rights[@"isAdministrator"]) boolValue]) {
					BOOL canSend = isChannel ? [TGCMNumber(rights[@"canPostMessages"]) boolValue] : YES;
					if (completion)
						completion(canSend, isChannel, TGCMFlatComposerPermissions(nil, canSend, YES, 0, 0));
					return;
				}

				BOOL isMember = [TGCMNumber(rights[@"isMember"]) boolValue];
				int64_t myId = [TGCMNumber(innerSelf.me[@"id"]) longLongValue];
				[innerSelf permissionsOfUser:myId
									  inGroup:chatId
								   completion:^(NSDictionary *permissions, BOOL isRestricted, NSInteger untilDate) {
									   BOOL canSend = [TGCMNumber(permissions[@"can_send_basic_messages"]) boolValue];
									   NSNumber *supergroupId = TGCMNumber(type[@"supergroup_id"]);
									   if (!isChannel && [kind isEqualToString:@"chatTypeSupergroup"] &&
										   [supergroupId longLongValue]) {
										   [innerSelf request:@{@"@type" : @"getSupergroupFullInfo",
											   @"supergroup_id" : supergroupId}
												   completion:^(NSDictionary *full) {
													   NSInteger slowModeDelay = TGCMFailed(full)
														   ? 0
														   : [TGCMNumber(full[@"slow_mode_delay"]) integerValue];
													   double slowModeSecondsRemaining = TGCMFailed(full)
														   ? 0
														   : [TGCMNumber(full[@"slow_mode_delay_expires_in"]) doubleValue];
													   NSMutableDictionary *chatInfo = innerSelf.chatsById[@(chatId)];
													   if (!chatInfo) {
														   chatInfo = [NSMutableDictionary dictionary];
														   innerSelf.chatsById[@(chatId)] = chatInfo;
													   }
													   chatInfo[@"slowModeDelay"] = @(slowModeDelay);
													   if (completion)
														   completion(canSend, isChannel,
															   TGCMFlatComposerPermissions(permissions, NO, isMember,
																   slowModeDelay, slowModeSecondsRemaining));
												   }];
										   return;
									   }
									   NSMutableDictionary *chatInfo = innerSelf.chatsById[@(chatId)];
									   if (!chatInfo) {
										   chatInfo = [NSMutableDictionary dictionary];
										   innerSelf.chatsById[@(chatId)] = chatInfo;
									   }
									   chatInfo[@"slowModeDelay"] = @0;
									   if (completion)
										   completion(canSend, isChannel,
											   TGCMFlatComposerPermissions(permissions, NO, isMember, 0, 0));
								   }];
			}];
		}];
}

- (void)canSendInChat:(int64_t)chatId
				 topic:(int64_t)topicId
			completion:(void (^)(BOOL canSend, BOOL isChannel, NSDictionary *permissions))completion {
	BOOL isForum = TGCMBool(self.chatsById[@(chatId)][@"isForum"]);
	if (topicId == 0 || !isForum) {
		[self canSendInChat:chatId completion:completion];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[self forumTopic:(int32_t)topicId inChat:chatId completion:^(NSDictionary *topic) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf) {
			if (completion)
				completion(NO, NO, TGCMFlatComposerPermissions(nil, NO, YES, 0, 0));
			return;
		}
		BOOL topicClosed = TGCMBool(topic[@"isClosed"]);
		BOOL topicIsOutgoing = TGCMBool(topic[@"isOutgoing"]);
		[strongSelf myRightsInChat:chatId completion:^(NSDictionary *rights) {
			TGClient *innerSelf = weakSelf;
			if (!innerSelf) {
				if (completion)
					completion(NO, NO, TGCMFlatComposerPermissions(nil, NO, YES, 0, 0));
				return;
			}
			BOOL canManageTopics = TGCMBool(rights[@"canManageTopics"]);
			[innerSelf canSendInChat:chatId completion:^(BOOL canSend, BOOL isChannel, NSDictionary *permissions) {
				NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:permissions];
				merged[@"topicClosed"] = @(topicClosed);
				BOOL canSendDespiteClosed = !topicClosed || topicIsOutgoing || canManageTopics;
				if (completion)
					completion(canSend && canSendDespiteClosed, isChannel, merged);
			}];
		}];
	}];
}

- (void)deleteChat:(int64_t)chatId {
	[self deleteChat:chatId revoke:NO completion:nil];
}

- (void)deleteChat:(int64_t)chatId revoke:(BOOL)revoke completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			if (TGResultIsError(chat)) {
				if (completion)
					completion(NO);
				return;
			}
			NSString *kind = chat[@"type"][@"@type"];
			BOOL isMembership = [kind isEqualToString:@"chatTypeSupergroup"] ||
				[kind isEqualToString:@"chatTypeBasicGroup"];
			[self request:@{
				@"@type" : @"deleteChatHistory",
				@"chat_id" : @(chatId),
				@"remove_from_chat_list" : @YES,
				@"revoke" : @(revoke && [kind isEqualToString:@"chatTypePrivate"]),
			} completion:^(NSDictionary *historyResult) {
				if (TGResultIsError(historyResult)) {
					if (completion)
						completion(NO);
					return;
				}
				if (!isMembership) {
					if (completion)
						completion(YES);
					return;
				}
				[self request:@{@"@type" : @"leaveChat", @"chat_id" : @(chatId)}
					completion:^(NSDictionary *leaveResult) {
						if (completion)
							completion(!TGResultIsError(leaveResult));
					}];
			}];
		}];
}

- (void)setChat:(int64_t)chatId joined:(BOOL)joined completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : joined ? @"joinChat" : @"leaveChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)pinnedMessageForChat:(int64_t)chatId
				  completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getChatPinnedMessage", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *m) {
			if (completion)
				completion([m[@"@type"] isEqualToString:@"message"] ? TGFlattenMessage(m, TGCurrentFlattenContext()) : nil);
		}];
}

- (void)pinnedMessagesForChat:(int64_t)chatId
					   thread:(int64_t)threadId
				   savedTopic:(int64_t)savedTopicId
				   completion:(void (^)(NSArray *messages))completion {
	if (!completion)
		return;
	NSMutableDictionary *request = [@{
		@"@type" : @"searchChatMessages",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"query" : @"",
		@"from_message_id" : @(0),
		@"offset" : @(0),
		@"limit" : @(100),
		@"filter" : @{@"@type" : @"searchMessagesFilterPinned"},
	} mutableCopy];
	NSDictionary *topic = TGTopicDictionary(threadId, 0, savedTopicId,
		TGCMChatIsForum(self, chatId));
	if (topic)
		request[@"topic_id"] = topic;

	[self request:request completion:^(NSDictionary *result) {
		NSArray *found = [result isKindOfClass:NSDictionary.class] ? result[@"messages"] : nil;
		if (![found isKindOfClass:NSArray.class]) {
			completion(nil);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *m in found) {
			NSDictionary *flat = TGFlattenMessage(m, TGCurrentFlattenContext());
			if (flat)
				[out insertObject:flat atIndex:0];
		}
		completion(out);
	}];
}

- (void)userProfile:(int64_t)userId completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getUserFullInfo", @"user_id" : @(userId)}
		completion:^(NSDictionary *full) {
			NSString *birthday = TGBirthdateInfo(full[@"birthdate"])[@"text"] ?: @"";
			if (completion)
				completion(@{
					@"bio" : full[@"bio"][@"text"] ?: @"",
					@"bioEntities" : TGFlattenEntities(full[@"bio"][@"entities"]),
					@"commonGroups" : full[@"group_in_common_count"] ?: @0,
					@"birthday" : birthday,

					@"canCall" : full[@"can_be_called"] ?: @NO,
					@"canVideoCall" : full[@"supports_video_calls"] ?: @NO,
					@"hasPersonalPhoto" : @([full[@"personal_photo"] isKindOfClass:[NSDictionary class]]),
					@"businessHours" : TGBizOpeningHoursFrom(
							full[@"business_info"][@"opening_hours"]) ?: [NSNull null],
				});
		}];
}

- (void)chatProfile:(int64_t)chatId completion:(void (^)(NSDictionary *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			NSString *kind = chat[@"type"][@"@type"];
			void (^answer)(NSDictionary *) = ^(NSDictionary *full) {
				if (completion)
					completion(@{
						@"description" : full[@"description"] ?: @"",
						@"members" : full[@"member_count"] ?: @([full[@"members"] count]),
						@"admins" : full[@"administrator_count"] ?: @0,
						@"inviteLink" : TGCMDict(full[@"invite_link"])[@"invite_link"] ?: @"",
					});
			};

			if ([kind isEqualToString:@"chatTypeSupergroup"]) {
				[weakSelf request:@{@"@type" : @"getSupergroupFullInfo",
					@"supergroup_id" : chat[@"type"][@"supergroup_id"]}
					   completion:answer];
			} else if ([kind isEqualToString:@"chatTypeBasicGroup"]) {
				[weakSelf request:@{@"@type" : @"getBasicGroupFullInfo",
					@"basic_group_id" : chat[@"type"][@"basic_group_id"]}
					   completion:answer];
			} else {
				answer(@{});
			}
		}];
}

- (BOOL)isChatMuted:(int64_t)chatId {
	return [self effectiveMutedForChatInfo:self.chatsById[@(chatId)]];
}

- (BOOL)isPrivateChat:(int64_t)chatId {
	return [self.chatsById[@(chatId)][@"isPrivate"] boolValue];
}

- (void)clearHistoryInChat:(int64_t)chatId {
	[self clearHistoryInChat:chatId revoke:NO completion:nil];
}

- (void)clearHistoryInChat:(int64_t)chatId revoke:(BOOL)revoke completion:(void (^)(BOOL ok))completion {
	BOOL effectiveRevoke = [self isSecretChat:chatId] ? YES : (revoke && [self isPrivateChat:chatId]);
	[self cm_run:@{
		@"@type" : @"deleteChatHistory",
		@"chat_id" : @(chatId),
		@"remove_from_chat_list" : @NO,
		@"revoke" : @(effectiveRevoke),
	}
		completion:completion];
}

- (void)setChat:(int64_t)chatId autoDeleteSeconds:(NSInteger)seconds {
	[self setChat:chatId autoDeleteSeconds:seconds completion:nil];
}

- (void)setChat:(int64_t)chatId autoDeleteSeconds:(NSInteger)seconds completion:(void (^)(BOOL ok))completion {
	[self cm_run:@{
		@"@type" : @"setChatMessageAutoDeleteTime",
		@"chat_id" : @(chatId),
		@"message_auto_delete_time" : @(seconds),
	}
		completion:completion];
}

- (NSInteger)autoDeleteSecondsForChat:(int64_t)chatId {
	return [self.chatsById[@(chatId)][@"autoDeleteSeconds"] integerValue];
}

@end

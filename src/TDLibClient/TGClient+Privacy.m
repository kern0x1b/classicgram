#import "TGClient+ChatState.h"
#import "TGClient+Private.h"
#import "TGClient+Account.h"
#import "TGClient+Notifications.h"
#import "TGClient+Privacy.h"
#import "TGLocalization.h"
#import "TGPrivacySettingTitle.h"
#import "TGFlattenPrivacy.h"

static NSArray *TGPrivacyArray(id value) {
	if (![value isKindOfClass:[NSArray class]])
		return [NSArray array];
	return value;
}

static NSString *TGPrivacyString(id value) {
	if (![value isKindOfClass:[NSString class]])
		return @"";
	return value;
}

static NSNumber *TGPrivacyBool(id value) {
	if (![value isKindOfClass:[NSNumber class]])
		return @NO;
	return [value boolValue] ? @YES : @NO;
}

static NSNumber *TGPrivacyNumber(id value) {
	if ([value isKindOfClass:[NSNumber class]])
		return value;
	if ([value isKindOfClass:[NSString class]])
		return [NSNumber numberWithLongLong:[value longLongValue]];
	return @0;
}

static NSDictionary *TGPrivacySettingObject(NSString *setting) {
	return @{@"@type" : [@"userPrivacySetting" stringByAppendingString:TGPrivacyString(setting)]};
}

NSString *TGSessionPlatformString(NSString *platform, NSString *systemVersion) {
	NSString *combined = [[platform stringByAppendingString:@" "] stringByAppendingString:systemVersion];
	return [combined stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

static NSDictionary *TGPrivacySessionDict(NSDictionary *session) {
	if (![session isKindOfClass:[NSDictionary class]])
		return nil;
	return @{
		@"id" : TGPrivacyNumber(session[@"id"]),
		@"appName" : TGPrivacyString(session[@"application_name"]),
		@"appVersion" : TGPrivacyString(session[@"application_version"]),
		@"deviceModel" : TGPrivacyString(session[@"device_model"]),
		@"platform" : TGSessionPlatformString(TGPrivacyString(session[@"platform"]), TGPrivacyString(session[@"system_version"])),
		@"ip" : TGPrivacyString(session[@"ip_address"]),
		@"location" : TGPrivacyString(session[@"location"]),
		@"isCurrent" : TGPrivacyBool(session[@"is_current"]),
		@"isOfficial" : TGPrivacyBool(session[@"is_official_application"]),
		@"isUnconfirmed" : TGPrivacyBool(session[@"is_unconfirmed"]),
		@"canAcceptCalls" : TGPrivacyBool(session[@"can_accept_calls"]),
		@"canAcceptSecretChats" : TGPrivacyBool(session[@"can_accept_secret_chats"]),
		@"loginDate" : TGPrivacyNumber(session[@"log_in_date"]),
		@"lastActive" : TGPrivacyNumber(session[@"last_active_date"]),
	};
}

static NSDictionary *TGPrivacyPasswordState(NSDictionary *state) {
	if (TGResultIsError(state))
		return nil;
	NSDictionary *codeInfo = state[@"recovery_email_address_code_info"];
	if (![codeInfo isKindOfClass:[NSDictionary class]])
		codeInfo = nil;
	return @{
		@"hasPassword" : TGPrivacyBool(state[@"has_password"]),
		@"hint" : TGPrivacyString(state[@"password_hint"]),
		@"hasRecoveryEmail" : TGPrivacyBool(state[@"has_recovery_email_address"]),
		@"recoveryEmailPattern" : TGPrivacyString(codeInfo[@"email_address_pattern"]),
		@"recoveryCodeLength" : TGPrivacyNumber(codeInfo[@"length"]),
		@"loginEmailPattern" : TGPrivacyString(state[@"login_email_address_pattern"]),
		@"pendingResetDate" : TGPrivacyNumber(state[@"pending_reset_date"]),
	};
}

NSString *const TGUnconfirmedSessionDidChangeNotification = @"TGUnconfirmedSessionDidChangeNotification";

@interface TGClient (PrivacyInternal)
- (void)tgPrivacyWriteNewChatAllow:(BOOL)allow
						 starCount:(long long)starCount
						completion:(void (^)(BOOL ok))completion;
@end

@implementation TGClient (Privacy)

+ (NSArray *)privacySettingNames {
	return [NSArray arrayWithObjects:
			@"ShowStatus",
		@"ShowProfilePhoto",
		@"ShowBio",
		@"ShowBirthdate",
		@"ShowPhoneNumber",
		@"ShowProfileAudio",
		@"ShowLinkInForwardedMessages",
		@"AllowChatInvites",
		@"AllowCalls",
		@"AllowPeerToPeerCalls",
		@"AllowPrivateVoiceAndVideoNoteMessages",
		@"AllowFindingByPhoneNumber",
		@"AutosaveGifts",
		@"AllowUnpaidMessages",
		nil];
}

+ (NSString *)titleForPrivacySetting:(NSString *)setting {
	return TGPrivacySettingTitle(TGPrivacyString(setting));
}

#pragma mark - privacy rules

- (void)privacyRuleDetailed:(NSString *)setting
				 completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"getUserPrivacySettingRules",
		@"setting" : TGPrivacySettingObject(setting),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}

		NSMutableArray *allowedUsers = [NSMutableArray array];
		NSMutableArray *restrictedUsers = [NSMutableArray array];
		NSMutableArray *allowedChats = [NSMutableArray array];
		NSMutableArray *restrictedChats = [NSMutableArray array];
		NSString *value = @"nobody";
		BOOL haveBase = NO;
		BOOL allowBots = NO;
		BOOL restrictBots = NO;
		BOOL allowPremiumUsers = NO;

		for (NSDictionary *rule in TGPrivacyArray(result[@"rules"])) {
			if (![rule isKindOfClass:[NSDictionary class]])
				continue;
			NSString *type = TGPrivacyString(rule[@"@type"]);
			if ([type isEqualToString:@"userPrivacySettingRuleAllowUsers"])
				[allowedUsers addObjectsFromArray:TGPrivacyArray(rule[@"user_ids"])];
			else if ([type isEqualToString:@"userPrivacySettingRuleRestrictUsers"])
				[restrictedUsers addObjectsFromArray:TGPrivacyArray(rule[@"user_ids"])];
			else if ([type isEqualToString:@"userPrivacySettingRuleAllowChatMembers"])
				[allowedChats addObjectsFromArray:TGPrivacyArray(rule[@"chat_ids"])];
			else if ([type isEqualToString:@"userPrivacySettingRuleRestrictChatMembers"])
				[restrictedChats addObjectsFromArray:TGPrivacyArray(rule[@"chat_ids"])];
			else if ([type isEqualToString:@"userPrivacySettingRuleAllowBots"])
				allowBots = YES;
			else if ([type isEqualToString:@"userPrivacySettingRuleRestrictBots"])
				restrictBots = YES;
			else if ([type isEqualToString:@"userPrivacySettingRuleAllowPremiumUsers"])
				allowPremiumUsers = YES;
			else if (!haveBase) {
				if ([type isEqualToString:@"userPrivacySettingRuleAllowAll"]) {
					value = @"everybody";
					haveBase = YES;
				} else if ([type isEqualToString:@"userPrivacySettingRuleAllowContacts"]) {
					value = @"contacts";
					haveBase = YES;
				} else if ([type isEqualToString:@"userPrivacySettingRuleRestrictAll"]) {
					value = @"nobody";
					haveBase = YES;
				} else if ([type isEqualToString:@"userPrivacySettingRuleRestrictContacts"]) {
					value = @"nobody";
					haveBase = YES;
				}
			}
		}

		completion(@{
			@"value" : value,
			@"allowedUserIds" : allowedUsers,
			@"restrictedUserIds" : restrictedUsers,
			@"allowedChatIds" : allowedChats,
			@"restrictedChatIds" : restrictedChats,
			@"allowBots" : @(allowBots),
			@"restrictBots" : @(restrictBots),
			@"allowPremiumUsers" : @(allowPremiumUsers),
		});
	}];
}

- (void)setPrivacyRule:(NSString *)setting
					to:(NSString *)value
		  allowedUsers:(NSArray *)allowedUserIds
	   restrictedUsers:(NSArray *)restrictedUserIds
			completion:(void (^)(BOOL))completion {
	[self setPrivacyRule:setting
					   to:value
			 allowedUsers:allowedUserIds
		  restrictedUsers:restrictedUserIds
			 allowedChats:nil
		  restrictedChats:nil
				allowBots:NO
			 restrictBots:NO
		allowPremiumUsers:NO
			   completion:completion];
}

- (void)setPrivacyRule:(NSString *)setting
					to:(NSString *)value
		  allowedUsers:(NSArray *)allowedUserIds
	   restrictedUsers:(NSArray *)restrictedUserIds
		  allowedChats:(NSArray *)allowedChatIds
	   restrictedChats:(NSArray *)restrictedChatIds
			completion:(void (^)(BOOL))completion {
	[self setPrivacyRule:setting
					   to:value
			 allowedUsers:allowedUserIds
		  restrictedUsers:restrictedUserIds
			 allowedChats:allowedChatIds
		  restrictedChats:restrictedChatIds
				allowBots:NO
			 restrictBots:NO
		allowPremiumUsers:NO
			   completion:completion];
}

- (void)setPrivacyRule:(NSString *)setting
					to:(NSString *)value
		  allowedUsers:(NSArray *)allowedUserIds
	   restrictedUsers:(NSArray *)restrictedUserIds
		  allowedChats:(NSArray *)allowedChatIds
	   restrictedChats:(NSArray *)restrictedChatIds
			 allowBots:(BOOL)allowBots
		  restrictBots:(BOOL)restrictBots
	 allowPremiumUsers:(BOOL)allowPremiumUsers
			completion:(void (^)(BOOL))completion {
	__weak TGClient *weakSelf = self;
	[self request:@{
		@"@type" : @"getUserPrivacySettingRules",
		@"setting" : TGPrivacySettingObject(setting),
	} completion:^(NSDictionary *current) {
		__strong TGClient *strongSelf = weakSelf;
		if (!strongSelf) {
			if (completion)
				completion(NO);
			return;
		}
		[strongSelf writePrivacyRule:setting
								  to:value
						allowedUsers:allowedUserIds
					 restrictedUsers:restrictedUserIds
						allowedChats:allowedChatIds
					 restrictedChats:restrictedChatIds
						   allowBots:allowBots
						restrictBots:restrictBots
				   allowPremiumUsers:allowPremiumUsers
						 keepingFrom:current
						  completion:completion];
	}];
}

- (void)writePrivacyRule:(NSString *)setting
					  to:(NSString *)value
			allowedUsers:(NSArray *)allowedUserIds
		 restrictedUsers:(NSArray *)restrictedUserIds
			allowedChats:(NSArray *)allowedChatIds
		 restrictedChats:(NSArray *)restrictedChatIds
			   allowBots:(BOOL)allowBots
			restrictBots:(BOOL)restrictBots
	   allowPremiumUsers:(BOOL)allowPremiumUsers
			 keepingFrom:(NSDictionary *)current
			  completion:(void (^)(BOOL))completion {
	NSString *base = @"userPrivacySettingRuleRestrictAll";
	if ([value isEqualToString:@"everybody"])
		base = @"userPrivacySettingRuleAllowAll";
	else if ([value isEqualToString:@"contacts"])
		base = @"userPrivacySettingRuleAllowContacts";

	NSArray *currentRules = TGResultIsError(current) ? nil : TGPrivacyArray(current[@"rules"]);
	NSArray *rules = TGPrivacyRebuiltRules(currentRules, base, allowedUserIds, restrictedUserIds,
		allowedChatIds, restrictedChatIds, allowBots, restrictBots, allowPremiumUsers);

	[self request:@{
		@"@type" : @"setUserPrivacySettingRules",
		@"setting" : TGPrivacySettingObject(setting),
		@"rules" : @{@"@type" : @"userPrivacySettingRules", @"rules" : rules},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - who may start a chat

- (void)newChatPrivacySettingsWithCompletion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getNewChatPrivacySettings"} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		completion(@{
			@"allowUnknownUsers" : TGPrivacyBool(result[@"allow_new_chats_from_unknown_users"]),
			@"paidMessageStarCount" : TGPrivacyNumber(result[@"incoming_paid_message_star_count"]),
		});
	}];
}

- (void)tgPrivacyWriteNewChatAllow:(BOOL)allow
						 starCount:(long long)starCount
						completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setNewChatPrivacySettings",
		@"settings" : @{
			@"@type" : @"newChatPrivacySettings",
			@"allow_new_chats_from_unknown_users" : allow ? @YES : @NO,
			@"incoming_paid_message_star_count" : @(starCount),
		},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)setNewChatPrivacyAllowsUnknownUsers:(BOOL)allow
								 completion:(void (^)(BOOL))completion {
	__weak TGClient *weakSelf = self;
	[self newChatPrivacySettingsWithCompletion:^(NSDictionary *current) {
		__strong TGClient *strongSelf = weakSelf;
		if (!strongSelf || ![current isKindOfClass:[NSDictionary class]]) {
			if (completion)
				completion(NO);
			return;
		}
		long long stars = [TGPrivacyNumber(current[@"paidMessageStarCount"]) longLongValue];
		[strongSelf tgPrivacyWriteNewChatAllow:allow starCount:stars completion:completion];
	}];
}

- (void)setNewChatPrivacyStarCount:(long long)starCount
						 completion:(void (^)(BOOL))completion {
	__weak TGClient *weakSelf = self;
	[self newChatPrivacySettingsWithCompletion:^(NSDictionary *current) {
		__strong TGClient *strongSelf = weakSelf;
		if (!strongSelf || ![current isKindOfClass:[NSDictionary class]]) {
			if (completion)
				completion(NO);
			return;
		}
		BOOL allow = [current[@"allowUnknownUsers"] boolValue];
		[strongSelf tgPrivacyWriteNewChatAllow:allow starCount:starCount completion:completion];
	}];
}

#pragma mark - read-date privacy

- (void)readDatePrivacyShowWithCompletion:(void (^)(BOOL, BOOL))completion {
	[self request:@{@"@type" : @"getReadDatePrivacySettings"} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, YES);
			return;
		}
		completion([TGPrivacyBool(result[@"show_read_date"]) boolValue], NO);
	}];
}

- (void)setReadDatePrivacyShow:(BOOL)show completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setReadDatePrivacySettings",
		@"settings" : @{
			@"@type" : @"readDatePrivacySettings",
			@"show_read_date" : show ? @YES : @NO,
		},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - block list

- (void)setUser:(int64_t)userId
		blocked:(BOOL)blocked
	 completion:(void (^)(BOOL))completion {
	[self setSender:userId isChat:NO blocked:blocked completion:completion];
}

- (void)setSender:(int64_t)senderId
		   isChat:(BOOL)isChat
		  blocked:(BOOL)blocked
	   completion:(void (^)(BOOL))completion {
	NSDictionary *request = @{
		@"@type" : @"setMessageSenderBlockList",
		@"sender_id" : isChat
			? @{@"@type" : @"messageSenderChat", @"chat_id" : @(senderId)}
			: @{@"@type" : @"messageSenderUser", @"user_id" : @(senderId)},
		@"block_list" : blocked ? (id) @{@"@type" : @"blockListMain"} : (id)[NSNull null],
	};
	[self request:request completion:^(NSDictionary *result) {
		BOOL ok = !TGResultIsError(result);
		if (ok) {
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGUserBlockedStateDidChangeNotification
							  object:@(senderId)];
		}
		if (completion)
			completion(ok);
	}];
}

- (void)blockedSendersFromOffset:(NSInteger)offset
						   limit:(NSInteger)limit
					  completion:(void (^)(NSArray *, NSInteger))completion {
	__weak TGClient *weakSelf = self;
	[self request:@{
		@"@type" : @"getBlockedMessageSenders",
		@"block_list" : @{@"@type" : @"blockListMain"},
		@"offset" : @(offset),
		@"limit" : @(limit > 0 ? limit : 100),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, 0);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *sender in TGPrivacyArray(result[@"senders"])) {
			if (![sender isKindOfClass:[NSDictionary class]])
				continue;
			NSNumber *userId = sender[@"user_id"];
			NSNumber *chatId = sender[@"chat_id"];
			if ([userId isKindOfClass:[NSNumber class]]) {
				[out addObject:@{
					@"id" : userId,
					@"name" : [weakSelf nameForUserId:[userId longLongValue]] ?: @"",
					@"username" : [weakSelf usernameForUserId:[userId longLongValue]] ?: @"",
					@"isChat" : @NO,
				}];
			} else if ([chatId isKindOfClass:[NSNumber class]]) {
				[out addObject:@{
					@"id" : chatId,
					@"name" : [weakSelf titleForChatId:[chatId longLongValue]] ?: @"",
					@"isChat" : @YES,
				}];
			}
		}
		completion(out, [TGPrivacyNumber(result[@"total_count"]) integerValue]);
	}];
}

#pragma mark - sessions

- (void)handleUpdateUnconfirmedSession:(NSDictionary *)update {
	NSDictionary *safe = [update isKindOfClass:[NSDictionary class]] ? update : nil;
	NSNumber *count = TGPrivacyNumber(safe[@"unconfirmed_session_count"]);
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGUnconfirmedSessionDidChangeNotification
					  object:nil
					userInfo:@{@"unconfirmedSessionCount" : count}];
}

- (void)activeSessionsWithCompletion:(void (^)(NSArray *, NSInteger))completion {
	[self request:@{@"@type" : @"getActiveSessions"} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion([NSArray array], 0);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *session in TGPrivacyArray(result[@"sessions"])) {
			NSDictionary *flat = TGPrivacySessionDict(session);
			if (flat)
				[out addObject:flat];
		}
		completion(out, [TGPrivacyNumber(result[@"inactive_session_ttl_days"]) integerValue]);
	}];
}

- (void)unconfirmedSessionsWithCompletion:(void (^)(NSArray *))completion {
	[self activeSessionsWithCompletion:^(NSArray *sessions, NSInteger ttlDays) {
		if (!completion)
			return;
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *session in sessions) {
			if ([session[@"isUnconfirmed"] boolValue])
				[out addObject:session];
		}
		completion(out);
	}];
}

- (void)terminateSession:(long long)sessionId completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"terminateSession", @"session_id" : @(sessionId)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)terminateAllOtherSessionsWithCompletion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"terminateAllOtherSessions"}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)confirmSession:(long long)sessionId completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"confirmSession", @"session_id" : @(sessionId)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)setSession:(long long)sessionId
	  canAcceptCalls:(BOOL)canAcceptCalls
	canAcceptSecrets:(BOOL)canAcceptSecretChats
		  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"toggleSessionCanAcceptCalls",
		@"session_id" : @(sessionId),
		@"can_accept_calls" : canAcceptCalls ? @YES : @NO,
	} completion:^(NSDictionary *callsResult) {
		BOOL callsOk = !TGResultIsError(callsResult);
		[self request:@{
			@"@type" : @"toggleSessionCanAcceptSecretChats",
			@"session_id" : @(sessionId),
			@"can_accept_secret_chats" : canAcceptSecretChats ? @YES : @NO,
		} completion:^(NSDictionary *secretsResult) {
			if (completion)
				completion(callsOk && !TGResultIsError(secretsResult));
		}];
	}];
}

- (void)setInactiveSessionTtlDays:(NSInteger)days completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setInactiveSessionTtl",
		@"inactive_session_ttl_days" : @(days),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - connected websites

- (void)connectedWebsitesWithCompletion:(void (^)(NSArray *, BOOL))completion {
	__weak TGClient *weakSelf = self;
	[self request:@{@"@type" : @"getConnectedWebsites"} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion([NSArray array], YES);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *site in TGPrivacyArray(result[@"websites"])) {
			if (![site isKindOfClass:[NSDictionary class]])
				continue;
			NSNumber *botId = TGPrivacyNumber(site[@"bot_user_id"]);
			[out addObject:@{
				@"id" : TGPrivacyNumber(site[@"id"]),
				@"domain" : TGPrivacyString(site[@"domain_name"]),
				@"botName" : [weakSelf nameForUserId:[botId longLongValue]] ?: @"",
				@"browser" : TGPrivacyString(site[@"browser"]),
				@"platform" : TGPrivacyString(site[@"platform"]),
				@"ip" : TGPrivacyString(site[@"ip_address"]),
				@"location" : TGPrivacyString(site[@"location"]),
				@"loginDate" : TGPrivacyNumber(site[@"log_in_date"]),
				@"lastActive" : TGPrivacyNumber(site[@"last_active_date"]),
			}];
		}
		completion(out, NO);
	}];
}

- (void)disconnectWebsite:(long long)websiteId completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"disconnectWebsite", @"website_id" : @(websiteId)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)disconnectAllWebsitesWithCompletion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"disconnectAllWebsites"} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - two-step verification

- (void)passwordStateWithCompletion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getPasswordState"} completion:^(NSDictionary *result) {
		if (completion)
			completion(TGPrivacyPasswordState(result));
	}];
}

- (void)setPasswordWithOldPassword:(NSString *)oldPassword
					   newPassword:(NSString *)newPassword
							  hint:(NSString *)hint
					 recoveryEmail:(NSString *)recoveryEmail
						completion:(void (^)(NSDictionary *))completion {
	BOOL setsEmail = [recoveryEmail isKindOfClass:[NSString class]] && [recoveryEmail length] > 0;
	[self request:@{
		@"@type" : @"setPassword",
		@"old_password" : oldPassword ?: @"",
		@"new_password" : newPassword ?: @"",
		@"new_hint" : hint ?: @"",
		@"set_recovery_email_address" : setsEmail ? @YES : @NO,
		@"new_recovery_email_address" : setsEmail ? recoveryEmail : @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(TGPrivacyPasswordState(result));
	}];
}

- (void)disablePasswordWithOldPassword:(NSString *)oldPassword
							completion:(void (^)(BOOL))completion {
	[self setPasswordWithOldPassword:oldPassword
						 newPassword:@""
								hint:@""
					   recoveryEmail:nil
						  completion:^(NSDictionary *state) {
							  if (completion)
								  completion(state != nil && ![state[@"hasPassword"] boolValue]);
						  }];
}

- (void)recoveryEmailWithPassword:(NSString *)password
					   completion:(void (^)(NSString *, NSString *))completion {
	[self request:@{
		@"@type" : @"getRecoveryEmailAddress",
		@"password" : password ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, TGResultErrorMessage(result));
			return;
		}
		completion(TGPrivacyString(result[@"recovery_email_address"]) ?: @"", nil);
	}];
}

- (void)setRecoveryEmail:(NSString *)email
				password:(NSString *)password
			  completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"setRecoveryEmailAddress",
		@"password" : password ?: @"",
		@"new_recovery_email_address" : email ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(TGPrivacyPasswordState(result));
	}];
}

- (void)checkRecoveryEmailCode:(NSString *)code
					completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"checkRecoveryEmailAddressCode",
		@"code" : code ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(TGPrivacyPasswordState(result));
	}];
}

- (void)resendRecoveryEmailCodeWithCompletion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"resendRecoveryEmailAddressCode"}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(TGPrivacyPasswordState(result));
		}];
}

#pragma mark - forgotten password

- (void)requestPasswordRecoveryWithCompletion:(void (^)(NSString *, NSInteger))completion {
	[self request:@{@"@type" : @"requestPasswordRecovery"} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, 0);
			return;
		}
		completion(TGPrivacyString(result[@"email_address_pattern"]),
			[TGPrivacyNumber(result[@"length"]) integerValue]);
	}];
}

- (void)checkRecoveryCode:(NSString *)code
				completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"checkPasswordRecoveryCode",
		@"recovery_code" : code ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)recoverPasswordWithCode:(NSString *)code
					newPassword:(NSString *)newPassword
						   hint:(NSString *)hint
					 completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"recoverPassword",
		@"recovery_code" : code ?: @"",
		@"new_password" : newPassword ?: @"",
		@"new_hint" : hint ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)resetPasswordWithCompletion:(void (^)(NSString *, NSInteger))completion {
	[self request:@{@"@type" : @"resetPassword"} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, 0);
			return;
		}
		NSString *type = TGPrivacyString(result[@"@type"]);
		if ([type isEqualToString:@"resetPasswordResultPending"]) {
			completion(@"pending", [TGPrivacyNumber(result[@"pending_reset_date"]) integerValue]);
			return;
		}
		if ([type isEqualToString:@"resetPasswordResultDeclined"]) {
			completion(@"declined", [TGPrivacyNumber(result[@"retry_date"]) integerValue]);
			return;
		}
		completion(@"ok", 0);
	}];
}

- (void)cancelPasswordResetWithCompletion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"cancelPasswordReset"} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - account

- (void)defaultAutoDeleteSecondsWithCompletion:(void (^)(NSInteger, BOOL))completion {
	[self request:@{@"@type" : @"getDefaultMessageAutoDeleteTime"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(0, YES);
				return;
			}
			completion([TGPrivacyNumber(result[@"time"]) integerValue], NO);
		}];
}

- (void)setDefaultAutoDeleteSeconds:(NSInteger)seconds completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setDefaultMessageAutoDeleteTime",
		@"message_auto_delete_time" : @{@"@type" : @"messageAutoDeleteTime",
			@"time" : @(seconds < 0 ? 0 : seconds)},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - reporting

- (void)reportChat:(int64_t)chatId
		messageIds:(NSArray *)messageIds
		  optionId:(NSString *)optionId
			  text:(NSString *)text
		completion:(void (^)(NSDictionary *))completion {
	NSArray *ids = [messageIds isKindOfClass:[NSArray class]] ? messageIds : [NSArray array];
	[self request:@{
		@"@type" : @"reportChat",
		@"chat_id" : @(chatId),
		@"option_id" : optionId ?: @"",
		@"message_ids" : ids,
		@"text" : text ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSString *type = TGPrivacyString(result[@"@type"]);
		if ([type isEqualToString:@"reportChatResultOptionRequired"]) {
			NSMutableArray *options = [NSMutableArray array];
			for (NSDictionary *option in TGPrivacyArray(result[@"options"])) {
				if (![option isKindOfClass:[NSDictionary class]])
					continue;
				[options addObject:@{
					@"id" : TGPrivacyString(option[@"id"]),
					@"text" : TGPrivacyString(option[@"text"]),
				}];
			}
			completion(@{
				@"status" : @"options",
				@"title" : TGPrivacyString(result[@"title"]),
				@"options" : options,
			});
			return;
		}
		if ([type isEqualToString:@"reportChatResultTextRequired"]) {
			completion(@{
				@"status" : @"text",
				@"optionId" : TGPrivacyString(result[@"option_id"]),
				@"optional" : TGPrivacyBool(result[@"is_optional"]),
			});
			return;
		}
		if ([type isEqualToString:@"reportChatResultMessagesRequired"]) {
			completion(@{@"status" : @"messages"});
			return;
		}
		completion(@{@"status" : @"ok"});
	}];
}

- (void)reportChatPhoto:(int64_t)chatId
				 fileId:(long long)fileId
				 reason:(NSString *)reason
				   text:(NSString *)text
			 completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"reportChatPhoto",
		@"chat_id" : @(chatId),
		@"file_id" : @(fileId),
		@"reason" : @{@"@type" : TGPrivacyReportReasonType(reason)},
		@"text" : text ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - chat action bar

- (void)actionBarForChat:(int64_t)chatId
			  completion:(void (^)(NSDictionary *actionBar))completion {
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			if (!completion)
				return;
			if (TGResultIsError(chat)) {
				completion(nil);
				return;
			}
			NSDictionary *actionBar = TGChatActionBarInfo(chat[@"action_bar"]);
			completion([actionBar isKindOfClass:[NSDictionary class]] ? actionBar : nil);
		}];
}

- (void)removeActionBarForChat:(int64_t)chatId
					completion:(void (^)(BOOL ok))completion {
	[self request:@{@"@type" : @"removeChatActionBar", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

@end

#import "TGFlattenPrivacy.h"
#import "TGStringTruncation.h"

static NSString *TGFPString(id value) {
	if (![value isKindOfClass:[NSString class]])
		return @"";
	return value;
}

BOOL TGPrivacyRuleIsModelled(NSString *type) {
	static NSSet *modelled = nil;
	if (!modelled)
		modelled = [NSSet setWithObjects:
				@"userPrivacySettingRuleAllowAll",
			@"userPrivacySettingRuleAllowContacts",
			@"userPrivacySettingRuleRestrictAll",
			@"userPrivacySettingRuleRestrictContacts",
			@"userPrivacySettingRuleAllowUsers",
			@"userPrivacySettingRuleRestrictUsers",
			@"userPrivacySettingRuleAllowChatMembers",
			@"userPrivacySettingRuleRestrictChatMembers",
			@"userPrivacySettingRuleAllowBots",
			@"userPrivacySettingRuleRestrictBots",
			@"userPrivacySettingRuleAllowPremiumUsers", nil];
	return [modelled containsObject:type];
}

NSArray *TGPrivacyExceptionListRemoving(NSArray *list, NSArray *idsToExclude) {
	if (![list isKindOfClass:[NSArray class]] || !list.count)
		return list ?: [NSArray array];
	if (![idsToExclude isKindOfClass:[NSArray class]] || !idsToExclude.count)
		return list;
	NSSet *excludeSet = [NSSet setWithArray:idsToExclude];
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:list.count];
	for (id value in list) {
		if (![excludeSet containsObject:value])
			[result addObject:value];
	}
	return result;
}

static NSArray *TGPrivacyExceptionRuleKinds(void) {
	return @[
		@"userPrivacySettingRuleRestrictUsers",
		@"userPrivacySettingRuleRestrictChatMembers",
		@"userPrivacySettingRuleRestrictBots",
		@"userPrivacySettingRuleAllowUsers",
		@"userPrivacySettingRuleAllowChatMembers",
		@"userPrivacySettingRuleAllowBots",
		@"userPrivacySettingRuleAllowPremiumUsers",
	];
}

NSDictionary *TGPrivacyRuleDictForType(NSString *type,
	NSArray *allowedUserIds,
	NSArray *restrictedUserIds,
	NSArray *allowedChatIds,
	NSArray *restrictedChatIds,
	BOOL allowBots,
	BOOL restrictBots,
	BOOL allowPremiumUsers) {
	if ([type isEqualToString:@"userPrivacySettingRuleRestrictUsers"])
		return ([restrictedUserIds isKindOfClass:[NSArray class]] && restrictedUserIds.count)
			? @{@"@type" : type, @"user_ids" : restrictedUserIds}
			: nil;
	if ([type isEqualToString:@"userPrivacySettingRuleRestrictChatMembers"])
		return ([restrictedChatIds isKindOfClass:[NSArray class]] && restrictedChatIds.count)
			? @{@"@type" : type, @"chat_ids" : restrictedChatIds}
			: nil;
	if ([type isEqualToString:@"userPrivacySettingRuleRestrictBots"])
		return restrictBots ? @{@"@type" : type} : nil;
	if ([type isEqualToString:@"userPrivacySettingRuleAllowUsers"])
		return ([allowedUserIds isKindOfClass:[NSArray class]] && allowedUserIds.count)
			? @{@"@type" : type, @"user_ids" : allowedUserIds}
			: nil;
	if ([type isEqualToString:@"userPrivacySettingRuleAllowChatMembers"])
		return ([allowedChatIds isKindOfClass:[NSArray class]] && allowedChatIds.count)
			? @{@"@type" : type, @"chat_ids" : allowedChatIds}
			: nil;
	if ([type isEqualToString:@"userPrivacySettingRuleAllowBots"])
		return allowBots ? @{@"@type" : type} : nil;
	if ([type isEqualToString:@"userPrivacySettingRuleAllowPremiumUsers"])
		return allowPremiumUsers ? @{@"@type" : type} : nil;
	return nil;
}

NSArray *TGPrivacyRebuiltRules(NSArray *currentRules,
	NSString *baseType,
	NSArray *allowedUserIds,
	NSArray *restrictedUserIds,
	NSArray *allowedChatIds,
	NSArray *restrictedChatIds,
	BOOL allowBots,
	BOOL restrictBots,
	BOOL allowPremiumUsers) {
	NSArray *exceptionKinds = TGPrivacyExceptionRuleKinds();
	NSMutableSet *emitted = [NSMutableSet set];
	NSMutableArray *rules = [NSMutableArray array];

	for (id entry in [currentRules isKindOfClass:[NSArray class]] ? currentRules : @[]) {
		if (![entry isKindOfClass:[NSDictionary class]])
			continue;
		NSDictionary *rule = entry;
		NSString *type = [rule[@"@type"] isKindOfClass:[NSString class]] ? rule[@"@type"] : @"";
		if (![exceptionKinds containsObject:type]) {
			if (!TGPrivacyRuleIsModelled(type))
				[rules addObject:rule];
			continue;
		}
		if ([emitted containsObject:type])
			continue;
		[emitted addObject:type];
		NSDictionary *rebuilt = TGPrivacyRuleDictForType(type, allowedUserIds, restrictedUserIds,
			allowedChatIds, restrictedChatIds, allowBots, restrictBots, allowPremiumUsers);
		if (rebuilt)
			[rules addObject:rebuilt];
	}

	for (NSString *type in exceptionKinds) {
		if ([emitted containsObject:type])
			continue;
		NSDictionary *rebuilt = TGPrivacyRuleDictForType(type, allowedUserIds, restrictedUserIds,
			allowedChatIds, restrictedChatIds, allowBots, restrictBots, allowPremiumUsers);
		if (rebuilt)
			[rules addObject:rebuilt];
	}

	[rules addObject:@{@"@type" : baseType.length ? baseType : @"userPrivacySettingRuleRestrictAll"}];
	return rules;
}

BOOL TGPrivacySettingSupportsExceptions(NSString *setting) {
	return ![setting isEqualToString:@"AllowFindingByPhoneNumber"];
}

NSString *TGPrivacyReportReasonType(NSString *reason) {
	NSArray *known = @[ @"spam", @"violence", @"pornography", @"childAbuse",
		@"copyright", @"unrelatedLocation", @"fake",
		@"illegalDrugs", @"personalDetails", @"custom" ];
	NSString *name = [TGFPString(reason) length] ? reason : @"custom";
	if (![known containsObject:name])
		name = @"custom";
	return [NSString stringWithFormat:@"reportReason%@",
		TGStringWithFirstCharacterUppercased(name)];
}

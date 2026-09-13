#import "TGFlattenGroups.h"
#import "TGLocalization.h"

static NSDictionary *TGDict(id value) {
	return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static NSString *TGString(id value) {
	return [value isKindOfClass:[NSString class]] ? value : @"";
}

NSString *TGGroupProfileTabName(id tab) {
	NSString *type = TGString(TGDict(tab)[@"@type"]);
	if (![type hasPrefix:@"profileTab"] || type.length <= 10)
		return @"";
	return [[type substringFromIndex:10] lowercaseString];
}

NSDictionary *TGUserSender(int64_t userId) {
	return @{@"@type" : @"messageSenderUser",
		@"user_id" : @(userId)};
}

NSDictionary *TGFlattenMemberIdentity(NSDictionary *memberId) {
	BOOL isChat = [TGString(TGDict(memberId)[@"@type"]) isEqualToString:@"messageSenderChat"];
	int64_t userId = isChat ? 0 : [TGDict(memberId)[@"user_id"] longLongValue];
	int64_t chatId = isChat ? [TGDict(memberId)[@"chat_id"] longLongValue] : 0;
	return @{
		@"isChat" : @(isChat),
		@"userId" : @(userId),
		@"chatId" : @(chatId),
	};
}

NSArray *TGPermissionKeys(void) {
	static NSArray *keys = nil;
	if (!keys)
		keys = @[ @"can_send_basic_messages", @"can_send_audios", @"can_send_documents",
			@"can_send_photos", @"can_send_videos", @"can_send_video_notes",
			@"can_send_voice_notes", @"can_send_polls", @"can_send_other_messages",
			@"can_add_link_previews", @"can_react_to_messages", @"can_edit_tag",
			@"can_change_info", @"can_invite_users", @"can_pin_messages",
			@"can_create_topics" ];
	return keys;
}

NSArray *TGAdminRightKeys(void) {
	static NSArray *keys = nil;
	if (!keys)
		keys = @[ @"can_manage_chat", @"can_change_info", @"can_post_messages",
			@"can_edit_messages", @"can_delete_messages", @"can_invite_users",
			@"can_restrict_members", @"can_pin_messages", @"can_manage_topics",
			@"can_promote_members", @"can_manage_video_chats", @"can_post_stories",
			@"can_edit_stories", @"can_delete_stories", @"can_manage_direct_messages",
			@"can_manage_tags", @"is_anonymous" ];
	return keys;
}

NSDictionary *TGBuildFlags(NSDictionary *source, NSArray *keys, NSString *type) {
	NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:keys.count + 1];
	out[@"@type"] = type;
	for (NSString *key in keys)
		out[key] = [source[key] boolValue] ? @YES : @NO;
	return out;
}

NSDictionary *TGReadFlags(NSDictionary *source, NSArray *keys) {
	NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:keys.count];
	for (NSString *key in keys)
		out[key] = [source[key] boolValue] ? @YES : @NO;
	return out;
}

NSString *TGStatusName(NSString *type) {
	if ([type isEqualToString:@"chatMemberStatusCreator"])
		return @"creator";
	if ([type isEqualToString:@"chatMemberStatusAdministrator"])
		return @"administrator";
	if ([type isEqualToString:@"chatMemberStatusMember"])
		return @"member";
	if ([type isEqualToString:@"chatMemberStatusRestricted"])
		return @"restricted";
	if ([type isEqualToString:@"chatMemberStatusBanned"])
		return @"banned";
	return @"left";
}

NSDictionary *TGFlattenMemberRestriction(id status) {
	NSString *type = TGString(TGDict(status)[@"@type"]);
	if ([type isEqualToString:@"chatMemberStatusRestricted"])
		return @{
			@"usesChatDefaults" : @NO,
			@"isRestricted" : @YES,
			@"untilDate" : @([TGDict(status)[@"restricted_until_date"] integerValue]),
			@"permissions" : TGDict(TGDict(status)[@"permissions"]) ?: @{},
		};
	if ([type isEqualToString:@"chatMemberStatusBanned"])
		return @{
			@"usesChatDefaults" : @NO,
			@"isRestricted" : @YES,
			@"untilDate" : @([TGDict(status)[@"banned_until_date"] integerValue]),
			@"permissions" : @{},
		};
	return @{
		@"usesChatDefaults" : @YES,
		@"isRestricted" : @NO,
		@"untilDate" : @0,
		@"permissions" : @{},
	};
}

NSDictionary *TGSupergroupFilter(NSString *filter, NSString *query) {
	NSString *text = query ?: @"";
	if ([filter isEqualToString:@"administrators"])
		return @{@"@type" : @"supergroupMembersFilterAdministrators"};
	if ([filter isEqualToString:@"restricted"])
		return @{@"@type" : @"supergroupMembersFilterRestricted", @"query" : text};
	if ([filter isEqualToString:@"banned"])
		return @{@"@type" : @"supergroupMembersFilterBanned", @"query" : text};
	if ([filter isEqualToString:@"bots"])
		return @{@"@type" : @"supergroupMembersFilterBots"};
	if ([filter isEqualToString:@"contacts"])
		return @{@"@type" : @"supergroupMembersFilterContacts", @"query" : text};
	if (text.length)
		return @{@"@type" : @"supergroupMembersFilterSearch", @"query" : text};
	return @{@"@type" : @"supergroupMembersFilterRecent"};
}

NSDictionary *TGChatMembersFilter(NSString *filter) {
	if ([filter isEqualToString:@"administrators"])
		return @{@"@type" : @"chatMembersFilterAdministrators"};
	if ([filter isEqualToString:@"restricted"])
		return @{@"@type" : @"chatMembersFilterRestricted"};
	if ([filter isEqualToString:@"banned"])
		return @{@"@type" : @"chatMembersFilterBanned"};
	if ([filter isEqualToString:@"bots"])
		return @{@"@type" : @"chatMembersFilterBots"};
	if ([filter isEqualToString:@"contacts"])
		return @{@"@type" : @"chatMembersFilterContacts"};
	return @{@"@type" : @"chatMembersFilterMembers"};
}

NSDictionary *TGFlattenInviteLink(NSDictionary *link) {
	if (!TGDict(link) || ![TGString(link[@"@type"]) isEqualToString:@"chatInviteLink"])
		return nil;
	return @{
		@"link" : TGString(link[@"invite_link"]),
		@"name" : TGString(link[@"name"]),
		@"creatorUserId" : link[@"creator_user_id"] ?: @(0),
		@"date" : link[@"date"] ?: @(0),
		@"expirationDate" : link[@"expiration_date"] ?: @(0),
		@"memberLimit" : link[@"member_limit"] ?: @(0),
		@"memberCount" : link[@"member_count"] ?: @(0),
		@"pendingJoinRequestCount" : link[@"pending_join_request_count"] ?: @(0),
		@"createsJoinRequest" : @([link[@"creates_join_request"] boolValue]),
		@"isPrimary" : @([link[@"is_primary"] boolValue]),
		@"isRevoked" : @([link[@"is_revoked"] boolValue]),
	};
}

NSString *TGTitleForAdministratorRightKey(NSString *key) {
	static NSDictionary *titles = nil;
	if (!titles)
		titles = @{
			@"can_manage_chat" : TGL(@"GroupRights.ManageGroup", @"Manage Group"),
			@"can_change_info" : TGL(@"GroupRights.ChangeInfo", @"Change Info"),
			@"can_post_messages" : TGL(@"GroupRights.PostMessages", @"Post Messages"),
			@"can_edit_messages" : TGL(@"GroupRights.EditMessages", @"Edit Messages"),
			@"can_delete_messages" : TGL(@"GroupRights.DeleteMessages", @"Delete Messages"),
			@"can_invite_users" : TGL(@"GroupRights.AddUsers", @"Add Users"),
			@"can_restrict_members" : TGL(@"GroupRights.BanUsers", @"Ban Users"),
			@"can_pin_messages" : TGL(@"GroupRights.PinMessages", @"Pin Messages"),
			@"can_manage_topics" : TGL(@"GroupRights.ManageTopics", @"Manage Topics"),
			@"can_promote_members" : TGL(@"GroupRights.AddNewAdmins", @"Add New Admins"),
			@"can_manage_video_chats" : TGL(@"GroupRights.ManageVoiceChats", @"Manage Voice Chats"),
			@"can_post_stories" : TGL(@"GroupRights.PostStories", @"Post Stories"),
			@"can_edit_stories" : TGL(@"GroupRights.EditStories", @"Edit Stories"),
			@"can_delete_stories" : TGL(@"GroupRights.DeleteStories", @"Delete Stories"),
			@"can_manage_direct_messages" : TGL(@"GroupRights.ManageDirectMessages", @"Manage Direct Messages"),
			@"can_manage_tags" : TGL(@"GroupRights.ManageTags", @"Manage Tags"),
			@"is_anonymous" : TGL(@"GroupRights.RemainAnonymous", @"Remain Anonymous"),
		};
	NSString *title = TGString(key).length ? titles[key] : nil;
	return title ?: (TGString(key).length ? key : @"");
}

NSString *TGTitleForMemberPermissionKey(NSString *key) {
	static NSDictionary *titles = nil;
	if (!titles)
		titles = @{
			@"can_send_basic_messages" : TGL(@"GroupRights.SendMessages", @"Send Messages"),
			@"can_send_audios" : TGL(@"GroupRights.SendMusic", @"Send Music"),
			@"can_send_documents" : TGL(@"GroupRights.SendFiles", @"Send Files"),
			@"can_send_photos" : TGL(@"GroupRights.SendPhotos", @"Send Photos"),
			@"can_send_videos" : TGL(@"GroupRights.SendVideos", @"Send Videos"),
			@"can_send_video_notes" : TGL(@"GroupRights.SendVideoMessages", @"Send Video Messages"),
			@"can_send_voice_notes" : TGL(@"GroupRights.SendVoiceMessages", @"Send Voice Messages"),
			@"can_send_polls" : TGL(@"GroupRights.SendPolls", @"Send Polls"),
			@"can_send_other_messages" : TGL(@"GroupRights.SendStickersAndGifs", @"Send Stickers & GIFs"),
			@"can_add_link_previews" : TGL(@"GroupRights.EmbedLinks", @"Embed Links"),
			@"can_react_to_messages" : TGL(@"GroupRights.AddReactions", @"Add Reactions"),
			@"can_edit_tag" : TGL(@"GroupRights.EditTags", @"Edit Tags"),
			@"can_change_info" : TGL(@"GroupRights.ChangeInfo", @"Change Info"),
			@"can_invite_users" : TGL(@"GroupRights.AddUsers", @"Add Users"),
			@"can_pin_messages" : TGL(@"GroupRights.PinMessages", @"Pin Messages"),
			@"can_create_topics" : TGL(@"GroupRights.CreateTopics", @"Create Topics"),
		};
	NSString *title = TGString(key).length ? titles[key] : nil;
	return title ?: (TGString(key).length ? key : @"");
}

NSDictionary *TGMentionCandidate(int64_t userId, NSString *username, NSString *firstName,
	NSString *lastName, NSString *fallbackName) {
	NSString *displayName = [[NSString stringWithFormat:@"%@ %@",
			TGString(firstName), TGString(lastName)]
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if (!displayName.length)
		displayName = TGString(fallbackName);
	if (!displayName.length)
		displayName = TGString(username);
	return @{
		@"id" : @(userId),
		@"username" : TGString(username),
		@"name" : displayName,
	};
}

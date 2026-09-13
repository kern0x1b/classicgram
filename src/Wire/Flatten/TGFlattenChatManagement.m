#import "TGFlattenChatManagement.h"
#import <math.h>

static NSNumber *TGFCMNumber(id value) {
	return [value isKindOfClass:NSNumber.class] ? value : [NSNumber numberWithInt:0];
}

static NSDictionary *TGFCMRightFields(void) {
	static NSDictionary *fields = nil;
	if (!fields)
		fields = @{
			@"canManageChat" : @"can_manage_chat",
			@"canChangeInfo" : @"can_change_info",
			@"canPostMessages" : @"can_post_messages",
			@"canEditMessages" : @"can_edit_messages",
			@"canDeleteMessages" : @"can_delete_messages",
			@"canInviteUsers" : @"can_invite_users",
			@"canRestrictMembers" : @"can_restrict_members",
			@"canPinMessages" : @"can_pin_messages",
			@"canManageTopics" : @"can_manage_topics",
			@"canPromoteMembers" : @"can_promote_members",
			@"canManageVideoChats" : @"can_manage_video_chats",
			@"canPostStories" : @"can_post_stories",
			@"canEditStories" : @"can_edit_stories",
			@"canDeleteStories" : @"can_delete_stories",
			@"canManageDirectMessages" : @"can_manage_direct_messages",
			@"canManageTags" : @"can_manage_tags",
			@"isAnonymous" : @"is_anonymous",
		};
	return fields;
}

NSString *TGCMStatusName(NSString *type) {
	if ([type isEqualToString:@"chatMemberStatusCreator"])
		return @"creator";
	if ([type isEqualToString:@"chatMemberStatusAdministrator"])
		return @"administrator";
	return @"member";
}

NSDictionary *TGCMFlatRights(NSDictionary *rights, BOOL isOwner,
	BOOL isAdministrator, NSString *customTitle) {
	NSDictionary *fields = TGFCMRightFields();
	NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:fields.count + 4];
	for (NSString *key in fields) {
		BOOL value = isOwner;
		if (!isOwner && [rights isKindOfClass:NSDictionary.class])
			value = [TGFCMNumber(rights[fields[key]]) boolValue];
		if (isOwner && [key isEqualToString:@"isAnonymous"])
			value = [TGFCMNumber(rights[fields[key]]) boolValue];
		out[key] = [NSNumber numberWithBool:value];
	}
	out[@"isOwner"] = [NSNumber numberWithBool:isOwner];
	out[@"isAdministrator"] = [NSNumber numberWithBool:isOwner || isAdministrator];
	out[@"isMember"] = [NSNumber numberWithBool:isOwner || isAdministrator];
	out[@"customTitle"] = [customTitle isKindOfClass:NSString.class] ? customTitle : @"";
	return out;
}

static NSDictionary *TGFCMComposerFields(void) {
	static NSDictionary *fields = nil;
	if (!fields)
		fields = @{
			@"canSendPhotos" : @"can_send_photos",
			@"canSendVideos" : @"can_send_videos",
			@"canSendVideoNotes" : @"can_send_video_notes",
			@"canSendVoiceNotes" : @"can_send_voice_notes",
			@"canSendAudios" : @"can_send_audios",
			@"canSendDocuments" : @"can_send_documents",
			@"canSendPolls" : @"can_send_polls",
			@"canSendOtherMessages" : @"can_send_other_messages",
		};
	return fields;
}

NSDictionary *TGCMFlatComposerPermissions(NSDictionary *memberPermissions,
	BOOL isAdminOrOwner, BOOL isMember, NSInteger slowModeDelay, double slowModeSecondsRemaining) {
	NSDictionary *fields = TGFCMComposerFields();
	NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:fields.count + 3];
	for (NSString *key in fields) {
		BOOL value = isAdminOrOwner;
		if (!isAdminOrOwner && [memberPermissions isKindOfClass:NSDictionary.class])
			value = [TGFCMNumber(memberPermissions[fields[key]]) boolValue];
		out[key] = [NSNumber numberWithBool:value];
	}
	NSInteger delay = isAdminOrOwner ? 0 : MAX((NSInteger)0, slowModeDelay);
	NSInteger secondsRemaining = isAdminOrOwner ? 0 : MAX((NSInteger)0, (NSInteger)ceil(slowModeSecondsRemaining));
	out[@"slowModeDelay"] = [NSNumber numberWithInteger:delay];
	out[@"slowModeSecondsRemaining"] = [NSNumber numberWithInteger:secondsRemaining];
	out[@"isMember"] = [NSNumber numberWithBool:isAdminOrOwner || isMember];
	return out;
}

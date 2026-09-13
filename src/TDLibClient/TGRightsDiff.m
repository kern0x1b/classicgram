#import "TGRightsDiff.h"

NSArray *TGAdminRightsDiffFields(void) {
	static NSArray *fields = nil;
	if (!fields)
		fields = @[
			@"can_manage_chat", @"can_change_info", @"can_post_messages", @"can_edit_messages",
			@"can_delete_messages", @"can_invite_users", @"can_restrict_members", @"can_pin_messages",
			@"can_manage_topics", @"can_promote_members", @"can_manage_video_chats", @"can_post_stories",
			@"can_edit_stories", @"can_delete_stories", @"can_manage_direct_messages", @"can_manage_tags",
			@"is_anonymous",
		];
	return fields;
}

static BOOL TGRightsFlag(id value) {
	return [value isKindOfClass:NSNumber.class] && [value boolValue];
}

NSInteger TGRightsDiffCount(NSDictionary *oldRights, NSDictionary *newRights, NSArray *fields) {
	NSInteger count = 0;
	for (NSString *field in fields)
		if (TGRightsFlag(oldRights[field]) != TGRightsFlag(newRights[field]))
			count++;
	return count;
}

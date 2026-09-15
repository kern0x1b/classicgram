#import "TGBotAdminRights.h"

NSArray *TGBotAdminRightNames(void) {
	static NSArray *names = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		names = @[
			@"can_manage_chat", @"can_change_info", @"can_post_messages", @"can_edit_messages",
			@"can_delete_messages", @"can_invite_users", @"can_restrict_members",
			@"can_pin_messages", @"can_manage_topics", @"can_promote_members",
			@"can_manage_video_chats", @"can_post_stories", @"can_edit_stories",
			@"can_delete_stories", @"can_manage_direct_messages", @"can_manage_tags",
			@"is_anonymous",
		];
	});
	return names;
}

BOOL TGBotAdminRightsRequested(NSDictionary *rights) {
	if (![rights isKindOfClass:NSDictionary.class])
		return NO;
	for (NSString *name in TGBotAdminRightNames()) {
		if ([rights[name] boolValue])
			return YES;
	}
	return NO;
}

NSDictionary *TGBotAdminRightsNormalised(NSDictionary *rights) {
	NSMutableDictionary *normalised = [NSMutableDictionary dictionary];
	for (NSString *name in TGBotAdminRightNames())
		normalised[name] = [rights[name] boolValue] ? @YES : @NO;
	return [normalised copy];
}

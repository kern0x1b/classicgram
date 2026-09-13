#import "TGFlattenChatList.h"

NSDictionary *TGChatListObject(TGChatListId list) {
	if (list == TGChatListArchive)
		return @{@"@type" : @"chatListArchive"};
	if (list == TGChatListMain)
		return @{@"@type" : @"chatListMain"};
	return @{@"@type" : @"chatListFolder",
		@"chat_folder_id" : @((int)list)};
}

TGChatListId TGChatListIdFromObject(id object) {
	if (![object isKindOfClass:NSDictionary.class])
		return TGChatListMain;
	NSString *type = object[@"@type"];
	if ([type isEqualToString:@"chatListArchive"])
		return TGChatListArchive;
	if ([type isEqualToString:@"chatListFolder"])
		return (TGChatListId)[object[@"chat_folder_id"] integerValue];
	return TGChatListMain;
}

NSString *TGPlainText(id formatted) {
	if ([formatted isKindOfClass:NSString.class])
		return formatted;
	if ([formatted isKindOfClass:NSDictionary.class]) {
		id text = formatted[@"text"];
		if ([text isKindOfClass:NSString.class])
			return text;
		if ([text isKindOfClass:NSDictionary.class])
			return TGPlainText(text);
	}
	return @"";
}

NSDictionary *TGChatFolderNamePayload(NSDictionary *wireName, NSString *title) {
	NSString *text = [title isKindOfClass:NSString.class] ? title : @"";
	if ([wireName isKindOfClass:NSDictionary.class] &&
		[TGPlainText(wireName) isEqualToString:text])
		return wireName;
	return @{@"@type" : @"chatFolderName",
		@"text" : @{@"@type" : @"formattedText", @"text" : text, @"entities" : @[]},
		@"animate_custom_emoji" : @(NO)};
}

NSInteger TGUnreadContributionForChatRow(NSDictionary *chat) {
	if (![chat isKindOfClass:NSDictionary.class])
		return 0;
	NSInteger unread = [chat[@"unread"] integerValue];
	if (unread > 0)
		return unread;
	return [chat[@"markedUnread"] boolValue] ? 1 : 0;
}

NSInteger TGUnreadChatCountFromUpdate(NSDictionary *update, BOOL includesMuted) {
	if (![update isKindOfClass:NSDictionary.class])
		return 0;
	NSString *withUnread = includesMuted ? @"unread_count" : @"unread_unmuted_count";
	NSString *withMark = includesMuted ? @"marked_as_unread_count"
									   : @"marked_as_unread_unmuted_count";
	NSInteger unread = [update[withUnread] isKindOfClass:NSNumber.class]
		? [update[withUnread] integerValue]
		: 0;
	NSInteger marked = [update[withMark] isKindOfClass:NSNumber.class]
		? [update[withMark] integerValue]
		: 0;
	return MAX((NSInteger)0, unread) + MAX((NSInteger)0, marked);
}

NSInteger TGUnreadBadgeCountInChatRows(NSArray *chats, BOOL countsChats, BOOL includesMuted) {
	if (![chats isKindOfClass:NSArray.class])
		return 0;
	NSInteger total = 0;
	for (id entry in chats) {
		if (![entry isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *chat = (NSDictionary *)entry;
		if ([chat[@"isMuted"] boolValue] && !includesMuted)
			continue;
		NSInteger contribution = TGUnreadContributionForChatRow(chat);
		if (countsChats)
			total += contribution > 0 ? 1 : 0;
		else
			total += contribution;
	}
	return total;
}

BOOL TGChatFolderExclusionAllowsChat(NSDictionary *folder, NSDictionary *chat) {
	if (![folder isKindOfClass:NSDictionary.class] || ![chat isKindOfClass:NSDictionary.class])
		return YES;

	BOOL hasUnreadMention = [chat[@"unreadMentionCount"] integerValue] > 0;
	if (!hasUnreadMention) {
		if ([folder[@"excludeMuted"] boolValue] && [chat[@"isMuted"] boolValue])
			return NO;
		if ([folder[@"excludeRead"] boolValue]) {
			BOOL unread = [chat[@"unread"] integerValue] > 0 || [chat[@"markedUnread"] boolValue];
			if (!unread)
				return NO;
		}
	}
	if ([folder[@"excludeArchived"] boolValue] && [chat[@"archiveOrder"] longLongValue] > 0)
		return NO;
	return YES;
}

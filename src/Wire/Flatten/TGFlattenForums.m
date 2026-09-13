#import "TGFlattenForums.h"
#import "TGFlattenMessage.h"
#import "TGDisappearingMedia.h"
#import "TGLocalization.h"

NSString *TGForumsMessagePreview(NSDictionary *message) {
	if (![message isKindOfClass:NSDictionary.class])
		return @"";
	NSDictionary *content = message[@"content"];
	if (![content isKindOfClass:NSDictionary.class])
		return @"";
	NSString *type = content[@"@type"];
	if (![type isKindOfClass:NSString.class])
		return @"";
	if (TGMessageDisappears(message)) {
		NSString *disappearing = TGDisappearingMediaLabel(type);
		if (disappearing)
			return disappearing;
	}
	NSDictionary *text = content[@"text"];
	if ([text isKindOfClass:NSDictionary.class]) {
		NSString *body = text[@"text"];
		if ([body isKindOfClass:NSString.class])
			return body;
	}
	NSDictionary *caption = content[@"caption"];
	if ([caption isKindOfClass:NSDictionary.class]) {
		NSString *body = caption[@"text"];
		if ([body isKindOfClass:NSString.class] && body.length)
			return body;
	}
	if ([type isEqualToString:@"messagePhoto"])
		return TGL(@"Message.Photo", @"Photo");
	if ([type isEqualToString:@"messageVideo"])
		return TGL(@"Message.Video", @"Video");
	if ([type isEqualToString:@"messageVideoNote"])
		return TGL(@"Message.VideoMessage", @"Video Message");
	if ([type isEqualToString:@"messageVoiceNote"])
		return TGL(@"Message.Audio", @"Voice message");
	if ([type isEqualToString:@"messageAudio"])
		return TGL(@"SharedMedia.CategoryOther", @"Audio");
	if ([type isEqualToString:@"messageDocument"])
		return TGL(@"Message.File", @"File");
	if ([type isEqualToString:@"messageSticker"])
		return TGL(@"Message.Sticker", @"Sticker");
	if ([type isEqualToString:@"messageAnimation"])
		return TGL(@"Message.Animation", @"GIF");
	if ([type isEqualToString:@"messageLocation"])
		return TGL(@"Message.Location", @"Location");
	if ([type isEqualToString:@"messageContact"])
		return TGL(@"Message.Contact", @"Contact");
	if ([type isEqualToString:@"messagePoll"])
		return TGL(@"Watch.Message.Poll", @"Poll");
	if ([type isEqualToString:@"messageForumTopicCreated"])
		return TGL(@"Notification.ForumTopicCreated", @"Topic created");
	if ([type isEqualToString:@"messageForumTopicEdited"]) {
		NSString *name = content[@"name"];
		if ([name isKindOfClass:NSString.class] && name.length)
			return [NSString stringWithFormat:
					TGL(@"Notification.ForumTopicRenamed", @"Topic renamed to \"%@\""),
				name];
		if ([content[@"edit_icon_custom_emoji_id"] boolValue])
			return TGL(@"Notification.ForumTopicIconOnlyChanged", @"Topic icon changed");
		return @"";
	}
	return TGMessageContentKindLabel(content) ?: @"";
}

int32_t TGForumsTopicIdForNotification(NSDictionary *notification) {
	if (![notification isKindOfClass:NSDictionary.class])
		return 0;
	NSDictionary *type = notification[@"type"];
	if (![type isKindOfClass:NSDictionary.class])
		return 0;
	if (![type[@"@type"] isEqualToString:@"notificationTypeNewMessage"])
		return 0;
	NSDictionary *message = type[@"message"];
	if (![message isKindOfClass:NSDictionary.class])
		return 0;
	NSDictionary *topicId = message[@"topic_id"];
	if (![topicId isKindOfClass:NSDictionary.class])
		return 0;
	if (![topicId[@"@type"] isEqualToString:@"messageTopicForum"])
		return 0;
	return (int32_t)[topicId[@"forum_topic_id"] longLongValue];
}

static NSNumber *TGForumsInt64(id value) {
	if ([value isKindOfClass:NSNumber.class])
		return value;
	if ([value isKindOfClass:NSString.class])
		return [NSNumber numberWithLongLong:[value longLongValue]];
	return [NSNumber numberWithLongLong:0];
}

NSDictionary *TGForumsFlattenTopic(NSDictionary *topic, int64_t chatId) {
	if (![topic isKindOfClass:NSDictionary.class])
		return nil;
	NSDictionary *info = topic[@"info"];
	if (![info isKindOfClass:NSDictionary.class])
		return nil;
	NSDictionary *icon = info[@"icon"];
	if (![icon isKindOfClass:NSDictionary.class])
		icon = [NSDictionary dictionary];
	NSDictionary *last = topic[@"last_message"];
	if (![last isKindOfClass:NSDictionary.class])
		last = nil;
	NSDictionary *creator = info[@"creator_id"];
	if (![creator isKindOfClass:NSDictionary.class])
		creator = [NSDictionary dictionary];
	NSDictionary *settings = topic[@"notification_settings"];
	if (![settings isKindOfClass:NSDictionary.class])
		settings = [NSDictionary dictionary];

	NSNumber *topicId = info[@"forum_topic_id"];
	if (![topicId isKindOfClass:NSNumber.class])
		topicId = @(0);
	NSNumber *ownerId = info[@"chat_id"];
	if (![ownerId isKindOfClass:NSNumber.class])
		ownerId = @(chatId);
	NSString *name = info[@"name"];
	if (![name isKindOfClass:NSString.class])
		name = @"";

	BOOL creatorIsChat = [creator[@"@type"] isEqualToString:@"messageSenderChat"];
	NSNumber *creatorId = creatorIsChat ? creator[@"chat_id"] : creator[@"user_id"];
	if (![creatorId isKindOfClass:NSNumber.class])
		creatorId = @(0);

	return [NSDictionary dictionaryWithObjectsAndKeys:
			topicId, @"topicId",
		topicId, @"threadId",
		ownerId, @"chatId",
		name, @"name",
		TGForumsMessagePreview(last) ?: @"", @"text",
		last[@"date"] ?: @(0), @"date",
		topic[@"unread_count"] ?: @(0), @"unread",
		topic[@"unread_mention_count"] ?: @(0), @"unreadMentions",
		topic[@"unread_reaction_count"] ?: @(0), @"unreadReactions",
		@([info[@"is_general"] boolValue]), @"isGeneral",
		@([info[@"is_closed"] boolValue]), @"isClosed",
		@([info[@"is_hidden"] boolValue]), @"isHidden",
		@([topic[@"is_pinned"] boolValue]), @"isPinned",
		@([info[@"is_outgoing"] boolValue]), @"isOutgoing",
		icon[@"color"] ?: @(0), @"iconColor",
		TGForumsInt64(icon[@"custom_emoji_id"]), @"iconEmojiId",
		settings[@"mute_for"] ?: @(0), @"muteFor",
		info[@"creation_date"] ?: @(0), @"creationDate",
		creatorId, @"creatorId",
		@(creatorIsChat), @"creatorIsChat",
		TGForumsInt64(topic[@"order"]), @"order",
		nil];
}

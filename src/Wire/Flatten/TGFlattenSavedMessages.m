#import "TGFlattenSavedMessages.h"
#import "TGFlattenMessage.h"
#import "TGDisappearingMedia.h"
#import "TGLocalization.h"
#import "TGMediaPreviewName.h"

NSString *TGSavedPreview(NSDictionary *message) {
	if (![message isKindOfClass:NSDictionary.class])
		return @"";
	NSDictionary *content = message[@"content"];
	if (![content isKindOfClass:NSDictionary.class])
		return @"";
	NSString *type = [content[@"@type"] isKindOfClass:NSString.class] ? content[@"@type"] : @"";
	if (TGMessageDisappears(message)) {
		NSString *disappearing = TGDisappearingMediaLabel(type);
		if (disappearing)
			return disappearing;
	}
	NSDictionary *text = content[@"text"];
	if ([text isKindOfClass:NSDictionary.class]) {
		NSString *body = text[@"text"];
		if ([body isKindOfClass:NSString.class] && body.length)
			return body;
	}
	NSDictionary *caption = content[@"caption"];
	if ([caption isKindOfClass:NSDictionary.class]) {
		NSString *body = caption[@"text"];
		if ([body isKindOfClass:NSString.class] && body.length)
			return body;
	}
	if (!type.length)
		return @"";
	if ([type isEqualToString:@"messagePhoto"])
		return TGL(@"Message.Photo", @"Photo");
	if ([type isEqualToString:@"messageVideo"])
		return TGL(@"Message.Video", @"Video");
	if ([type isEqualToString:@"messageVideoNote"])
		return TGL(@"Message.VideoMessage", @"Video Message");
	if ([type isEqualToString:@"messageVoiceNote"])
		return TGL(@"Message.Audio", @"Voice message");
	if ([type isEqualToString:@"messageAudio"])
		return TGMediaPreviewName(content) ?: TGL(@"SharedMedia.CategoryOther", @"Audio");
	if ([type isEqualToString:@"messageDocument"])
		return TGMediaPreviewName(content) ?: TGL(@"Message.File", @"File");
	if ([type isEqualToString:@"messageSticker"])
		return TGL(@"Message.Sticker", @"Sticker");
	if ([type isEqualToString:@"messageAnimation"])
		return TGL(@"Message.Animation", @"GIF");
	if ([type isEqualToString:@"messageAnimatedEmoji"])
		return content[@"emoji"] ?: TGL(@"Message.Emoji", @"Emoji");
	if ([type isEqualToString:@"messageLocation"])
		return TGL(@"Message.Location", @"Location");
	if ([type isEqualToString:@"messageLiveLocation"])
		return TGL(@"Message.LiveLocation", @"Live location");
	if ([type isEqualToString:@"messageVenue"])
		return TGL(@"Message.Location", @"Location");
	if ([type isEqualToString:@"messageContact"])
		return TGL(@"Message.Contact", @"Contact");
	if ([type isEqualToString:@"messagePoll"])
		return TGL(@"Watch.Message.Poll", @"Poll");
	if ([type isEqualToString:@"messageDice"]) {
		NSString *emoji = content[@"emoji"];
		return [emoji isKindOfClass:NSString.class] && emoji.length
			? emoji
			: TGL(@"Message.Dice", @"Dice");
	}
	if ([type isEqualToString:@"messageGame"]) {
		NSString *gameTitle = content[@"game"][@"title"];
		return [gameTitle isKindOfClass:NSString.class] && gameTitle.length
			? gameTitle
			: TGL(@"Message.Game", @"Game");
	}
	if ([type isEqualToString:@"messageInvoice"]) {
		id productTitle = content[@"product_info"][@"title"] ?: content[@"title"];
		return [productTitle isKindOfClass:NSString.class] && [productTitle length]
			? productTitle
			: TGL(@"Watch.Message.Invoice", @"Invoice");
	}
	if ([type isEqualToString:@"messageStory"])
		return TGL(@"Message.Story", @"Story");
	if ([type isEqualToString:@"messagePaidMedia"])
		return TGL(@"Message.PaidMedia", @"Paid media");
	if ([type isEqualToString:@"messageChecklist"]) {
		NSString *checklistTitle = content[@"list"][@"title"][@"text"];
		return [checklistTitle isKindOfClass:NSString.class] && checklistTitle.length
			? checklistTitle
			: TGL(@"Attachment.Todo", @"Checklist");
	}
	if ([type isEqualToString:@"messageRichMessage"])
		return TGL(@"Attachment.Article", @"Article");
	return TGMessageContentKindLabel(content) ?: @"";
}

NSNumber *TGSavedTagCustomEmojiId(NSDictionary *tag) {
	if (![tag isKindOfClass:NSDictionary.class])
		return nil;
	if (![tag[@"@type"] isEqualToString:@"reactionTypeCustomEmoji"])
		return nil;
	id raw = tag[@"custom_emoji_id"];
	if (![raw isKindOfClass:NSNumber.class] && ![raw isKindOfClass:NSString.class])
		return nil;
	long long value = [raw longLongValue];
	return value ? @(value) : nil;
}

NSArray *TGSavedMessageTags(NSDictionary *message) {
	NSDictionary *info = message[@"interaction_info"];
	if (![info isKindOfClass:NSDictionary.class])
		return [NSArray array];
	NSDictionary *reactions = info[@"reactions"];
	if (![reactions isKindOfClass:NSDictionary.class])
		return [NSArray array];
	NSArray *list = reactions[@"reactions"];
	if (![list isKindOfClass:NSArray.class])
		return [NSArray array];

	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *reaction in list) {
		if (![reaction isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *type = reaction[@"type"];
		if (![type isKindOfClass:NSDictionary.class])
			continue;
		NSString *emoji = type[@"emoji"];
		if ([emoji isKindOfClass:NSString.class] && emoji.length) {
			[out addObject:emoji];
			continue;
		}
		NSNumber *customEmojiId = TGSavedTagCustomEmojiId(type);
		if (customEmojiId)
			[out addObject:[NSString stringWithFormat:@"custom:%lld", [customEmojiId longLongValue]]];
	}
	return out;
}

NSDictionary *TGSavedFlattenTopic(NSDictionary *topic,
		NSString * (^resolveChatName)(int64_t chatId)) {
	if (![topic isKindOfClass:NSDictionary.class])
		return nil;
	NSNumber *topicId = topic[@"id"];
	if (![topicId isKindOfClass:NSNumber.class])
		return nil;

	NSDictionary *type = topic[@"type"];
	if (![type isKindOfClass:NSDictionary.class])
		type = [NSDictionary dictionary];
	NSString *typeName = type[@"@type"];
	if (![typeName isKindOfClass:NSString.class])
		typeName = @"";

	NSString *kind = @"fromChat";
	NSString *title = @"";
	int64_t originChatId = 0;

	if ([typeName isEqualToString:@"savedMessagesTopicTypeMyNotes"]) {
		kind = @"myNotes";
		title = TGL(@"DialogList.MyNotes", @"My Notes");
	} else if ([typeName isEqualToString:@"savedMessagesTopicTypeAuthorHidden"]) {
		kind = @"authorHidden";
		title = TGL(@"ChatList.AuthorHidden", @"Author Hidden");
	} else {
		NSNumber *chatId = type[@"chat_id"];
		if ([chatId isKindOfClass:NSNumber.class])
			originChatId = [chatId longLongValue];
		NSString *known = resolveChatName ? resolveChatName(originChatId) : nil;
		if ([known isKindOfClass:NSString.class] && known.length)
			title = known;
	}

	NSDictionary *last = topic[@"last_message"];
	if (![last isKindOfClass:NSDictionary.class])
		last = [NSDictionary dictionary];

	NSString *draftText = @"";
	NSDictionary *draft = topic[@"draft_message"];
	if ([draft isKindOfClass:NSDictionary.class]) {
		NSDictionary *content = draft[@"content"];
		if ([content isKindOfClass:NSDictionary.class]) {
			NSDictionary *text = content[@"text"];
			if ([text isKindOfClass:NSDictionary.class] &&
				[text[@"text"] isKindOfClass:NSString.class])
				draftText = text[@"text"];
		}
	}

	return [NSDictionary dictionaryWithObjectsAndKeys:
			topicId, @"id",
		kind, @"kind",
		@(originChatId), @"chatId",
		title, @"title",
		TGSavedPreview(last) ?: @"", @"text",
		last[@"date"] ?: @(0), @"date",
		last[@"id"] ?: @(0), @"messageId",
		@([last[@"is_outgoing"] boolValue]), @"outgoing",
		@([topic[@"is_pinned"] boolValue]), @"isPinned",
		topic[@"order"] ?: @(0), @"order",
		draftText, @"draft",
		[draft isKindOfClass:NSDictionary.class] ? draft : (id)[NSNull null], @"draftMessage",
		nil];
}

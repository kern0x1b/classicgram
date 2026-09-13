#import "TGFlattenDirectMessages.h"
#import "TGFlattenMessage.h"
#import "TGDisappearingMedia.h"
#import "TGTDLibInt64.h"
#import "TGMediaPreviewName.h"
#import "TGLocalization.h"

static NSDictionary *TGDMDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSString *TGDMString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSNumber *TGDMNumber(id value) {
	return [value isKindOfClass:NSNumber.class] ? value : [NSNumber numberWithInt:0];
}

static int64_t TGDMInt64(id value) {
	return TGTDLibInt64(value);
}

static NSNumber *TGDMInt64Number(id value) {
	if ([value isKindOfClass:NSNumber.class])
		return value;
	if ([value isKindOfClass:NSString.class])
		return [NSNumber numberWithLongLong:[(NSString *)value longLongValue]];
	return [NSNumber numberWithLongLong:0];
}

NSString *TGDMPreview(NSDictionary *message) {
	NSDictionary *content = TGDMDict(message[@"content"]);
	NSString *type = TGDMString(content[@"@type"]);
	if (TGMessageDisappears(message)) {
		NSString *disappearing = TGDisappearingMediaLabel(type);
		if (disappearing)
			return disappearing;
	}
	NSDictionary *text = TGDMDict(content[@"text"]);
	if (text && [text[@"text"] isKindOfClass:NSString.class] && [text[@"text"] length])
		return text[@"text"];
	NSDictionary *caption = TGDMDict(content[@"caption"]);
	if (caption && [caption[@"text"] isKindOfClass:NSString.class] && [caption[@"text"] length])
		return caption[@"text"];
	if ([type isEqualToString:@"messagePhoto"])
		return TGL(@"Message.Photo", @"Photo");
	if ([type isEqualToString:@"messageVideo"])
		return TGL(@"Message.Video", @"Video");
	if ([type isEqualToString:@"messageVideoNote"])
		return TGL(@"Message.VideoMessage", @"Video Message");
	if ([type isEqualToString:@"messageVoiceNote"])
		return TGL(@"Message.Audio", @"Voice message");
	if ([type isEqualToString:@"messageSticker"])
		return TGL(@"Message.Sticker", @"Sticker");
	if ([type isEqualToString:@"messageDocument"])
		return TGMediaPreviewName(content) ?: TGL(@"Message.File", @"File");
	if ([type isEqualToString:@"messageAudio"])
		return TGMediaPreviewName(content) ?: TGL(@"SharedMedia.CategoryOther", @"Audio");
	if ([type isEqualToString:@"messageAnimation"])
		return TGL(@"Message.Animation", @"GIF");
	if ([type isEqualToString:@"messageLocation"])
		return TGL(@"Message.Location", @"Location");
	if ([type isEqualToString:@"messageContact"])
		return TGL(@"Message.Contact", @"Contact");
	if ([type isEqualToString:@"messagePoll"])
		return TGL(@"Watch.Message.Poll", @"Poll");
	return TGMessageContentKindLabel(content) ?: @"";
}

NSDictionary *TGDMFlattenTopic(NSDictionary *topic) {
	if (![topic isKindOfClass:NSDictionary.class])
		return nil;
	NSDictionary *sender = TGDMDict(topic[@"sender_id"]);
	BOOL senderIsChat = [TGDMString(sender[@"@type"]) isEqualToString:@"messageSenderChat"];
	int64_t senderUserId = senderIsChat ? 0 : TGDMInt64(sender[@"user_id"]);
	int64_t senderChatId = senderIsChat ? TGDMInt64(sender[@"chat_id"]) : 0;
	NSDictionary *last = TGDMDict(topic[@"last_message"]);
	NSDictionary *draft = TGDMDict(topic[@"draft_message"]);

	return @{
		@"topicId" : TGDMNumber(topic[@"id"]),
		@"chatId" : TGDMNumber(topic[@"chat_id"]),
		@"senderUserId" : @(senderUserId),
		@"senderChatId" : @(senderChatId),
		@"order" : TGDMInt64Number(topic[@"order"]),
		@"canSendUnpaidMessages" : @([TGDMNumber(topic[@"can_send_unpaid_messages"]) boolValue]),
		@"isMarkedAsUnread" : @([TGDMNumber(topic[@"is_marked_as_unread"]) boolValue]),
		@"unread" : TGDMNumber(topic[@"unread_count"]),
		@"lastReadInboxMessageId" : TGDMInt64Number(topic[@"last_read_inbox_message_id"]),
		@"lastReadOutboxMessageId" : TGDMInt64Number(topic[@"last_read_outbox_message_id"]),
		@"unreadReactions" : TGDMNumber(topic[@"unread_reaction_count"]),
		@"text" : TGDMPreview(last) ?: @"",
		@"date" : TGDMNumber(last[@"date"]),
		@"outgoing" : @([TGDMNumber(last[@"is_outgoing"]) boolValue]),
		@"draftMessage" : draft ?: (id)[NSNull null],
	};
}

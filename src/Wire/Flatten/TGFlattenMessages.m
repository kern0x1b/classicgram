#import "TGFlattenMessages.h"
#import "TGDisappearingMedia.h"
#import "TGFlattenSavedMessages.h"
#import "TGResultIsError.h"
#import "TGLocalization.h"
#import <math.h>

static NSDictionary *TGMsgDictOf(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSString *TGMsgStringOf(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

BOOL TGMsgLooksLikeMp3(NSString *mimeType, NSString *fileName) {
	if ([mimeType isEqualToString:@"audio/mpeg"] || [mimeType isEqualToString:@"audio/mp3"])
		return YES;
	return [fileName.pathExtension.lowercaseString isEqualToString:@"mp3"];
}

NSString *TGMsgNotificationSoundPathFromRaw(NSDictionary *message) {
	NSDictionary *content = TGMsgDictOf(message[@"content"]);
	NSString *kind = TGMsgStringOf(content[@"@type"]);
	NSDictionary *media = nil;
	NSString *fileKey = nil;
	if ([kind isEqualToString:@"messageAudio"]) {
		media = TGMsgDictOf(content[@"audio"]);
		fileKey = @"audio";
	} else if ([kind isEqualToString:@"messageDocument"]) {
		media = TGMsgDictOf(content[@"document"]);
		fileKey = @"document";
	} else {
		return nil;
	}
	if (!media)
		return nil;

	NSString *mimeType = TGMsgStringOf(media[@"mime_type"]);
	NSString *fileName = TGMsgStringOf(media[@"file_name"]);
	if (!TGMsgLooksLikeMp3(mimeType, fileName))
		return nil;
	if ([media[@"duration"] doubleValue] >= 60)
		return nil;

	NSDictionary *file = TGMsgDictOf(media[fileKey]);
	if ([file[@"size"] longLongValue] >= 1024 * 1024)
		return nil;
	NSDictionary *local = TGMsgDictOf(file[@"local"]);
	if (![local[@"is_downloading_completed"] boolValue])
		return nil;
	NSString *path = TGMsgStringOf(local[@"path"]);
	return path.length ? path : nil;
}

NSDictionary *TGMsgSendOptions(NSDictionary *options) {
	NSMutableDictionary *out = [@{
		@"@type" : @"messageSendOptions",
		@"disable_notification" : @([options[@"silent"] boolValue]),
		@"protect_content" : @([options[@"protect"] boolValue]),
		@"from_background" : @NO,
	} mutableCopy];

	NSTimeInterval sendDate = [options[@"sendDate"] doubleValue];
	if (sendDate > 0)
		out[@"scheduling_state"] = @{@"@type" : @"messageSchedulingStateSendAtDate",
			@"send_date" : @((int32_t)sendDate)};
	else if ([options[@"whenOnline"] boolValue])
		out[@"scheduling_state"] = @{@"@type" : @"messageSchedulingStateSendWhenOnline"};

	int64_t effectId = [options[@"effectId"] longLongValue];
	if (effectId)
		out[@"effect_id"] = @(effectId);

	int64_t paidStarCount = [options[@"paidStarCount"] longLongValue];
	if (paidStarCount > 0) {
		NSInteger messageCount = [options[@"paidStarMessageCount"] integerValue];
		if (messageCount < 1)
			messageCount = 1;
		out[@"paid_message_star_count"] = @(paidStarCount * messageCount);
	}

	return out;
}

BOOL TGMsgCanReactTo(NSDictionary *reactions) {
	if (TGResultIsError(reactions))
		return NO;
	if ([reactions[@"unavailability_reason"] isKindOfClass:NSDictionary.class])
		return NO;
	for (NSString *key in @[ @"top_reactions", @"recent_reactions", @"popular_reactions" ]) {
		NSArray *list = reactions[key];
		if ([list isKindOfClass:NSArray.class] && list.count)
			return YES;
	}
	return NO;
}

NSDictionary *TGMsgBrief(NSDictionary *m) {
	if (![m isKindOfClass:NSDictionary.class])
		return nil;

	NSDictionary *content = [m[@"content"] isKindOfClass:NSDictionary.class]
		? m[@"content"]
		: @{};
	NSString *ctype = [content[@"@type"] isKindOfClass:NSString.class]
		? content[@"@type"]
		: @"";

	NSString *text = @"";
	if (TGMessageDisappears(m)) {
		text = TGDisappearingMediaLabel(ctype) ?: @"";
	} else {
		NSDictionary *body = [content[@"text"] isKindOfClass:NSDictionary.class]
			? content[@"text"]
			: ([content[@"caption"] isKindOfClass:NSDictionary.class]
					  ? content[@"caption"]
					  : nil);
		if ([body[@"text"] isKindOfClass:NSString.class])
			text = body[@"text"];
	}

	NSNumber *senderId = @0;
	NSNumber *senderChatId = @0;
	NSDictionary *sender = [m[@"sender_id"] isKindOfClass:NSDictionary.class]
		? m[@"sender_id"]
		: nil;
	if ([sender[@"@type"] isEqualToString:@"messageSenderChat"]) {
		if ([sender[@"chat_id"] isKindOfClass:NSNumber.class])
			senderChatId = sender[@"chat_id"];
	} else if ([sender[@"user_id"] isKindOfClass:NSNumber.class]) {
		senderId = sender[@"user_id"];
	}

	NSDictionary *sendingState = [m[@"sending_state"] isKindOfClass:NSDictionary.class]
		? m[@"sending_state"]
		: nil;
	NSString *sendingStateType = [sendingState[@"@type"] isKindOfClass:NSString.class]
		? sendingState[@"@type"]
		: @"";
	NSString *sendingStatus = @"sent";
	if ([sendingStateType isEqualToString:@"messageSendingStatePending"])
		sendingStatus = @"pending";
	else if ([sendingStateType isEqualToString:@"messageSendingStateFailed"])
		sendingStatus = @"failed";
	BOOL canRetry = [sendingStateType isEqualToString:@"messageSendingStateFailed"] &&
		[sendingState[@"can_retry"] boolValue];
	BOOL needAnotherReplyQuote = [sendingStateType isEqualToString:@"messageSendingStateFailed"] &&
		[sendingState[@"need_another_reply_quote"] boolValue];
	BOOL needDropReply = [sendingStateType isEqualToString:@"messageSendingStateFailed"] &&
		[sendingState[@"need_drop_reply"] boolValue];
	int64_t requiredPaidMessageStarCount = [sendingStateType isEqualToString:@"messageSendingStateFailed"]
		? [sendingState[@"required_paid_message_star_count"] longLongValue]
		: 0;

	return @{
		@"id" : m[@"id"] ?: @0,
		@"text" : text,
		@"kind" : ctype,
		@"date" : m[@"date"] ?: @0,
		@"outgoing" : m[@"is_outgoing"] ?: @NO,
		@"senderId" : senderId,
		@"senderChatId" : senderChatId,
		@"sendingState" : sendingStatus,
		@"canRetry" : @(canRetry),
		@"needAnotherReplyQuote" : @(needAnotherReplyQuote),
		@"needDropReply" : @(needDropReply),
		@"requiredPaidMessageStarCount" : @(requiredPaidMessageStarCount),
		@"sendErrorMessage" : TGSendFailureMessage(sendingState, NO) ?: @"",
	};
}

NSString *TGQuickReplyContentLabel(NSString *kind) {
	if ([kind isEqualToString:@"messagePhoto"])
		return TGL(@"Message.Photo", @"Photo");
	if ([kind isEqualToString:@"messageVideo"])
		return TGL(@"Message.Video", @"Video");
	if ([kind isEqualToString:@"messageAnimation"])
		return TGL(@"Message.Animation", @"GIF");
	if ([kind isEqualToString:@"messageSticker"])
		return TGL(@"Message.Sticker", @"Sticker");
	if ([kind isEqualToString:@"messageVoiceNote"])
		return TGL(@"Message.Audio", @"Voice message");
	if ([kind isEqualToString:@"messageVideoNote"])
		return TGL(@"Message.VideoMessage", @"Video Message");
	if ([kind isEqualToString:@"messageDocument"])
		return TGL(@"Message.File", @"File");
	if ([kind isEqualToString:@"messageAudio"])
		return TGL(@"SharedMedia.CategoryOther", @"Audio");
	if ([kind isEqualToString:@"messageContact"])
		return TGL(@"Message.Contact", @"Contact");
	if ([kind isEqualToString:@"messagePoll"])
		return TGL(@"Watch.Message.Poll", @"Poll");
	if ([kind isEqualToString:@"messageLocation"])
		return TGL(@"Message.Location", @"Location");
	if ([kind isEqualToString:@"messageRichMessage"])
		return TGL(@"Attachment.Article", @"Article");
	return kind.length ? TGL(@"Watch.Message.Unsupported", @"Unsupported Message") : @"";
}

NSDictionary *TGQuickReplyShortcutFromUpdate(NSDictionary *shortcut) {
	if (![shortcut isKindOfClass:NSDictionary.class])
		return nil;
	NSNumber *shortcutId = shortcut[@"id"];
	if (![shortcutId isKindOfClass:NSNumber.class])
		return nil;

	NSDictionary *brief = TGMsgBrief(shortcut[@"first_message"]);
	NSString *preview = brief[@"text"];
	if (!preview.length)
		preview = TGQuickReplyContentLabel(brief[@"kind"] ?: @"");

	return @{
		@"id" : shortcutId,
		@"name" : [shortcut[@"name"] isKindOfClass:NSString.class]
			? shortcut[@"name"]
			: @"",
		@"messageCount" : shortcut[@"message_count"] ?: @0,
		@"preview" : preview ?: @"",
	};
}

NSArray *TGCustomEmojiRunsFromEntities(NSArray *entities, NSString *text) {
	NSMutableArray *runs = [NSMutableArray array];
	for (NSDictionary *entity in entities) {
		if (![entity isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *type = entity[@"type"];
		if (![type[@"@type"] isEqualToString:@"textEntityTypeCustomEmoji"])
			continue;
		NSRange range = NSMakeRange((NSUInteger)[entity[@"offset"] integerValue],
			(NSUInteger)[entity[@"length"] integerValue]);
		if (NSMaxRange(range) > text.length)
			continue;
		long long customEmojiId = [type[@"custom_emoji_id"] longLongValue];
		if (!customEmojiId)
			continue;
		[runs addObject:@{
			@"range" : [NSValue valueWithRange:range],
			@"glyph" : [text substringWithRange:range],
			@"customEmojiId" : @(customEmojiId),
		}];
	}
	return runs;
}

NSArray *TGMentionNameRunsFromEntities(NSArray *entities, NSString *text) {
	NSMutableArray *runs = [NSMutableArray array];
	for (NSDictionary *entity in entities) {
		if (![entity isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *type = entity[@"type"];
		if (![type[@"@type"] isEqualToString:@"textEntityTypeMentionName"])
			continue;
		NSRange range = NSMakeRange((NSUInteger)[entity[@"offset"] integerValue],
			(NSUInteger)[entity[@"length"] integerValue]);
		if (NSMaxRange(range) > text.length)
			continue;
		int64_t userId = [type[@"user_id"] longLongValue];
		if (!userId)
			continue;
		[runs addObject:@{
			@"range" : [NSValue valueWithRange:range],
			@"text" : [text substringWithRange:range],
			@"userId" : @(userId),
		}];
	}
	return runs;
}

static NSString *const kTGSlowModeWaitPrefix = @"SLOWMODE_WAIT_";

static NSString *TGSendFailureDurationText(NSInteger seconds) {
	seconds = MAX(seconds, (NSInteger)1);
	if (seconds < 60)
		return TGLPlural(@"MessageTimer.Seconds", seconds, @"%ld second", @"%ld seconds");
	if (seconds < 3600) {
		NSInteger minutes = (seconds + 59) / 60;
		return TGLPlural(@"MessageTimer.Minutes", minutes, @"%ld minute", @"%ld minutes");
	}
	NSInteger hours = (seconds + 3599) / 3600;
	return TGLPlural(@"MessageTimer.Hours", hours, @"%ld hour", @"%ld hours");
}

NSString *TGSendFailureMessage(NSDictionary *sendingState, BOOL slowModeActiveForChat) {
	NSDictionary *state = TGMsgDictOf(sendingState);
	if (![TGMsgStringOf(state[@"@type"]) isEqualToString:@"messageSendingStateFailed"])
		return nil;

	NSDictionary *error = TGMsgDictOf(state[@"error"]);
	NSString *errorMessage = TGMsgStringOf(error[@"message"]);
	double retryAfter = [state[@"retry_after"] doubleValue];

	if ([errorMessage hasPrefix:kTGSlowModeWaitPrefix]) {
		NSInteger seconds = [[errorMessage substringFromIndex:kTGSlowModeWaitPrefix.length] integerValue];
		if (seconds <= 0 && retryAfter > 0)
			seconds = (NSInteger)ceil(retryAfter);
		return [NSString stringWithFormat:TGL(@"Toast.SlowModeWaitFormat", @"Slow mode is active. Try again in %@"),
			TGSendFailureDurationText(seconds)];
	}

	NSInteger requiredPaidMessageStarCount = [state[@"required_paid_message_star_count"] integerValue];
	if (requiredPaidMessageStarCount > 0) {
		NSString *starsText = TGLPlural(@"Chat.PaidMessage.Confirm.Text.Stars", requiredPaidMessageStarCount,
			@"%@ Star", @"%@ Stars");
		return [NSString stringWithFormat:TGL(@"Chat.PaidMessage.RequiredAmount", @"This message requires %@ to send"),
			starsText];
	}

	if (retryAfter > 0) {
		NSInteger seconds = (NSInteger)ceil(retryAfter);
		if (slowModeActiveForChat) {
			return [NSString stringWithFormat:TGL(@"Toast.SlowModeWaitFormat", @"Slow mode is active. Try again in %@"),
				TGSendFailureDurationText(seconds)];
		}
		return [NSString stringWithFormat:TGL(@"Toast.PleaseWaitBeforeSendingFormat", @"Please wait %@ before sending again"),
			TGSendFailureDurationText(seconds)];
	}

	return errorMessage.length ? errorMessage : nil;
}

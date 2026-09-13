#import "TGClient+ChatManagement.h"
#import "TGLocalization.h"
#import "TGClient+ChatState.h"
#import "TGMessageReply.h"
#import "TGClient+Messages.h"
#import "TGClient+Private.h"
#import "TGClient+Privacy.h"
#import "TGClient+SavedMessages.h"
#import "TGClient+SecretChats.h"
#import "TGFlattenMessage.h"
#import "TGFlattenMessages.h"
#import "TGMessageTopic.h"
#import "TGBase64.h"

static NSDictionary *TGMsgDictOf(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSString *TGMsgStringOf(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSDictionary *TGMsgFormattedText(NSString *text) {
	return @{@"@type" : @"formattedText", @"text" : text ?: @""};
}

static BOOL TGMsgChatIsForum(TGClient *client, int64_t chatId) {
	id value = client.chatsById[@(chatId)][@"isForum"];
	return [value isKindOfClass:NSNumber.class] && [value boolValue];
}

static NSDictionary *TGMsgTopic(int64_t threadId, BOOL chatIsForum) {
	return TGMessageTopicDictionary(threadId, chatIsForum);
}

static NSDictionary *TGDraftTopic(int64_t threadId, int64_t directMessagesTopicId, int64_t savedTopicId,
	BOOL chatIsForum) {
	return TGTopicDictionary(threadId, directMessagesTopicId, savedTopicId, chatIsForum);
}

static NSDictionary *TGMsgTextContent(NSString *text, BOOL clearDraft) {
	return @{
		@"@type" : @"inputMessageText",
		@"text" : TGMsgFormattedText(text),
		@"clear_draft" : @(clearDraft),
	};
}

static NSDictionary *TGMsgFormattedTextWithEntities(NSString *text, NSArray *entities) {
	NSMutableDictionary *out = [@{@"@type" : @"formattedText", @"text" : text ?: @""}
		mutableCopy];
	if (entities.count > 0)
		out[@"entities"] = entities;
	return out;
}

static NSDictionary *TGMsgTextContentWithEntities(NSString *text, NSArray *entities,
	BOOL clearDraft) {
	return @{
		@"@type" : @"inputMessageText",
		@"text" : TGMsgFormattedTextWithEntities(text, entities),
		@"clear_draft" : @(clearDraft),
	};
}

static NSDictionary *TGMsgDefaultLinkPreviewOptions(void) {
	return @{
		@"@type" : @"linkPreviewOptions",
		@"is_disabled" : @NO,
		@"url" : @"",
		@"force_small_media" : @NO,
		@"force_large_media" : @NO,
		@"show_above_text" : @NO,
	};
}

static NSDictionary *TGMsgEditTextContent(NSString *text, NSDictionary *linkPreviewOptions) {
	NSMutableDictionary *out = [TGMsgTextContent(text, NO) mutableCopy];
	out[@"link_preview_options"] = linkPreviewOptions ?: TGMsgDefaultLinkPreviewOptions();
	return out;
}

static NSDictionary *TGMsgEditTextContentWithEntities(NSString *text, NSArray *entities,
	NSDictionary *linkPreviewOptions) {
	NSMutableDictionary *out = [TGMsgTextContentWithEntities(text, entities, NO) mutableCopy];
	out[@"link_preview_options"] = linkPreviewOptions ?: TGMsgDefaultLinkPreviewOptions();
	return out;
}

static NSDictionary *TGWireEntityTypeFromFlattened(NSDictionary *flattened) {
	NSString *kind = TGMsgStringOf(flattened[@"kind"]);
	NSString *typeName = [@"textEntityType" stringByAppendingString:kind];
	if ([kind isEqualToString:@"TextUrl"])
		return @{@"@type" : typeName, @"url" : TGMsgStringOf(flattened[@"url"])};
	if ([kind isEqualToString:@"MentionName"])
		return @{@"@type" : typeName, @"user_id" : @([flattened[@"userId"] longLongValue])};
	if ([kind isEqualToString:@"PreCode"])
		return @{@"@type" : typeName, @"language" : TGMsgStringOf(flattened[@"language"])};
	if ([kind isEqualToString:@"CustomEmoji"])
		return @{@"@type" : typeName,
			@"custom_emoji_id" : [NSString stringWithFormat:@"%lld", [flattened[@"customEmojiId"] longLongValue]]};
	if ([kind isEqualToString:@"MediaTimestamp"])
		return @{@"@type" : typeName, @"media_timestamp" : @([flattened[@"timestamp"] intValue])};
	if ([kind isEqualToString:@"DateTime"])
		return @{@"@type" : typeName, @"unix_time" : @([flattened[@"timestamp"] intValue])};
	return @{@"@type" : typeName};
}

NSArray *TGWireEntitiesFromFlattened(NSArray *flattened) {
	if (![flattened isKindOfClass:NSArray.class] || flattened.count == 0)
		return nil;
	NSMutableArray *out = [NSMutableArray arrayWithCapacity:flattened.count];
	for (NSDictionary *entity in flattened) {
		if (![entity isKindOfClass:NSDictionary.class])
			continue;
		NSString *kind = TGMsgStringOf(entity[@"kind"]);
		if (!kind.length)
			continue;
		[out addObject:@{
			@"@type" : @"textEntity",
			@"offset" : @((int32_t)[entity[@"offset"] integerValue]),
			@"length" : @((int32_t)[entity[@"length"] integerValue]),
			@"type" : TGWireEntityTypeFromFlattened(entity),
		}];
	}
	return out.count ? out : nil;
}

static NSString *TGMsgSenderName(int64_t userId) {
	NSString *name = [[TGClient shared] nameForUserId:userId];
	return name.length ? name : @"";
}

NSString *const TGQuickReplyShortcutsUpdatedNotification =
	@"TGQuickReplyShortcutsUpdatedNotification";
NSString *const TGQuickReplyShortcutMessagesUpdatedNotification =
	@"TGQuickReplyShortcutMessagesUpdatedNotification";

static NSMutableDictionary *TGQuickReplyStore(void) {
	static NSMutableDictionary *store = nil;
	if (!store)
		store = [[NSMutableDictionary alloc] init];
	return store;
}

static NSMutableArray *TGQuickReplyOrder(void) {
	static NSMutableArray *order = nil;
	if (!order)
		order = [[NSMutableArray alloc] init];
	return order;
}

static NSMutableDictionary *TGQuickReplyMessagesStore(void) {
	static NSMutableDictionary *store = nil;
	if (!store)
		store = [[NSMutableDictionary alloc] init];
	return store;
}

static NSArray *TGMsgBriefList(NSDictionary *result) {
	NSMutableArray *out = [NSMutableArray array];
	NSArray *messages = result[@"messages"];
	if (![messages isKindOfClass:NSArray.class])
		return out;
	for (NSDictionary *m in messages) {
		NSDictionary *flat = TGMsgBrief(m);
		if (flat)
			[out addObject:flat];
	}
	return out;
}

static NSArray *TGFlattenedQuickReplyMessageList(NSDictionary *result) {
	NSMutableArray *out = [NSMutableArray array];
	NSArray *messages = result[@"messages"];
	if (![messages isKindOfClass:NSArray.class])
		return out;
	TGFlattenContext *context = TGCurrentFlattenContext();
	for (NSDictionary *m in messages) {
		if (![m isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *flat = TGFlattenMessage(m, context);
		if (flat)
			[out addObject:flat];
	}
	return out;
}

@implementation TGClient (Messages)

#pragma mark - sending

- (void)sendText:(NSString *)text
		  toChat:(int64_t)chatId
		  thread:(int64_t)threadId
	  savedTopic:(int64_t)savedTopicId
		 replyTo:(int64_t)replyToId
		 options:(NSDictionary *)options
	  completion:(void (^)(NSDictionary *))completion {
	BOOL clearDraft = YES;
	NSArray *entities = [options[@"entities"] isKindOfClass:NSArray.class]
		? options[@"entities"]
		: nil;

	NSMutableDictionary *request = [@{
		@"@type" : @"sendMessage",
		@"chat_id" : @(chatId),
		@"options" : TGMsgSendOptions(options),
		@"input_message_content" : entities.count
			? TGMsgTextContentWithEntities(text, entities, clearDraft)
			: TGMsgTextContent(text, clearDraft),
	} mutableCopy];

	NSDictionary *topic = TGTopicDictionary(threadId, 0, savedTopicId, TGMsgChatIsForum(self, chatId));
	if (topic)
		request[@"topic_id"] = topic;
	NSDictionary *replyTo = TGReplyToDictionary(replyToId, nil, nil, 0);
	if (replyTo)
		request[@"reply_to"] = replyTo;

	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGMsgBrief(result));
	}];
}

- (void)sendText:(NSString *)text
		   toChat:(int64_t)chatId
		   thread:(int64_t)threadId
		  replyTo:(int64_t)replyToId
		quoteText:(NSString *)quoteText
	quotePosition:(NSInteger)quotePosition
	   completion:(void (^)(NSDictionary *))completion {
	[self sendText:text toChat:chatId thread:threadId savedTopic:0 replyTo:replyToId
			quoteText:quoteText
		quotePosition:quotePosition
			  options:nil
		   completion:completion];
}

- (void)sendText:(NSString *)text
		   toChat:(int64_t)chatId
		   thread:(int64_t)threadId
	   savedTopic:(int64_t)savedTopicId
		  replyTo:(int64_t)replyToId
		quoteText:(NSString *)quoteText
	quotePosition:(NSInteger)quotePosition
		  options:(NSDictionary *)options
	   completion:(void (^)(NSDictionary *))completion {
	if (replyToId == 0 || !quoteText.length) {
		[self sendText:text toChat:chatId thread:threadId savedTopic:savedTopicId replyTo:replyToId
			   options:options
			completion:completion];
		return;
	}

	NSArray *entities = [options[@"entities"] isKindOfClass:NSArray.class]
		? options[@"entities"]
		: nil;
	NSArray *quoteEntities = TGWireEntitiesFromFlattened(options[@"quoteEntities"]);

	NSMutableDictionary *request = [@{
		@"@type" : @"sendMessage",
		@"chat_id" : @(chatId),
		@"options" : TGMsgSendOptions(options),
		@"input_message_content" : entities.count
			? TGMsgTextContentWithEntities(text, entities, YES)
			: TGMsgTextContent(text, YES),
		@"reply_to" : TGReplyToDictionary(replyToId, quoteText, quoteEntities, quotePosition),
	} mutableCopy];

	NSDictionary *topic = TGTopicDictionary(threadId, 0, savedTopicId, TGMsgChatIsForum(self, chatId));
	if (topic)
		request[@"topic_id"] = topic;

	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGMsgBrief(result));
	}];
}

- (void)sendText:(NSString *)text
			toChat:(int64_t)chatId
	replyToMessage:(int64_t)messageId
		  fromChat:(int64_t)sourceChatId
		completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"sendMessage",
		@"chat_id" : @(chatId),
		@"options" : TGMsgSendOptions(nil),
		@"input_message_content" : TGMsgTextContent(text, YES),
		@"reply_to" : @{
			@"@type" : @"inputMessageReplyToExternalMessage",
			@"chat_id" : @(sourceChatId),
			@"message_id" : @(messageId),
		},
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGMsgBrief(result));
	}];
}

- (void)addLocalTextMessage:(NSString *)text
					 toChat:(int64_t)chatId
			   senderUserId:(int64_t)senderUserId
					replyTo:(int64_t)replyToId
				 completion:(void (^)(NSDictionary *))completion {
	int64_t sender = senderUserId;
	if (sender == 0)
		sender = [self.me[@"id"] longLongValue];

	NSMutableDictionary *request = [@{
		@"@type" : @"addLocalMessage",
		@"chat_id" : @(chatId),
		@"sender_id" : @{@"@type" : @"messageSenderUser",
			@"user_id" : @(sender)},
		@"disable_notification" : @YES,
		@"input_message_content" : TGMsgTextContent(text, NO),
	} mutableCopy];

	NSDictionary *replyTo = TGReplyToDictionary(replyToId, nil, nil, 0);
	if (replyTo)
		request[@"reply_to"] = replyTo;

	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGMsgBrief(result));
	}];
}

- (void)resendMessages:(NSArray *)messageIds
				inChat:(int64_t)chatId
			completion:(void (^)(NSArray *))completion {
	[self resendMessages:messageIds inChat:chatId dropQuote:NO completion:completion];
}

- (void)resendMessages:(NSArray *)messageIds
				inChat:(int64_t)chatId
			 dropQuote:(BOOL)dropQuote
			completion:(void (^)(NSArray *))completion {
	[self resendMessages:messageIds inChat:chatId dropQuote:dropQuote paidStarCount:0 completion:completion];
}

- (void)resendMessages:(NSArray *)messageIds
				inChat:(int64_t)chatId
			 dropQuote:(BOOL)dropQuote
		 paidStarCount:(int64_t)paidStarCount
			completion:(void (^)(NSArray *))completion {
	if (!messageIds.count) {
		if (completion)
			completion(@[]);
		return;
	}

	NSMutableDictionary *request = [@{
		@"@type" : @"resendMessages",
		@"chat_id" : @(chatId),
		@"message_ids" : messageIds,
	} mutableCopy];
	if (dropQuote)
		request[@"quote"] = @{@"@type" : @"inputTextQuote",
			@"text" : TGMsgFormattedText(@""),
			@"position" : @0};
	if (paidStarCount > 0)
		request[@"paid_message_star_count"] = @(paidStarCount);

	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? @[] : TGMsgBriefList(result));
	}];
}

- (void)sendingStateOfMessage:(int64_t)messageId
					   inChat:(int64_t)chatId
				   completion:(void (^)(NSString *, BOOL))completion {
	[self request:@{@"@type" : @"getMessage",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(@"failed", NO);
				return;
			}

			NSDictionary *state = [result[@"sending_state"] isKindOfClass:NSDictionary.class]
				? result[@"sending_state"]
				: nil;
			NSString *type = [state[@"@type"] isKindOfClass:NSString.class]
				? state[@"@type"]
				: nil;

			if (!type) {
				completion(@"sent", NO);
				return;
			}
			if ([type isEqualToString:@"messageSendingStateFailed"]) {
				completion(@"failed", [state[@"can_retry"] boolValue]);
				return;
			}
			completion(@"pending", NO);
		}];
}

#pragma mark - editing

- (void)replaceMediaInMessage:(int64_t)messageId
					   inChat:(int64_t)chatId
					  content:(NSDictionary *)content
				   completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"editMessageMedia",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"input_message_content" : content,
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)replacePhotoInMessage:(int64_t)messageId
					   inChat:(int64_t)chatId
						 path:(NSString *)path
					  caption:(NSString *)caption
					  spoiler:(BOOL)spoiler
				   completion:(void (^)(BOOL))completion {
	if (!path.length) {
		if (completion)
			completion(NO);
		return;
	}

	[self replaceMediaInMessage:messageId inChat:chatId content:@{
		@"@type" : @"inputMessagePhoto",
		@"photo" : @{@"@type" : @"inputPhoto",
			@"photo" : @{@"@type" : @"inputFileLocal", @"path" : path}},
		@"caption" : TGMsgFormattedText(caption),
		@"has_spoiler" : @(spoiler),
	}
					 completion:completion];
}

- (void)replaceVideoInMessage:(int64_t)messageId
					   inChat:(int64_t)chatId
						 path:(NSString *)path
					  caption:(NSString *)caption
					  spoiler:(BOOL)spoiler
				   completion:(void (^)(BOOL))completion {
	if (!path.length) {
		if (completion)
			completion(NO);
		return;
	}

	[self replaceMediaInMessage:messageId inChat:chatId content:@{
		@"@type" : @"inputMessageVideo",
		@"video" : @{@"@type" : @"inputVideo",
			@"video" : @{@"@type" : @"inputFileLocal", @"path" : path},
			@"supports_streaming" : @NO},
		@"caption" : TGMsgFormattedText(caption),
		@"has_spoiler" : @(spoiler),
	}
					 completion:completion];
}

- (void)propertiesOfMessage:(int64_t)messageId
					 inChat:(int64_t)chatId
				 completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getMessageProperties",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(@{});
				return;
			}

			NSMutableDictionary *out = [@{
				@"canEdit" : result[@"can_be_edited"] ?: @NO,
				@"canEditMedia" : result[@"can_edit_media"] ?: @NO,
				@"canDeleteForMe" : result[@"can_be_deleted_only_for_self"] ?: @NO,
				@"canDeleteForEveryone" : result[@"can_be_deleted_for_all_users"] ?: @NO,
				@"canForward" : result[@"can_be_forwarded"] ?: @NO,
				@"canCopy" : result[@"can_be_copied"] ?: @NO,
				@"canPin" : result[@"can_be_pinned"] ?: @NO,
				@"canReply" : result[@"can_be_replied"] ?: @NO,
				@"canReplyInAnotherChat" : result[@"can_be_replied_in_another_chat"] ?: @NO,
				@"canGetLink" : result[@"can_get_link"] ?: @NO,
				@"canGetEmbeddingCode" : result[@"can_get_embedding_code"] ?: @NO,
				@"canGetViewers" : result[@"can_get_viewers"] ?: @NO,
				@"canGetAuthor" : result[@"can_get_author"] ?: @NO,
				@"canGetReadDate" : result[@"can_get_read_date"] ?: @NO,
				@"canGetThread" : result[@"can_get_message_thread"] ?: @NO,
				@"canEditSchedulingState" : result[@"can_edit_scheduling_state"] ?: @NO,
				@"canReport" : result[@"can_report_chat"] ?: @NO,
				@"canSave" : result[@"can_be_saved"] ?: @NO,
				@"canDeleteReactions" : result[@"can_delete_reactions"] ?: @NO,
				@"canReportReactions" : result[@"can_report_reactions"] ?: @NO,
				@"canReportSpam" : result[@"can_report_supergroup_spam"] ?: @NO,
				@"canRecognizeSpeech" : result[@"can_recognize_speech"] ?: @NO,
				@"canGetStatistics" : result[@"can_get_statistics"] ?: @NO,
				@"canGetPollVoteStatistics" : result[@"can_get_poll_vote_statistics"] ?: @NO,
				@"canSetFactCheck" : result[@"can_set_fact_check"] ?: @NO,
				@"canApproveSuggestedPost" : result[@"can_be_approved"] ?: @NO,
				@"canDeclineSuggestedPost" : result[@"can_be_declined"] ?: @NO,
				@"canAddOffer" : result[@"can_add_offer"] ?: @NO,
				@"canEditSuggestedPostInfo" : result[@"can_edit_suggested_post_info"] ?: @NO,
			} mutableCopy];

			BOOL canSelect = [result[@"can_be_copied"] boolValue] ||
				[result[@"can_be_forwarded"] boolValue] ||
				[result[@"can_be_deleted_only_for_self"] boolValue] ||
				[result[@"can_be_deleted_for_all_users"] boolValue];
			out[@"canSelect"] = @(canSelect);

			[self request:@{@"@type" : @"getMessage",
				@"chat_id" : @(chatId),
				@"message_id" : @(messageId)}
				completion:^(NSDictionary *message) {
					NSDictionary *flat = TGResultIsError(message) ? nil : TGMsgBrief(message);
					NSString *text = [flat[@"text"] isKindOfClass:NSString.class]
						? flat[@"text"]
						: @"";
					out[@"canTranslate"] = @(text.length > 0 && ![self isSecretChat:chatId]);
					out[@"canSetAsNotificationSound"] = @(TGMsgNotificationSoundPathFromRaw(message) != nil);

					[self request:@{@"@type" : @"getMessageAvailableReactions",
						@"chat_id" : @(chatId),
						@"message_id" : @(messageId),
						@"row_size" : @(7)}
						completion:^(NSDictionary *reactions) {
							out[@"canReactTo"] = @(TGMsgCanReactTo(reactions));
							completion(out);
						}];
				}];
		}];
}

- (void)notificationSoundPathForMessage:(int64_t)messageId
								 inChat:(int64_t)chatId
							 completion:(void (^)(NSString *, NSString *))completion {
	if (!completion)
		return;
	[self request:@{@"@type" : @"getMessage",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId)}
		completion:^(NSDictionary *message) {
			if (TGResultIsError(message)) {
				completion(nil, TGL(@"NotificationSound.MessageUnreadable", @"This message could not be read."));
				return;
			}
			NSDictionary *content = TGMsgDictOf(message[@"content"]);
			NSString *kind = TGMsgStringOf(content[@"@type"]);
			if (![kind isEqualToString:@"messageAudio"] && ![kind isEqualToString:@"messageDocument"]) {
				completion(nil, TGL(@"NotificationSound.NotAudio", @"This isn't an audio file."));
				return;
			}
			NSDictionary *media = [kind isEqualToString:@"messageAudio"]
				? TGMsgDictOf(content[@"audio"])
				: TGMsgDictOf(content[@"document"]);
			NSString *mimeType = TGMsgStringOf(media[@"mime_type"]);
			NSString *fileName = TGMsgStringOf(media[@"file_name"]);
			if (!TGMsgLooksLikeMp3(mimeType, fileName)) {
				completion(nil, TGL(@"NotificationSound.NeedsMp3", @"Telegram only accepts notification sounds in MP3 format."));
				return;
			}
			NSString *path = TGMsgNotificationSoundPathFromRaw(message);
			if (!path.length) {
				completion(nil, TGL(@"NotificationSound.StillDownloading", @"This file hasn't finished downloading yet."));
				return;
			}
			completion(path, nil);
		}];
}

#pragma mark - suggested posts

- (void)approveSuggestedPost:(int64_t)messageId
					  inChat:(int64_t)chatId
				  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"approveSuggestedPost",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"send_date" : @0,
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)declineSuggestedPost:(int64_t)messageId
					  inChat:(int64_t)chatId
					 comment:(NSString *)comment
				  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"declineSuggestedPost",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"comment" : comment ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)addOfferForMessage:(int64_t)messageId
					inChat:(int64_t)chatId
				 starCount:(int64_t)starCount
				  sendDate:(int64_t)sendDate
				completion:(void (^)(BOOL))completion {
	NSMutableDictionary *suggestedPostInfo = [NSMutableDictionary dictionaryWithDictionary:@{
		@"@type" : @"inputSuggestedPostInfo",
		@"send_date" : @(sendDate),
	}];
	suggestedPostInfo[@"price"] = starCount > 0
		? @{@"@type" : @"suggestedPostPriceStar", @"star_count" : @(starCount)}
		: (id)[NSNull null];

	[self request:@{
		@"@type" : @"addOffer",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"options" : @{
			@"@type" : @"messageSendOptions",
			@"suggested_post_info" : suggestedPostInfo,
		},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - pinning a message

- (void)pinMessage:(int64_t)messageId
			inChat:(int64_t)chatId
		  silently:(BOOL)silently
		 onlyForMe:(BOOL)onlyForMe
		completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"pinChatMessage",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"disable_notification" : @(silently),
		@"only_for_self" : @(onlyForMe),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)unpinMessage:(int64_t)messageId
			  inChat:(int64_t)chatId
		  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"unpinChatMessage",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)unpinAllMessagesInChat:(int64_t)chatId
					completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"unpinAllChatMessages", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)isMessagePinned:(int64_t)messageId
				 inChat:(int64_t)chatId
			 completion:(void (^)(BOOL))completion {
	if (!completion)
		return;

	[self pinnedMessagesForChat:chatId thread:0 savedTopic:0 completion:^(NSArray *pinned) {
		BOOL isPinned = NO;
		for (NSDictionary *m in pinned) {
			if ([m[@"id"] longLongValue] == messageId) {
				isPinned = YES;
				break;
			}
		}
		completion(isPinned);
	}];
}

#pragma mark - deleting

- (void)deleteMessages:(NSArray *)messageIds
				inChat:(int64_t)chatId
		   forEveryone:(BOOL)forEveryone
			completion:(void (^)(BOOL))completion {
	if (!messageIds.count) {
		if (completion)
			completion(NO);
		return;
	}

	[self request:@{
		@"@type" : @"deleteMessages",
		@"chat_id" : @(chatId),
		@"message_ids" : messageIds,
		@"revoke" : @(forEveryone),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)deleteMessagesFromUser:(int64_t)userId
						inChat:(int64_t)chatId
					completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"deleteChatMessagesBySender",
		@"chat_id" : @(chatId),
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @(userId)},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)deleteMessagesInChat:(int64_t)chatId
					fromDate:(NSTimeInterval)minDate
					  toDate:(NSTimeInterval)maxDate
				 forEveryone:(BOOL)forEveryone
				  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"deleteChatMessagesByDate",
		@"chat_id" : @(chatId),
		@"min_date" : @((int32_t)minDate),
		@"max_date" : @((int32_t)maxDate),
		@"revoke" : @(forEveryone),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - forwarding

- (void)forwardMessages:(NSArray *)messageIds
			   fromChat:(int64_t)fromChatId
				 toChat:(int64_t)toChatId
				 thread:(int64_t)threadId
				 asCopy:(BOOL)asCopy
		 removeCaptions:(BOOL)removeCaptions
				 silent:(BOOL)silent
			 completion:(void (^)(NSArray *))completion {
	if (!messageIds.count) {
		if (completion)
			completion(@[]);
		return;
	}

	NSMutableDictionary *request = [@{
		@"@type" : @"forwardMessages",
		@"chat_id" : @(toChatId),
		@"from_chat_id" : @(fromChatId),
		@"message_ids" : messageIds,
		@"options" : TGMsgSendOptions(@{@"silent" : @(silent)}),
		@"send_copy" : @(asCopy),
		@"remove_caption" : @(removeCaptions),
	} mutableCopy];

	NSDictionary *topic = TGMsgTopic(threadId, TGMsgChatIsForum(self, toChatId));
	if (topic)
		request[@"topic_id"] = topic;

	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? @[] : TGMsgBriefList(result));
	}];
}

#pragma mark - drafts

- (void)setDraftText:(NSString *)text
			entities:(NSArray *)entities
			 replyTo:(int64_t)replyToId
		   quoteText:(NSString *)quoteText
	   quoteEntities:(NSArray *)quoteEntities
	   quotePosition:(NSInteger)quotePosition
			  inChat:(int64_t)chatId
			  thread:(int64_t)threadId
 directMessagesTopic:(int64_t)directMessagesTopicId
		  savedTopic:(int64_t)savedTopicId {
	BOOL hasReplyTarget = replyToId != 0;
	if (!text.length && !hasReplyTarget) {
		[self clearDraftInChat:chatId thread:threadId
			directMessagesTopic:directMessagesTopicId savedTopic:savedTopicId];
		return;
	}

	NSMutableDictionary *draft = [@{
		@"@type" : @"draftMessage",
		@"date" : @((int32_t)[[NSDate date] timeIntervalSince1970]),
		@"content" : @{@"@type" : @"draftMessageContentText",
			@"text" : TGMsgFormattedTextWithEntities(text, entities)},
	} mutableCopy];

	if (hasReplyTarget)
		draft[@"reply_to"] = TGReplyToDictionary(replyToId, quoteText,
			TGWireEntitiesFromFlattened(quoteEntities), quotePosition);

	NSMutableDictionary *request = [@{
		@"@type" : @"setChatDraftMessage",
		@"chat_id" : @(chatId),
		@"draft_message" : draft,
	} mutableCopy];

	NSDictionary *topic = TGDraftTopic(threadId, directMessagesTopicId, savedTopicId,
		TGMsgChatIsForum(self, chatId));
	if (topic)
		request[@"topic_id"] = topic;

	[self send:request];
}

- (void)clearDraftInChat:(int64_t)chatId
				   thread:(int64_t)threadId
	 directMessagesTopic:(int64_t)directMessagesTopicId
			   savedTopic:(int64_t)savedTopicId {
	NSMutableDictionary *request = [@{
		@"@type" : @"setChatDraftMessage",
		@"chat_id" : @(chatId),
	} mutableCopy];

	NSDictionary *topic = TGDraftTopic(threadId, directMessagesTopicId, savedTopicId,
		TGMsgChatIsForum(self, chatId));
	if (topic)
		request[@"topic_id"] = topic;

	[self send:request];
}

- (void)draftForChat:(int64_t)chatId
			  thread:(int64_t)threadId
 directMessagesTopic:(int64_t)directMessagesTopicId
		  savedTopic:(int64_t)savedTopicId
		  completion:(void (^)(NSString *, int64_t, NSArray *, NSArray *, NSString *, NSArray *, NSInteger))completion {
	void (^handleResult)(NSDictionary *) = ^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(@"", 0, nil, nil, nil, nil, 0);
			return;
		}

		NSDictionary *draft = [result[@"draft_message"] isKindOfClass:NSDictionary.class]
			? result[@"draft_message"]
			: nil;
		NSDictionary *content = [draft[@"content"] isKindOfClass:NSDictionary.class]
			? draft[@"content"]
			: nil;
		NSDictionary *body = [content[@"text"] isKindOfClass:NSDictionary.class]
			? content[@"text"]
			: nil;
		NSString *text = [body[@"text"] isKindOfClass:NSString.class] ? body[@"text"] : @"";
		NSArray *entities = [body[@"entities"] isKindOfClass:NSArray.class]
			? body[@"entities"]
			: nil;

		NSDictionary *replyTo = [draft[@"reply_to"] isKindOfClass:NSDictionary.class]
			? draft[@"reply_to"]
			: nil;
		int64_t replyToId = [replyTo[@"message_id"] longLongValue];

		NSDictionary *quote = [replyTo[@"quote"] isKindOfClass:NSDictionary.class]
			? replyTo[@"quote"]
			: nil;
		NSDictionary *quoteBody = [quote[@"text"] isKindOfClass:NSDictionary.class]
			? quote[@"text"]
			: nil;
		NSString *quoteText = [quoteBody[@"text"] isKindOfClass:NSString.class]
			? quoteBody[@"text"]
			: nil;
		NSArray *quoteEntities = TGFlattenEntities(quoteBody[@"entities"]);
		NSInteger quotePosition = [quote[@"position"] integerValue];

		completion(text, replyToId, TGCustomEmojiRunsFromEntities(entities, text),
			TGMentionNameRunsFromEntities(entities, text), quoteText, quoteEntities, quotePosition);
	};

	if (directMessagesTopicId != 0) {
		[self request:@{@"@type" : @"getDirectMessagesChatTopic", @"chat_id" : @(chatId),
				@"topic_id" : @(directMessagesTopicId)}
			completion:handleResult];
		return;
	}

	if (savedTopicId != 0) {
		NSDictionary *cached = [self cachedSavedMessagesTopic:savedTopicId];
		NSDictionary *rawDraft = [cached[@"draftMessage"] isKindOfClass:NSDictionary.class]
			? cached[@"draftMessage"]
			: nil;
		handleResult(@{@"draft_message" : rawDraft ?: (id)[NSNull null]});
		return;
	}

	if (threadId != 0) {
		[self request:@{@"@type" : @"getForumTopic", @"chat_id" : @(chatId),
				@"forum_topic_id" : @((int32_t)threadId)}
			completion:handleResult];
		return;
	}

	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:handleResult];
}

#pragma mark - scheduling

- (void)scheduledMessagesInChat:(int64_t)chatId
					 completion:(void (^)(NSArray *, BOOL))completion {
	[self request:@{@"@type" : @"getChatScheduledMessages", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(@[], YES);
				return;
			}

			NSArray *messages = [result[@"messages"] isKindOfClass:NSArray.class]
				? result[@"messages"]
				: @[];
			NSMutableArray *out = [NSMutableArray array];
			for (NSDictionary *m in messages) {
				NSDictionary *flat = TGMsgBrief(m);
				if (!flat)
					continue;

				NSDictionary *state = [m[@"scheduling_state"] isKindOfClass:NSDictionary.class]
					? m[@"scheduling_state"]
					: nil;
				BOOL whenOnline = [state[@"@type"]
					isEqualToString:@"messageSchedulingStateSendWhenOnline"];

				NSMutableDictionary *entry = [flat mutableCopy];
				entry[@"sendDate"] = state[@"send_date"] ?: @0;
				entry[@"whenOnline"] = @(whenOnline);
				[out addObject:entry];
			}
			completion(out, NO);
		}];
}

- (void)rescheduleMessage:(int64_t)messageId
				   inChat:(int64_t)chatId
				 sendDate:(NSTimeInterval)sendDate
			   whenOnline:(BOOL)whenOnline
			   completion:(void (^)(BOOL))completion {
	NSDictionary *state = whenOnline && sendDate <= 0
		? @{@"@type" : @"messageSchedulingStateSendWhenOnline"}
		: @{@"@type" : @"messageSchedulingStateSendAtDate",
			  @"send_date" : @((int32_t)sendDate)};

	[self request:@{
		@"@type" : @"editMessageSchedulingState",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"scheduling_state" : state,
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)sendScheduledMessageNow:(int64_t)messageId
						 inChat:(int64_t)chatId
					 completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"editMessageSchedulingState",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - read state

- (void)markRead:(NSArray *)messageIds
		  inChat:(int64_t)chatId
		  source:(NSString *)source {
	if (!messageIds.count)
		return;

	NSString *type = @"messageSourceChatHistory";
	if ([source isEqualToString:@"thread"])
		type = @"messageSourceMessageThreadHistory";
	else if ([source isEqualToString:@"forum_topic"])
		type = @"messageSourceForumTopicHistory";
	else if ([source isEqualToString:@"search"])
		type = @"messageSourceSearch";
	else if ([source isEqualToString:@"notification"])
		type = @"messageSourceNotification";
	else if ([source isEqualToString:@"screenshot"])
		type = @"messageSourceScreenshot";

	[self send:@{
		@"@type" : @"viewMessages",
		@"chat_id" : @(chatId),
		@"message_ids" : messageIds,
		@"source" : @{@"@type" : type},
		@"force_read" : @YES,
	}];
}

- (void)readAllMentionsInChat:(int64_t)chatId {
	[self send:@{@"@type" : @"readAllChatMentions", @"chat_id" : @(chatId)}];
}

- (void)readAllMentionsInChat:(int64_t)chatId forumTopicId:(int64_t)topicId {
	if (topicId == 0) {
		[self readAllMentionsInChat:chatId];
		return;
	}
	[self send:@{
		@"@type" : @"readAllForumTopicMentions",
		@"chat_id" : @(chatId),
		@"forum_topic_id" : @(topicId),
	}];
}

- (void)readAllReactionsInChat:(int64_t)chatId {
	[self send:@{@"@type" : @"readAllChatReactions", @"chat_id" : @(chatId)}];
}

- (void)readAllPollVotesInChat:(int64_t)chatId {
	[self send:@{@"@type" : @"readAllChatPollVotes", @"chat_id" : @(chatId)}];
}

- (void)readDateOfMessage:(int64_t)messageId
				   inChat:(int64_t)chatId
			   completion:(void (^)(NSString *, NSTimeInterval))completion {
	[self request:@{@"@type" : @"getMessageReadDate",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(@"unread", 0);
				return;
			}

			NSString *type = [result[@"@type"] isKindOfClass:NSString.class]
				? result[@"@type"]
				: @"";
			if ([type isEqualToString:@"messageReadDateRead"]) {
				completion(@"read", [result[@"read_date"] doubleValue]);
				return;
			}
			if ([type isEqualToString:@"messageReadDateTooOld"]) {
				completion(@"tooOld", 0);
				return;
			}
			if ([type isEqualToString:@"messageReadDateUserPrivacyRestricted"]) {
				completion(@"theirPrivacy", 0);
				return;
			}
			if ([type isEqualToString:@"messageReadDateMyPrivacyRestricted"]) {
				completion(@"myPrivacy", 0);
				return;
			}
			completion(@"unread", 0);
		}];
}

- (void)viewersOfMessage:(int64_t)messageId
				  inChat:(int64_t)chatId
			  completion:(void (^)(NSArray *, NSString *))completion {
	[self request:@{@"@type" : @"getMessageViewers",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				NSString *message = [result[@"message"] isKindOfClass:NSString.class]
					? result[@"message"]
					: @"";
				NSString *reason = @"unavailable";
				if ([message rangeOfString:@"too old"].location != NSNotFound)
					reason = @"tooOld";
				else if ([message rangeOfString:@"too big"].location != NSNotFound)
					reason = @"chatTooBig";
				else if ([message rangeOfString:@"hidden"].location != NSNotFound)
					reason = @"hiddenParticipants";
				else if ([message rangeOfString:@"incoming"].location != NSNotFound)
					reason = @"incoming";
				completion(@[], reason);
				return;
			}

			NSArray *viewers = [result[@"viewers"] isKindOfClass:NSArray.class]
				? result[@"viewers"]
				: @[];
			NSMutableArray *out = [NSMutableArray array];
			for (NSDictionary *viewer in viewers) {
				if (![viewer isKindOfClass:NSDictionary.class])
					continue;
				int64_t userId = [viewer[@"user_id"] longLongValue];
				[out addObject:@{
					@"id" : @(userId),
					@"name" : TGMsgSenderName(userId),
					@"date" : viewer[@"view_date"] ?: @0,
				}];
			}
			completion(out, nil);
		}];
}

- (void)sendViewMetricsForMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
					 timeInViewMs:(int32_t)timeInViewMs
			   activeTimeInViewMs:(int32_t)activeTimeInViewMs
			  heightRatioPerMille:(int32_t)heightRatioPerMille
				seenRangePerMille:(int32_t)seenRangePerMille {
	[self send:@{
		@"@type" : @"sendMessageViewMetrics",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"time_in_view_ms" : @(timeInViewMs),
		@"active_time_in_view_ms" : @(activeTimeInViewMs),
		@"height_to_viewport_ratio_per_mille" : @(heightRatioPerMille),
		@"seen_range_ratio_per_mille" : @(seenRangePerMille),
	}];
}

#pragma mark - typing indicator

- (void)sendChatAction:(NSString *)action toChat:(int64_t)chatId thread:(int64_t)threadId {
	NSDictionary *names = @{
		@"typing" : @"chatActionTyping",
		@"recordingVoice" : @"chatActionRecordingVoiceNote",
		@"uploadingVoice" : @"chatActionUploadingVoiceNote",
		@"recordingVideo" : @"chatActionRecordingVideo",
		@"uploadingVideo" : @"chatActionUploadingVideo",
		@"recordingVideoNote" : @"chatActionRecordingVideoNote",
		@"uploadingVideoNote" : @"chatActionUploadingVideoNote",
		@"uploadingPhoto" : @"chatActionUploadingPhoto",
		@"uploadingDocument" : @"chatActionUploadingDocument",
		@"choosingSticker" : @"chatActionChoosingSticker",
		@"choosingLocation" : @"chatActionChoosingLocation",
		@"choosingContact" : @"chatActionChoosingContact",
		@"cancel" : @"chatActionCancel",
	};

	NSString *type = names[action ?: @""];
	if (!type)
		return;

	NSMutableDictionary *request = [@{
		@"@type" : @"sendChatAction",
		@"chat_id" : @(chatId),
		@"action" : @{@"@type" : type},
	} mutableCopy];

	NSDictionary *topic = TGMsgTopic(threadId, TGMsgChatIsForum(self, chatId));
	if (topic)
		request[@"topic_id"] = topic;

	[self send:request];
}

#pragma mark - links

- (void)linkForMessage:(int64_t)messageId
				inChat:(int64_t)chatId
			  inThread:(BOOL)inThread
			completion:(void (^)(NSString *, BOOL))completion {
	[self request:@{
		@"@type" : @"getMessageLink",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"media_timestamp" : @0,
		@"for_album" : @NO,
		@"in_message_thread" : @(inThread),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, NO);
			return;
		}

		NSString *link = [result[@"link"] isKindOfClass:NSString.class]
			? result[@"link"]
			: nil;
		completion(link.length ? link : nil, [result[@"is_public"] boolValue]);
	}];
}

- (void)linkForMessage:(int64_t)messageId
				inChat:(int64_t)chatId
		  pollOptionId:(NSString *)pollOptionId
			completion:(void (^)(NSString *, BOOL))completion {
	[self request:@{
		@"@type" : @"getMessageLink",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"media_timestamp" : @0,
		@"checklist_task_id" : @0,
		@"poll_option_id" : pollOptionId ?: @"",
		@"for_album" : @NO,
		@"in_message_thread" : @NO,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, NO);
			return;
		}

		NSString *link = [result[@"link"] isKindOfClass:NSString.class]
			? result[@"link"]
			: nil;
		completion(link.length ? link : nil, [result[@"is_public"] boolValue]);
	}];
}

#pragma mark - threads

- (void)threadForMessage:(int64_t)messageId
				  inChat:(int64_t)chatId
			  completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getMessageThread",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}

			NSDictionary *info = [result[@"reply_info"] isKindOfClass:NSDictionary.class]
				? result[@"reply_info"]
				: @{};
			completion(@{
				@"chatId" : result[@"chat_id"] ?: @0,
				@"threadId" : result[@"message_thread_id"] ?: @0,
				@"replies" : info[@"reply_count"] ?: @0,
				@"unread" : result[@"unread_message_count"] ?: @0,
			});
		}];
}

#pragma mark - translation

- (void)translateText:(NSString *)text
		   toLanguage:(NSString *)languageCode
		   completion:(void (^)(NSString *))completion {
	if (!text.length) {
		if (completion)
			completion(nil);
		return;
	}

	[self request:@{@"@type" : @"translateText",
		@"text" : TGMsgFormattedText(text),
		@"to_language_code" : languageCode ?: @"en"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			NSString *out = [result[@"text"] isKindOfClass:NSString.class]
				? result[@"text"]
				: nil;
			completion(out.length ? out : nil);
		}];
}

#pragma mark - bot buttons

#pragma mark - reporting

- (void)reportMessages:(NSArray *)messageIds
				inChat:(int64_t)chatId
			  optionId:(NSString *)optionId
				  text:(NSString *)text
			completion:(void (^)(NSDictionary *))completion {
	[self reportChat:chatId
		  messageIds:messageIds
			optionId:optionId
				text:text
		  completion:^(NSDictionary *result) {
			  if (!completion)
				  return;
			  if (!result) {
				  completion(@{@"status" : @"error"});
				  return;
			  }

			  NSString *status = [result[@"status"] isKindOfClass:NSString.class]
				  ? result[@"status"]
				  : @"";

			  if ([status isEqualToString:@"options"]) {
				  completion(@{@"status" : @"chooseOption",
					  @"title" : result[@"title"] ?: @"",
					  @"options" : result[@"options"] ?: @[]});
				  return;
			  }

			  if ([status isEqualToString:@"text"]) {
				  completion(@{@"status" : @"needText",
					  @"optionId" : result[@"optionId"] ?: @"",
					  @"optional" : result[@"optional"] ?: @NO});
				  return;
			  }

			  if ([status isEqualToString:@"messages"]) {
				  completion(@{@"status" : @"messagesRequired"});
				  return;
			  }

			  completion(@{@"status" : [status isEqualToString:@"ok"] ? @"ok" : @"error"});
		  }];
}

#pragma mark - quick replies

- (void)resetQuickReplyCachesForAccountSwitch {
	[TGQuickReplyStore() removeAllObjects];
	[TGQuickReplyOrder() removeAllObjects];
	[TGQuickReplyMessagesStore() removeAllObjects];
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGQuickReplyShortcutsUpdatedNotification
					  object:nil];
}

- (void)addQuickReplyShortcutNamed:(NSString *)name
							  text:(NSString *)text
						  entities:(NSArray *)entities
						completion:(void (^)(BOOL))completion {
	if (!name.length || !text.length) {
		if (completion)
			completion(NO);
		return;
	}

	[self request:@{
		@"@type" : @"addQuickReplyShortcutMessage",
		@"shortcut_name" : name,
		@"reply_to_message_id" : @0,
		@"input_message_content" : TGMsgTextContentWithEntities(text, entities, NO),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)editQuickReplyMessage:(int64_t)messageId
					inShortcut:(NSInteger)shortcutId
						  text:(NSString *)text
					  entities:(NSArray *)entities
					completion:(void (^)(BOOL))completion {
	if (!text.length) {
		if (completion)
			completion(NO);
		return;
	}

	[self request:@{
		@"@type" : @"editQuickReplyMessage",
		@"shortcut_id" : @(shortcutId),
		@"message_id" : @(messageId),
		@"input_message_content" : TGMsgTextContentWithEntities(text, entities, NO),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)sendQuickReplyShortcut:(NSInteger)shortcutId
						toChat:(int64_t)chatId
					completion:(void (^)(NSArray *, BOOL))completion {
	[self request:@{
		@"@type" : @"sendQuickReplyShortcutMessages",
		@"chat_id" : @(chatId),
		@"shortcut_id" : @(shortcutId),
		@"sending_id" : @0,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		BOOL isError = TGResultIsError(result);
		completion(isError ? @[] : TGMsgBriefList(result), !isError);
	}];
}

- (void)loadQuickReplyShortcuts {
	[self request:@{@"@type" : @"loadQuickReplyShortcuts"} completion:nil];
}

- (void)checkQuickReplyShortcutName:(NSString *)name completion:(void (^)(BOOL valid))completion {
	if (!name.length) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{@"@type" : @"checkQuickReplyShortcutName", @"name" : name}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (NSArray *)quickReplyShortcuts {
	NSMutableArray *ordered = [NSMutableArray array];
	NSMutableSet *placed = [NSMutableSet set];
	for (NSNumber *shortcutId in TGQuickReplyOrder()) {
		NSDictionary *shortcut = TGQuickReplyStore()[shortcutId];
		if (shortcut) {
			[ordered addObject:shortcut];
			[placed addObject:shortcutId];
		}
	}
	NSMutableArray *rest = [NSMutableArray array];
	for (NSNumber *shortcutId in TGQuickReplyStore().allKeys)
		if (![placed containsObject:shortcutId])
			[rest addObject:TGQuickReplyStore()[shortcutId]];
	[rest sortUsingComparator:^NSComparisonResult(id a, id b) {
		return [((NSDictionary *)a)[@"name"] caseInsensitiveCompare:
				((NSDictionary *)b)[@"name"] ?: @""];
	}];
	[ordered addObjectsFromArray:rest];
	return ordered;
}

- (void)loadQuickReplyShortcutMessages:(NSInteger)shortcutId {
	[self request:@{@"@type" : @"loadQuickReplyShortcutMessages", @"shortcut_id" : @(shortcutId)}
		completion:nil];
}

- (NSArray *)cachedQuickReplyShortcutMessages:(NSInteger)shortcutId {
	NSArray *cached = TGQuickReplyMessagesStore()[@(shortcutId)];
	return [cached isKindOfClass:NSArray.class] ? cached : nil;
}

- (void)deleteQuickReplyShortcutMessages:(NSArray *)messageIds
							  inShortcut:(NSInteger)shortcutId
							  completion:(void (^)(BOOL))completion {
	if (!messageIds.count) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"deleteQuickReplyShortcutMessages",
		@"shortcut_id" : @(shortcutId),
		@"message_ids" : messageIds,
	} completion:^(NSDictionary *result) {
		BOOL ok = !TGResultIsError(result);
		if (ok) {
			NSMutableArray *remaining = [(TGQuickReplyMessagesStore()[@(shortcutId)] ?: @[]) mutableCopy];
			NSSet *removed = [NSSet setWithArray:messageIds];
			NSPredicate *keep = [NSPredicate
				predicateWithBlock:^BOOL(NSDictionary *m, NSDictionary *bindings) {
					return ![removed containsObject:m[@"id"]];
				}];
			[remaining filterUsingPredicate:keep];
			TGQuickReplyMessagesStore()[@(shortcutId)] = remaining;
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGQuickReplyShortcutMessagesUpdatedNotification
							  object:@(shortcutId)];
		}
		if (completion)
			completion(ok);
	}];
}

- (void)retryQuickReplyShortcutMessages:(NSArray *)messageIds
						   shortcutName:(NSString *)shortcutName
							 completion:(void (^)(BOOL))completion {
	if (!messageIds.count || !shortcutName.length) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"readdQuickReplyShortcutMessages",
		@"shortcut_name" : shortcutName,
		@"message_ids" : messageIds,
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)setQuickReplyShortcutName:(NSInteger)shortcutId
							 name:(NSString *)name
					   completion:(void (^)(BOOL))completion {
	if (!name.length) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"setQuickReplyShortcutName",
		@"shortcut_id" : @(shortcutId),
		@"name" : name,
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)reorderQuickReplyShortcuts:(NSArray *)orderedShortcutIds
						completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"reorderQuickReplyShortcuts",
		@"shortcut_ids" : orderedShortcutIds ?: @[],
	} completion:^(NSDictionary *result) {
		BOOL ok = !TGResultIsError(result);
		if (ok) {
			[TGQuickReplyOrder() removeAllObjects];
			[TGQuickReplyOrder() addObjectsFromArray:orderedShortcutIds ?: @[]];
		}
		if (completion)
			completion(ok);
	}];
}

- (void)deleteQuickReplyShortcut:(NSInteger)shortcutId
					  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"deleteQuickReplyShortcut",
		@"shortcut_id" : @(shortcutId),
	} completion:^(NSDictionary *result) {
		BOOL ok = !TGResultIsError(result);
		if (ok) {
			[TGQuickReplyStore() removeObjectForKey:@(shortcutId)];
			[TGQuickReplyOrder() removeObject:@(shortcutId)];
		}
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGQuickReplyShortcutsUpdatedNotification
						  object:nil];
		if (completion)
			completion(ok);
	}];
}

- (void)handleQuickReplyUpdate:(NSDictionary *)obj type:(NSString *)type {
	if ([type isEqualToString:@"updateQuickReplyShortcuts"]) {
		NSArray *ids = obj[@"shortcut_ids"];
		NSMutableSet *keep = [NSMutableSet set];
		for (NSNumber *shortcutId in ids)
			if ([shortcutId isKindOfClass:NSNumber.class])
				[keep addObject:shortcutId];
		for (NSNumber *known in [TGQuickReplyStore().allKeys copy])
			if (![keep containsObject:known])
				[TGQuickReplyStore() removeObjectForKey:known];
		[TGQuickReplyOrder() removeAllObjects];
		for (NSNumber *shortcutId in ids)
			if ([shortcutId isKindOfClass:NSNumber.class])
				[TGQuickReplyOrder() addObject:shortcutId];
	} else if ([type isEqualToString:@"updateQuickReplyShortcut"]) {
		NSDictionary *flat = TGQuickReplyShortcutFromUpdate(obj[@"shortcut"]);
		if (flat)
			TGQuickReplyStore()[flat[@"id"]] = flat;
	} else if ([type isEqualToString:@"updateQuickReplyShortcutDeleted"]) {
		NSNumber *shortcutId = obj[@"shortcut_id"];
		if ([shortcutId isKindOfClass:NSNumber.class]) {
			[TGQuickReplyStore() removeObjectForKey:shortcutId];
			[TGQuickReplyOrder() removeObject:shortcutId];
		}
	} else if ([type isEqualToString:@"updateQuickReplyShortcutMessages"]) {
		NSNumber *shortcutId = obj[@"shortcut_id"];
		if ([shortcutId isKindOfClass:NSNumber.class])
			TGQuickReplyMessagesStore()[shortcutId] = TGFlattenedQuickReplyMessageList(obj);
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGQuickReplyShortcutMessagesUpdatedNotification
						  object:shortcutId];
		return;
	}
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGQuickReplyShortcutsUpdatedNotification
					  object:nil];
}

- (void)repliedMessageOf:(int64_t)messageId
				  inChat:(int64_t)chatId
			  completion:(void (^)(int64_t repliedMessageId))completion {
	[self request:@{@"@type" : @"getRepliedMessage",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(TGResultIsError(result) ? 0 : [result[@"id"] longLongValue]);
		}];
}

#pragma mark - moved from TGClient.m core

- (void)sendText:(NSString *)text toChat:(int64_t)chatId {
	[self sendText:text toChat:chatId thread:0];
}

- (void)sendText:(NSString *)text toChat:(int64_t)chatId thread:(int64_t)threadId {
	[self sendText:text toChat:chatId thread:threadId savedTopic:0 replyTo:0];
}

- (void)sendText:(NSString *)text toChat:(int64_t)chatId
		  thread:(int64_t)threadId
	  savedTopic:(int64_t)savedTopicId
		 replyTo:(int64_t)replyToId {
	NSMutableDictionary *request = [@{
		@"@type" : @"sendMessage",
		@"chat_id" : @(chatId),
		@"input_message_content" : @{
			@"@type" : @"inputMessageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : text ?: @""},
		},
	} mutableCopy];

	NSDictionary *topic = TGTopicDictionary(threadId, 0, savedTopicId, TGMsgChatIsForum(self, chatId));
	if (topic)
		request[@"topic_id"] = topic;
	NSDictionary *replyTo = TGReplyToDictionary(replyToId, nil, nil, 0);
	if (replyTo)
		request[@"reply_to"] = replyTo;

	[self send:request];
}

- (void)editMessage:(int64_t)messageId inChat:(int64_t)chatId text:(NSString *)text
			entities:(NSArray *)entities
  linkPreviewOptions:(NSDictionary *)linkPreviewOptions
		  completion:(void (^)(BOOL ok))completion {
	[self request:@{
		@"@type" : @"editMessageText",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"input_message_content" : entities.count
			? TGMsgEditTextContentWithEntities(text, entities, linkPreviewOptions)
			: TGMsgEditTextContent(text, linkPreviewOptions),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)setFactCheck:(NSString *)text
		  forMessage:(int64_t)messageId
			  inChat:(int64_t)chatId
		  completion:(void (^)(BOOL ok))completion {
	[self request:@{
		@"@type" : @"setMessageFactCheck",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"text" : @{@"@type" : @"formattedText", @"text" : text ?: @""},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion([result[@"@type"] isEqualToString:@"ok"]);
	}];
}

- (void)messageWithId:(int64_t)messageId
			   inChat:(int64_t)chatId
		   completion:(void (^)(NSDictionary *))completion {
	[self fetchMessageId:messageId inChat:chatId
			  completion:^(NSDictionary *message, BOOL confirmedNotFound) {
				  (void)confirmedNotFound;
				  if (completion)
					  completion(message);
			  }];
}

- (void)fetchMessageId:(int64_t)messageId
				 inChat:(int64_t)chatId
			 completion:(void (^)(NSDictionary *, BOOL))completion {
	[self request:@{@"@type" : @"getMessage",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId)}
		completion:^(NSDictionary *m) {
			if (!completion)
				return;
			if ([m[@"@type"] isEqualToString:@"message"]) {
				completion(TGFlattenMessage(m, TGCurrentFlattenContext()), NO);
				return;
			}
			BOOL confirmedNotFound = TGResultIsError(m) &&
				[m[@"code"] respondsToSelector:@selector(integerValue)] &&
				[m[@"code"] integerValue] == 404;
			completion(nil, confirmedNotFound);
		}];
}

- (void)recentStickersWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getRecentStickers", @"is_attached" : @NO}
		completion:^(NSDictionary *result) {
			NSMutableArray *out = [NSMutableArray array];
			for (NSDictionary *sticker in result[@"stickers"]) {
				NSNumber *fileId = sticker[@"sticker"][@"id"];
				if (!fileId)
					continue;
				NSString *format = sticker[@"format"][@"@type"] ?: @"";
				NSDictionary *thumbnail = TGMsgDictOf(sticker[@"thumbnail"]);
				NSDictionary *thumbFile = TGMsgDictOf(thumbnail[@"file"]);
				[out addObject:@{
					@"fileId" : fileId,
					@"emoji" : sticker[@"emoji"] ?: @"",

					@"isAnimated" : @([format isEqualToString:@"stickerFormatTgs"]),
					@"thumbId" : thumbFile[@"id"] ?: @0,
				}];
			}
			if (completion)
				completion(out);
		}];
}

- (void)sendStickerWithFileId:(long long)fileId
						toChat:(int64_t)chatId
						thread:(int64_t)threadId
					savedTopic:(int64_t)savedTopicId
					   replyTo:(int64_t)replyToId
					   options:(NSDictionary *)options {
	NSMutableDictionary *request = [@{
		@"@type" : @"sendMessage",
		@"chat_id" : @(chatId),
		@"options" : TGMsgSendOptions(options),
		@"input_message_content" : @{
			@"@type" : @"inputMessageSticker",
			@"sticker" : @{
				@"@type" : @"inputSticker",
				@"sticker" : @{@"@type" : @"inputFileId", @"id" : @(fileId)},
			},
		},
	} mutableCopy];

	NSDictionary *topic = TGDraftTopic(threadId, 0, savedTopicId, TGMsgChatIsForum(self, chatId));
	if (topic)
		request[@"topic_id"] = topic;
	NSDictionary *replyTo = TGReplyToDictionary(replyToId, nil, nil, 0);
	if (replyTo)
		request[@"reply_to"] = replyTo;

	[self send:request];
}

- (void)sendVoiceAtPath:(NSString *)path duration:(NSInteger)seconds
			   waveform:(NSData *)waveform
				 toChat:(int64_t)chatId
				 thread:(int64_t)threadId
			 savedTopic:(int64_t)savedTopicId
				options:(NSDictionary *)options {
	if (!path.length)
		return;

	NSDictionary *attributes = [[NSFileManager defaultManager]
		attributesOfItemAtPath:path
						 error:nil];
	NSLog(@"TGClient: sending voice %@ (%llu bytes, %lds) to %lld",
		path.lastPathComponent, [attributes fileSize], (long)seconds, chatId);

	NSMutableDictionary *request = [@{
		@"@type" : @"sendMessage",
		@"chat_id" : @(chatId),
		@"options" : TGMsgSendOptions(options),
		@"input_message_content" : @{
			@"@type" : @"inputMessageVoiceNote",
			@"voice_note" : @{
				@"@type" : @"inputVoiceNote",
				@"voice_note" : @{@"@type" : @"inputFileLocal", @"path" : path},
				@"duration" : @(seconds),
				@"waveform" : TGBase64Encode(waveform),
			},
		},
	} mutableCopy];

	NSDictionary *topic = TGDraftTopic(threadId, 0, savedTopicId, TGMsgChatIsForum(self, chatId));
	if (topic)
		request[@"topic_id"] = topic;

	[self request:request completion:^(NSDictionary *result) {
		if ([result[@"@type"] isEqualToString:@"error"])
			NSLog(@"TGClient: voice rejected: %@ %@",
				result[@"code"], result[@"message"]);
		else
			NSLog(@"TGClient: voice accepted, message %@", result[@"id"]);
	}];
}

- (void)sendVideoAtPath:(NSString *)path toChat:(int64_t)chatId {
	if (!path.length)
		return;
	[self send:@{
		@"@type" : @"sendMessage",
		@"chat_id" : @(chatId),
		@"input_message_content" : @{
			@"@type" : @"inputMessageVideo",
			@"video" : @{
				@"@type" : @"inputVideo",
				@"video" : @{@"@type" : @"inputFileLocal", @"path" : path},
			},
		},
	}];
}

- (void)sendLocation:(double)latitude longitude:(double)longitude toChat:(int64_t)chatId options:(NSDictionary *)options {
	[self send:@{
		@"@type" : @"sendMessage",
		@"chat_id" : @(chatId),
		@"options" : TGMsgSendOptions(options),
		@"input_message_content" : @{
			@"@type" : @"inputMessageLocation",
			@"location" : @{
				@"@type" : @"location",
				@"latitude" : @(latitude),
				@"longitude" : @(longitude),
			},
		},
	}];
}

- (void)sendContactFirstName:(NSString *)firstName
					 lastName:(NSString *)lastName
						phone:(NSString *)phone
						vcard:(NSString *)vcard
					   userId:(int64_t)userId
					   toChat:(int64_t)chatId
					  options:(NSDictionary *)options {
	if (!phone.length)
		return;
	[self send:@{
		@"@type" : @"sendMessage",
		@"chat_id" : @(chatId),
		@"options" : TGMsgSendOptions(options),
		@"input_message_content" : @{
			@"@type" : @"inputMessageContact",
			@"contact" : @{
				@"@type" : @"contact",
				@"phone_number" : phone,
				@"first_name" : firstName ?: @"",
				@"last_name" : lastName ?: @"",
				@"vcard" : vcard ?: @"",
				@"user_id" : @(userId),
			},
		},
	}];
}

- (void)sendPhotoAtPath:(NSString *)path toChat:(int64_t)chatId {
	if (!path.length)
		return;
	[self send:@{
		@"@type" : @"sendMessage",
		@"chat_id" : @(chatId),
		@"input_message_content" : @{
			@"@type" : @"inputMessagePhoto",
			@"photo" : @{
				@"@type" : @"inputPhoto",
				@"photo" : @{@"@type" : @"inputFileLocal", @"path" : path},
			},
		},
	}];
}

- (void)votePoll:(int64_t)messageId inChat:(int64_t)chatId options:(NSArray *)optionIds {
	[self votePoll:messageId inChat:chatId options:optionIds completion:nil];
}

- (void)votePoll:(int64_t)messageId
		  inChat:(int64_t)chatId
		 options:(NSArray *)optionIds
	  completion:(void (^)(BOOL ok))completion {
	[self request:@{
		@"@type" : @"setPollAnswer",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"option_ids" : optionIds ?: @[],
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)addPollOptionText:(NSString *)text inMessage:(int64_t)messageId chat:(int64_t)chatId {
	[self addPollOptionText:text inMessage:messageId chat:chatId completion:nil];
}

- (void)addPollOptionText:(NSString *)text
				inMessage:(int64_t)messageId
					 chat:(int64_t)chatId
			   completion:(void (^)(BOOL ok))completion {
	if (!text.length) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"addPollOption",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"option" : @{
			@"@type" : @"inputPollOption",
			@"text" : @{@"@type" : @"formattedText", @"text" : text, @"entities" : @[]},
		},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)markChecklistTask:(int32_t)taskId
					 done:(BOOL)done
				inMessage:(int64_t)messageId
					 chat:(int64_t)chatId
			   completion:(void (^)(BOOL ok))completion {
	[self request:@{
		@"@type" : @"markChecklistTasksAsDone",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"marked_as_done_task_ids" : done ? @[ @(taskId) ] : @[],
		@"marked_as_not_done_task_ids" : done ? @[] : @[ @(taskId) ],
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)addChecklistTaskId:(int32_t)taskId
					  text:(NSString *)text
				 inMessage:(int64_t)messageId
					  chat:(int64_t)chatId
				completion:(void (^)(BOOL ok))completion {
	[self request:@{
		@"@type" : @"addChecklistTasks",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"tasks" : @[ @{
			@"@type" : @"inputChecklistTask",
			@"id" : @(taskId),
			@"text" : @{@"@type" : @"formattedText",
				@"text" : text ?: @"",
				@"entities" : @[]},
		} ],
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)replaceChecklistTasks:(NSArray *)tasks
						title:(NSString *)title
				 othersCanAdd:(BOOL)othersCanAdd
				othersCanMark:(BOOL)othersCanMark
					inMessage:(int64_t)messageId
						 chat:(int64_t)chatId
				   completion:(void (^)(BOOL ok))completion {
	NSMutableArray *inputTasks = [NSMutableArray arrayWithCapacity:tasks.count];
	for (NSDictionary *task in tasks) {
		if (![task isKindOfClass:NSDictionary.class])
			continue;
		[inputTasks addObject:@{
			@"@type" : @"inputChecklistTask",
			@"id" : task[@"id"] ?: @0,
			@"text" : @{@"@type" : @"formattedText",
				@"text" : task[@"text"] ?: @"",
				@"entities" : @[]},
		}];
	}
	[self request:@{
		@"@type" : @"editMessageChecklist",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"checklist" : @{
			@"@type" : @"inputChecklist",
			@"title" : @{@"@type" : @"formattedText",
				@"text" : title ?: @"",
				@"entities" : @[]},
			@"tasks" : inputTasks,
			@"others_can_add_tasks" : @(othersCanAdd),
			@"others_can_mark_tasks_as_done" : @(othersCanMark),
		},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)markRead:(NSArray *)messageIds inChat:(int64_t)chatId {
	if (!messageIds.count)
		return;
	[self send:@{
		@"@type" : @"viewMessages",
		@"chat_id" : @(chatId),
		@"message_ids" : messageIds,
		@"force_read" : @YES,
	}];
}

@end

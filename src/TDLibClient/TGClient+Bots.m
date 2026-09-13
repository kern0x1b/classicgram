#import "TGClient+ChatState.h"
#import "TGMessageReply.h"
#import "TGClient+Bots.h"
#import "TGClient+Private.h"
#import "TGFlattenBots.h"
#import "TGLocalization.h"
#import "TGMessageTopic.h"

static NSMutableSet *TGBotStartLinksInFlight = nil;

static NSDictionary *TGBDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSArray *TGBArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : nil;
}

static NSString *TGBString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSNumber *TGBNumber(id value) {
	return [value isKindOfClass:NSNumber.class] ? value : @0;
}

static BOOL TGBotsChatIsForum(TGClient *client, int64_t chatId) {
	id value = client.chatsById[@(chatId)][@"isForum"];
	return [value isKindOfClass:NSNumber.class] && [value boolValue];
}

static NSNumber *TGBInt64(id value) {
	if ([value isKindOfClass:NSNumber.class])
		return value;
	if ([value isKindOfClass:NSString.class])
		return @([value longLongValue]);
	return @0;
}

@implementation TGClient (Bots)

#pragma mark - keyboards

- (NSDictionary *)tgb_inlineButton:(NSDictionary *)raw {
	NSDictionary *button = TGBDict(raw);
	if (!button)
		return nil;

	NSDictionary *type = TGBDict(button[@"type"]);
	NSString *kindName = TGBString(type[@"@type"]);
	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	out[@"text"] = TGBString(button[@"text"]);
	out[@"kind"] = @"unsupported";

	if ([kindName isEqualToString:@"inlineKeyboardButtonTypeUrl"]) {
		out[@"kind"] = @"url";
		out[@"url"] = TGBString(type[@"url"]);
	} else if ([kindName isEqualToString:@"inlineKeyboardButtonTypeLoginUrl"]) {
		out[@"kind"] = @"loginUrl";
		out[@"url"] = TGBString(type[@"url"]);
		out[@"buttonId"] = TGBNumber(type[@"id"]);
		out[@"forwardText"] = TGBString(type[@"forward_text"]);
	} else if ([kindName isEqualToString:@"inlineKeyboardButtonTypeWebApp"]) {
		out[@"kind"] = @"webApp";
		out[@"url"] = TGBString(type[@"url"]);
	} else if ([kindName isEqualToString:@"inlineKeyboardButtonTypeCallback"]) {
		out[@"kind"] = @"callback";
		out[@"data"] = TGBString(type[@"data"]);
	} else if ([kindName isEqualToString:@"inlineKeyboardButtonTypeCallbackWithPassword"]) {
		out[@"kind"] = @"callbackWithPassword";
		out[@"data"] = TGBString(type[@"data"]);
	} else if ([kindName isEqualToString:@"inlineKeyboardButtonTypeCallbackGame"]) {
		out[@"kind"] = @"callbackGame";
	} else if ([kindName isEqualToString:@"inlineKeyboardButtonTypeSwitchInline"]) {
		NSString *target = TGBString(TGBDict(type[@"target_chat"])[@"@type"]);
		out[@"kind"] = @"switchInline";
		out[@"query"] = TGBString(type[@"query"]);
		if ([target isEqualToString:@"targetChatCurrent"])
			out[@"target"] = @"current";
		else if ([target isEqualToString:@"targetChatInternalLink"])
			out[@"target"] = @"link";
		else
			out[@"target"] = @"chosen";
	} else if ([kindName isEqualToString:@"inlineKeyboardButtonTypeUser"]) {
		out[@"kind"] = @"user";
		out[@"userId"] = TGBNumber(type[@"user_id"]);
	} else if ([kindName isEqualToString:@"inlineKeyboardButtonTypeCopyText"]) {
		out[@"kind"] = @"copyText";
		out[@"copyText"] = TGBString(type[@"text"]);
	} else if ([kindName isEqualToString:@"inlineKeyboardButtonTypeBuy"]) {
		out[@"kind"] = @"buy";
	}

	return out;
}

- (NSArray *)inlineKeyboardRowsForMessage:(NSDictionary *)message {
	NSDictionary *markup = TGBMarkup(message);
	if (![TGBString(markup[@"@type"]) isEqualToString:@"replyMarkupInlineKeyboard"])
		return nil;

	NSMutableArray *rows = [NSMutableArray array];
	for (id rawRow in TGBArray(markup[@"rows"])) {
		NSMutableArray *row = [NSMutableArray array];
		for (id rawButton in TGBArray(rawRow)) {
			NSDictionary *button = [self tgb_inlineButton:rawButton];
			if (button)
				[row addObject:button];
		}
		if (row.count > 0)
			[rows addObject:row];
	}
	return rows.count > 0 ? rows : nil;
}

- (NSDictionary *)tgb_replyButton:(NSDictionary *)raw {
	NSDictionary *button = TGBDict(raw);
	if (!button)
		return nil;

	NSDictionary *type = TGBDict(button[@"type"]);
	NSString *kindName = TGBString(type[@"@type"]);
	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	out[@"text"] = TGBString(button[@"text"]);
	out[@"kind"] = @"unsupported";

	if ([kindName isEqualToString:@"keyboardButtonTypeText"]) {
		out[@"kind"] = @"text";
	} else if ([kindName isEqualToString:@"keyboardButtonTypeRequestPhoneNumber"]) {
		out[@"kind"] = @"requestPhoneNumber";
	} else if ([kindName isEqualToString:@"keyboardButtonTypeRequestLocation"]) {
		out[@"kind"] = @"requestLocation";
	} else if ([kindName isEqualToString:@"keyboardButtonTypeRequestPoll"]) {
		out[@"kind"] = @"requestPoll";
		out[@"forceQuiz"] = TGBNumber(type[@"force_quiz"]);
		out[@"forceRegular"] = TGBNumber(type[@"force_regular"]);
	} else if ([kindName isEqualToString:@"keyboardButtonTypeRequestUsers"]) {
		out[@"kind"] = @"requestUsers";
		out[@"buttonId"] = TGBNumber(type[@"id"]);
		out[@"maxQuantity"] = TGBNumber(type[@"max_quantity"]);
		out[@"userIsBot"] = [TGBNumber(type[@"restrict_user_is_bot"]) boolValue]
			? TGBNumber(type[@"user_is_bot"])
			: @NO;
		out[@"userIsPremium"] = [TGBNumber(type[@"restrict_user_is_premium"]) boolValue]
			? TGBNumber(type[@"user_is_premium"])
			: @NO;
	} else if ([kindName isEqualToString:@"keyboardButtonTypeRequestChat"]) {
		out[@"kind"] = @"requestChat";
		out[@"buttonId"] = TGBNumber(type[@"id"]);
		out[@"chatIsChannel"] = TGBNumber(type[@"chat_is_channel"]);
	} else if ([kindName isEqualToString:@"keyboardButtonTypeWebApp"]) {
		out[@"kind"] = @"webApp";
		out[@"url"] = TGBString(type[@"url"]);
	}

	return out;
}

- (NSDictionary *)replyKeyboardForMessage:(NSDictionary *)message {
	NSDictionary *markup = TGBMarkup(message);
	NSString *kind = TGBString(markup[@"@type"]);

	if ([kind isEqualToString:@"replyMarkupRemoveKeyboard"])
		return @{@"mode" : @"remove", @"rows" : @[], @"resize" : @NO, @"oneTime" : @NO, @"persistent" : @NO, @"placeholder" : @""};

	if ([kind isEqualToString:@"replyMarkupForceReply"])
		return @{@"mode" : @"forceReply", @"rows" : @[], @"resize" : @NO, @"oneTime" : @NO, @"persistent" : @NO, @"placeholder" : TGBString(markup[@"input_field_placeholder"])};

	if (![kind isEqualToString:@"replyMarkupShowKeyboard"])
		return nil;

	NSMutableArray *rows = [NSMutableArray array];
	for (id rawRow in TGBArray(markup[@"rows"])) {
		NSMutableArray *row = [NSMutableArray array];
		for (id rawButton in TGBArray(rawRow)) {
			NSDictionary *button = [self tgb_replyButton:rawButton];
			if (button)
				[row addObject:button];
		}
		if (row.count > 0)
			[rows addObject:row];
	}

	return @{
		@"mode" : @"show",
		@"rows" : rows,
		@"resize" : TGBNumber(markup[@"resize_keyboard"]),
		@"oneTime" : TGBNumber(markup[@"one_time"]),
		@"persistent" : TGBNumber(markup[@"is_persistent"]),
		@"placeholder" : TGBString(markup[@"input_field_placeholder"]),
	};
}

- (void)shareUsers:(NSArray *)userIds
	 withBotButton:(NSInteger)buttonId
			inChat:(int64_t)chatId
		   message:(int64_t)messageId
		completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type" : @"shareUsersWithBot",
		@"source" : @{@"@type" : @"keyboardButtonSourceMessage",
			@"chat_id" : @(chatId),
			@"message_id" : @(messageId)},
		@"button_id" : @(buttonId),
		@"shared_user_ids" : userIds ?: @[],
		@"only_check" : @NO,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGResultErrorMessage(result));
			return;
		}
		completion(YES, nil);
	}];
}

- (void)shareChat:(int64_t)sharedChatId
	withBotButton:(NSInteger)buttonId
		   inChat:(int64_t)chatId
		  message:(int64_t)messageId
	   completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type" : @"shareChatWithBot",
		@"source" : @{@"@type" : @"keyboardButtonSourceMessage",
			@"chat_id" : @(chatId),
			@"message_id" : @(messageId)},
		@"button_id" : @(buttonId),
		@"shared_chat_id" : @(sharedChatId),
		@"only_check" : @NO,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGResultErrorMessage(result));
			return;
		}
		completion(YES, nil);
	}];
}

#pragma mark - callback buttons

- (void)tgb_callbackWithPayload:(NSDictionary *)payload
						 inChat:(int64_t)chatId
						message:(int64_t)messageId
					 completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!payload) {
		if (completion)
			completion(nil, nil);
		return;
	}

	[self request:@{
		@"@type" : @"getCallbackQueryAnswer",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"payload" : payload,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, TGResultErrorMessage(result));
			return;
		}
		completion(@{
			@"text" : TGBString(result[@"text"]),
			@"showAlert" : TGBNumber(result[@"show_alert"]),
			@"url" : TGBString(result[@"url"]),
		}, nil);
	}];
}

- (NSDictionary *)tgb_payloadForButton:(NSDictionary *)button password:(NSString *)password {
	NSDictionary *b = TGBDict(button);
	NSString *kind = TGBString(b[@"kind"]);

	if ([kind isEqualToString:@"callbackGame"])
		return nil;

	NSString *data = TGBString(b[@"data"]);
	if (data.length == 0)
		return nil;

	if (password.length > 0)
		return @{@"@type" : @"callbackQueryPayloadDataWithPassword",
			@"password" : password,
			@"data" : data};

	return @{@"@type" : @"callbackQueryPayloadData", @"data" : data};
}

- (void)pressCallbackButton:(NSDictionary *)button
					 inChat:(int64_t)chatId
					message:(int64_t)messageId
				 completion:(void (^)(NSDictionary *, NSString *))completion {
	[self pressCallbackButton:button inChat:chatId message:messageId
					 password:nil
				   completion:completion];
}

- (void)pressCallbackButton:(NSDictionary *)button
					 inChat:(int64_t)chatId
					message:(int64_t)messageId
				   password:(NSString *)password
				 completion:(void (^)(NSDictionary *, NSString *))completion {
	[self tgb_callbackWithPayload:[self tgb_payloadForButton:button password:password]
						   inChat:chatId
						  message:messageId
					   completion:completion];
}

#pragma mark - bot profile and commands

- (NSArray *)tgb_commandsFromCommandList:(NSArray *)list {
	NSMutableArray *out = [NSMutableArray array];
	for (id entry in TGBArray(list)) {
		NSDictionary *command = TGBDict(entry);
		if (!command)
			continue;
		[out addObject:@{
			@"command" : TGBString(command[@"command"]),
			@"description" : TGBString(command[@"description"]),
			@"isEphemeral" : TGBNumber(command[@"is_ephemeral"]),
		}];
	}
	return out;
}

- (NSArray *)tgb_commandsFromBotInfo:(NSDictionary *)botInfo {
	return [self tgb_commandsFromCommandList:TGBDict(botInfo)[@"commands"]];
}

- (NSArray *)tgb_botCommandGroupsFromFullInfo:(NSDictionary *)full {
	NSMutableArray *out = [NSMutableArray array];
	for (id entry in TGBArray(TGBDict(full)[@"bot_commands"])) {
		NSDictionary *group = TGBDict(entry);
		if (!group)
			continue;
		int64_t botUserId = [TGBInt64(group[@"bot_user_id"]) longLongValue];
		NSArray *commands = [self tgb_commandsFromCommandList:group[@"commands"]];
		if (!botUserId || !commands.count)
			continue;
		[out addObject:@{
			@"botUserId" : @(botUserId),
			@"name" : ([self nameForUserId:botUserId] ?: TGL(@"Attachment.Bot", @"Bot")),
			@"commands" : commands,
		}];
	}
	return out;
}

- (void)tgb_botCommandsForBasicGroupId:(NSNumber *)basicGroupId
							 completion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getBasicGroupFullInfo", @"basic_group_id" : basicGroupId}
		completion:^(NSDictionary *full) {
			if (completion)
				completion([weakSelf tgb_botCommandGroupsFromFullInfo:full]);
		}];
}

- (void)tgb_botCommandsForSupergroupId:(NSNumber *)supergroupId
							 completion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getSupergroupFullInfo", @"supergroup_id" : supergroupId}
		completion:^(NSDictionary *full) {
			if (completion)
				completion([weakSelf tgb_botCommandGroupsFromFullInfo:full]);
		}];
}

- (void)botCommandsInGroup:(int64_t)chatId completion:(void (^)(NSArray *bots))completion {
	NSDictionary *known = self.chatsById[@(chatId)];
	NSNumber *basicGroupId = known[@"basicGroupId"];
	NSNumber *supergroupId = known[@"supergroupId"];
	if (basicGroupId) {
		[self tgb_botCommandsForBasicGroupId:basicGroupId completion:completion];
		return;
	}
	if (supergroupId) {
		[self tgb_botCommandsForSupergroupId:supergroupId completion:completion];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			TGClient *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			NSDictionary *type = TGBDict(chat[@"type"]);
			NSString *t = TGBString(type[@"@type"]);
			if ([t isEqualToString:@"chatTypeBasicGroup"]) {
				[strongSelf tgb_botCommandsForBasicGroupId:type[@"basic_group_id"] completion:completion];
			} else if ([t isEqualToString:@"chatTypeSupergroup"]) {
				[strongSelf tgb_botCommandsForSupergroupId:type[@"supergroup_id"] completion:completion];
			} else if (completion) {
				completion(@[]);
			}
		}];
}

- (void)botInfoForUser:(int64_t)userId completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getUserFullInfo", @"user_id" : @(userId)}
		completion:^(NSDictionary *full) {
			if (!completion)
				return;
			NSDictionary *botInfo = TGBDict(TGBDict(full)[@"bot_info"]);
			if (!botInfo) {
				completion(nil);
				return;
			}
			NSDictionary *menu = TGBDict(botInfo[@"menu_button"]);
			completion(@{
				@"description" : TGBString(botInfo[@"description"]),
				@"shortDescription" : TGBString(botInfo[@"short_description"]),
				@"commands" : [self tgb_commandsFromBotInfo:botInfo],
				@"menuButtonText" : TGBString(menu[@"text"]),
				@"menuButtonUrl" : TGBString(menu[@"url"]),
			});
		}];
}

- (void)botCommandsForUser:(int64_t)userId completion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getUserFullInfo", @"user_id" : @(userId)}
		completion:^(NSDictionary *full) {
			if (completion)
				completion([self tgb_commandsFromBotInfo:TGBDict(TGBDict(full)[@"bot_info"])]);
		}];
}

- (void)botCommandsForUser:(int64_t)userId
			matchingPrefix:(NSString *)prefix
				completion:(void (^)(NSArray *))completion {
	NSString *needle = prefix ?: @"";
	if ([needle hasPrefix:@"/"])
		needle = [needle substringFromIndex:1];
	needle = [needle lowercaseString];

	[self botCommandsForUser:userId completion:^(NSArray *commands) {
		if (!completion)
			return;
		if (needle.length == 0) {
			completion(commands);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *command in commands) {
			if ([[TGBString(command[@"command"]) lowercaseString] hasPrefix:needle])
				[out addObject:command];
		}
		completion(out);
	}];
}

- (void)menuButtonForBot:(int64_t)userId completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getMenuButton", @"user_id" : @(userId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			completion(@{@"text" : TGBString(result[@"text"]),
				@"url" : TGBString(result[@"url"])});
		}];
}

#pragma mark - starting a bot

- (void)startBot:(int64_t)botUserId
		  inChat:(int64_t)chatId
	   parameter:(NSString *)parameter
	  completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type" : @"sendBotStartMessage",
		@"bot_user_id" : @(botUserId),
		@"chat_id" : @(chatId),
		@"parameter" : parameter ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGResultErrorMessage(result));
			return;
		}
		completion(YES, nil);
	}];
}

- (void)botStartLinkInfo:(NSString *)link completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getInternalLinkType", @"link" : link ?: @""}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			NSString *kind = TGBString(TGBDict(result)[@"@type"]);
			BOOL inGroup = [kind isEqualToString:@"internalLinkTypeBotStartInGroup"];
			if (!inGroup && ![kind isEqualToString:@"internalLinkTypeBotStart"]) {
				completion(nil);
				return;
			}
			BOOL autostart = [TGBNumber(result[@"autostart"]) boolValue];
			completion(@{
				@"username" : TGBString(result[@"bot_username"]),
				@"parameter" : TGBString(result[@"start_parameter"]),
				@"inGroup" : inGroup ? @YES : @NO,
				@"autostart" : autostart ? @YES : @NO,
			});
		}];
}

- (void)openBotStartLink:(NSString *)link completion:(void (^)(int64_t, NSString *))completion {
	if (!link.length)
		return;
	if (!TGBotStartLinksInFlight)
		TGBotStartLinksInFlight = [NSMutableSet set];
	if ([TGBotStartLinksInFlight containsObject:link])
		return;
	[TGBotStartLinksInFlight addObject:link];

	void (^finish)(int64_t, NSString *) = ^(int64_t openedChatId, NSString *errorCode) {
		[TGBotStartLinksInFlight removeObject:link];
		if (completion)
			completion(openedChatId, errorCode);
	};

	[self botStartLinkInfo:link completion:^(NSDictionary *info) {
		if (!info) {
			finish(0, @"notFound");
			return;
		}
		if ([info[@"inGroup"] boolValue]) {
			finish(0, @"unsupported");
			return;
		}
		NSString *parameter = TGBString(info[@"parameter"]);
		[self request:@{@"@type" : @"searchPublicChat",
			@"username" : TGBString(info[@"username"])}
			completion:^(NSDictionary *chat) {
				if (TGResultIsError(chat)) {
					finish(0, @"notFound");
					return;
				}
				int64_t chatId = [TGBNumber(chat[@"id"]) longLongValue];
				int64_t botUserId = [TGBNumber(TGBDict(chat[@"type"])[@"user_id"]) longLongValue];
				if (chatId == 0 || botUserId == 0) {
					finish(0, @"notFound");
					return;
				}
				[self startBot:botUserId inChat:chatId parameter:parameter
					completion:^(BOOL ok, NSString *errorMessage) {
						if (!ok) {
							finish(0, errorMessage.length ? errorMessage : @"sendFailed");
							return;
						}
						finish(chatId, nil);
					}];
			}];
	}];
}

- (void)resetBotStartLinksForAccountSwitch {
	[TGBotStartLinksInFlight removeAllObjects];
}

#pragma mark - write access

- (void)canBotSendMessages:(int64_t)botUserId completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"canBotSendMessages", @"bot_user_id" : @(botUserId)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)allowBotToSendMessages:(int64_t)botUserId completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"allowBotToSendMessages", @"bot_user_id" : @(botUserId)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

#pragma mark - inline queries

- (NSDictionary *)tgb_inlineResult:(NSDictionary *)raw {
	NSDictionary *result = TGBDict(raw);
	if (!result)
		return nil;

	NSString *type = TGBString(result[@"@type"]);
	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	out[@"id"] = TGBString(result[@"id"]);
	out[@"title"] = TGBString(result[@"title"]);
	out[@"description"] = TGBString(result[@"description"]);
	out[@"kind"] = @"article";

	NSNumber *thumbId = TGBFileIdOfThumbnail(result);
	NSNumber *fileId = nil;

	if ([type isEqualToString:@"inlineQueryResultArticle"]) {
		out[@"url"] = TGBString(result[@"url"]);
	} else if ([type isEqualToString:@"inlineQueryResultPhoto"]) {
		out[@"kind"] = @"photo";
		NSDictionary *photo = TGBDict(result[@"photo"]);
		fileId = TGBFileIdOfPhoto(photo);
		if (!thumbId)
			thumbId = fileId;
	} else if ([type isEqualToString:@"inlineQueryResultSticker"]) {
		out[@"kind"] = @"sticker";
		NSDictionary *sticker = TGBDict(result[@"sticker"]);
		fileId = TGBFileIdOfDocument(sticker, @"sticker");
		thumbId = TGBFileIdOfThumbnail(sticker) ?: fileId;
		out[@"title"] = TGBString(sticker[@"emoji"]);
	} else if ([type isEqualToString:@"inlineQueryResultAnimation"]) {
		out[@"kind"] = @"animation";
		NSDictionary *animation = TGBDict(result[@"animation"]);
		fileId = TGBFileIdOfDocument(animation, @"animation");
		thumbId = TGBFileIdOfThumbnail(animation);
	} else if ([type isEqualToString:@"inlineQueryResultVideo"]) {
		out[@"kind"] = @"video";
		NSDictionary *video = TGBDict(result[@"video"]);
		fileId = TGBFileIdOfDocument(video, @"video");
		thumbId = TGBFileIdOfThumbnail(video);
	} else if ([type isEqualToString:@"inlineQueryResultAudio"]) {
		out[@"kind"] = @"audio";
		NSDictionary *audio = TGBDict(result[@"audio"]);
		fileId = TGBFileIdOfDocument(audio, @"audio");
		out[@"title"] = TGBString(audio[@"title"]);
		out[@"description"] = TGBString(audio[@"performer"]);
	} else if ([type isEqualToString:@"inlineQueryResultVoiceNote"]) {
		out[@"kind"] = @"voiceNote";
		fileId = TGBFileIdOfDocument(TGBDict(result[@"voice_note"]), @"voice");
	} else if ([type isEqualToString:@"inlineQueryResultDocument"]) {
		out[@"kind"] = @"document";
		NSDictionary *document = TGBDict(result[@"document"]);
		fileId = TGBFileIdOfDocument(document, @"document");
		thumbId = TGBFileIdOfThumbnail(document);
	} else if ([type isEqualToString:@"inlineQueryResultLocation"]) {
		out[@"kind"] = @"location";
	} else if ([type isEqualToString:@"inlineQueryResultVenue"]) {
		out[@"kind"] = @"venue";
		NSDictionary *venue = TGBDict(result[@"venue"]);
		out[@"title"] = TGBString(venue[@"title"]);
		out[@"description"] = TGBString(venue[@"address"]);
	} else if ([type isEqualToString:@"inlineQueryResultContact"]) {
		out[@"kind"] = @"contact";
		NSDictionary *contact = TGBDict(result[@"contact"]);
		out[@"title"] = [NSString stringWithFormat:@"%@ %@",
			TGBString(contact[@"first_name"]), TGBString(contact[@"last_name"])];
		out[@"description"] = TGBString(contact[@"phone_number"]);
	} else if ([type isEqualToString:@"inlineQueryResultGame"]) {
		out[@"kind"] = @"game";
		NSDictionary *game = TGBDict(result[@"game"]);
		out[@"title"] = TGBString(game[@"title"]);
		out[@"description"] = TGBString(game[@"description"]);
		thumbId = TGBFileIdOfPhoto(TGBDict(game[@"photo"]));
	}

	if (thumbId)
		out[@"thumbId"] = thumbId;
	if (fileId)
		out[@"fileId"] = fileId;
	return out;
}

- (void)inlineQueryToBot:(int64_t)botUserId
				  inChat:(int64_t)chatId
				   query:(NSString *)query
				  offset:(NSString *)offset
			  completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"getInlineQueryResults",
		@"bot_user_id" : @(botUserId),
		@"chat_id" : @(chatId),
		@"query" : query ?: @"",
		@"offset" : offset ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSMutableArray *results = [NSMutableArray array];
		for (id entry in TGBArray(result[@"results"])) {
			NSDictionary *flat = [self tgb_inlineResult:entry];
			if (flat)
				[results addObject:flat];
		}
		NSDictionary *button = TGBDict(result[@"button"]);
		NSDictionary *buttonType = TGBDict(button[@"type"]);
		BOOL startBot = [TGBString(buttonType[@"@type"])
			isEqualToString:@"inlineQueryResultsButtonTypeStartBot"];
		completion(@{
			@"queryId" : TGBInt64(result[@"inline_query_id"]),
			@"nextOffset" : TGBString(result[@"next_offset"]),
			@"buttonText" : startBot ? TGBString(button[@"text"]) : @"",
			@"buttonParameter" : startBot ? TGBString(buttonType[@"parameter"]) : @"",
			@"results" : results,
		});
	}];
}

- (void)sendInlineResult:(NSString *)resultId
				 queryId:(NSNumber *)queryId
				  toChat:(int64_t)chatId
				  thread:(int64_t)threadId
	 directMessagesTopic:(int64_t)directMessagesTopicId
			  savedTopic:(int64_t)savedTopicId
				 replyTo:(int64_t)replyToId
				 hideVia:(BOOL)hideVia {
	NSMutableDictionary *request = [@{
		@"@type" : @"sendInlineQueryResultMessage",
		@"chat_id" : @(chatId),
		@"query_id" : queryId ?: @0,
		@"result_id" : resultId ?: @"",
		@"hide_via_bot" : hideVia ? @YES : @NO,
	} mutableCopy];

	NSDictionary *topic = TGTopicDictionary(threadId, directMessagesTopicId, savedTopicId,
		TGBotsChatIsForum(self, chatId));
	if (topic)
		request[@"topic_id"] = topic;

	NSDictionary *replyTo = TGReplyToDictionary(replyToId, nil, nil, 0);
	if (replyTo)
		request[@"reply_to"] = replyTo;

	[self send:request];
}

#pragma mark - users

- (void)tgb_usersForIds:(NSArray *)userIds completion:(void (^)(NSArray *))completion {
	NSArray *ids = TGBArray(userIds) ?: @[];
	if (ids.count == 0) {
		if (completion)
			completion(@[]);
		return;
	}

	NSMutableArray *out = [NSMutableArray array];
	for (NSInteger i = 0; i < ids.count; i++)
		[out addObject:[NSNull null]];

	__block NSUInteger remaining = ids.count;
	for (NSInteger i = 0; i < ids.count; i++) {
		NSInteger index = i;
		[self request:@{@"@type" : @"getUser", @"user_id" : ids[i]}
			completion:^(NSDictionary *user) {
				if (!TGResultIsError(user)) {
					NSString *username = TGBString(
						[TGBArray(TGBDict(user[@"usernames"])[@"active_usernames"]) firstObject]);
					NSString *name = [NSString stringWithFormat:@"%@ %@",
						TGBString(user[@"first_name"]), TGBString(user[@"last_name"])];
					out[index] = @{
						@"id" : TGBNumber(user[@"id"]),
						@"name" : [name stringByTrimmingCharactersInSet:
								[NSCharacterSet whitespaceCharacterSet]],
						@"username" : username,
					};
				}
				if (--remaining > 0)
					return;
				NSMutableArray *clean = [NSMutableArray array];
				for (id entry in out) {
					if ([entry isKindOfClass:NSDictionary.class])
						[clean addObject:entry];
				}
				if (completion)
					completion(clean);
			}];
	}
}

- (void)recentInlineBotsWithCompletion:(void (^)(NSArray *, BOOL))completion {
	[self request:@{@"@type" : @"getRecentInlineBots"}
		completion:^(NSDictionary *result) {
			if (TGResultIsError(result)) {
				if (completion)
					completion(@[], YES);
				return;
			}
			[self tgb_usersForIds:result[@"user_ids"] completion:^(NSArray *users) {
				if (completion)
					completion(users ?: @[], NO);
			}];
		}];
}

- (void)similarBotsFor:(int64_t)botUserId
			completion:(void (^)(NSArray *, NSInteger))completion {
	[self request:@{@"@type" : @"getBotSimilarBots", @"bot_user_id" : @(botUserId)}
		completion:^(NSDictionary *result) {
			if (TGResultIsError(result)) {
				if (completion)
					completion(nil, 0);
				return;
			}
			NSInteger total = [TGBNumber(result[@"total_count"]) integerValue];
			[self tgb_usersForIds:result[@"user_ids"] completion:^(NSArray *bots) {
				if (completion)
					completion(bots, total > 0 ? total : (NSInteger)bots.count);
			}];
		}];
}

- (void)openSimilarBot:(int64_t)openedBotUserId fromBot:(int64_t)botUserId {
	[self send:@{
		@"@type" : @"openBotSimilarBot",
		@"bot_user_id" : @(botUserId),
		@"opened_bot_user_id" : @(openedBotUserId),
	}];
}

#pragma mark - message decoration

- (void)viaBotForMessage:(NSDictionary *)message completion:(void (^)(NSString *))completion {
	NSDictionary *m = TGBDict(message);
	NSNumber *botId = [m[@"via_bot_user_id"] isKindOfClass:NSNumber.class]
		? m[@"via_bot_user_id"]
		: m[@"viaBotId"];
	if (![botId isKindOfClass:NSNumber.class] || [botId longLongValue] == 0) {
		if (completion)
			completion(nil);
		return;
	}

	[self request:@{@"@type" : @"getUser", @"user_id" : botId}
		completion:^(NSDictionary *user) {
			if (!completion)
				return;
			NSString *username = TGBString(
				[TGBArray(TGBDict(user[@"usernames"])[@"active_usernames"]) firstObject]);
			completion(username.length > 0 ? username : nil);
		}];
}

- (NSString *)botServiceTextForMessage:(NSDictionary *)message {
	NSDictionary *m = TGBDict(message);
	NSDictionary *content = TGBDict(m[@"content"]) ?: m;
	NSString *type = TGBString(content[@"@type"]);

	if ([type isEqualToString:@"messageBotWriteAccessAllowed"]) {
		NSString *reason = TGBString(TGBDict(content[@"reason"])[@"@type"]);
		if ([reason isEqualToString:@"botWriteAccessAllowReasonLaunchedWebApp"]) {
			NSString *appTitle = TGBString(TGBDict(TGBDict(content[@"reason"])[@"web_app"])[@"title"]);
			return [NSString stringWithFormat:TGL(@"AuthSessions.MessageApp", @"You allowed this bot to message you when you opened %@."), appTitle];
		}
		return TGL(@"Notification.BotWriteAllowedRequest", @"You allowed this bot to message you in the app.");
	}

	if ([type isEqualToString:@"messageUsersShared"]) {
		NSString *botName = TGBString(TGBDict(self.chatsById[m[@"chat_id"]])[@"title"]);
		NSMutableArray *names = [NSMutableArray array];
		for (NSDictionary *rawUser in TGBArray(content[@"users"])) {
			NSDictionary *user = TGBDict(rawUser);
			NSString *full = [[NSString stringWithFormat:@"%@ %@",
				TGBString(user[@"first_name"]), TGBString(user[@"last_name"])]
				stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if (full.length)
				[names addObject:full];
		}
		NSString *joined = [names componentsJoinedByString:@", "];
		if (names.count == 1)
			return [NSString stringWithFormat:TGL(@"Notification.RequestedPeer", @"You shared %1$@ with %2$@."), joined, botName];
		return [NSString stringWithFormat:TGL(@"Notification.RequestedPeerMultiple", @"You shared %1$@ with %2$@."), joined, botName];
	}

	if ([type isEqualToString:@"messageChatShared"]) {
		NSString *botName = TGBString(TGBDict(self.chatsById[m[@"chat_id"]])[@"title"]);
		NSString *sharedChatTitle = TGBString(TGBDict(content[@"chat"])[@"title"]);
		return [NSString stringWithFormat:TGL(@"Notification.RequestedPeer", @"You shared %1$@ with %2$@."), sharedChatTitle, botName];
	}

	if ([type isEqualToString:@"messageWebAppDataSent"] ||
		[type isEqualToString:@"messageWebAppDataReceived"]) {
		NSString *buttonText = TGBString(content[@"button_text"]);
		return [NSString stringWithFormat:TGL(@"Notification.WebAppSentData", @"You have successfully transferred data from the \"%@\" button to the bot."), buttonText];
	}

	return nil;
}

#pragma mark - verification granting

- (void)botVerificationParametersForBotUserId:(int64_t)botUserId
								   completion:(void (^)(NSDictionary *))completion {
	if (!completion)
		return;
	[self request:@{@"@type" : @"getUserFullInfo", @"user_id" : @(botUserId)}
		completion:^(NSDictionary *full) {
			if (TGResultIsError(full)) {
				completion(nil);
				return;
			}
			NSDictionary *botInfo = TGBDict(full[@"bot_info"]);
			NSDictionary *parameters = TGBDict(botInfo[@"verification_parameters"]);
			if (!parameters) {
				completion(nil);
				return;
			}
			NSDictionary *defaultDescription = TGBDict(parameters[@"default_custom_description"]);
			completion(@{
				@"organizationName" : TGBString(parameters[@"organization_name"]),
				@"canSetCustomDescription" : @([parameters[@"can_set_custom_description"] boolValue]),
				@"defaultCustomDescription" : TGBString(defaultDescription[@"text"]),
			});
		}];
}

- (void)resolveBotVerificationTargetForUsername:(NSString *)username
									  completion:(void (^)(BOOL found, BOOL isChat, int64_t targetId, NSString *displayName))completion {
	if (!completion)
		return;
	NSString *name = username;
	while ([name hasPrefix:@"@"])
		name = [name substringFromIndex:1];
	if (!name.length) {
		completion(NO, NO, 0, nil);
		return;
	}
	[self request:@{@"@type" : @"searchPublicChat", @"username" : name}
		completion:^(NSDictionary *chat) {
			if (TGResultIsError(chat)) {
				completion(NO, NO, 0, nil);
				return;
			}
			NSString *title = TGBString(chat[@"title"]);
			NSDictionary *type = TGBDict(chat[@"type"]);
			NSString *kind = type[@"@type"];
			if ([kind isEqualToString:@"chatTypePrivate"]) {
				int64_t userId = [TGBNumber(type[@"user_id"]) longLongValue];
				completion(userId != 0, NO, userId, title);
				return;
			}
			if ([kind isEqualToString:@"chatTypeSupergroup"] || [kind isEqualToString:@"chatTypeBasicGroup"]) {
				int64_t chatId = [TGBNumber(chat[@"id"]) longLongValue];
				completion(chatId != 0, YES, chatId, title);
				return;
			}
			completion(NO, NO, 0, nil);
		}];
}

- (NSDictionary *)tgb_messageSenderForTargetId:(int64_t)targetId isChat:(BOOL)targetIsChat {
	return targetIsChat
		? @{@"@type" : @"messageSenderChat", @"chat_id" : @(targetId)}
		: @{@"@type" : @"messageSenderUser", @"user_id" : @(targetId)};
}

- (void)grantBotVerification:(int64_t)botUserId
				  toTargetId:(int64_t)targetId
				targetIsChat:(BOOL)targetIsChat
		   customDescription:(NSString *)customDescription
				  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setMessageSenderBotVerification",
		@"bot_user_id" : @(botUserId),
		@"verified_id" : [self tgb_messageSenderForTargetId:targetId isChat:targetIsChat],
		@"custom_description" : customDescription ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)revokeBotVerification:(int64_t)botUserId
				fromTargetId:(int64_t)targetId
				targetIsChat:(BOOL)targetIsChat
				   completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"removeMessageSenderBotVerification",
		@"bot_user_id" : @(botUserId),
		@"verified_id" : [self tgb_messageSenderForTargetId:targetId isChat:targetIsChat],
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

@end

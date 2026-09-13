#import "TGClient+ChatState.h"
#import "TGClient+Messages.h"
#import "TGMessageReply.h"
#import "TGClient+Private.h"
#import "TGClient+MessageContent.h"
#import "TGMessageTopic.h"
#import "TGClient+Notifications.h"
#import "TGFlattenMessageContent.h"
#import "TGFlattenMessages.h"
#import "TGLocalization.h"
#import "TGStringTruncation.h"

static NSDictionary *TGMCDict(id value) {
	return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static NSArray *TGMCArray(id value) {
	return [value isKindOfClass:[NSArray class]] ? value : nil;
}

static NSString *TGMCString(id value) {
	return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSNumber *TGMCNumber(id value) {
	return [value isKindOfClass:[NSNumber class]] ? value : @0;
}

static NSDictionary *TGMCFormattedText(NSString *text) {
	return @{@"@type" : @"formattedText",
		@"text" : text ?: @"",
		@"entities" : @[]};
}

static NSDictionary *TGMCLocalFile(NSString *path) {
	return @{@"@type" : @"inputFileLocal", @"path" : path ?: @""};
}

static NSDictionary *TGMCDefaultLinkPreviewOptions(void) {
	return @{
		@"@type" : @"linkPreviewOptions",
		@"is_disabled" : @NO,
		@"url" : @"",
		@"force_small_media" : @NO,
		@"force_large_media" : @NO,
		@"show_above_text" : @NO,
	};
}

NSDictionary *TGCustomEmojiEntity(NSInteger offset, NSInteger length, long long customEmojiId) {
	return @{
		@"@type" : @"textEntity",
		@"offset" : @((int32_t)offset),
		@"length" : @((int32_t)length),
		@"type" : @{
			@"@type" : @"textEntityTypeCustomEmoji",
			@"custom_emoji_id" : [NSString stringWithFormat:@"%lld", customEmojiId],
		},
	};
}

NSDictionary *TGMentionNameEntity(NSInteger offset, NSInteger length, int64_t userId) {
	return @{
		@"@type" : @"textEntity",
		@"offset" : @((int32_t)offset),
		@"length" : @((int32_t)length),
		@"type" : @{
			@"@type" : @"textEntityTypeMentionName",
			@"user_id" : @(userId),
		},
	};
}

static NSNumber *TGMCFileId(id file) {
	NSDictionary *dict = TGMCDict(file);
	return dict ? TGMCNumber(dict[@"id"]) : @0;
}

static NSNumber *TGMCThumbId(id owner) {
	NSDictionary *dict = TGMCDict(owner);
	NSDictionary *thumbnail = TGMCDict(dict[@"thumbnail"]);
	return TGMCFileId(thumbnail[@"file"]);
}

@implementation TGClient (MessageContent)

static BOOL TGMCChatIsForum(TGClient *client, int64_t chatId) {
	id value = client.chatsById[@(chatId)][@"isForum"];
	return [value isKindOfClass:NSNumber.class] && [value boolValue];
}

- (NSDictionary *)mc_sendRequestForChat:(int64_t)chatId
								 thread:(int64_t)threadId
					directMessagesTopic:(int64_t)directMessagesTopicId
							 savedTopic:(int64_t)savedTopicId
								content:(NSDictionary *)content
								replyTo:(int64_t)replyToId
								options:(NSDictionary *)options {
	NSMutableDictionary *request = [@{
		@"@type" : @"sendMessage",
		@"chat_id" : @(chatId),
		@"options" : TGMsgSendOptions(options),
		@"input_message_content" : content ?: @{},
	} mutableCopy];

	NSDictionary *topic = TGTopicDictionary(threadId, directMessagesTopicId, savedTopicId,
		TGMCChatIsForum(self, chatId));
	if (topic)
		request[@"topic_id"] = topic;
	NSDictionary *replyTo = TGReplyToDictionary(replyToId, options[@"quoteText"],
		TGWireEntitiesFromFlattened(options[@"quoteEntities"]),
		[options[@"quotePosition"] integerValue]);
	if (replyTo)
		request[@"reply_to"] = replyTo;
	return request;
}

- (void)mc_send:(NSDictionary *)content
				 toChat:(int64_t)chatId
				 thread:(int64_t)threadId
	directMessagesTopic:(int64_t)directMessagesTopicId
			 savedTopic:(int64_t)savedTopicId
				replyTo:(int64_t)replyToId
				options:(NSDictionary *)options
			 completion:(void (^)(int64_t messageId))completion {
	NSDictionary *request = [self mc_sendRequestForChat:chatId
												 thread:threadId
									directMessagesTopic:directMessagesTopicId
											 savedTopic:savedTopicId
												content:content
												replyTo:replyToId
												options:options];
	[self request:request completion:^(NSDictionary *result) {
		if (TGResultIsError(result))
			NSLog(@"TGClient: send rejected: %@ %@", result[@"code"], result[@"message"]);
		if (completion)
			completion(TGResultIsError(result) ? 0 : [TGMCNumber(result[@"id"]) longLongValue]);
	}];
}

- (void)mc_parse:(NSString *)text completion:(void (^)(NSDictionary *formatted))completion {
	if (!text.length) {
		if (completion)
			completion(TGMCFormattedText(@""));
		return;
	}
	[self request:@{
		@"@type" : @"parseMarkdown",
		@"text" : TGMCFormattedText(text),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result) || !TGMCString(result[@"text"]).length) {
			completion(TGMCFormattedText(text));
			return;
		}
		completion(@{@"@type" : @"formattedText",
			@"text" : TGMCString(result[@"text"]),
			@"entities" : TGMCArray(result[@"entities"]) ?: @[]});
	}];
}

#pragma mark - text entities

- (void)parseMarkdown:(NSString *)text
		   completion:(void (^)(NSString *, NSArray *))completion {
	[self mc_parse:text completion:^(NSDictionary *formatted) {
		if (completion)
			completion(TGMCString(formatted[@"text"]),
				TGMCFlattenEntities(formatted[@"entities"]));
	}];
}

- (void)formattedTextFromMarkdown:(NSString *)text
						completion:(void (^)(NSString *, NSArray *))completion {
	[self mc_parse:text completion:^(NSDictionary *formatted) {
		if (completion)
			completion(TGMCString(formatted[@"text"]),
				TGMCArray(formatted[@"entities"]) ?: @[]);
	}];
}

- (void)entitiesInText:(NSString *)text completion:(void (^)(NSArray *))completion {
	if (!text.length) {
		if (completion)
			completion(@[]);
		return;
	}
	[self request:@{@"@type" : @"getTextEntities", @"text" : text}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(TGResultIsError(result) ? @[] : TGMCFlattenEntities(result[@"entities"]));
		}];
}

- (void)sendMarkdown:(NSString *)text
				 toChat:(int64_t)chatId
				 thread:(int64_t)threadId
	directMessagesTopic:(int64_t)directMessagesTopicId
			 savedTopic:(int64_t)savedTopicId
				replyTo:(int64_t)replyToId {
	if (!text.length)
		return;
	__weak TGClient *weakSelf = self;
	[self mc_parse:text completion:^(NSDictionary *formatted) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSDictionary *content = @{@"@type" : @"inputMessageText", @"text" : formatted};
		NSDictionary *request =
			[strongSelf mc_sendRequestForChat:chatId
									   thread:threadId
						  directMessagesTopic:directMessagesTopicId
								   savedTopic:savedTopicId
									  content:content
									  replyTo:replyToId
									  options:nil];
		[strongSelf send:request];
	}];
}

static void TGMCSendEditCaptionRequest(TGClient *client, int64_t messageId, int64_t chatId,
	NSDictionary *formattedCaption, BOOL showCaptionAboveMedia, void (^completion)(BOOL)) {
	[client request:@{
		@"@type" : @"editMessageCaption",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"caption" : formattedCaption,
		@"show_caption_above_media" : @(showCaptionAboveMedia),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)editCaptionOfMessage:(int64_t)messageId
					  inChat:(int64_t)chatId
					 caption:(NSString *)caption
					entities:(NSArray *)entities
	  showCaptionAboveMedia:(BOOL)showCaptionAboveMedia
				  completion:(void (^)(BOOL))completion {
	if (entities.count > 0) {
		NSDictionary *formatted = @{
			@"@type" : @"formattedText",
			@"text" : caption ?: @"",
			@"entities" : entities,
		};
		TGMCSendEditCaptionRequest(self, messageId, chatId, formatted, showCaptionAboveMedia, completion);
		return;
	}

	__weak TGClient *weakSelf = self;
	[self mc_parse:caption completion:^(NSDictionary *formatted) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf) {
			if (completion)
				completion(NO);
			return;
		}
		TGMCSendEditCaptionRequest(strongSelf, messageId, chatId, formatted, showCaptionAboveMedia,
			completion);
	}];
}

- (void)editMessageWithMarkdown:(int64_t)messageId
						 inChat:(int64_t)chatId
						   text:(NSString *)text
			 linkPreviewOptions:(NSDictionary *)linkPreviewOptions
					 completion:(void (^)(BOOL))completion {
	__weak TGClient *weakSelf = self;
	[self mc_parse:text completion:^(NSDictionary *formatted) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf) {
			if (completion)
				completion(NO);
			return;
		}
		[strongSelf request:@{
			@"@type" : @"editMessageText",
			@"chat_id" : @(chatId),
			@"message_id" : @(messageId),
			@"input_message_content" : @{
				@"@type" : @"inputMessageText",
				@"text" : formatted,
				@"link_preview_options" : linkPreviewOptions ?: TGMCDefaultLinkPreviewOptions(),
			},
		} completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
	}];
}

- (void)actualAuthorOfMessage:(int64_t)messageId
					   inChat:(int64_t)chatId
				   completion:(void (^)(NSString *name, int64_t userId))completion {
	[self request:@{
		@"@type" : @"getMessageAuthor",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result) || ![result[@"@type"] isEqualToString:@"user"]) {
			completion(nil, 0);
			return;
		}

		int64_t userId = [result[@"id"] longLongValue];
		NSString *name = [[NSString stringWithFormat:@"%@ %@",
			TGMCString(result[@"first_name"]), TGMCString(result[@"last_name"])]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		if (userId && name.length) {
			[self capUserRegistriesIfNeeded];
			self.usersById[@(userId)] = name;
			self.userRecordsById[@(userId)] = result;
		}
		completion(name.length ? name : nil, userId);
	}];
}

#pragma mark - inspecting media

- (void)mediaInfoForMessage:(int64_t)messageId
					 inChat:(int64_t)chatId
				 completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getMessage",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(TGResultIsError(result) ? nil : TGMCMediaInfo(result));
		}];
}

- (void)openContentOfMessage:(int64_t)messageId inChat:(int64_t)chatId {
	[self send:@{@"@type" : @"openMessageContent",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId)}];
}

- (NSString *)placeholderTextForContentKind:(NSString *)kind {
	if ([kind isEqualToString:@"messageExpiredPhoto"])
		return TGL(@"Message.ImageExpired", @"Photo has expired");
	if ([kind isEqualToString:@"messageExpiredVideo"])
		return TGL(@"Message.VideoExpired", @"Video has expired");
	if ([kind isEqualToString:@"messageExpiredVoiceNote"])
		return TGL(@"Message.VoiceMessageExpired", @"Expired voice message");
	if ([kind isEqualToString:@"messageExpiredVideoNote"])
		return TGL(@"Message.VideoMessageExpired", @"Expired video message");
	if ([kind isEqualToString:@"messageUnsupported"])
		return TGL(@"Conversation.UnsupportedMediaPlaceholder",
			@"This message is not supported on your version of Telegram. Please update to the latest version."
			 "Please update to the latest version.");
	return nil;
}

#pragma mark - sending media

- (void)sendPhotoAtPath:(NSString *)path
				 toChat:(int64_t)chatId
				 thread:(int64_t)threadId
	directMessagesTopic:(int64_t)directMessagesTopicId
			 savedTopic:(int64_t)savedTopicId
				replyTo:(int64_t)replyToId
				caption:(NSString *)caption
				spoiler:(BOOL)spoiler
	selfDestructSeconds:(NSInteger)selfDestructSeconds
				options:(NSDictionary *)options {
	if (!path.length)
		return;
	__weak TGClient *weakSelf = self;
	[self mc_parse:caption completion:^(NSDictionary *formatted) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSMutableDictionary *content = [@{
			@"@type" : @"inputMessagePhoto",
			@"photo" : @{@"@type" : @"inputPhoto",
				@"photo" : TGMCLocalFile(path)},
			@"caption" : formatted,
			@"has_spoiler" : @(spoiler),
		} mutableCopy];
		NSDictionary *destruct = TGMCSelfDestruct(selfDestructSeconds);
		if (destruct)
			content[@"self_destruct_type"] = destruct;
		[strongSelf mc_send:content
						 toChat:chatId
						 thread:threadId
			directMessagesTopic:directMessagesTopicId
					 savedTopic:savedTopicId
						replyTo:replyToId
						options:options
					 completion:nil];
	}];
}

- (void)sendVideoAtPath:(NSString *)path
				 toChat:(int64_t)chatId
				 thread:(int64_t)threadId
	directMessagesTopic:(int64_t)directMessagesTopicId
			 savedTopic:(int64_t)savedTopicId
				replyTo:(int64_t)replyToId
				caption:(NSString *)caption
			   duration:(NSInteger)duration
				  width:(NSInteger)width
				 height:(NSInteger)height
				spoiler:(BOOL)spoiler
	selfDestructSeconds:(NSInteger)selfDestructSeconds
				options:(NSDictionary *)options {
	if (!path.length)
		return;
	__weak TGClient *weakSelf = self;
	[self mc_parse:caption completion:^(NSDictionary *formatted) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSMutableDictionary *content = [@{
			@"@type" : @"inputMessageVideo",
			@"video" : @{@"@type" : @"inputVideo",
				@"video" : TGMCLocalFile(path),
				@"duration" : @(duration),
				@"width" : @(width),
				@"height" : @(height)},
			@"caption" : formatted,
			@"has_spoiler" : @(spoiler),
		} mutableCopy];
		NSDictionary *destruct = TGMCSelfDestruct(selfDestructSeconds);
		if (destruct)
			content[@"self_destruct_type"] = destruct;
		[strongSelf mc_send:content
						 toChat:chatId
						 thread:threadId
			directMessagesTopic:directMessagesTopicId
					 savedTopic:savedTopicId
						replyTo:replyToId
						options:options
					 completion:nil];
	}];
}

- (void)sendVideoNoteAtPath:(NSString *)path
					 toChat:(int64_t)chatId
					 thread:(int64_t)threadId
		directMessagesTopic:(int64_t)directMessagesTopicId
				 savedTopic:(int64_t)savedTopicId
					replyTo:(int64_t)replyToId
				   duration:(NSInteger)duration
					   side:(NSInteger)side
					options:(NSDictionary *)options {
	if (!path.length)
		return;
	NSDictionary *content = @{
		@"@type" : @"inputMessageVideoNote",
		@"video_note" : @{@"@type" : @"inputVideoNote",
			@"video_note" : TGMCLocalFile(path),
			@"duration" : @(duration),
			@"length" : @(side > 0 ? side : 240)},
	};
	[self send:[self mc_sendRequestForChat:chatId
									thread:threadId
					   directMessagesTopic:directMessagesTopicId
								savedTopic:savedTopicId
								   content:content
								   replyTo:replyToId
								   options:options]];
}

- (void)sendAnimationAtPath:(NSString *)path
					 toChat:(int64_t)chatId
					 thread:(int64_t)threadId
		directMessagesTopic:(int64_t)directMessagesTopicId
				 savedTopic:(int64_t)savedTopicId
					replyTo:(int64_t)replyToId
					caption:(NSString *)caption
				   duration:(NSInteger)duration
					  width:(NSInteger)width
					 height:(NSInteger)height
					options:(NSDictionary *)options {
	if (!path.length)
		return;
	__weak TGClient *weakSelf = self;
	[self mc_parse:caption completion:^(NSDictionary *formatted) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf mc_send:@{
			@"@type" : @"inputMessageAnimation",
			@"animation" : @{@"@type" : @"inputAnimation",
				@"animation" : TGMCLocalFile(path),
				@"duration" : @(duration),
				@"width" : @(width),
				@"height" : @(height)},
			@"caption" : formatted,
		}
						 toChat:chatId
						 thread:threadId
			directMessagesTopic:directMessagesTopicId
					 savedTopic:savedTopicId
						replyTo:replyToId
						options:options
					 completion:nil];
	}];
}

- (void)sendAudioAtPath:(NSString *)path
				 toChat:(int64_t)chatId
				 thread:(int64_t)threadId
	directMessagesTopic:(int64_t)directMessagesTopicId
			 savedTopic:(int64_t)savedTopicId
				replyTo:(int64_t)replyToId
				  title:(NSString *)title
			  performer:(NSString *)performer
			   duration:(NSInteger)duration
				caption:(NSString *)caption
				options:(NSDictionary *)options {
	if (!path.length)
		return;
	__weak TGClient *weakSelf = self;
	[self mc_parse:caption completion:^(NSDictionary *formatted) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf mc_send:@{
			@"@type" : @"inputMessageAudio",
			@"audio" : @{@"@type" : @"inputAudio",
				@"audio" : TGMCLocalFile(path),
				@"duration" : @(duration),
				@"title" : title ?: @"",
				@"performer" : performer ?: @""},
			@"caption" : formatted,
		}
						 toChat:chatId
						 thread:threadId
			directMessagesTopic:directMessagesTopicId
					 savedTopic:savedTopicId
						replyTo:replyToId
						options:options
					 completion:nil];
	}];
}

- (void)sendDocumentAtPath:(NSString *)path
					toChat:(int64_t)chatId
					thread:(int64_t)threadId
	   directMessagesTopic:(int64_t)directMessagesTopicId
				savedTopic:(int64_t)savedTopicId
				   replyTo:(int64_t)replyToId
				   caption:(NSString *)caption
				   options:(NSDictionary *)options {
	if (!path.length)
		return;
	__weak TGClient *weakSelf = self;
	[self mc_parse:caption completion:^(NSDictionary *formatted) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf mc_send:@{
			@"@type" : @"inputMessageDocument",
			@"document" : @{@"@type" : @"inputDocument",
				@"document" : TGMCLocalFile(path),
				@"disable_content_type_detection" : @NO},
			@"caption" : formatted,
		}
						 toChat:chatId
						 thread:threadId
			directMessagesTopic:directMessagesTopicId
					 savedTopic:savedTopicId
						replyTo:replyToId
						options:options
					 completion:nil];
	}];
}

- (void)sendPhotoAlbumAtPaths:(NSArray *)paths
					   toChat:(int64_t)chatId
					   thread:(int64_t)threadId
		  directMessagesTopic:(int64_t)directMessagesTopicId
				   savedTopic:(int64_t)savedTopicId
					  replyTo:(int64_t)replyToId
					  caption:(NSString *)caption
					  spoiler:(BOOL)spoiler
		  selfDestructSeconds:(NSInteger)selfDestructSeconds
					  options:(NSDictionary *)options
				   completion:(void (^)(NSInteger))completion {
	NSArray *safePaths = TGMCArray(paths);
	if (!safePaths.count) {
		if (completion)
			completion(0);
		return;
	}
	__weak TGClient *weakSelf = self;
	[self mc_parse:caption completion:^(NSDictionary *formatted) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf) {
			if (completion)
				completion(0);
			return;
		}
		NSMutableArray *contents = [NSMutableArray array];
		for (id item in safePaths) {
			NSString *path = [item isKindOfClass:[NSString class]] ? item : nil;
			if (!path.length)
				continue;
			NSMutableDictionary *content = [@{
				@"@type" : @"inputMessagePhoto",
				@"photo" : @{@"@type" : @"inputPhoto",
					@"photo" : TGMCLocalFile(path)},
				@"caption" : (contents.count == 0 ? formatted : TGMCFormattedText(@"")),
				@"has_spoiler" : @(spoiler),
			} mutableCopy];
			NSDictionary *destruct = TGMCSelfDestruct(selfDestructSeconds);
			if (destruct)
				content[@"self_destruct_type"] = destruct;
			[contents addObject:content];
		}
		if (!contents.count) {
			if (completion)
				completion(0);
			return;
		}
		NSMutableDictionary *albumOptions = [(options ?: @{}) mutableCopy];
		if ([albumOptions[@"paidStarCount"] longLongValue] > 0)
			albumOptions[@"paidStarMessageCount"] = @(contents.count);
		NSMutableDictionary *request = [@{
			@"@type" : @"sendMessageAlbum",
			@"chat_id" : @(chatId),
			@"options" : TGMsgSendOptions(albumOptions),
			@"input_message_contents" : contents,
		} mutableCopy];
		NSDictionary *topic = TGTopicDictionary(threadId, directMessagesTopicId, savedTopicId,
			TGMCChatIsForum(strongSelf, chatId));
		if (topic)
			request[@"topic_id"] = topic;
		NSDictionary *replyTo = TGReplyToDictionary(replyToId, albumOptions[@"quoteText"],
			TGWireEntitiesFromFlattened(albumOptions[@"quoteEntities"]),
			[albumOptions[@"quotePosition"] integerValue]);
		if (replyTo)
			request[@"reply_to"] = replyTo;
		[strongSelf request:request completion:^(NSDictionary *result) {
			if (!completion)
				return;
			NSArray *messages = TGMCArray(result[@"messages"]);
			completion(TGResultIsError(result) ? 0 : (NSInteger)messages.count);
		}];
	}];
}

- (void)sendVenueWithTitle:(NSString *)title
				   address:(NSString *)address
				  latitude:(double)latitude
				 longitude:(double)longitude
					toChat:(int64_t)chatId
				   replyTo:(int64_t)replyToId
				   options:(NSDictionary *)options {
	[self mc_send:@{
		@"@type" : @"inputMessageVenue",
		@"venue" : @{
			@"@type" : @"venue",
			@"location" : @{@"@type" : @"location",
				@"latitude" : @(latitude),
				@"longitude" : @(longitude)},
			@"title" : title ?: @"",
			@"address" : address ?: @"",
			@"provider" : @"",
			@"id" : @"",
			@"type" : @"",
		},
	}
					 toChat:chatId
					 thread:0
		directMessagesTopic:0
				 savedTopic:0
					replyTo:replyToId
					options:options
				 completion:nil];
}

- (void)sendLiveLocationWithLatitude:(double)latitude
						   longitude:(double)longitude
							 heading:(NSInteger)heading
							accuracy:(double)accuracy
							  period:(NSInteger)period
							  toChat:(int64_t)chatId
							 replyTo:(int64_t)replyToId
						  completion:(void (^)(int64_t))completion {
	NSInteger safePeriod = period;
	if (safePeriod < 60)
		safePeriod = 60;
	if (safePeriod > 86400)
		safePeriod = 86400;
	[self mc_send:@{
		@"@type" : @"inputMessageLiveLocation",
		@"location" : @{
			@"@type" : @"liveLocation",
			@"location" : @{@"@type" : @"location",
				@"latitude" : @(latitude),
				@"longitude" : @(longitude),
				@"horizontal_accuracy" : @(accuracy)},
			@"live_period" : @(safePeriod),
			@"heading" : @(heading),
			@"proximity_alert_radius" : @0,
		},
	}
					 toChat:chatId
					 thread:0
		directMessagesTopic:0
				 savedTopic:0
					replyTo:replyToId
					options:nil
				 completion:completion];
}

- (void)updateLiveLocation:(int64_t)messageId
					inChat:(int64_t)chatId
				  latitude:(double)latitude
				 longitude:(double)longitude
				   heading:(NSInteger)heading
				  accuracy:(double)accuracy
				completion:(void (^)(BOOL ok, NSInteger errorCode))completion {
	[self request:@{
		@"@type" : @"editMessageLiveLocation",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"location" : @{
			@"@type" : @"liveLocation",
			@"location" : @{@"@type" : @"location",
				@"latitude" : @(latitude),
				@"longitude" : @(longitude),
				@"horizontal_accuracy" : @(accuracy)},
			@"heading" : @(heading),
			@"proximity_alert_radius" : @0,
		},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result), TGResultErrorCode(result));
	}];
}

- (void)stopLiveLocation:(int64_t)messageId
				   inChat:(int64_t)chatId
			   completion:(void (^)(BOOL ok, NSInteger errorCode))completion {
	[self request:@{
		@"@type" : @"editMessageLiveLocation",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"location" : [NSNull null],
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result), TGResultErrorCode(result));
	}];
}

- (void)sendDice:(NSString *)emoji
				 toChat:(int64_t)chatId
				 thread:(int64_t)threadId
	directMessagesTopic:(int64_t)directMessagesTopicId
			 savedTopic:(int64_t)savedTopicId {
	[self mc_send:@{
		@"@type" : @"inputMessageDice",
		@"emoji" : emoji.length ? emoji : @"\U0001F3B2",
		@"clear_draft" : @NO,
	}
					 toChat:chatId
					 thread:threadId
		directMessagesTopic:directMessagesTopicId
				 savedTopic:savedTopicId
					replyTo:0
					options:nil
				 completion:nil];
}

#pragma mark - polls

- (void)sendPollWithQuestion:(NSString *)question
					 options:(NSArray *)options
				   anonymous:(BOOL)anonymous
			 multipleAnswers:(BOOL)multipleAnswers
		   quizCorrectOption:(NSInteger)quizCorrectOption
			 quizExplanation:(NSString *)quizExplanation
					  toChat:(int64_t)chatId
					  thread:(int64_t)threadId
		 directMessagesTopic:(int64_t)directMessagesTopicId
				  savedTopic:(int64_t)savedTopicId
					 replyTo:(int64_t)replyToId
				 sendOptions:(NSDictionary *)sendOptions
				  completion:(void (^)(int64_t))completion {
	NSArray *safeOptions = TGMCArray(options);
	if (!question.length || safeOptions.count < 2) {
		if (completion)
			completion(0);
		return;
	}

	NSMutableArray *pollOptions = [NSMutableArray array];
	for (id item in safeOptions) {
		NSString *option = [item isKindOfClass:[NSString class]] ? item : nil;
		if (!option.length)
			continue;
		[pollOptions addObject:@{@"@type" : @"inputPollOption",
			@"text" : TGMCFormattedText(option)}];
	}
	if (pollOptions.count < 2) {
		if (completion)
			completion(0);
		return;
	}

	BOOL isQuiz = quizCorrectOption >= 0 &&
		quizCorrectOption < (NSInteger)pollOptions.count;
	NSString *explanation = [quizExplanation isKindOfClass:[NSString class]]
		? quizExplanation
		: @"";
	if (explanation.length > 200)
		explanation = TGSafeSubstringToIndex(explanation, 200);
	NSDictionary *type = isQuiz
		? @{@"@type" : @"inputPollTypeQuiz",
			  @"correct_option_ids" : @[ @(quizCorrectOption) ],
			  @"explanation" : TGMCFormattedText(explanation)}
		: @{@"@type" : @"inputPollTypeRegular", @"allow_adding_options" : @NO};

	[self mc_send:@{
		@"@type" : @"inputMessagePoll",
		@"question" : TGMCFormattedText(question),
		@"options" : pollOptions,
		@"is_anonymous" : @(anonymous),
		@"allows_multiple_answers" : @(!isQuiz && multipleAnswers),
		@"allows_revoting" : @(!isQuiz),
		@"type" : type,
		@"open_period" : @0,
		@"close_date" : @0,
		@"is_closed" : @NO,
	}
					 toChat:chatId
					 thread:threadId
		directMessagesTopic:directMessagesTopicId
				 savedTopic:savedTopicId
					replyTo:replyToId
					options:sendOptions
				 completion:completion];
}

- (void)stopPoll:(int64_t)messageId inChat:(int64_t)chatId {
	[self stopPoll:messageId inChat:chatId completion:nil];
}

- (void)stopPoll:(int64_t)messageId
		  inChat:(int64_t)chatId
	  completion:(void (^)(BOOL ok))completion {
	[self request:@{@"@type" : @"stopPoll",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)votersForPollOption:(NSInteger)optionIndex
				  ofMessage:(int64_t)messageId
					 inChat:(int64_t)chatId
					 offset:(NSInteger)offset
					  limit:(NSInteger)limit
				 completion:(void (^)(BOOL, NSArray *, NSInteger))completion {
	__weak TGClient *weakSelf = self;
	[self request:@{
		@"@type" : @"getPollVoters",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"option_id" : @(optionIndex),
		@"offset" : @(offset > 0 ? offset : 0),
		@"limit" : @(limit > 0 ? limit : 50),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, @[], 0);
			return;
		}
		TGClient *strongSelf = weakSelf;
		NSMutableArray *out = [NSMutableArray array];
		for (id item in TGMCArray(result[@"voters"])) {
			NSDictionary *voter = TGMCDict(item);
			NSDictionary *sender = TGMCDict(voter[@"voter_id"]);
			BOOL isChatVoter = [sender[@"@type"] isEqualToString:@"messageSenderChat"];
			int64_t senderId = isChatVoter
				? [TGMCNumber(sender[@"chat_id"]) longLongValue]
				: [TGMCNumber(sender[@"user_id"]) longLongValue];
			NSString *name = isChatVoter
				? [strongSelf titleForChatId:senderId]
				: [strongSelf nameForUserId:senderId];
			if (!name.length)
				name = TGL(@"Chat.UnknownVoter", @"Unknown");
			[out addObject:@{@"id" : @(senderId), @"name" : name}];
		}
		completion(YES, out, [TGMCNumber(result[@"total_count"]) integerValue]);
	}];
}

- (void)propertiesOfPollOption:(NSString *)optionId
					 ofMessage:(int64_t)messageId
						inChat:(int64_t)chatId
					completion:(void (^)(BOOL, BOOL, BOOL, BOOL))completion {
	if (!optionId.length) {
		if (completion)
			completion(NO, NO, NO, NO);
		return;
	}
	[self request:@{
		@"@type" : @"getPollOptionProperties",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"poll_option_id" : optionId,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, NO, NO, NO);
			return;
		}
		completion(YES,
			[result[@"can_be_replied"] boolValue],
			[result[@"can_be_replied_in_another_chat"] boolValue],
			[result[@"can_get_link"] boolValue]);
	}];
}

#pragma mark - links

- (void)linkForMessage:(int64_t)messageId
				inChat:(int64_t)chatId
		mediaTimestamp:(NSInteger)mediaTimestamp
			  forAlbum:(BOOL)forAlbum
			completion:(void (^)(NSString *))completion {
	[self request:@{
		@"@type" : @"getMessageLink",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"media_timestamp" : @(mediaTimestamp > 0 ? mediaTimestamp : 0),
		@"for_album" : @(forAlbum),
		@"in_message_thread" : @NO,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSString *link = TGMCString(result[@"link"]);
		completion((TGResultIsError(result) || !link.length) ? nil : link);
	}];
}

- (void)resolveMessageLink:(NSString *)url
				completion:(void (^)(NSDictionary *))completion {
	if (!url.length) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{@"@type" : @"getMessageLinkInfo", @"url" : url}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			NSDictionary *message = TGMCDict(result[@"message"]);
			completion(@{
				@"chatId" : TGMCNumber(result[@"chat_id"]),
				@"messageId" : TGMCNumber(message[@"id"]),
				@"mediaTimestamp" : TGMCNumber(result[@"media_timestamp"]),
			});
		}];
}

- (void)linkPreviewForText:(NSString *)text
				completion:(void (^)(NSDictionary *))completion {
	if (!text.length) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{
		@"@type" : @"getLinkPreview",
		@"text" : TGMCFormattedText(text),
		@"link_preview_options" : @{@"@type" : @"linkPreviewOptions",
			@"is_disabled" : @NO},
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSDictionary *type = TGMCDict(result[@"type"]);
		NSNumber *photoId = @0;
		NSDictionary *photo = TGMCDict(type[@"photo"]);
		NSArray *sizes = TGMCArray(photo[@"sizes"]);
		if (sizes.count)
			photoId = TGMCFileId(TGMCDict([sizes lastObject])[@"photo"]);
		completion(@{
			@"url" : TGMCString(result[@"url"]),
			@"siteName" : TGMCString(result[@"site_name"]),
			@"title" : TGMCString(result[@"title"]),
			@"description" : TGMCString(TGMCDict(result[@"description"])[@"text"]),
			@"kind" : TGMCString(type[@"@type"]),
			@"photoId" : photoId,
		});
	}];
}

#pragma mark - odds and ends

- (void)bankCardInfoForNumber:(NSString *)cardNumber
				   completion:(void (^)(NSString *title, NSArray *actions))completion {
	if (!cardNumber.length) {
		if (completion)
			completion(nil, nil);
		return;
	}
	[self request:@{
		@"@type" : @"getBankCardInfo",
		@"bank_card_number" : cardNumber,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, nil);
			return;
		}
		NSMutableArray *actions = [NSMutableArray array];
		for (id entry in TGMCArray(result[@"actions"])) {
			NSDictionary *action = TGMCDict(entry);
			NSString *text = TGMCString(action[@"text"]);
			NSString *url = TGMCString(action[@"url"]);
			if (text.length && url.length)
				[actions addObject:@{@"text" : text, @"url" : url}];
		}
		NSString *title = TGMCString(result[@"title"]);
		completion(title.length ? title : nil, actions);
	}];
}

- (void)translateMessage:(int64_t)messageId
				  inChat:(int64_t)chatId
			  toLanguage:(NSString *)languageCode
			  completion:(void (^)(NSString *))completion {
	[self request:@{
		@"@type" : @"translateMessageText",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"to_language_code" : languageCode.length ? languageCode : @"en",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSString *text = TGMCString(result[@"text"]);
		completion((TGResultIsError(result) || !text.length) ? nil : text);
	}];
}

- (void)mapThumbnailForLatitude:(double)latitude
					  longitude:(double)longitude
						   zoom:(NSInteger)zoom
						  width:(NSInteger)width
						 height:(NSInteger)height
						  scale:(NSInteger)scale
						 inChat:(int64_t)chatId
					 completion:(void (^)(long long))completion {
	[self request:@{
		@"@type" : @"getMapThumbnailFile",
		@"location" : @{@"@type" : @"location",
			@"latitude" : @(latitude),
			@"longitude" : @(longitude)},
		@"zoom" : @(zoom > 0 ? zoom : 16),
		@"width" : @(width > 0 ? width : 320),
		@"height" : @(height > 0 ? height : 160),
		@"scale" : @(scale > 0 ? scale : 1),
		@"chat_id" : @(chatId),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? 0 : [TGMCNumber(result[@"id"]) longLongValue]);
	}];
}

- (void)clickAnimatedEmojiInMessage:(int64_t)messageId
							 inChat:(int64_t)chatId
						 completion:(void (^)(long long, BOOL))completion {
	[self request:@{@"@type" : @"clickAnimatedEmojiMessage",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(0, NO);
				return;
			}
			BOOL isAnimated = [TGMCString(result[@"format"][@"@type"]) isEqualToString:@"stickerFormatTgs"];
			completion([TGMCFileId(result[@"sticker"]) longLongValue], isAnimated);
		}];
}

- (void)storyForMessage:(int64_t)messageId
				 inChat:(int64_t)chatId
			 completion:(void (^)(NSDictionary *))completion {
	__weak TGClient *weakSelf = self;
	[self request:@{@"@type" : @"getMessage",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId)}
		completion:^(NSDictionary *message) {
			TGClient *strongSelf = weakSelf;
			NSDictionary *content = TGMCDict(message[@"content"]);
			if (!strongSelf || TGResultIsError(message) ||
				![TGMCString(content[@"@type"]) isEqualToString:@"messageStory"]) {
				if (completion)
					completion(nil);
				return;
			}
			[strongSelf request:@{
				@"@type" : @"getStory",
				@"story_poster_chat_id" : TGMCNumber(content[@"story_poster_chat_id"]),
				@"story_id" : TGMCNumber(content[@"story_id"]),
				@"only_local" : @NO,
			} completion:^(NSDictionary *story) {
				if (!completion)
					return;
				if (TGResultIsError(story)) {
					completion(nil);
					return;
				}
				NSDictionary *storyContent = TGMCDict(story[@"content"]);
				NSString *kind = TGMCString(storyContent[@"@type"]);
				BOOL isVideo = [kind isEqualToString:@"storyContentVideo"];
				NSNumber *fileId = @0;
				NSNumber *thumbId = @0;
				if (isVideo) {
					NSDictionary *video = TGMCDict(storyContent[@"video"]);
					fileId = TGMCFileId(video[@"video"]);
					thumbId = TGMCThumbId(video);
				} else {
					NSArray *sizes = TGMCArray(TGMCDict(storyContent[@"photo"])[@"sizes"]);
					if (sizes.count) {
						fileId = TGMCFileId(TGMCDict([sizes lastObject])[@"photo"]);
						thumbId = TGMCFileId(TGMCDict([sizes firstObject])[@"photo"]);
					}
				}
				completion(@{
					@"caption" : TGMCString(TGMCDict(story[@"caption"])[@"text"]),
					@"date" : TGMCNumber(story[@"date"]),
					@"isVideo" : @(isVideo),
					@"fileId" : fileId,
					@"thumbId" : thumbId,
				});
			}];
		}];
}

@end

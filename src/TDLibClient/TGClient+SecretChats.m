#import "TGClient+ChatState.h"
#import "TGClient+Private.h"
#import "TGClient+SecretChats.h"
#import "TGFlattenSecretChats.h"
#import "TGLocalization.h"

NSString *const TGSecretChatStateDidChangeNotification = @"TGSecretChatStateDidChangeNotification";

static NSMutableDictionary *TGSecretChatIds(void) {
	static NSMutableDictionary *map = nil;
	if (!map)
		map = [[NSMutableDictionary alloc] init];
	return map;
}

static NSMutableDictionary *TGSecretChatUserIds(void) {
	static NSMutableDictionary *map = nil;
	if (!map)
		map = [[NSMutableDictionary alloc] init];
	return map;
}

static NSDictionary *TGScDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSString *TGScString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSNumber *TGScNumber(id value) {
	return [value isKindOfClass:NSNumber.class] ? value : @(0);
}

@implementation TGClient (SecretChats)

#pragma mark - internals

- (void)tgSecretRemember:(NSDictionary *)chat {
	NSDictionary *type = TGScDict(chat[@"type"]);
	NSNumber *chatId = TGScNumber(chat[@"id"]);
	if (!type || chatId.longLongValue == 0)
		return;
	if (![TGScString(type[@"@type"]) isEqualToString:@"chatTypeSecret"]) {
		TGSecretChatIds()[chatId] = @(0);
		return;
	}
	TGSecretChatIds()[chatId] = TGScNumber(type[@"secret_chat_id"]);
	TGSecretChatUserIds()[chatId] = TGScNumber(type[@"user_id"]);
}

- (void)tgSecretFetchChat:(int64_t)chatId completion:(void (^)(NSDictionary *chat))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			if (TGResultIsError(chat)) {
				if (completion)
					completion(nil);
				return;
			}
			[weakSelf tgSecretRemember:chat];
			if (completion)
				completion(chat);
		}];
}

- (NSDictionary *)tgSecretInfoFrom:(NSDictionary *)secretChat chatId:(int64_t)chatId {
	if (!TGScDict(secretChat))
		return nil;
	int64_t userId = [TGScNumber(secretChat[@"user_id"]) longLongValue];
	NSString *name = [self nameForUserId:userId] ?: @"";
	return @{
		@"secretChatId" : TGScNumber(secretChat[@"id"]),
		@"chatId" : @(chatId),
		@"userId" : @(userId),
		@"name" : name,
		@"state" : TGScStateName(secretChat),
		@"isOutbound" : @([secretChat[@"is_outbound"] boolValue]),
		@"layer" : TGScNumber(secretChat[@"layer"]),
		@"keyHash" : TGScString(secretChat[@"key_hash"]),
	};
}

#pragma mark - lifecycle

- (void)createSecretChatWithUser:(int64_t)userId
					  completion:(void (^)(NSDictionary *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"createNewSecretChat", @"user_id" : @(userId)}
		completion:^(NSDictionary *chat) {
			if (TGResultIsError(chat)) {
				if (completion)
					completion(nil);
				return;
			}
			TGClient *strongSelf = weakSelf;
			[strongSelf tgSecretRemember:chat];
			int64_t chatId = [TGScNumber(chat[@"id"]) longLongValue];
			int secretId = (int)[TGScNumber(TGScDict(chat[@"type"])[@"secret_chat_id"]) intValue];
			if (!completion)
				return;
			if (secretId == 0) {
				completion(nil);
				return;
			}
			[strongSelf request:@{@"@type" : @"getSecretChat",
				@"secret_chat_id" : @(secretId)}
				completion:^(NSDictionary *secret) {
					if (TGResultIsError(secret)) {
						completion(@{
							@"secretChatId" : @(secretId),
							@"chatId" : @(chatId),
							@"userId" : @(userId),
							@"name" : [strongSelf nameForUserId:userId] ?: @"",
							@"state" : @"pending",
							@"isOutbound" : @YES,
							@"layer" : @(0),
							@"keyHash" : @"",
						});
						return;
					}
					completion([strongSelf tgSecretInfoFrom:secret chatId:chatId]);
				}];
		}];
}

- (void)openSecretChatId:(int)secretChatId
			  completion:(void (^)(int64_t))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"createSecretChat", @"secret_chat_id" : @(secretChatId)}
		completion:^(NSDictionary *chat) {
			if (TGResultIsError(chat)) {
				if (completion)
					completion(0);
				return;
			}
			[weakSelf tgSecretRemember:chat];
			if (completion)
				completion([TGScNumber(chat[@"id"]) longLongValue]);
		}];
}

- (void)closeSecretChatId:(int)secretChatId completion:(void (^)(BOOL ok))completion {
	if (secretChatId == 0) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{@"@type" : @"closeSecretChat", @"secret_chat_id" : @(secretChatId)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)closeSecretChatForChat:(int64_t)chatId
				  deleteHistory:(BOOL)deleteHistory
					 completion:(void (^)(BOOL ok))completion {
	__weak typeof(self) weakSelf = self;
	void (^finish)(int) = ^(int secretId) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf) {
			if (completion)
				completion(NO);
			return;
		}
		[strongSelf closeSecretChatId:secretId
							completion:^(BOOL closedOk) {
			if (!closedOk) {
				if (completion)
					completion(NO);
				return;
			}
			if (!deleteHistory) {
				if (completion)
					completion(YES);
				return;
			}
			TGClient *innerSelf = weakSelf;
			if (!innerSelf) {
				if (completion)
					completion(NO);
				return;
			}
			[innerSelf request:@{
				@"@type" : @"deleteChatHistory",
				@"chat_id" : @(chatId),
				@"remove_from_chat_list" : @YES,
				@"revoke" : @YES,
			}
				completion:^(NSDictionary *result) {
					if (completion)
						completion(!TGResultIsError(result));
				}];
		}];
	};

	int known = [self secretChatIdForChat:chatId];
	if (known != 0) {
		finish(known);
		return;
	}
	[self tgSecretFetchChat:chatId completion:^(NSDictionary *chat) {
		finish((int)[TGScNumber(TGScDict(chat[@"type"])[@"secret_chat_id"]) intValue]);
	}];
}

#pragma mark - state

- (int)secretChatIdForChat:(int64_t)chatId {
	NSNumber *known = TGSecretChatIds()[@(chatId)];
	if (known)
		return [known intValue];
	[self tgSecretFetchChat:chatId completion:nil];
	return 0;
}

- (BOOL)isSecretChat:(int64_t)chatId {
	return [self secretChatIdForChat:chatId] != 0;
}

- (int64_t)secretChatUserIdForChat:(int64_t)chatId {
	NSNumber *known = TGSecretChatUserIds()[@(chatId)];
	if (known)
		return known.longLongValue;
	[self tgSecretFetchChat:chatId completion:nil];
	return 0;
}

- (void)secretChatInfoForChat:(int64_t)chatId
				   completion:(void (^)(NSDictionary *))completion {
	__weak typeof(self) weakSelf = self;
	void (^withSecretId)(int) = ^(int secretId) {
		TGClient *strongSelf = weakSelf;
		if (secretId == 0 || !strongSelf) {
			if (completion)
				completion(nil);
			return;
		}
		[strongSelf request:@{@"@type" : @"getSecretChat", @"secret_chat_id" : @(secretId)}
			completion:^(NSDictionary *secret) {
				if (!completion)
					return;
				if (TGResultIsError(secret)) {
					completion(nil);
					return;
				}
				completion([strongSelf tgSecretInfoFrom:secret chatId:chatId]);
			}];
	};

	NSNumber *known = TGSecretChatIds()[@(chatId)];
	if (known) {
		withSecretId([known intValue]);
		return;
	}
	[self tgSecretFetchChat:chatId completion:^(NSDictionary *chat) {
		withSecretId((int)[TGScNumber(TGScDict(chat[@"type"])[@"secret_chat_id"]) intValue]);
	}];
}

- (void)secretChatStatusForChat:(int64_t)chatId
					 completion:(void (^)(NSString *))completion {
	[self secretChatInfoForChat:chatId completion:^(NSDictionary *info) {
		if (!completion)
			return;
		if (!info) {
			completion(nil);
			return;
		}
		NSString *state = info[@"state"];
		if ([state isEqualToString:@"ready"]) {
			completion(nil);
			return;
		}
		if ([state isEqualToString:@"closed"]) {
			completion(TGL(@"DialogList.EncryptionRejected", @"Secret chat cancelled"));
			return;
		}
		NSString *name = [info[@"name"] length] ? info[@"name"]
			: TGL(@"Notification.UnknownUserListLowercase", @"someone");
		if ([info[@"isOutbound"] boolValue])
			completion([NSString stringWithFormat:
				TGL(@"DialogList.AwaitingEncryption", @"Waiting for %@ to get online..."), name]);
		else
			completion(TGL(@"DialogList.EncryptionProcessing", @"Exchanging encryption keys..."));
	}];
}

- (void)canSendInSecretChat:(int64_t)chatId
				 completion:(void (^)(BOOL, NSString *))completion {
	[self secretChatInfoForChat:chatId completion:^(NSDictionary *info) {
		if (!completion)
			return;
		if (!info) {
			completion(YES, @"");
			return;
		}
		NSString *state = info[@"state"];
		completion([state isEqualToString:@"ready"], state);
	}];
}

#pragma mark - encryption key

- (void)encryptionKeyGridForChat:(int64_t)chatId
					  completion:(void (^)(NSArray *))completion {
	[self encryptionKeyHashForChat:chatId completion:^(NSString *base64) {
		if (!completion)
			return;
		NSData *hash = TGScBase64Decode(base64);
		if (hash.length < 36) {
			completion(nil);
			return;
		}
		const unsigned char *bytes = hash.bytes;
		NSMutableArray *cells = [NSMutableArray arrayWithCapacity:144];
		for (NSInteger i = 0; i < 36; i++) {
			unsigned char byte = bytes[i];
			[cells addObject:@((byte >> 6) & 0x03)];
			[cells addObject:@((byte >> 4) & 0x03)];
			[cells addObject:@((byte >> 2) & 0x03)];
			[cells addObject:@(byte & 0x03)];
		}
		completion(cells);
	}];
}

- (void)encryptionKeyHashForChat:(int64_t)chatId
					  completion:(void (^)(NSString *))completion {
	[self secretChatInfoForChat:chatId completion:^(NSDictionary *info) {
		if (!completion)
			return;
		completion(info[@"keyHash"] ?: @"");
	}];
}

#pragma mark - capability gating

- (void)secretChat:(int64_t)chatId
	supportsFeature:(NSString *)feature
		 completion:(void (^)(BOOL))completion {
	[self secretChatInfoForChat:chatId completion:^(NSDictionary *info) {
		if (!completion)
			return;
		if (!info) {
			completion(NO);
			return;
		}
		NSInteger layer = [info[@"layer"] integerValue];
		NSInteger needed = 46;
		if ([feature isEqualToString:@"video_note"])
			needed = 66;
		else if ([feature isEqualToString:@"delete_for_both"])
			needed = 17;
		else if ([feature isEqualToString:@"sticker"])
			needed = 45;
		completion(layer >= needed && [info[@"state"] isEqualToString:@"ready"]);
	}];
}

- (BOOL)secretChat:(int64_t)chatId allowsInputMessage:(NSString *)kind {
	if (![self isSecretChat:chatId])
		return YES;
	if (![kind isKindOfClass:NSString.class])
		return YES;

	static NSSet *forbidden = nil;
	if (!forbidden) {
		forbidden = [[NSSet alloc] initWithObjects:
				@"inputMessagePoll",
			@"inputMessageChecklist",
			@"inputMessageForwarded",
			@"inputMessageStory",
			@"inputMessageReplyToExternalMessage",
			@"inputMessageInvoice",
			@"inputMessageGame",
			nil];
	}
	return ![forbidden containsObject:kind];
}

- (BOOL)chatAllowsMessageEditing:(int64_t)chatId {
	return ![self isSecretChat:chatId];
}

#pragma mark - self-destruct timer

- (void)autoDeleteTimeForChat:(int64_t)chatId
				   completion:(void (^)(NSInteger))completion {
	[self tgSecretFetchChat:chatId completion:^(NSDictionary *chat) {
		if (completion)
			completion([TGScNumber(chat[@"message_auto_delete_time"]) integerValue]);
	}];
}

+ (NSArray *)autoDeleteLadder {
	NSArray *values = @[ @(0), @(1), @(2), @(5), @(10), @(30),
		@(60), @(3600), @(86400), @(604800) ];
	NSMutableArray *out = [NSMutableArray arrayWithCapacity:values.count];
	for (NSNumber *value in values) {
		[out addObject:@{
			@"seconds" : value,
			@"title" : [self autoDeleteTitleForSeconds:[value integerValue]],
		}];
	}
	return out;
}

+ (NSString *)autoDeleteTitleForSeconds:(NSInteger)seconds {
	if (seconds <= 0)
		return TGL(@"Profile.MessageLifetimeForever", @"Off");
	if (seconds < 60) {
		return TGLPlural(@"MessageTimer.Seconds", seconds, @"%ld second", @"%ld seconds");
	}
	if (seconds < 3600) {
		NSInteger minutes = seconds / 60;
		return TGLPlural(@"MessageTimer.Minutes", minutes, @"%ld minute", @"%ld minutes");
	}
	if (seconds < 86400) {
		NSInteger hours = seconds / 3600;
		return TGLPlural(@"MessageTimer.Hours", hours, @"%ld hour", @"%ld hours");
	}
	if (seconds < 604800) {
		NSInteger days = seconds / 86400;
		return TGLPlural(@"MessageTimer.Days", days, @"%ld day", @"%ld days");
	}
	NSInteger weeks = seconds / 604800;
	return TGLPlural(@"MessageTimer.Weeks", weeks, @"%ld week", @"%ld weeks");
}

- (void)defaultAutoDeleteTimeWithCompletion:(void (^)(NSInteger, BOOL))completion {
	[self request:@{@"@type" : @"getDefaultMessageAutoDeleteTime"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(0, YES);
				return;
			}
			completion([TGScNumber(result[@"time"]) integerValue], NO);
		}];
}

- (void)setDefaultAutoDeleteTime:(NSInteger)seconds completion:(void (^)(BOOL ok))completion {
	[self request:@{
		@"@type" : @"setDefaultMessageAutoDeleteTime",
		@"message_auto_delete_time" : @{
			@"@type" : @"messageAutoDeleteTime",
			@"time" : @(seconds < 0 ? 0 : seconds),
		},
	}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

#pragma mark - sessions

- (void)setSession:(int64_t)sessionId canAcceptSecretChats:(BOOL)canAccept {
	[self send:@{
		@"@type" : @"toggleSessionCanAcceptSecretChats",
		@"session_id" : @(sessionId),
		@"can_accept_secret_chats" : @(canAccept),
	}];
}

#pragma mark - service messages

- (NSString *)secretServiceTextForMessage:(NSDictionary *)message {
	NSDictionary *msg = TGScDict(message);
	NSDictionary *content = TGScDict(msg[@"content"]);
	NSString *kind = TGScString(content[@"@type"]);

	int64_t senderId = 0;
	NSDictionary *sender = TGScDict(msg[@"sender_id"]);
	if ([TGScString(sender[@"@type"]) isEqualToString:@"messageSenderUser"])
		senderId = [TGScNumber(sender[@"user_id"]) longLongValue];

	if ([kind isEqualToString:@"messageScreenshotTaken"]) {
		NSString *who = [self nameForUserId:senderId];
		if ([msg[@"is_outgoing"] boolValue])
			return TGL(@"Notification.SecretChatMessageScreenshotSelf", @"You took a screenshot!");
		return [NSString stringWithFormat:
			TGL(@"Notification.SecretChatMessageScreenshot", @"%@ took a screenshot!"),
			who.length ? who : TGL(@"Premium.GiftedTitle.Someone", @"Someone")];
	}

	if ([kind isEqualToString:@"messageChatSetMessageAutoDeleteTime"]) {
		NSInteger seconds = [TGScNumber(content[@"message_auto_delete_time"]) integerValue];
		int64_t fromUser = [TGScNumber(content[@"from_user_id"]) longLongValue];
		NSString *duration = [[self class] autoDeleteTitleForSeconds:seconds];
		if ([msg[@"is_outgoing"] boolValue]) {
			if (seconds <= 0)
				return TGL(@"Notification.MessageLifetimeRemovedOutgoing",
					@"You disabled the self-destruct timer");
			return [NSString stringWithFormat:
				TGL(@"Notification.MessageLifetimeChangedOutgoing",
					@"You set the self-destruct timer to %1$@"), duration];
		}
		NSString *who = [self nameForUserId:fromUser ?: senderId];
		if (!who.length)
			who = TGL(@"Premium.GiftedTitle.Someone", @"Someone");
		if (seconds <= 0)
			return [NSString stringWithFormat:
				TGL(@"Notification.MessageLifetimeRemoved", @"%1$@ disabled the self-destruct timer"),
				who];
		return [NSString stringWithFormat:
			TGL(@"Notification.MessageLifetimeChanged", @"%1$@ set the self-destruct timer to %2$@"),
			who, duration];
	}

	return nil;
}

- (NSString *)textForSecretChatNotification:(NSDictionary *)notification {
	NSDictionary *note = TGScDict(notification);
	NSDictionary *type = TGScDict(note[@"type"]);
	if (![TGScString(type[@"@type"]) isEqualToString:@"notificationTypeNewSecretChat"])
		return nil;
	return [NSString stringWithFormat:TGL(@"PUSH_ENCRYPTION_REQUEST", @"New encryption request%1$@"), @""];
}

#pragma mark - account switch

- (void)resetSecretChatCachesForAccountSwitch {
	[TGSecretChatIds() removeAllObjects];
	[TGSecretChatUserIds() removeAllObjects];
}

@end

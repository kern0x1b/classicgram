#import "TGClient+ChatState.h"
#import "TGClient+Private.h"
#import "TGClient+Translation.h"
#import "TGLocalization.h"
#import "TGFlattenTranslation.h"
#import "TGFlattenMessage.h"

static NSString *TGTrString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSArray *TGTrArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : nil;
}

static NSDictionary *TGTrDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

@implementation TGClient (Translation)

#pragma mark - translating text

- (void)translateMessage:(int64_t)messageId
				  inChat:(int64_t)chatId
			  toLanguage:(NSString *)languageCode
					tone:(NSString *)tone
			  completion:(void (^)(NSString *, NSArray *, NSString *))completion {
	[self request:@{
		@"@type" : @"translateMessageText",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"to_language_code" : languageCode.length ? languageCode : @"en",
		@"tone" : tone ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, nil, TGResultErrorMessage(result));
			return;
		}
		NSString *text = TGTrString(result[@"text"]);
		NSArray *entities = TGFlattenEntities(result[@"entities"]);
		completion(text.length ? text : nil, entities, @"");
	}];
}

- (void)translateText:(NSString *)text
			 entities:(NSArray *)entities
		   toLanguage:(NSString *)languageCode
				 tone:(NSString *)tone
		   completion:(void (^)(NSString *, NSArray *, NSString *))completion {
	if (!text.length) {
		if (completion)
			completion(nil, nil, nil);
		return;
	}

	[self request:@{
		@"@type" : @"translateText",
		@"text" : TGTrFormattedText(text, entities),
		@"to_language_code" : languageCode.length ? languageCode : @"en",
		@"tone" : tone ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, nil, TGResultErrorMessage(result));
			return;
		}
		NSString *out = TGTrString(result[@"text"]);
		NSArray *outEntities = TGFlattenEntities(result[@"entities"]);
		completion(out.length ? out : nil, outEntities, @"");
	}];
}

- (void)setChat:(int64_t)chatId
	translatable:(BOOL)translatable
	  completion:(void (^)(BOOL ok))completion {
	[self request:@{
		@"@type" : @"toggleChatIsTranslatable",
		@"chat_id" : @(chatId),
		@"is_translatable" : @(translatable),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (BOOL)isChatTranslatable:(int64_t)chatId {
	return [self.chatsById[@(chatId)][@"isTranslatable"] boolValue];
}

#pragma mark - language packs

- (void)languagePacksWithCompletion:(void (^)(NSArray *, NSString *, BOOL))completion {
	if (!completion)
		return;

	__weak typeof(self) weakSelf = self;
	void (^answer)(NSArray *, BOOL) = ^(NSArray *packs, BOOL failed) {
		[weakSelf request:@{@"@type" : @"getOption",
			@"name" : @"language_pack_id"}
			   completion:^(NSDictionary *option) {
				   NSString *current = TGTrString(TGTrDict(option)[@"value"]);
				   if (!current.length)
					   current = @"en";
				   completion(packs ?: [NSArray array], current, failed);
			   }];
	};

	[self request:@{@"@type" : @"getLocalizationTargetInfo",
		@"only_local" : @NO}
		completion:^(NSDictionary *target) {
			NSArray *packs = TGTrPacks(target);
			if (packs.count) {
				answer(packs, NO);
				return;
			}
			BOOL remoteFailed = TGResultIsError(target);
			[weakSelf request:@{@"@type" : @"getLocalizationTargetInfo",
				@"only_local" : @YES}
				completion:^(NSDictionary *local) {
					NSArray *localPacks = TGTrPacks(local);
					answer(localPacks, localPacks.count ? NO : remoteFailed || TGResultIsError(local));
				}];
		}];
}

- (void)synchronizeLanguagePack:(NSString *)packId {
	if (!packId.length)
		return;
	[self send:@{@"@type" : @"synchronizeLanguagePack",
		@"language_pack_id" : packId}];
}

- (void)languagePackStrings:(NSString *)packId
					   keys:(NSArray *)keys
				 completion:(void (^)(NSDictionary *))completion {
	if (!completion)
		return;
	if (!packId.length) {
		completion([NSDictionary dictionary]);
		return;
	}

	NSMutableArray *wanted = [NSMutableArray array];
	for (id key in keys) {
		if ([key isKindOfClass:NSString.class])
			[wanted addObject:key];
	}

	[self request:@{@"@type" : @"getLanguagePackStrings",
		@"language_pack_id" : packId,
		@"keys" : wanted}
		completion:^(NSDictionary *result) {
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			NSMutableDictionary *out = [NSMutableDictionary dictionary];
			for (id item in TGTrArray(TGTrDict(result)[@"strings"])) {
				NSDictionary *entry = TGTrDict(item);
				NSString *key = TGTrString(entry[@"key"]);
				id value = TGTrStringValue(entry[@"value"]);
				if (key.length && value)
					[out setObject:value forKey:key];
			}
			completion(out);
		}];
}

- (void)deleteLanguagePack:(NSString *)packId
				completion:(void (^)(BOOL))completion {
	if (!packId.length) {
		if (completion)
			completion(NO);
		return;
	}

	[self request:@{@"@type" : @"deleteLanguagePack",
		@"language_pack_id" : packId}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)languagePackInfoForId:(NSString *)packId
				   completion:(void (^)(NSDictionary *))completion {
	if (!packId.length) {
		if (completion)
			completion(nil);
		return;
	}

	[self request:@{@"@type" : @"getLanguagePackInfo",
		@"language_pack_id" : packId}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(TGResultIsError(result) ? nil : TGTrPack(result));
		}];
}

- (void)addCustomServerLanguagePack:(NSString *)packId
						 completion:(void (^)(BOOL))completion {
	if (!packId.length) {
		if (completion)
			completion(NO);
		return;
	}

	[self request:@{@"@type" : @"addCustomServerLanguagePack",
		@"language_pack_id" : packId}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)applyLanguagePack:(NSString *)packId
				completion:(void (^)(BOOL success, BOOL packNotFound))completion {
	if (!packId.length) {
		if (completion)
			completion(NO, YES);
		return;
	}

	__weak typeof(self) weakSelf = self;
	[self addCustomServerLanguagePack:packId completion:^(BOOL ok) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			if (completion)
				completion(NO, YES);
			return;
		}
		[strongSelf setLanguage:packId];
		[strongSelf synchronizeLanguagePack:packId];
		[strongSelf languagePackInfoForId:packId completion:^(NSDictionary *info) {
			TGClient *innerSelf = weakSelf;
			if (!innerSelf)
				return;
			NSString *pluralCode = [info[@"pluralCode"] isKindOfClass:[NSString class]] ? info[@"pluralCode"] : packId;
			BOOL rtl = [info[@"rtl"] boolValue];
			[innerSelf languagePackStrings:packId keys:nil completion:^(NSDictionary *strings) {
				if (!strings) {
					if (completion)
						completion(NO, NO);
					return;
				}
				[[TGLocalization shared] installPackId:packId strings:strings pluralCode:pluralCode rtl:rtl];
				if (completion)
					completion(YES, NO);
			}];
		}];
	}];
}

#pragma mark - speech recognition

- (void)speechTranscriptForMessage:(int64_t)messageId
							inChat:(int64_t)chatId
						completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getMessage",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId)}
		completion:^(NSDictionary *message) {
			if (!completion)
				return;
			if (TGResultIsError(message)) {
				completion(nil);
				return;
			}
			NSDictionary *note = TGTrNoteOfMessage(message);
			completion(note ? TGTrTranscript(note[@"speech_recognition_result"]) : nil);
		}];
}

- (void)rateSpeechRecognitionForMessage:(int64_t)messageId
								 inChat:(int64_t)chatId
								   good:(BOOL)good {
	[self send:@{@"@type" : @"rateSpeechRecognition",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"is_good" : @(good)}];
}

@end

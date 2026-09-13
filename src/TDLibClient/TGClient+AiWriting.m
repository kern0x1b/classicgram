#import "TGClient+Private.h"
#import "TGClient+AiWriting.h"

NSString *const TGAiWritingStylesDidChangeNotification =
	@"TGAiWritingStylesDidChangeNotification";

static NSString *TGAiString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSString *TGAiErrorMessage(NSDictionary *result) {
	if (!TGResultIsError(result))
		return @"";
	return TGAiString(result[@"message"]);
}

static NSDictionary *TGAiFormattedText(NSString *text) {
	return @{@"@type" : @"formattedText",
		@"text" : text ?: @"",
		@"entities" : @[]};
}

@implementation TGClient (AiWriting)

#pragma mark - ai text composition

- (void)composeTextWithAi:(NSString *)text
	translateToLanguageCode:(NSString *)languageCode
				  styleName:(NSString *)styleName
				  addEmojis:(BOOL)addEmojis
				 completion:(void (^)(NSString *, NSString *))completion {
	if (!text.length) {
		if (completion)
			completion(nil, @"");
		return;
	}
	[self request:@{
		@"@type" : @"composeTextWithAi",
		@"text" : TGAiFormattedText(text),
		@"translate_to_language_code" : languageCode ?: @"",
		@"style_name" : styleName ?: @"",
		@"add_emojis" : @(addEmojis),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, TGAiErrorMessage(result));
			return;
		}
		NSString *out = TGAiString(result[@"text"]);
		completion(out.length ? out : nil, @"");
	}];
}

- (void)fixTextWithAi:(NSString *)text
		   completion:(void (^)(NSString *, NSString *))completion {
	if (!text.length) {
		if (completion)
			completion(nil, @"");
		return;
	}
	[self request:@{
		@"@type" : @"fixTextWithAi",
		@"text" : TGAiFormattedText(text),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, TGAiErrorMessage(result));
			return;
		}
		NSDictionary *fixed = [result[@"text"] isKindOfClass:NSDictionary.class]
			? result[@"text"]
			: nil;
		NSString *out = TGAiString(fixed[@"text"]);
		completion(out.length ? out : nil, @"");
	}];
}

- (void)summarizeMessage:(int64_t)messageId
					 inChat:(int64_t)chatId
	translateToLanguageCode:(NSString *)languageCode
					   tone:(NSString *)tone
				 completion:(void (^)(NSString *, NSString *))completion {
	[self request:@{
		@"@type" : @"summarizeMessage",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"translate_to_language_code" : languageCode ?: @"",
		@"tone" : tone ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, TGAiErrorMessage(result));
			return;
		}
		NSString *out = TGAiString(result[@"text"]);
		completion(out.length ? out : nil, @"");
	}];
}

#pragma mark - text composition styles ("tones")

- (NSArray *)cachedTextCompositionStyles {
	return self.textCompositionStyles ?: @[];
}

- (void)resetAiWritingCachesForAccountSwitch {
	self.textCompositionStyles = nil;
}

@end

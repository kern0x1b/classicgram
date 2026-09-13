#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGAiWritingStylesDidChangeNotification;

@interface TGClient (AiWriting)

#pragma mark - ai text composition

- (void)composeTextWithAi:(NSString *)text
	translateToLanguageCode:(NSString *)languageCode
				  styleName:(NSString *)styleName
				  addEmojis:(BOOL)addEmojis
				 completion:(void (^ _Nullable)(NSString *text, NSString *errorMessage))completion;

- (void)fixTextWithAi:(NSString *)text
		   completion:(void (^ _Nullable)(NSString *text, NSString *errorMessage))completion;

- (void)summarizeMessage:(int64_t)messageId
					 inChat:(int64_t)chatId
	translateToLanguageCode:(NSString *)languageCode
					   tone:(NSString *)tone
				 completion:(void (^ _Nullable)(NSString *text, NSString *errorMessage))completion;

#pragma mark - text composition styles ("tones")

- (NSArray *)cachedTextCompositionStyles;

- (void)resetAiWritingCachesForAccountSwitch;

@end

NS_ASSUME_NONNULL_END

#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (Translation)

#pragma mark - translating text

- (void)translateMessage:(int64_t)messageId
				  inChat:(int64_t)chatId
			  toLanguage:(NSString *)languageCode
					tone:(nullable NSString *)tone
			  completion:(void (^ _Nullable)(NSString *text, NSArray *entities, NSString *errorMessage))completion;

- (void)translateText:(NSString *)text
			 entities:(nullable NSArray *)entities
		   toLanguage:(NSString *)languageCode
				 tone:(nullable NSString *)tone
		   completion:(void (^ _Nullable)(NSString *text, NSArray *entities, NSString *errorMessage))completion;

- (void)setChat:(int64_t)chatId
	translatable:(BOOL)translatable
	  completion:(nullable void (^)(BOOL ok))completion;

- (BOOL)isChatTranslatable:(int64_t)chatId;

#pragma mark - language packs

- (void)languagePacksWithCompletion:(void (^ _Nullable)(NSArray *packs,
	NSString *current,
	BOOL failed))completion;

- (void)synchronizeLanguagePack:(NSString *)packId;

- (void)languagePackStrings:(NSString *)packId
					   keys:(NSArray * _Nullable)keys
				 completion:(void (^ _Nullable)(NSDictionary *strings))completion;

- (void)deleteLanguagePack:(NSString *)packId
				completion:(void (^ _Nullable)(BOOL deleted))completion;

- (void)languagePackInfoForId:(NSString *)packId
				   completion:(void (^ _Nullable)(NSDictionary *pack))completion;

- (void)addCustomServerLanguagePack:(NSString *)packId
						 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)applyLanguagePack:(NSString *)packId
				completion:(void (^ _Nullable)(BOOL success, BOOL packNotFound))completion;

#pragma mark - speech recognition

- (void)speechTranscriptForMessage:(int64_t)messageId
							inChat:(int64_t)chatId
						completion:(void (^ _Nullable)(NSDictionary *transcript))completion;

- (void)rateSpeechRecognitionForMessage:(int64_t)messageId
								 inChat:(int64_t)chatId
								   good:(BOOL)good;

@end

NS_ASSUME_NONNULL_END

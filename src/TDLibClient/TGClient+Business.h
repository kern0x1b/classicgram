#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (Business)

- (void)businessSettingsWithCompletion:(void (^ _Nullable)(NSDictionary *settings, BOOL failed))completion;

- (void)setBusinessGreetingMessage:(NSDictionary *)settings
						completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setBusinessAwayMessage:(NSDictionary *)settings
					completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setBusinessAddress:(NSString *)address
				  latitude:(double)latitude
				 longitude:(double)longitude
				  hasPoint:(BOOL)hasPoint
				completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setBusinessOpeningHoursTimeZoneId:(NSString *)timeZoneId
									 days:(NSArray *)days
							   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setBusinessStartPageTitle:(NSString *)title
						  message:(NSString *)message
						  sticker:(id)sticker
					   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)businessChatLinksWithCompletion:(void (^ _Nullable)(NSArray *links))completion;

- (void)businessChatLinkCountMaxWithCompletion:(void (^ _Nullable)(NSInteger maxCount))completion;

- (void)createBusinessChatLinkWithText:(NSString *)text
								 title:(NSString *)title
							completion:(void (^ _Nullable)(NSDictionary * _Nullable link, NSString * _Nullable errorMessage))completion;

- (void)editBusinessChatLink:(NSString *)link
						text:(NSString *)text
					entities:(nullable NSArray *)entities
					   title:(NSString *)title
				  completion:(void (^ _Nullable)(BOOL ok, NSString * _Nullable errorMessage))completion;

- (void)deleteBusinessChatLink:(NSString *)link
					completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)businessConnectedBotWithCompletion:(void (^ _Nullable)(NSDictionary *bot))completion;

- (void)setBusinessConnectedBotUserId:(int64_t)botUserId
						   recipients:(NSDictionary *)recipients
							   rights:(NSDictionary *)rights
						   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)deleteBusinessConnectedBotUserId:(int64_t)botUserId
							  completion:(void (^ _Nullable)(BOOL ok))completion;

@end

NS_ASSUME_NONNULL_END

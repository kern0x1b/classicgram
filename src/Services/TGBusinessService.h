#import <Foundation/Foundation.h>

@interface TGBusinessService : NSObject

+ (void)businessSettingsWithCompletion:(void (^)(NSDictionary *settings, BOOL failed))completion;

+ (void)setBusinessGreetingMessage:(NSDictionary *)settings
						completion:(void (^)(BOOL ok))completion;

+ (void)setBusinessAwayMessage:(NSDictionary *)settings
					completion:(void (^)(BOOL ok))completion;

+ (void)setBusinessAddress:(NSString *)address
				  latitude:(double)latitude
				 longitude:(double)longitude
				  hasPoint:(BOOL)hasPoint
				completion:(void (^)(BOOL ok))completion;

+ (void)setBusinessOpeningHoursTimeZoneId:(NSString *)timeZoneId
									 days:(NSArray *)days
							   completion:(void (^)(BOOL ok))completion;

+ (void)setBusinessStartPageTitle:(NSString *)title
						  message:(NSString *)message
						  sticker:(id)sticker
					   completion:(void (^)(BOOL ok))completion;

+ (void)businessChatLinksWithCompletion:(void (^)(NSArray *links))completion;

+ (void)businessChatLinkCountMaxWithCompletion:(void (^)(NSInteger maxCount))completion;

+ (void)createBusinessChatLinkWithText:(NSString *)text
								 title:(NSString *)title
							completion:(void (^)(NSDictionary *link, NSString *errorMessage))completion;

+ (void)editBusinessChatLink:(NSString *)link
						text:(NSString *)text
					entities:(NSArray *)entities
					   title:(NSString *)title
				  completion:(void (^)(BOOL ok, NSString *errorMessage))completion;

+ (void)deleteBusinessChatLink:(NSString *)link
					completion:(void (^)(BOOL ok))completion;

+ (void)businessConnectedBotWithCompletion:(void (^)(NSDictionary *bot))completion;

+ (void)setBusinessConnectedBotUserId:(int64_t)botUserId
						   recipients:(NSDictionary *)recipients
							   rights:(NSDictionary *)rights
						   completion:(void (^)(BOOL ok))completion;

+ (void)deleteBusinessConnectedBotUserId:(int64_t)botUserId
							  completion:(void (^)(BOOL ok))completion;

+ (void)loadQuickReplyShortcuts;

+ (NSArray *)quickReplyShortcuts;

@end

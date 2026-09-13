#import "TGBusinessService.h"
#import "TGClient+Business.h"
#import "TGClient+Messages.h"

@implementation TGBusinessService

+ (void)businessSettingsWithCompletion:(void (^)(NSDictionary *settings, BOOL failed))completion {
	[[TGClient shared] businessSettingsWithCompletion:completion];
}

+ (void)setBusinessGreetingMessage:(NSDictionary *)settings
						completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setBusinessGreetingMessage:settings completion:completion];
}

+ (void)setBusinessAwayMessage:(NSDictionary *)settings
					completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setBusinessAwayMessage:settings completion:completion];
}

+ (void)setBusinessAddress:(NSString *)address
				  latitude:(double)latitude
				 longitude:(double)longitude
				  hasPoint:(BOOL)hasPoint
				completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setBusinessAddress:address latitude:latitude longitude:longitude
								 hasPoint:hasPoint
							   completion:completion];
}

+ (void)setBusinessOpeningHoursTimeZoneId:(NSString *)timeZoneId
									 days:(NSArray *)days
							   completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setBusinessOpeningHoursTimeZoneId:timeZoneId days:days completion:completion];
}

+ (void)setBusinessStartPageTitle:(NSString *)title
						  message:(NSString *)message
						  sticker:(id)sticker
					   completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setBusinessStartPageTitle:title message:message sticker:sticker completion:completion];
}

+ (void)businessChatLinksWithCompletion:(void (^)(NSArray *links))completion {
	[[TGClient shared] businessChatLinksWithCompletion:completion];
}

+ (void)businessChatLinkCountMaxWithCompletion:(void (^)(NSInteger maxCount))completion {
	[[TGClient shared] businessChatLinkCountMaxWithCompletion:completion];
}

+ (void)createBusinessChatLinkWithText:(NSString *)text
								 title:(NSString *)title
							completion:(void (^)(NSDictionary *link, NSString *errorMessage))completion {
	[[TGClient shared] createBusinessChatLinkWithText:text title:title completion:completion];
}

+ (void)editBusinessChatLink:(NSString *)link
						text:(NSString *)text
					entities:(NSArray *)entities
					   title:(NSString *)title
				  completion:(void (^)(BOOL ok, NSString *errorMessage))completion {
	[[TGClient shared] editBusinessChatLink:link text:text entities:entities title:title completion:completion];
}

+ (void)deleteBusinessChatLink:(NSString *)link
					completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] deleteBusinessChatLink:link completion:completion];
}

+ (void)businessConnectedBotWithCompletion:(void (^)(NSDictionary *bot))completion {
	[[TGClient shared] businessConnectedBotWithCompletion:completion];
}

+ (void)setBusinessConnectedBotUserId:(int64_t)botUserId
						   recipients:(NSDictionary *)recipients
							   rights:(NSDictionary *)rights
						   completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setBusinessConnectedBotUserId:botUserId recipients:recipients
											  rights:rights
										  completion:completion];
}

+ (void)deleteBusinessConnectedBotUserId:(int64_t)botUserId
							  completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] deleteBusinessConnectedBotUserId:botUserId completion:completion];
}

+ (void)loadQuickReplyShortcuts {
	[[TGClient shared] loadQuickReplyShortcuts];
}

+ (NSArray *)quickReplyShortcuts {
	return [[TGClient shared] quickReplyShortcuts];
}

@end

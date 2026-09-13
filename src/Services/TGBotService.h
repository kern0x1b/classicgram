#import <Foundation/Foundation.h>

@interface TGBotService : NSObject

+ (void)botVerificationParametersForBotUserId:(int64_t)botUserId
									completion:(void (^)(NSDictionary *parameters))completion;

+ (void)resolveBotVerificationTargetForUsername:(NSString *)username
									  completion:(void (^)(BOOL found, BOOL isChat, int64_t targetId, NSString *displayName))completion;

+ (void)grantBotVerification:(int64_t)botUserId
				  toTargetId:(int64_t)targetId
				targetIsChat:(BOOL)targetIsChat
		   customDescription:(NSString *)customDescription
				  completion:(void (^)(BOOL ok))completion;

+ (void)revokeBotVerification:(int64_t)botUserId
				fromTargetId:(int64_t)targetId
				targetIsChat:(BOOL)targetIsChat
				   completion:(void (^)(BOOL ok))completion;

@end

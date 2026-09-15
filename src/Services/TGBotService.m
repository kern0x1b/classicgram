#import "TGBotService.h"
#import "TGClient+Bots.h"

@implementation TGBotService

+ (void)botVerificationParametersForBotUserId:(int64_t)botUserId
								   completion:(void (^)(NSDictionary *parameters))completion {
	[[TGClient shared] botVerificationParametersForBotUserId:botUserId completion:completion];
}

+ (void)resolveBotVerificationTargetForUsername:(NSString *)username
									  completion:(void (^)(BOOL found, BOOL isChat, int64_t targetId, NSString *displayName))completion {
	[[TGClient shared] resolveBotVerificationTargetForUsername:username completion:completion];
}

+ (void)grantBotVerification:(int64_t)botUserId
				  toTargetId:(int64_t)targetId
				targetIsChat:(BOOL)targetIsChat
		   customDescription:(NSString *)customDescription
				  completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] grantBotVerification:botUserId toTargetId:targetId
								targetIsChat:targetIsChat
						   customDescription:customDescription
								  completion:completion];
}

+ (void)revokeBotVerification:(int64_t)botUserId
				fromTargetId:(int64_t)targetId
				targetIsChat:(BOOL)targetIsChat
				   completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] revokeBotVerification:botUserId fromTargetId:targetId
								 targetIsChat:targetIsChat
								   completion:completion];
}

+ (void)botStartLinkInfo:(NSString *)link
			  completion:(void (^)(NSDictionary *info))completion {
	[[TGClient shared] botStartLinkInfo:link completion:completion];
}

+ (void)resolveBotForUsername:(NSString *)username
				   completion:(void (^)(int64_t botUserId))completion {
	[[TGClient shared] resolveBotVerificationTargetForUsername:username
												   completion:^(BOOL found, BOOL isChat,
													   int64_t targetId,
													   NSString *__unused displayName) {
													   if (!completion)
														   return;
													   completion(found && !isChat ? targetId : 0);
												   }];
}

+ (void)chatsAcceptingBots:(BOOL)channelsOnly
				completion:(void (^)(NSArray *chats))completion {
	[[TGClient shared] chatsAcceptingBots:channelsOnly completion:completion];
}

+ (void)addBot:(int64_t)botUserId
			toChat:(int64_t)chatId
	administratorRights:(NSDictionary *)rights
		 parameter:(NSString *)parameter
		completion:(void (^)(int64_t chatId, NSString *errorCode))completion {
	[[TGClient shared] addBot:botUserId
					   toChat:chatId
		  administratorRights:rights
					parameter:parameter
				   completion:completion];
}

@end

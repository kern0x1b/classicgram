#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (Bots)

#pragma mark - keyboards

- (NSArray *)inlineKeyboardRowsForMessage:(NSDictionary *)message;

- (NSDictionary *)replyKeyboardForMessage:(NSDictionary *)message;

- (void)shareUsers:(NSArray *)userIds
	 withBotButton:(NSInteger)buttonId
			inChat:(int64_t)chatId
		   message:(int64_t)messageId
		completion:(void (^ _Nullable)(BOOL ok, NSString *errorMessage))completion;

- (void)shareChat:(int64_t)sharedChatId
	withBotButton:(NSInteger)buttonId
		   inChat:(int64_t)chatId
		  message:(int64_t)messageId
	   completion:(void (^ _Nullable)(BOOL ok, NSString *errorMessage))completion;

#pragma mark - callback buttons

- (void)pressCallbackButton:(NSDictionary *)button
					 inChat:(int64_t)chatId
					message:(int64_t)messageId
				 completion:(void (^ _Nullable)(NSDictionary *_Nullable answer, NSString *_Nullable errorMessage))completion;

- (void)pressCallbackButton:(NSDictionary *)button
					 inChat:(int64_t)chatId
					message:(int64_t)messageId
				   password:(NSString * _Nullable)password
				 completion:(void (^ _Nullable)(NSDictionary *_Nullable answer, NSString *_Nullable errorMessage))completion;

#pragma mark - bot profile and commands

- (void)botInfoForUser:(int64_t)userId completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)botCommandsForUser:(int64_t)userId completion:(void (^ _Nullable)(NSArray *commands))completion;

- (void)botCommandsForUser:(int64_t)userId
			matchingPrefix:(NSString *)prefix
				completion:(void (^ _Nullable)(NSArray *commands))completion;

- (void)menuButtonForBot:(int64_t)userId completion:(void (^ _Nullable)(NSDictionary *button))completion;

- (void)botCommandsInGroup:(int64_t)chatId completion:(void (^ _Nullable)(NSArray *bots))completion;

#pragma mark - starting a bot

- (void)startBot:(int64_t)botUserId
		  inChat:(int64_t)chatId
	   parameter:(nullable NSString *)parameter
	  completion:(nullable void (^)(BOOL ok, NSString * _Nullable errorMessage))completion;

- (void)botStartLinkInfo:(NSString *)link completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)openBotStartLink:(NSString *)link
			   completion:(void (^ _Nullable)(int64_t chatId, NSString * _Nullable errorCode))completion;

- (void)resetBotStartLinksForAccountSwitch;

#pragma mark - write access

- (void)canBotSendMessages:(int64_t)botUserId completion:(void (^ _Nullable)(BOOL allowed))completion;

- (void)allowBotToSendMessages:(int64_t)botUserId completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - inline queries

- (void)inlineQueryToBot:(int64_t)botUserId
				  inChat:(int64_t)chatId
				   query:(NSString *)query
				  offset:(nullable NSString *)offset
			  completion:(void (^ _Nullable)(NSDictionary *results))completion;

- (void)sendInlineResult:(NSString *)resultId
				 queryId:(NSNumber *)queryId
				  toChat:(int64_t)chatId
				  thread:(int64_t)threadId
	 directMessagesTopic:(int64_t)directMessagesTopicId
			  savedTopic:(int64_t)savedTopicId
				 replyTo:(int64_t)replyToId
				 hideVia:(BOOL)hideVia;

- (void)recentInlineBotsWithCompletion:(void (^ _Nullable)(NSArray *bots, BOOL failed))completion;

#pragma mark - discovery

- (void)similarBotsFor:(int64_t)botUserId
			completion:(void (^ _Nullable)(NSArray *bots, NSInteger total))completion;

- (void)openSimilarBot:(int64_t)openedBotUserId fromBot:(int64_t)botUserId;

#pragma mark - message decoration

- (void)viaBotForMessage:(NSDictionary *)message
			  completion:(void (^ _Nullable)(NSString *username))completion;

- (NSString *)botServiceTextForMessage:(NSDictionary *)message;

#pragma mark - verification granting

- (void)botVerificationParametersForBotUserId:(int64_t)botUserId
								   completion:(void (^ _Nullable)(NSDictionary *parameters))completion;

- (void)resolveBotVerificationTargetForUsername:(NSString *)username
									  completion:(void (^ _Nullable)(BOOL found, BOOL isChat, int64_t targetId, NSString *displayName))completion;

- (void)grantBotVerification:(int64_t)botUserId
				  toTargetId:(int64_t)targetId
				  targetIsChat:(BOOL)targetIsChat
		   customDescription:(NSString *)customDescription
				  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)revokeBotVerification:(int64_t)botUserId
				fromTargetId:(int64_t)targetId
				targetIsChat:(BOOL)targetIsChat
				   completion:(void (^ _Nullable)(BOOL ok))completion;

@end

NS_ASSUME_NONNULL_END

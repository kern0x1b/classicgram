#import "TGClient+ChatManagement.h"
#import "TGReactionService.h"
#import "TGClient+Reactions.h"
#import "TGClient+Payments.h"
#import "TGClient+Premium.h"
#import "TGClient+SavedMessages.h"
#import "TGFlattenReactions.h"

@implementation TGReactionService

+ (BOOL)isPremiumAccount {
	return [[TGClient shared] isPremiumAccount];
}

+ (NSString *)savedMessagesTagLabelForEmoji:(NSString *)emoji inChat:(int64_t)chatId {
	if (!TGChatIsSavedMessages(chatId, [[TGClient shared] savedMessagesChatId]))
		return nil;
	return [[TGClient shared] cachedSavedMessagesTagLabelForEmoji:emoji customEmojiId:0];
}

+ (NSString *)quickReactionEmoji {
	return [[TGClient shared] quickReactionEmoji];
}

+ (void)setQuickReactionEmoji:(NSString *)emoji {
	[[TGClient shared] setQuickReactionEmoji:emoji];
}

+ (void)setQuickReactionEmoji:(NSString *)emoji completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setQuickReactionEmoji:emoji completion:completion];
}

+ (void)toggleReaction:(NSString *)emoji
			 onMessage:(int64_t)messageId
				inChat:(int64_t)chatId
				   big:(BOOL)big
			completion:(void (^)(BOOL nowChosen, BOOL succeeded))completion {
	[[TGClient shared] toggleReaction:emoji onMessage:messageId inChat:chatId big:big completion:completion];
}

+ (BOOL)isReactionInFlightForMessage:(int64_t)messageId
							   inChat:(int64_t)chatId
								emoji:(NSString *)emoji {
	return [[TGClient shared] isReactionInFlightForMessage:messageId inChat:chatId emoji:emoji];
}

+ (void)reactionIconPathForEmoji:(NSString *)emoji
					  completion:(void (^)(NSString *path))completion {
	[[TGClient shared] reactionIconPathForEmoji:emoji completion:completion];
}

+ (void)reactionIconPathForCustomEmojiId:(NSString *)customEmojiId
							  completion:(void (^)(NSString *path))completion {
	[[TGClient shared] reactionIconPathForCustomEmojiId:customEmojiId completion:completion];
}

+ (void)availableReactionsForMessage:(int64_t)messageId
							  inChat:(int64_t)chatId
						  completion:(void (^)(NSDictionary *info))completion {
	[[TGClient shared] availableReactionsForMessage:messageId inChat:chatId completion:completion];
}

+ (void)availableReactionsInChat:(int64_t)chatId
					  completion:(void (^)(NSArray *emojis, BOOL allowsAll, NSInteger maxCount,
									 BOOL hasAnyReactionsAllowed))completion {
	[[TGClient shared] availableReactionsInChat:chatId completion:completion];
}

+ (void)reactionUsageForMessage:(int64_t)messageId
						 inChat:(int64_t)chatId
					 completion:(void (^)(NSArray *chosenEmoji, NSArray *existingReactionTypes,
									NSInteger usedCount,
									NSInteger maxCount, BOOL canAddMore))completion {
	[[TGClient shared] reactionUsageForMessage:messageId inChat:chatId completion:completion];
}

+ (void)reactionPermissionsForMessage:(int64_t)messageId
							   inChat:(int64_t)chatId
						   completion:(void (^)(BOOL canDelete, BOOL canReport))completion {
	[[TGClient shared] reactionPermissionsForMessage:messageId inChat:chatId completion:completion];
}

+ (void)addedReactionsForMessage:(int64_t)messageId
						  inChat:(int64_t)chatId
						   emoji:(NSString *)emoji
						  offset:(NSString *)offset
						   limit:(NSInteger)limit
					  completion:(void (^)(NSArray *reactors, NSString *nextOffset,
									 NSInteger totalCount))completion {
	[[TGClient shared] addedReactionsForMessage:messageId inChat:chatId emoji:emoji offset:offset
										  limit:limit
									 completion:completion];
}

+ (NSArray *)resolvedReactorRows:(NSArray *)rows {
	return [TGClient resolvedChips:rows];
}

+ (id)addCustomEmojiResolvedObserver:(void (^)(void))handler {
	return [[NSNotificationCenter defaultCenter]
		addObserverForName:TGReactionCustomEmojiResolvedNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					if (handler)
						handler();
				}];
}

+ (void)deleteReactionsFromSender:(int64_t)senderId
						onMessage:(int64_t)messageId
						   inChat:(int64_t)chatId {
	[[TGClient shared] deleteReactionsFromSender:senderId onMessage:messageId inChat:chatId];
}

+ (void)deleteReactionsFromSender:(int64_t)senderId
						onMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
					   completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] deleteReactionsFromSender:senderId
										onMessage:messageId
										   inChat:chatId
									   completion:completion];
}

+ (void)deleteAllRecentReactionsFromSender:(int64_t)senderId
									inChat:(int64_t)chatId {
	[[TGClient shared] deleteAllRecentReactionsFromSender:senderId inChat:chatId];
}

+ (void)deleteAllRecentReactionsFromSender:(int64_t)senderId
									inChat:(int64_t)chatId
								 completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] deleteAllRecentReactionsFromSender:senderId
													inChat:chatId
												completion:completion];
}

+ (void)reportReactionsFromSender:(int64_t)senderId
						onMessage:(int64_t)messageId
						   inChat:(int64_t)chatId {
	[[TGClient shared] reportReactionsFromSender:senderId onMessage:messageId inChat:chatId];
}

+ (void)reportReactionsFromSender:(int64_t)senderId
						onMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
					   completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] reportReactionsFromSender:senderId
										onMessage:messageId
										   inChat:chatId
									   completion:completion];
}

+ (void)addPaidReactionToMessage:(int64_t)messageId
						  inChat:(int64_t)chatId
					   starCount:(long long)starCount
					   anonymous:(BOOL)anonymous
					  completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] addPaidReactionToMessage:messageId
										  inChat:chatId
									   starCount:starCount
									   anonymous:anonymous
									  completion:completion];
}

+ (void)commitPaidReactionsOnMessage:(int64_t)messageId
							   inChat:(int64_t)chatId
						   completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] commitPaidReactionsOnMessage:messageId inChat:chatId completion:completion];
}

+ (void)cancelPaidReactionsOnMessage:(int64_t)messageId inChat:(int64_t)chatId {
	[[TGClient shared] cancelPaidReactionsOnMessage:messageId inChat:chatId];
}

+ (BOOL)defaultPaidReactionIsAnonymous {
	return [[TGClient shared] defaultPaidReactionIsAnonymous];
}

+ (void)paidReactionSendersInChat:(int64_t)chatId
					   completion:(void (^)(NSArray *senders))completion {
	[[TGClient shared] paidReactionSendersInChat:chatId completion:completion];
}

+ (void)starBalanceWithCompletion:(void (^)(long long stars))completion {
	[[TGClient shared] starBalanceWithCompletion:completion];
}

@end

#import <Foundation/Foundation.h>

@interface TGReactionService : NSObject

+ (BOOL)isPremiumAccount;

+ (NSString *)savedMessagesTagLabelForEmoji:(NSString *)emoji inChat:(int64_t)chatId;

+ (NSString *)quickReactionEmoji;

+ (void)setQuickReactionEmoji:(NSString *)emoji;

+ (void)setQuickReactionEmoji:(NSString *)emoji completion:(void (^)(BOOL ok))completion;

+ (void)toggleReaction:(NSString *)emoji
			 onMessage:(int64_t)messageId
				inChat:(int64_t)chatId
				   big:(BOOL)big
			completion:(void (^)(BOOL nowChosen, BOOL succeeded))completion;

+ (BOOL)isReactionInFlightForMessage:(int64_t)messageId
							   inChat:(int64_t)chatId
								emoji:(NSString *)emoji;

+ (void)reactionIconPathForEmoji:(NSString *)emoji
					  completion:(void (^)(NSString *path))completion;

+ (void)reactionIconPathForCustomEmojiId:(NSString *)customEmojiId
							  completion:(void (^)(NSString *path))completion;

+ (void)availableReactionsForMessage:(int64_t)messageId
							  inChat:(int64_t)chatId
						  completion:(void (^)(NSDictionary *info))completion;

+ (void)availableReactionsInChat:(int64_t)chatId
					  completion:(void (^)(NSArray *emojis, BOOL allowsAll, NSInteger maxCount,
									 BOOL hasAnyReactionsAllowed))completion;

+ (void)reactionUsageForMessage:(int64_t)messageId
						 inChat:(int64_t)chatId
					 completion:(void (^)(NSArray *chosenEmoji, NSArray *existingReactionTypes,
									NSInteger usedCount,
									NSInteger maxCount, BOOL canAddMore))completion;

+ (void)reactionPermissionsForMessage:(int64_t)messageId
							   inChat:(int64_t)chatId
						   completion:(void (^)(BOOL canDelete, BOOL canReport))completion;

+ (void)addedReactionsForMessage:(int64_t)messageId
						  inChat:(int64_t)chatId
						   emoji:(NSString *)emoji
						  offset:(NSString *)offset
						   limit:(NSInteger)limit
					  completion:(void (^)(NSArray *reactors, NSString *nextOffset,
									 NSInteger totalCount))completion;

+ (void)paidReactorsForMessage:(int64_t)messageId
						inChat:(int64_t)chatId
					completion:(void (^)(NSArray *reactors))completion;

+ (NSArray *)resolvedReactorRows:(NSArray *)rows;

+ (id)addCustomEmojiResolvedObserver:(void (^)(void))handler;

+ (void)deleteReactionsFromSender:(int64_t)senderId
						onMessage:(int64_t)messageId
						   inChat:(int64_t)chatId;

+ (void)deleteReactionsFromSender:(int64_t)senderId
						onMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
					   completion:(void (^)(BOOL ok))completion;

+ (void)deleteAllRecentReactionsFromSender:(int64_t)senderId
									inChat:(int64_t)chatId;

+ (void)deleteAllRecentReactionsFromSender:(int64_t)senderId
									inChat:(int64_t)chatId
								 completion:(void (^)(BOOL ok))completion;

+ (void)reportReactionsFromSender:(int64_t)senderId
						onMessage:(int64_t)messageId
						   inChat:(int64_t)chatId;

+ (void)reportReactionsFromSender:(int64_t)senderId
						onMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
					   completion:(void (^)(BOOL ok))completion;

+ (void)addPaidReactionToMessage:(int64_t)messageId
						  inChat:(int64_t)chatId
					   starCount:(long long)starCount
					   anonymous:(BOOL)anonymous
					  completion:(void (^)(BOOL ok))completion;

+ (void)commitPaidReactionsOnMessage:(int64_t)messageId
							   inChat:(int64_t)chatId
						   completion:(void (^)(BOOL ok))completion;

+ (void)cancelPaidReactionsOnMessage:(int64_t)messageId inChat:(int64_t)chatId;

+ (BOOL)defaultPaidReactionIsAnonymous;

+ (void)paidReactionSendersInChat:(int64_t)chatId
					   completion:(void (^)(NSArray *senders))completion;

+ (void)starBalanceWithCompletion:(void (^)(long long stars))completion;

@end

#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (Reactions)

#pragma mark - sending

- (void)addReaction:(NSString *)emoji
		  toMessage:(int64_t)messageId
			 inChat:(int64_t)chatId
				big:(BOOL)big
		 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)removeReaction:(NSString *)emoji
		   fromMessage:(int64_t)messageId
				inChat:(int64_t)chatId
			completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)toggleReaction:(NSString *)emoji
			 onMessage:(int64_t)messageId
				inChat:(int64_t)chatId
				   big:(BOOL)big
			completion:(void (^ _Nullable)(BOOL nowChosen, BOOL succeeded))completion;

- (BOOL)isReactionInFlightForMessage:(int64_t)messageId
							   inChat:(int64_t)chatId
								emoji:(NSString *)emoji;

- (void)setReactions:(NSArray *)emojis
		   onMessage:(int64_t)messageId
			  inChat:(int64_t)chatId
				 big:(BOOL)big;

- (NSString *)quickReactionEmoji;

- (void)setQuickReactionEmoji:(NSString *)emoji;

- (void)setQuickReactionEmoji:(NSString *)emoji completion:(nullable void (^)(BOOL ok))completion;

- (void)applyServerDefaultReactionType:(NSDictionary *)reactionType;

- (void)clearRecentReactions;

#pragma mark - reading

+ (NSArray *)reactionChipsFromMessage:(NSDictionary *)message chatId:(int64_t)chatId;

+ (NSArray *)reactionChipsFromInteractionInfo:(NSDictionary *)info chatId:(int64_t)chatId;

+ (NSArray *)resolvedChips:(NSArray *)chips;

+ (NSString *)reactionSummaryFromChips:(NSArray *)chips;

extern NSString *const TGReactionCustomEmojiResolvedNotification;

- (void)reactionChipsForMessage:(int64_t)messageId
						 inChat:(int64_t)chatId
					 completion:(void (^ _Nullable)(NSArray *chips))completion;

- (void)availableReactionsForMessage:(int64_t)messageId
							  inChat:(int64_t)chatId
						  completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)addedReactionsForMessage:(int64_t)messageId
						  inChat:(int64_t)chatId
						   emoji:(NSString *)emoji
						  offset:(NSString *)offset
						   limit:(NSInteger)limit
					  completion:(void (^ _Nullable)(NSArray *reactors,
									 NSString *nextOffset,
									 NSInteger totalCount))completion;

- (void)emojiReactionInfo:(NSString *)emoji
			   completion:(void (^ _Nullable)(NSDictionary *info))completion;

+ (NSArray *)paidReactorsFromMessage:(NSDictionary *)message;

- (void)reactionUsageForMessage:(int64_t)messageId
						 inChat:(int64_t)chatId
					 completion:(void (^ _Nullable)(NSArray *chosenEmoji,
									NSArray *existingReactionTypes,
									NSInteger usedCount,
									NSInteger maxCount,
									BOOL canAddMore))completion;

- (void)reactionIconPathForEmoji:(NSString *)emoji
					  completion:(void (^ _Nullable)(NSString *path))completion;

- (void)reactionIconPathForCustomEmojiId:(NSString *)customEmojiId
					  completion:(void (^ _Nullable)(NSString *path))completion;

#pragma mark - live chip updates

- (void)watchReactionsForMessage:(int64_t)messageId
						  inChat:(int64_t)chatId
						onChange:(void (^)(NSArray *chips))onChange;

- (void)unwatchReactionsForMessage:(int64_t)messageId inChat:(int64_t)chatId;

- (void)unwatchAllReactions;

- (void)setReactionWatchInterval:(NSTimeInterval)seconds;

- (void)resetReactionCachesForAccountSwitch;

#pragma mark - unread reactions

- (void)unreadReactionsInChat:(int64_t)chatId
				fromMessageId:(int64_t)fromMessageId
						limit:(NSInteger)limit
				   completion:(void (^ _Nullable)(NSArray *messageIds))completion;

- (void)unreadReactionsInChat:(int64_t)chatId
					 threadId:(int64_t)threadId
		  directMessagesTopic:(int64_t)directMessagesTopicId
				   savedTopic:(int64_t)savedTopicId
				fromMessageId:(int64_t)fromMessageId
						limit:(NSInteger)limit
				   completion:(void (^ _Nullable)(NSArray *messageIds))completion;

- (void)markReactionsReadInChat:(int64_t)chatId;

- (void)markReactionsReadInChat:(int64_t)chatId forumTopicId:(int64_t)topicId;

#pragma mark - moderation

- (void)reactionPermissionsForMessage:(int64_t)messageId
							   inChat:(int64_t)chatId
						   completion:(void (^ _Nullable)(BOOL canDelete,
										  BOOL canReport))completion;

- (void)deleteReactionsFromSender:(int64_t)senderId
						onMessage:(int64_t)messageId
						   inChat:(int64_t)chatId;

- (void)deleteReactionsFromSender:(int64_t)senderId
						onMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
					   completion:(nullable void (^)(BOOL ok))completion;

- (void)deleteAllRecentReactionsFromSender:(int64_t)senderId
									inChat:(int64_t)chatId;

- (void)deleteAllRecentReactionsFromSender:(int64_t)senderId
									inChat:(int64_t)chatId
								 completion:(nullable void (^)(BOOL ok))completion;

- (void)reportReactionsFromSender:(int64_t)senderId
						onMessage:(int64_t)messageId
						   inChat:(int64_t)chatId;

- (void)reportReactionsFromSender:(int64_t)senderId
						onMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
					   completion:(nullable void (^)(BOOL ok))completion;

#pragma mark - chat settings

- (void)availableReactionsInChat:(int64_t)chatId
					  completion:(void (^ _Nullable)(NSArray *emojis,
									 BOOL allowsAll,
									 NSInteger maxCount,
									 BOOL hasAnyReactionsAllowed))completion;

- (void)setAvailableReactionsInChat:(int64_t)chatId
							 emojis:(NSArray *)emojis
						   maxCount:(NSInteger)maxCount;

#pragma mark - message effects

- (void)availableMessageEffectsWithCompletion:(void (^ _Nullable)(NSArray *effects))completion;

- (void)messageEffect:(int64_t)effectId
		   completion:(void (^ _Nullable)(NSDictionary *effect))completion;

@end

NS_ASSUME_NONNULL_END

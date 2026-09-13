#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGSavedMessagesTagsDidChangeNotification;
extern NSString *const TGSavedMessagesTagsTopicIdKey;

@interface TGClient (SavedMessages)

#pragma mark - topics list

- (void)loadSavedMessagesTopicsWithLimit:(NSInteger)limit
							  completion:(void (^ _Nullable)(NSArray *topics))completion;

- (NSArray *)cachedSavedMessagesTopics;

- (NSDictionary *)cachedSavedMessagesTopic:(int64_t)topicId;

- (NSInteger)savedMessagesTopicCount;

- (void)setSavedMessagesTopicsChangedHandler:(void (^ _Nullable)(void))handler;

- (void)resetSavedMessagesTopicsCache;

#pragma mark - topic history

- (void)savedMessagesTopic:(int64_t)topicId
			 messageAtDate:(NSInteger)date
				completion:(void (^ _Nullable)(NSDictionary *message))completion;

- (void)savedMessagesSparsePositionsForTopic:(int64_t)topicId
								 fromMessage:(int64_t)fromMessageId
									   limit:(NSInteger)limit
								  completion:(void (^ _Nullable)(NSArray *positions, NSInteger totalCount))completion;

#pragma mark - pinning topics

- (void)setSavedMessagesTopic:(int64_t)topicId
					   pinned:(BOOL)pinned
				   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setPinnedSavedMessagesTopics:(NSArray *)topicIds
						  completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - deleting

- (void)deleteSavedMessagesTopic:(int64_t)topicId
					  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)deleteSavedMessagesTopic:(int64_t)topicId
					messagesFrom:(NSInteger)minDate
							  to:(NSInteger)maxDate
					  completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - tags

- (void)setSavedMessagesTagLabel:(NSString *)label
						forEmoji:(NSString *)emoji
					  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setSavedMessagesTagLabel:(NSString *)label
				forCustomEmojiId:(long long)customEmojiId
					  completion:(void (^ _Nullable)(BOOL ok))completion;

- (nullable NSString *)cachedSavedMessagesTagLabelForEmoji:(nullable NSString *)emoji
											 customEmojiId:(int64_t)customEmojiId;

#pragma mark - pinned message inside Saved Messages

- (void)unpinAllMessagesInSavedTopic:(int64_t)topicId
						  completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - per-topic drafts

- (void)setSavedMessagesTopic:(int64_t)topicId
					draftText:(NSString *)text
				   completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - links

#pragma mark - tags

- (void)savedMessagesTagsForTopic:(int64_t)topicId
					   completion:(void (^ _Nullable)(NSArray *tags))completion;

- (void)searchSavedMessagesWithQuery:(NSString *)query
							tagEmoji:(NSString *)tagEmoji
					tagCustomEmojiId:(int64_t)tagCustomEmojiId
							 topicId:(int64_t)topicId
					   fromMessageId:(int64_t)fromMessageId
							   limit:(NSInteger)limit
						  completion:(void (^ _Nullable)(NSArray *messages, int64_t nextFromMessageId))completion;

#pragma mark - account switch

- (void)resetSavedMessagesCachesForAccountSwitch;

@end

NS_ASSUME_NONNULL_END

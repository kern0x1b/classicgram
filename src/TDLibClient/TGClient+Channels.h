#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (Channels)

#pragma mark - Signatures

- (void)channelSignaturesForChat:(int64_t)chatId
					  completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)setChannelSignaturesForChat:(int64_t)chatId
					   signMessages:(BOOL)sign
				 showAuthorProfiles:(BOOL)showAuthorProfiles
						 completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - Discussion group

- (void)discussionGroupForChannel:(int64_t)chatId
					   completion:(void (^ _Nullable)(NSNumber *linkedChatId))completion;

- (void)suitableDiscussionChatsWithCompletion:(void (^ _Nullable)(NSArray *chats))completion;

- (void)setDiscussionGroup:(int64_t)discussionChatId
				forChannel:(int64_t)chatId
				completion:(void (^ _Nullable)(BOOL ok, NSString *errorMessage))completion;

- (void)isAllHistoryAvailableForChat:(int64_t)chatId
						  completion:(void (^ _Nullable)(BOOL available))completion;

- (void)setAllHistoryAvailable:(BOOL)available
					   forChat:(int64_t)chatId
					completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - Statistics

- (void)canGetStatisticsForChat:(int64_t)chatId
					 completion:(void (^ _Nullable)(BOOL canGet))completion;

- (void)statisticsForChat:(int64_t)chatId
				   isDark:(BOOL)isDark
			   completion:(void (^ _Nullable)(NSDictionary *stats, NSString *errorMessage))completion;

- (void)statisticalGraphForChat:(int64_t)chatId
						  token:(NSString *)token
						zoomAtX:(int64_t)x
					 completion:(void (^ _Nullable)(NSDictionary *graph))completion;

- (void)statisticsForMessage:(int64_t)messageId
					  inChat:(int64_t)chatId
					  isDark:(BOOL)isDark
				  completion:(void (^ _Nullable)(NSArray *graphs))completion;

- (void)pollVoteStatisticsForMessage:(int64_t)messageId
							  inChat:(int64_t)chatId
							  isDark:(BOOL)isDark
						  completion:(void (^ _Nullable)(NSDictionary *graph))completion;

- (void)publicForwardsOfMessage:(int64_t)messageId
						 inChat:(int64_t)chatId
						 offset:(NSString *)offset
						  limit:(NSInteger)limit
					 completion:(void (^ _Nullable)(NSArray *forwards, NSString *nextOffset, NSInteger totalCount))completion;

#pragma mark - Boosts

- (void)boostStatusForChat:(int64_t)chatId
				completion:(void (^ _Nullable)(NSDictionary *status))completion;

- (void)channelBoostSlotsWithCompletion:(void (^ _Nullable)(NSArray *slots))completion;

- (void)boostChat:(int64_t)chatId
	  withSlotIds:(NSArray *)slotIds
	   completion:(void (^ _Nullable)(NSArray *slots))completion;

- (void)boostLinkForChat:(int64_t)chatId
			  completion:(void (^ _Nullable)(NSString *link, BOOL isPublic))completion;

- (void)resolveBoostLink:(NSString *)url
			  completion:(void (^ _Nullable)(NSNumber *chatId, BOOL isPublic))completion;

- (void)isChannelChat:(int64_t)chatId completion:(void (^ _Nullable)(BOOL isChannel))completion;

- (void)boostsForChat:(int64_t)chatId
		onlyGiftCodes:(BOOL)onlyGiftCodes
			   offset:(NSString *)offset
				limit:(NSInteger)limit
		   completion:(void (^ _Nullable)(NSArray *boosts, NSString *nextOffset, NSInteger totalCount))completion;

- (void)boostsByUser:(int64_t)userId
			  inChat:(int64_t)chatId
		  completion:(void (^ _Nullable)(NSArray *boosts))completion;

- (void)boostLevelFeaturesForChannel:(BOOL)isChannel
							   level:(NSInteger)level
						  completion:(void (^ _Nullable)(NSDictionary *features))completion;

- (void)boostLevelFeatureTableForChannel:(BOOL)isChannel
							  completion:(void (^ _Nullable)(NSArray *levels, NSDictionary *minimums))completion;

#pragma mark - similar channels

- (void)similarChatsForChat:(int64_t)chatId
				 completion:(void (^ _Nullable)(NSArray *chats, NSInteger totalCount))completion;

- (void)openSimilarChat:(int64_t)openedChatId fromChat:(int64_t)chatId;

@end

NS_ASSUME_NONNULL_END

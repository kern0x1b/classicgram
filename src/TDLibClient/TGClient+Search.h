#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (Search)

#pragma mark - global message search

- (void)searchMessagesWithQuery:(NSString *)query
						 filter:(NSString *)filter
					   chatType:(NSString * _Nullable)chatType
						minDate:(NSInteger)minDate
						maxDate:(NSInteger)maxDate
					archiveOnly:(BOOL)archiveOnly
						 offset:(NSString *)offset
						  limit:(NSInteger)limit
					 completion:(void (^ _Nullable)(NSArray *messages, NSString *nextOffset))completion;

- (void)searchMessagesWithQuery:(NSString *)query
						 filter:(NSString *)filter
						 offset:(NSString *)offset
					 completion:(void (^ _Nullable)(NSArray *messages, NSString *nextOffset))completion;

#pragma mark - in-chat message search

- (void)searchMessagesInChat:(int64_t)chatId
					   query:(NSString *)query
				senderUserId:(int64_t)senderUserId
					  filter:(NSString *)filter
			   fromMessageId:(int64_t)fromMessageId
					   limit:(NSInteger)limit
				  completion:(void (^ _Nullable)(NSArray *messages, int64_t nextFromMessageId, NSInteger totalCount))completion;

- (void)searchMessagesInChat:(int64_t)chatId
					   query:(NSString *)query
				senderUserId:(int64_t)senderUserId
					  filter:(NSString *)filter
					threadId:(int64_t)threadId
		 directMessagesTopic:(int64_t)directMessagesTopicId
				  savedTopic:(int64_t)savedTopicId
			   fromMessageId:(int64_t)fromMessageId
					   limit:(NSInteger)limit
				  completion:(void (^ _Nullable)(NSArray *messages, int64_t nextFromMessageId, NSInteger totalCount))completion;

- (void)searchSecretMessagesInChat:(int64_t)chatId
							  query:(NSString *)query
							 filter:(NSString *)filter
							 offset:(NSString *)offset
							  limit:(NSInteger)limit
						 completion:(void (^ _Nullable)(NSArray *messages, NSString *nextOffset, NSInteger totalCount))completion;

- (void)recentLocationMessagesInChat:(int64_t)chatId
							   limit:(NSInteger)limit
						  completion:(void (^ _Nullable)(NSArray *messages))completion;

#pragma mark - special message searches

- (void)searchPublicMessagesWithTag:(NSString *)tag
							 offset:(NSString *)offset
							  limit:(NSInteger)limit
						 completion:(void (^ _Nullable)(NSArray *messages, NSString *nextOffset))completion;

#pragma mark - global public-post search

- (void)publicPostSearchLimitsForQuery:(NSString *)query
							completion:(void (^ _Nullable)(NSDictionary *limits))completion;

- (void)searchPublicPostsWithQuery:(NSString *)query
							offset:(NSString *)offset
						 starCount:(NSInteger)starCount
							 limit:(NSInteger)limit
						completion:(void (^ _Nullable)(NSArray *messages, NSString *nextOffset,
									   NSDictionary *limits, BOOL limitsExceeded,
									   NSString *error))completion;

#pragma mark - hashtags

- (void)searchHashtagsWithPrefix:(NSString *)prefix
						   limit:(NSInteger)limit
					  completion:(void (^ _Nullable)(NSArray *hashtags))completion;

- (void)searchedForTagsWithPrefix:(NSString *)prefix
							limit:(NSInteger)limit
					   completion:(void (^ _Nullable)(NSArray *hashtags))completion;

- (void)removeSearchedForTag:(NSString *)tag;

- (void)clearSearchedForTagsIncludingCashtags:(BOOL)cashtags;

#pragma mark - public chats

- (void)searchPublicChatsWithQuery:(NSString *)query
							  type:(NSString * _Nullable)type
						completion:(void (^ _Nullable)(NSArray *chats))completion;

- (void)searchPublicChatsWithQuery:(NSString *)query
						completion:(void (^ _Nullable)(NSArray *chats))completion;

- (void)searchChatsOnServerWithQuery:(NSString *)query
							   limit:(NSInteger)limit
						  completion:(void (^ _Nullable)(NSArray *chats))completion;

- (void)publicChatWithUsername:(NSString *)username
					completion:(void (^ _Nullable)(NSDictionary *chat))completion;

- (void)chatAffiliateProgramWithUsername:(NSString *)username
								referrer:(NSString *)referrer
							  completion:(void (^ _Nullable)(NSDictionary *chat))completion;

- (void)chatSummaryForChatId:(int64_t)chatId
				  completion:(void (^ _Nullable)(NSDictionary *chat))completion;

#pragma mark - recents

- (void)recentlyFoundChatsWithQuery:(NSString *)query
							  limit:(NSInteger)limit
						 completion:(void (^ _Nullable)(NSArray *chats))completion;

#pragma mark - jumping around a history

- (void)messageInChat:(int64_t)chatId
		closestToDate:(NSInteger)date
		   completion:(void (^ _Nullable)(int64_t messageId))completion;

- (void)lastMessageInChat:(int64_t)chatId
			  noLaterThan:(NSInteger)date
			   completion:(void (^ _Nullable)(int64_t messageId, NSInteger messageDate))completion;

- (void)messageCalendarForChat:(int64_t)chatId
						filter:(NSString *)filter
				 fromMessageId:(int64_t)fromMessageId
					completion:(void (^ _Nullable)(NSArray *days, NSInteger totalCount))completion;

- (void)sparseMessagePositionsInChat:(int64_t)chatId
							  filter:(NSString *)filter
					   fromMessageId:(int64_t)fromMessageId
							   limit:(NSInteger)limit
						  completion:(void (^ _Nullable)(NSArray *positions, NSInteger totalCount))completion;

#pragma mark - text helpers

- (void)indexesOfStrings:(NSArray *)strings
		  matchingPrefix:(NSString *)query
				   limit:(NSInteger)limit
			  completion:(void (^ _Nullable)(NSArray *indexes))completion;

- (void)positionOfQuote:(NSString *)quote
				 inText:(NSString *)text
			 completion:(void (^ _Nullable)(NSInteger position))completion;

- (void)sharedMediaInChat:(int64_t)chatId
				  topicId:(int64_t)topicId
					query:(NSString *)query
			   filterName:(NSString *)filterName
			fromMessageId:(int64_t)fromMessageId
					limit:(NSInteger)limit
			   completion:(void (^ _Nullable)(NSDictionary *page, int64_t nextFromMessageId))completion;

- (void)rawMessageWithId:(int64_t)messageId
				  inChat:(int64_t)chatId
			  completion:(void (^ _Nullable)(NSDictionary *rawMessage))completion;

@end

NS_ASSUME_NONNULL_END

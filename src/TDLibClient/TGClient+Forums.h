#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (Forums)

#pragma mark - listing

- (void)forumTopicsForChat:(int64_t)chatId
					 query:(nullable NSString *)query
				offsetDate:(NSInteger)offsetDate
		   offsetMessageId:(int64_t)offsetMessageId
			 offsetTopicId:(int32_t)offsetTopicId
					 limit:(NSInteger)limit
				completion:(void (^ _Nullable)(NSArray *topics, NSDictionary *nextOffset, NSInteger totalCount))completion;

- (void)forumTopicRowsForChat:(int64_t)chatId
				   completion:(void (^ _Nullable)(NSArray *topics))completion;

- (void)searchForumTopicsInChat:(int64_t)chatId
						  query:(NSString *)query
					 completion:(void (^ _Nullable)(NSArray *topics))completion;

- (void)forumTopic:(int32_t)topicId
			inChat:(int64_t)chatId
		completion:(void (^ _Nullable)(NSDictionary *topic))completion;

- (void)forumTopicHistoryForChat:(int64_t)chatId
						   topic:(int32_t)topicId
					 fromMessage:(int64_t)fromMessageId
						   limit:(NSInteger)limit
					  completion:(void (^ _Nullable)(NSArray *messages))completion;

#pragma mark - create and edit

- (NSArray *)forumTopicIconColors;

- (void)createForumTopicInChat:(int64_t)chatId
						  name:(NSString *)name
					 iconColor:(NSInteger)iconColor
				   iconEmojiId:(int64_t)iconEmojiId
					completion:(void (^ _Nullable)(NSDictionary *topic))completion;

- (void)editForumTopicInChat:(int64_t)chatId
					   topic:(int32_t)topicId
						name:(NSString *)name
				  changeIcon:(BOOL)changeIcon
				 iconEmojiId:(int64_t)iconEmojiId
				  completion:(void (^ _Nullable)(BOOL success))completion;

- (void)setForumTopicInChat:(int64_t)chatId
					  topic:(int32_t)topicId
					 closed:(BOOL)closed
				 completion:(void (^ _Nullable)(BOOL success))completion;

- (void)setGeneralForumTopicInChat:(int64_t)chatId
							hidden:(BOOL)hidden
						completion:(void (^ _Nullable)(BOOL success))completion;

- (void)setForumTopicInChat:(int64_t)chatId
					  topic:(int32_t)topicId
					 pinned:(BOOL)pinned
				 completion:(void (^ _Nullable)(BOOL success))completion;

- (void)setPinnedForumTopicsInChat:(int64_t)chatId
						  topicIds:(NSArray *)topicIds
						completion:(void (^ _Nullable)(BOOL success))completion;

- (void)deleteForumTopicInChat:(int64_t)chatId
						 topic:(int32_t)topicId
					completion:(void (^ _Nullable)(BOOL success))completion;

#pragma mark - per-topic housekeeping

- (void)setForumTopicInChat:(int64_t)chatId
					  topic:(int32_t)topicId
				   mutedFor:(NSInteger)seconds
				 completion:(void (^ _Nullable)(BOOL success))completion;

- (void)markForumTopicReadInChat:(int64_t)chatId
						   topic:(int32_t)topicId
					  completion:(nullable void (^)(BOOL success))completion;

- (void)unpinAllMessagesInForumTopicInChat:(int64_t)chatId
									 topic:(int32_t)topicId
								completion:(void (^ _Nullable)(BOOL success))completion;

- (void)forumTopicLinkInChat:(int64_t)chatId
					   topic:(int32_t)topicId
				  completion:(void (^ _Nullable)(NSString *link))completion;

#pragma mark - icons

- (void)forumTopicDefaultIconsWithCompletion:(void (^ _Nullable)(NSArray *icons))completion;

#pragma mark - notification gating

- (BOOL)isForumTopicMuted:(int32_t)topicId inChat:(int64_t)chatId;

- (void)cacheForumTopicNotificationSettingsForChat:(int64_t)chatId
											  topic:(int32_t)topicId
										 useDefault:(BOOL)useDefault
											muteFor:(long long)muteFor;

#pragma mark - forum mode

- (void)setSupergroup:(int64_t)supergroupId
			  isForum:(BOOL)isForum
			  hasTabs:(BOOL)hasTabs
		   completion:(void (^ _Nullable)(BOOL success))completion;

- (void)setChat:(int64_t)chatId
	viewAsTopics:(BOOL)viewAsTopics
	  completion:(void (^ _Nullable)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END

#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGDirectMessagesChatTopicsUpdatedNotification;

@interface TGClient (DirectMessages)

#pragma mark - channel owner setting

- (void)setChat:(int64_t)chatId
	directMessagesGroupEnabled:(BOOL)enabled
					 starCount:(NSInteger)starCount
					completion:(void (^ _Nullable)(BOOL success))completion;

#pragma mark - topics

- (void)directMessagesTopicsForChat:(int64_t)chatId
						 completion:(void (^ _Nullable)(NSArray *topics))completion;

- (NSArray *)cachedDirectMessagesTopicsForChat:(int64_t)chatId;

- (void)directMessagesTopic:(int64_t)topicId
					 inChat:(int64_t)chatId
				 completion:(void (^ _Nullable)(NSDictionary *topic))completion;

- (void)setDirectMessagesTopicInChat:(int64_t)chatId
							   topic:(int64_t)topicId
					  markedAsUnread:(BOOL)markedAsUnread
						  completion:(void (^ _Nullable)(BOOL success))completion;

- (void)toggleDirectMessagesTopicInChat:(int64_t)chatId
								  topic:(int64_t)topicId
				  canSendUnpaidMessages:(BOOL)canSendUnpaid
						 refundPayments:(BOOL)refundPayments
							 completion:(void (^ _Nullable)(BOOL success))completion;

#pragma mark - sending inside a topic

- (void)sendText:(NSString *)text
				 toChat:(int64_t)chatId
	directMessagesTopic:(int64_t)topicId
				replyTo:(int64_t)replyToId
			  quoteText:(NSString *)quoteText
		  quotePosition:(NSInteger)quotePosition
				options:(NSDictionary *)options
			 completion:(void (^ _Nullable)(NSDictionary *message))completion;

#pragma mark - live updates

- (void)handleDirectMessagesTopicUpdate:(NSDictionary *)obj;

#pragma mark - account switch

- (void)resetDirectMessagesCachesForAccountSwitch;

@end

NS_ASSUME_NONNULL_END

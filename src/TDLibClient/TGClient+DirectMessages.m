#import "TGClient+DirectMessages.h"
#import "TGTDLibInt64.h"
#import "TGMessageReply.h"
#import "TGMessageTopic.h"
#import "TGClient+Messages.h"
#import "TGClient+Private.h"
#import "TGFlattenDirectMessages.h"
#import "TGFlattenMessages.h"

static BOOL TGDMFailed(NSDictionary *result) {
	return ![result isKindOfClass:NSDictionary.class] ||
		[result[@"@type"] isEqualToString:@"error"];
}

static NSDictionary *TGDMDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static int64_t TGDMInt64(id value) {
	return TGTDLibInt64(value);
}

static NSMutableDictionary *TGDMTopicsStore(void) {
	static NSMutableDictionary *store = nil;
	if (!store)
		store = [[NSMutableDictionary alloc] init];
	return store;
}

@implementation TGClient (DirectMessages)

#pragma mark - channel owner setting

- (void)setChat:(int64_t)chatId
	directMessagesGroupEnabled:(BOOL)enabled
					 starCount:(NSInteger)starCount
					completion:(void (^)(BOOL success))completion {
	[self request:@{
		@"@type" : @"setChatDirectMessagesGroup",
		@"chat_id" : @(chatId),
		@"is_enabled" : @(enabled),
		@"paid_message_star_count" : @(starCount),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGDMFailed(result));
	}];
}

#pragma mark - topics

- (void)directMessagesTopicsForChat:(int64_t)chatId
						 completion:(void (^)(NSArray *topics))completion {
	[self request:@{
		@"@type" : @"loadDirectMessagesChatTopics",
		@"chat_id" : @(chatId),
		@"limit" : @(100),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion([self cachedDirectMessagesTopicsForChat:chatId]);
	}];
}

- (NSArray *)cachedDirectMessagesTopicsForChat:(int64_t)chatId {
	NSDictionary *byTopic = TGDMTopicsStore()[@(chatId)];
	if (![byTopic isKindOfClass:NSDictionary.class])
		return @[];
	NSArray *topics = [byTopic.allValues sortedArrayUsingComparator:
			^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
				int64_t left = TGDMInt64(a[@"order"]);
				int64_t right = TGDMInt64(b[@"order"]);
				if (left == right)
					return NSOrderedSame;
				return left > right ? NSOrderedAscending : NSOrderedDescending;
			}];
	return topics;
}

- (void)directMessagesTopic:(int64_t)topicId
					 inChat:(int64_t)chatId
				 completion:(void (^)(NSDictionary *topic))completion {
	[self request:@{
		@"@type" : @"getDirectMessagesChatTopic",
		@"chat_id" : @(chatId),
		@"topic_id" : @(topicId),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGDMFailed(result)) {
			completion(nil);
			return;
		}
		NSDictionary *flat = TGDMFlattenTopic(result);
		if (flat) {
			NSMutableDictionary *byTopic = TGDMTopicsStore()[@(chatId)];
			if (![byTopic isKindOfClass:NSMutableDictionary.class]) {
				byTopic = [NSMutableDictionary dictionary];
				TGDMTopicsStore()[@(chatId)] = byTopic;
			}
			byTopic[flat[@"topicId"]] = flat;
		}
		completion(flat);
	}];
}

- (void)setDirectMessagesTopicInChat:(int64_t)chatId
							   topic:(int64_t)topicId
					  markedAsUnread:(BOOL)markedAsUnread
						  completion:(void (^)(BOOL success))completion {
	[self request:@{
		@"@type" : @"setDirectMessagesChatTopicIsMarkedAsUnread",
		@"chat_id" : @(chatId),
		@"topic_id" : @(topicId),
		@"is_marked_as_unread" : @(markedAsUnread),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGDMFailed(result));
	}];
}

- (void)toggleDirectMessagesTopicInChat:(int64_t)chatId
								  topic:(int64_t)topicId
				  canSendUnpaidMessages:(BOOL)canSendUnpaid
						 refundPayments:(BOOL)refundPayments
							 completion:(void (^)(BOOL success))completion {
	[self request:@{
		@"@type" : @"toggleDirectMessagesChatTopicCanSendUnpaidMessages",
		@"chat_id" : @(chatId),
		@"topic_id" : @(topicId),
		@"can_send_unpaid_messages" : @(canSendUnpaid),
		@"refund_payments" : @(refundPayments),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGDMFailed(result));
	}];
}

#pragma mark - sending inside a topic

- (void)sendText:(NSString *)text
				 toChat:(int64_t)chatId
	directMessagesTopic:(int64_t)topicId
				replyTo:(int64_t)replyToId
			  quoteText:(NSString *)quoteText
		  quotePosition:(NSInteger)quotePosition
				options:(NSDictionary *)options
			 completion:(void (^)(NSDictionary *message))completion {
	NSArray *entities = [options[@"entities"] isKindOfClass:NSArray.class]
		? options[@"entities"]
		: nil;
	NSMutableDictionary *formattedText = [@{@"@type" : @"formattedText", @"text" : text ?: @""}
		mutableCopy];
	if (entities.count > 0)
		formattedText[@"entities"] = entities;

	NSMutableDictionary *request = [@{
		@"@type" : @"sendMessage",
		@"chat_id" : @(chatId),
		@"topic_id" : TGTopicDictionary(0, topicId, 0, NO),
		@"input_message_content" : @{
			@"@type" : @"inputMessageText",
			@"text" : formattedText,
			@"clear_draft" : @YES,
		},
		@"options" : TGMsgSendOptions(options),
	} mutableCopy];
	NSDictionary *replyTo = TGReplyToDictionary(replyToId, quoteText,
		TGWireEntitiesFromFlattened(options[@"quoteEntities"]), quotePosition);
	if (replyTo)
		request[@"reply_to"] = replyTo;

	[self request:request completion:^(NSDictionary *result) {
		if (completion)
			completion(TGDMFailed(result) ? nil : result);
	}];
}

#pragma mark - live updates

- (void)handleDirectMessagesTopicUpdate:(NSDictionary *)obj {
	NSDictionary *topic = TGDMDict(obj[@"topic"]);
	NSDictionary *flat = TGDMFlattenTopic(topic);
	if (!flat)
		return;
	int64_t chatId = TGDMInt64(flat[@"chatId"]);
	NSMutableDictionary *byTopic = TGDMTopicsStore()[@(chatId)];
	if (![byTopic isKindOfClass:NSMutableDictionary.class]) {
		byTopic = [NSMutableDictionary dictionary];
		TGDMTopicsStore()[@(chatId)] = byTopic;
	}
	byTopic[flat[@"topicId"]] = flat;
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGDirectMessagesChatTopicsUpdatedNotification
					  object:@(chatId)];
}

#pragma mark - account switch

- (void)resetDirectMessagesCachesForAccountSwitch {
	[TGDMTopicsStore() removeAllObjects];
}

@end

NSString *const TGDirectMessagesChatTopicsUpdatedNotification =
	@"TGDirectMessagesChatTopicsUpdatedNotification";

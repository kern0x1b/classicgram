#import "TGMessage.h"
#import "TGMessageContent.h"

@implementation TGMessage

- (instancetype)initWithMessageId:(int64_t)messageId
						   chatId:(int64_t)chatId
						chatTitle:(NSString *)chatTitle
						 senderId:(int64_t)senderId
							 date:(NSTimeInterval)date
					   isOutgoing:(BOOL)isOutgoing
					isChannelPost:(BOOL)isChannelPost
				  authorSignature:(NSString *)authorSignature
						 isEdited:(BOOL)isEdited
						isService:(BOOL)isService
			   serviceNamesAuthor:(BOOL)serviceNamesAuthor
				 serviceActorName:(NSString *)serviceActorName
			pinnedTargetMessageId:(int64_t)pinnedTargetMessageId
		   oldBackgroundMessageId:(int64_t)oldBackgroundMessageId
							 text:(NSString *)text
						 entities:(NSArray<TGMessageEntity *> *)entities
					  captionText:(NSString *)captionText
						  albumId:(NSString *)albumId
						viewCount:(NSInteger)viewCount
						reactions:(NSArray<TGReaction *> *)reactions
			 reactionsSummaryText:(NSString *)reactionsSummaryText
						sendState:(TGMessageSendState)sendState
						 canRetry:(BOOL)canRetry
					   isViewOnce:(BOOL)isViewOnce
					destructTimer:(NSInteger)destructTimer
					   destructIn:(NSTimeInterval)destructIn
					isSecretMedia:(BOOL)isSecretMedia
					   hasSpoiler:(BOOL)hasSpoiler
					factCheckText:(NSString *)factCheckText
						replyInfo:(TGMessageReplyInfo *)replyInfo
					  forwardInfo:(TGMessageForwardInfo *)forwardInfo
				suggestedPostInfo:(TGSuggestedPostInfo *)suggestedPostInfo
							 kind:(TGMessageContentKind)kind
						  content:(TGMessageContent *)content {
	self = [super init];
	if (self != nil) {
		_messageId = messageId;
		_chatId = chatId;
		_chatTitle = [chatTitle copy];
		_senderId = senderId;
		_date = date;
		_outgoing = isOutgoing;
		_channelPost = isChannelPost;
		_authorSignature = [authorSignature copy];
		_edited = isEdited;
		_service = isService;
		_serviceNamesAuthor = serviceNamesAuthor;
		_serviceActorName = [serviceActorName copy];
		_pinnedTargetMessageId = pinnedTargetMessageId;
		_oldBackgroundMessageId = oldBackgroundMessageId;
		_text = [text copy];
		_entities = [entities copy];
		_captionText = [captionText copy];
		_albumId = [albumId copy];
		_viewCount = viewCount;
		_reactions = [reactions copy];
		_reactionsSummaryText = [reactionsSummaryText copy];
		_sendState = sendState;
		_canRetry = canRetry;
		_viewOnce = isViewOnce;
		_destructTimer = destructTimer;
		_destructIn = destructIn;
		_secretMedia = isSecretMedia;
		_spoiler = hasSpoiler;
		_factCheckText = [factCheckText copy];
		_replyInfo = replyInfo;
		_forwardInfo = forwardInfo;
		_suggestedPostInfo = suggestedPostInfo;
		_kind = kind;
		_content = content;
	}
	return self;
}

@end

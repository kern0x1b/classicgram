#import <Foundation/Foundation.h>

@class TGMessageContent;
@class TGMessageEntity;
@class TGMessageReplyInfo;
@class TGMessageForwardInfo;
@class TGSuggestedPostInfo;
@class TGReaction;

typedef NS_ENUM(NSInteger, TGMessageContentKind) {
	TGMessageContentKindUnknown = 0,
	TGMessageContentKindText,
	TGMessageContentKindPhoto,
	TGMessageContentKindVideo,
	TGMessageContentKindVideoNote,
	TGMessageContentKindAnimation,
	TGMessageContentKindSticker,
	TGMessageContentKindAnimatedEmoji,
	TGMessageContentKindDocument,
	TGMessageContentKindVoiceNote,
	TGMessageContentKindAudio,
	TGMessageContentKindContact,
	TGMessageContentKindLocation,
	TGMessageContentKindLiveLocation,
	TGMessageContentKindVenue,
	TGMessageContentKindPoll,
	TGMessageContentKindChecklist,
	TGMessageContentKindCall,
	TGMessageContentKindDice,
	TGMessageContentKindGame,
	TGMessageContentKindInvoice,
	TGMessageContentKindStory,
	TGMessageContentKindPaidMedia,
	TGMessageContentKindExpiredMedia,
	TGMessageContentKindRichMessage,
	TGMessageContentKindUnsupported,
	TGMessageContentKindService
};

typedef NS_ENUM(NSInteger, TGMessageSendState) {
	TGMessageSendStateSent = 0,
	TGMessageSendStatePending,
	TGMessageSendStateFailed
};

@interface TGMessage : NSObject

@property (nonatomic, readonly) int64_t messageId;
@property (nonatomic, readonly) int64_t chatId;
@property (nonatomic, readonly, copy) NSString *chatTitle;
@property (nonatomic, readonly) int64_t senderId;
@property (nonatomic, readonly) NSTimeInterval date;
@property (nonatomic, readonly) BOOL outgoing;
@property (nonatomic, readonly) BOOL channelPost;
@property (nonatomic, readonly, copy) NSString *authorSignature;
@property (nonatomic, readonly) BOOL edited;

@property (nonatomic, readonly) BOOL service;
@property (nonatomic, readonly) BOOL serviceNamesAuthor;
@property (nonatomic, readonly, copy) NSString *serviceActorName;
@property (nonatomic, readonly) int64_t pinnedTargetMessageId;
@property (nonatomic, readonly) int64_t oldBackgroundMessageId;

@property (nonatomic, readonly, copy) NSString *text;
@property (nonatomic, readonly, copy) NSArray<TGMessageEntity *> *entities;
@property (nonatomic, readonly, copy) NSString *captionText;
@property (nonatomic, readonly, copy) NSString *albumId;

@property (nonatomic, readonly) NSInteger viewCount;
@property (nonatomic, readonly, copy) NSArray<TGReaction *> *reactions;
@property (nonatomic, readonly, copy) NSString *reactionsSummaryText;

@property (nonatomic, readonly) TGMessageSendState sendState;
@property (nonatomic, readonly) BOOL canRetry;

@property (nonatomic, readonly) BOOL viewOnce;
@property (nonatomic, readonly) NSInteger destructTimer;
@property (nonatomic, readonly) NSTimeInterval destructIn;
@property (nonatomic, readonly) BOOL secretMedia;
@property (nonatomic, readonly) BOOL spoiler;

@property (nonatomic, readonly, copy) NSString *factCheckText;

@property (nonatomic, readonly, strong) TGMessageReplyInfo *replyInfo;
@property (nonatomic, readonly, strong) TGMessageForwardInfo *forwardInfo;
@property (nonatomic, readonly, strong) TGSuggestedPostInfo *suggestedPostInfo;

@property (nonatomic, readonly) TGMessageContentKind kind;
@property (nonatomic, readonly, strong) TGMessageContent *content;

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
						  content:(TGMessageContent *)content NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

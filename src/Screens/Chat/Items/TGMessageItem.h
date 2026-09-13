#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "TGMessage.h"

@class TGRichTextLayout;

typedef struct {
	const void *messageIdentity;
	uint32_t memberIdentity;
	uint32_t sideRevision;
	uint32_t contextGeneration;
} TGMessageFingerprint;

static inline BOOL TGMessageFingerprintEqual(TGMessageFingerprint a, TGMessageFingerprint b) {
	return a.messageIdentity == b.messageIdentity &&
		a.memberIdentity == b.memberIdentity &&
		a.sideRevision == b.sideRevision &&
		a.contextGeneration == b.contextGeneration;
}

static inline TGMessageFingerprint TGMessageFingerprintWithContextGeneration(
	TGMessageFingerprint fingerprint, uint32_t contextGeneration) {
	fingerprint.contextGeneration = contextGeneration;
	return fingerprint;
}

@interface TGMessageItem : NSObject

@property (nonatomic, readonly) int64_t messageId;
@property (nonatomic, readonly) int64_t chatId;
@property (nonatomic, readonly) int64_t senderId;
@property (nonatomic, readonly) int64_t senderChatId;
@property (nonatomic, readonly, strong) TGMessage *message;
@property (nonatomic, readonly, copy) NSArray<TGMessage *> *albumMembers;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) Class cellClass;
@property (nonatomic, readonly) BOOL opensNewDay;
@property (nonatomic, readonly) BOOL carriesUnreadBand;
@property (nonatomic, readonly) BOOL deliveryWasRead;
@property (nonatomic, readonly, copy) NSString *dayText;

@property (nonatomic, readonly, copy) NSString *senderDisplayName;
@property (nonatomic, readonly, copy) NSString *forwardDisplayName;
@property (nonatomic, readonly, copy) NSString *viaBotDisplayName;
@property (nonatomic, readonly, copy) NSString *forwardLinePrefix;
@property (nonatomic, readonly, copy) NSString *forwardLineText;
@property (nonatomic, readonly) BOOL forwardOriginIsReachable;
@property (nonatomic, readonly) int64_t forwardAvatarUserId;
@property (nonatomic, readonly) int64_t forwardAvatarChatId;
@property (nonatomic, readonly, copy) NSString *bodyText;
@property (nonatomic, readonly, strong) TGRichTextLayout *bodyRichLayout;
@property (nonatomic, readonly, copy) NSString *stampText;
@property (nonatomic, readonly, copy) NSString *viewCountText;
@property (nonatomic, readonly, copy) NSString *signatureText;
@property (nonatomic, readonly, copy) NSString *serviceLineText;
@property (nonatomic, readonly, copy) NSString *quoteAuthorText;
@property (nonatomic, readonly, copy) NSString *quoteBodyText;
@property (nonatomic, readonly, strong) TGRichTextLayout *quoteRichLayout;
@property (nonatomic, readonly) BOOL quoteIsMissing;
@property (nonatomic, readonly) CGSize quoteThumbnailSize;
@property (nonatomic, readonly, copy) NSString *transcriptText;
@property (nonatomic, readonly, copy) NSString *translationText;
@property (nonatomic, readonly, copy) NSString *summaryText;
@property (nonatomic, readonly, copy) NSArray *reactionChips;
@property (nonatomic, readonly) CGSize reactionRowSize;
@property (nonatomic, readonly) NSInteger commentCount;
@property (nonatomic, readonly) int64_t commentLastMessageId;
@property (nonatomic, readonly, copy) NSArray *commentReplierIds;
@property (nonatomic, readonly) BOOL hasCommentThread;
@property (nonatomic, readonly, strong) NSDictionary *linkPreview;
@property (nonatomic, readonly) CGSize linkPreviewImageSize;
@property (nonatomic, readonly) CGSize richCoverImageSize;
@property (nonatomic, readonly) CGSize pictureSize;
@property (nonatomic, readonly) BOOL pictureLoadFailed;
@property (nonatomic, readonly, copy) NSString *mediaBadgeText;
@property (nonatomic, readonly) BOOL fileShowsThumbnail;
@property (nonatomic, readonly) CGFloat fileTileSide;
@property (nonatomic, readonly, copy) NSString *fileTitleText;
@property (nonatomic, readonly, copy) NSString *fileMetaText;
@property (nonatomic, readonly, copy) NSString *fileCaptionText;
@property (nonatomic, readonly) BOOL fileHasCoverArt;
@property (nonatomic, readonly, copy) NSString *audioClockTemplate;
@property (nonatomic, readonly, copy) NSString *roundNoteDurationText;
@property (nonatomic, readonly, copy) NSString *voiceDurationText;
@property (nonatomic, readonly, copy) NSString *callTitleText;
@property (nonatomic, readonly, copy) NSString *callDetailText;
@property (nonatomic, readonly, copy) NSString *pollQuestionText;
@property (nonatomic, readonly, copy) NSString *pollSubtitleText;
@property (nonatomic, readonly, copy) NSString *checklistTitleText;
@property (nonatomic, readonly, copy) NSString *lottiePath;
@property (nonatomic, readonly) CGSize mosaicSize;
@property (nonatomic, readonly) NSUInteger mosaicTileCount;

- (CGRect)mosaicTileFrameAtIndex:(NSUInteger)index;
- (NSUInteger)mosaicTilePositionAtIndex:(NSUInteger)index;

@property (nonatomic, readonly) uint32_t sideRevision;
@property (nonatomic, readonly) TGMessageFingerprint fingerprint;

- (instancetype)initWithMessageId:(int64_t)messageId
						   chatId:(int64_t)chatId
						 senderId:(int64_t)senderId
					 senderChatId:(int64_t)senderChatId
						  message:(TGMessage *)message
					 albumMembers:(NSArray<TGMessage *> *)albumMembers
				  reuseIdentifier:(NSString *)reuseIdentifier
						cellClass:(Class)cellClass
					  opensNewDay:(BOOL)opensNewDay
				carriesUnreadBand:(BOOL)carriesUnreadBand
				  deliveryWasRead:(BOOL)deliveryWasRead
						  dayText:(NSString *)dayText
				senderDisplayName:(NSString *)senderDisplayName
			   forwardDisplayName:(NSString *)forwardDisplayName
			    viaBotDisplayName:(NSString *)viaBotDisplayName
		 forwardOriginIsReachable:(BOOL)forwardOriginIsReachable
			  forwardAvatarUserId:(int64_t)forwardAvatarUserId
			  forwardAvatarChatId:(int64_t)forwardAvatarChatId
						 bodyText:(NSString *)bodyText
				   bodyRichLayout:(TGRichTextLayout *)bodyRichLayout
						stampText:(NSString *)stampText
					viewCountText:(NSString *)viewCountText
					signatureText:(NSString *)signatureText
				  serviceLineText:(NSString *)serviceLineText
				  quoteAuthorText:(NSString *)quoteAuthorText
					quoteBodyText:(NSString *)quoteBodyText
				  quoteRichLayout:(TGRichTextLayout *)quoteRichLayout
				   quoteIsMissing:(BOOL)quoteIsMissing
			   quoteThumbnailSize:(CGSize)quoteThumbnailSize
				   transcriptText:(NSString *)transcriptText
				  translationText:(NSString *)translationText
					  summaryText:(NSString *)summaryText
					reactionChips:(NSArray *)reactionChips
				  reactionRowSize:(CGSize)reactionRowSize
					 commentCount:(NSInteger)commentCount
			 commentLastMessageId:(int64_t)commentLastMessageId
				commentReplierIds:(NSArray *)commentReplierIds
				 hasCommentThread:(BOOL)hasCommentThread
					  linkPreview:(NSDictionary *)linkPreview
			 linkPreviewImageSize:(CGSize)linkPreviewImageSize
			   richCoverImageSize:(CGSize)richCoverImageSize
					  pictureSize:(CGSize)pictureSize
				pictureLoadFailed:(BOOL)pictureLoadFailed
				   mediaBadgeText:(NSString *)mediaBadgeText
			   fileShowsThumbnail:(BOOL)fileShowsThumbnail
					 fileTileSide:(CGFloat)fileTileSide
					fileTitleText:(NSString *)fileTitleText
					 fileMetaText:(NSString *)fileMetaText
				  fileCaptionText:(NSString *)fileCaptionText
				  fileHasCoverArt:(BOOL)fileHasCoverArt
			   audioClockTemplate:(NSString *)audioClockTemplate
			roundNoteDurationText:(NSString *)roundNoteDurationText
				voiceDurationText:(NSString *)voiceDurationText
					callTitleText:(NSString *)callTitleText
				   callDetailText:(NSString *)callDetailText
				 pollQuestionText:(NSString *)pollQuestionText
				 pollSubtitleText:(NSString *)pollSubtitleText
			   checklistTitleText:(NSString *)checklistTitleText
					   lottiePath:(NSString *)lottiePath
					   mosaicSize:(CGSize)mosaicSize
				 mosaicTileFrames:(NSArray<NSValue *> *)mosaicTileFrames
			  mosaicTilePositions:(NSArray<NSNumber *> *)mosaicTilePositions
					 sideRevision:(uint32_t)sideRevision NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

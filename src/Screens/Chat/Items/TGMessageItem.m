#import "TGMessageItem.h"
#import "TGLocalization.h"
#import <UIKit/UIKit.h>

static uint32_t TGMessageItemAlbumFNV1a(NSArray<TGMessage *> *members) {
	uint32_t hash = 2166136261u;
	for (TGMessage *member in members) {
		const void *pointer = (__bridge const void *)member;
		uintptr_t bits = (uintptr_t)pointer;
		for (NSInteger i = 0; i < sizeof(bits); i++) {
			hash ^= (uint8_t)(bits >> (i * 8));
			hash *= 16777619u;
		}
	}
	return hash;
}

@implementation TGMessageItem {
	NSArray<NSValue *> *_mosaicTileFrames;
	NSArray<NSNumber *> *_mosaicTilePositions;
	NSString *_forwardDisplayName;
	NSString *_viaBotDisplayName;
}

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
					 sideRevision:(uint32_t)sideRevision {
	self = [super init];
	if (!self)
		return nil;

	_messageId = messageId;
	_chatId = chatId;
	_senderId = senderId;
	_senderChatId = senderChatId;
	_message = message;
	_albumMembers = [albumMembers copy];
	_reuseIdentifier = [reuseIdentifier copy];
	_cellClass = cellClass;
	_opensNewDay = opensNewDay;
	_carriesUnreadBand = carriesUnreadBand;
	_deliveryWasRead = deliveryWasRead;
	_dayText = [dayText copy];
	_senderDisplayName = [senderDisplayName copy];
	_forwardDisplayName = [forwardDisplayName copy];
	_viaBotDisplayName = [viaBotDisplayName copy];
	_forwardOriginIsReachable = forwardOriginIsReachable;
	_forwardAvatarUserId = forwardAvatarUserId;
	_forwardAvatarChatId = forwardAvatarChatId;
	_bodyText = [bodyText copy];
	_bodyRichLayout = bodyRichLayout;
	_stampText = [stampText copy];
	_viewCountText = [viewCountText copy];
	_signatureText = [signatureText copy];
	_serviceLineText = [serviceLineText copy];
	_quoteAuthorText = [quoteAuthorText copy];
	_quoteBodyText = [quoteBodyText copy];
	_quoteRichLayout = quoteRichLayout;
	_quoteIsMissing = quoteIsMissing;
	_quoteThumbnailSize = quoteThumbnailSize;
	_transcriptText = [transcriptText copy];
	_translationText = [translationText copy];
	_summaryText = [summaryText copy];
	_reactionChips = [reactionChips copy];
	_reactionRowSize = reactionRowSize;
	_commentCount = commentCount;
	_commentLastMessageId = commentLastMessageId;
	_commentReplierIds = [commentReplierIds copy];
	_hasCommentThread = hasCommentThread;
	_linkPreview = linkPreview;
	_linkPreviewImageSize = linkPreviewImageSize;
	_richCoverImageSize = richCoverImageSize;
	_pictureSize = pictureSize;
	_pictureLoadFailed = pictureLoadFailed;
	_mediaBadgeText = [mediaBadgeText copy];
	_fileShowsThumbnail = fileShowsThumbnail;
	_fileTileSide = fileTileSide;
	_fileTitleText = [fileTitleText copy];
	_fileMetaText = [fileMetaText copy];
	_fileCaptionText = [fileCaptionText copy];
	_fileHasCoverArt = fileHasCoverArt;
	_audioClockTemplate = [audioClockTemplate copy];
	_roundNoteDurationText = [roundNoteDurationText copy];
	_voiceDurationText = [voiceDurationText copy];
	_callTitleText = [callTitleText copy];
	_callDetailText = [callDetailText copy];
	_pollQuestionText = [pollQuestionText copy];
	_pollSubtitleText = [pollSubtitleText copy];
	_checklistTitleText = [checklistTitleText copy];
	_lottiePath = [lottiePath copy];
	_mosaicSize = mosaicSize;
	_mosaicTileFrames = [mosaicTileFrames copy];
	_mosaicTilePositions = [mosaicTilePositions copy];
	_mosaicTileCount = _mosaicTileFrames.count;
	_sideRevision = sideRevision;
	return self;
}

- (CGRect)mosaicTileFrameAtIndex:(NSUInteger)index {
	NSAssert(index < _mosaicTileFrames.count, @"mosaic tile index %lu out of range %lu",
		(unsigned long)index, (unsigned long)_mosaicTileFrames.count);
	return [_mosaicTileFrames[index] CGRectValue];
}

- (NSUInteger)mosaicTilePositionAtIndex:(NSUInteger)index {
	NSAssert(index < _mosaicTilePositions.count, @"mosaic tile index %lu out of range %lu",
		(unsigned long)index, (unsigned long)_mosaicTilePositions.count);
	return _mosaicTilePositions[index].unsignedIntegerValue;
}

- (TGMessageFingerprint)fingerprint {
	TGMessageFingerprint fingerprint;
	fingerprint.messageIdentity = (__bridge const void *)_message;
	fingerprint.memberIdentity = _albumMembers.count
		? TGMessageItemAlbumFNV1a(_albumMembers)
		: 0;
	fingerprint.sideRevision = _sideRevision;
	fingerprint.contextGeneration = 0;
	return fingerprint;
}

- (NSString *)forwardDisplayName {
	if (_forwardDisplayName.length)
		return _forwardDisplayName;
	return _viaBotDisplayName;
}

- (NSString *)forwardLinePrefix {
	if (_forwardDisplayName.length)
		return TGL(@"Chat.MessageForwardInfo.MessageHeader", @"Forwarded from ");
	return TGL(@"Conversation.MessageViaUserPrefix", @"via ");
}

- (NSString *)forwardLineText {
	if (!self.forwardDisplayName.length)
		return nil;
	return [self.forwardLinePrefix stringByAppendingString:self.forwardDisplayName];
}

@end

#import <UIKit/UIKit.h>
#import "TGMessage.h"

@class TGRichTextLayout;

@interface TGMessageItemResolvedInputs : NSObject

@property (nonatomic, copy) NSString *senderDisplayName;
@property (nonatomic, assign) int64_t senderChatId;
@property (nonatomic, copy) NSString *forwardDisplayName;
@property (nonatomic, copy) NSString *viaBotDisplayName;
@property (nonatomic, assign) BOOL forwardOriginIsReachable;
@property (nonatomic, assign) int64_t forwardAvatarUserId;
@property (nonatomic, assign) int64_t forwardAvatarChatId;
@property (nonatomic, copy) NSString *bodyText;
@property (nonatomic, strong) TGRichTextLayout *bodyRichLayout;
@property (nonatomic, copy) NSString *stampText;
@property (nonatomic, copy) NSString *viewCountText;
@property (nonatomic, copy) NSString *quoteAuthorText;
@property (nonatomic, copy) NSString *quoteBodyText;
@property (nonatomic, strong) TGRichTextLayout *quoteRichLayout;
@property (nonatomic, assign) CGSize quoteThumbnailSize;
@property (nonatomic, copy) NSString *serviceLineText;
@property (nonatomic, copy) NSArray *reactionChips;
@property (nonatomic, assign) CGSize reactionRowSize;
@property (nonatomic, strong) NSDictionary *linkPreview;
@property (nonatomic, assign) CGSize linkPreviewImageSize;
@property (nonatomic, assign) CGSize pictureSize;
@property (nonatomic, assign) BOOL pictureLoadFailed;
@property (nonatomic, copy) NSString *mediaBadgeText;
@property (nonatomic, assign) BOOL fileShowsThumbnail;
@property (nonatomic, assign) CGFloat fileTileSide;
@property (nonatomic, copy) NSString *fileTitleText;
@property (nonatomic, copy) NSString *fileMetaText;
@property (nonatomic, copy) NSString *fileCaptionText;
@property (nonatomic, assign) BOOL fileHasCoverArt;
@property (nonatomic, copy) NSString *audioClockTemplate;
@property (nonatomic, copy) NSString *roundNoteDurationText;
@property (nonatomic, copy) NSString *voiceDurationText;
@property (nonatomic, copy) NSString *transcriptText;
@property (nonatomic, assign) CGSize mosaicSize;
@property (nonatomic, copy) NSArray *mosaicTileFrames;
@property (nonatomic, copy) NSArray *mosaicTilePositions;
@property (nonatomic, copy) NSString *callTitleText;
@property (nonatomic, copy) NSString *callDetailText;
@property (nonatomic, copy) NSString *pollQuestionText;
@property (nonatomic, copy) NSString *pollSubtitleText;
@property (nonatomic, copy) NSString *checklistTitleText;
@property (nonatomic, copy) NSString *lottiePath;
@property (nonatomic, assign) TGMessageSendState sendState;
@property (nonatomic, assign) BOOL opensNewDay;
@property (nonatomic, assign) BOOL carriesUnreadBand;
@property (nonatomic, assign) BOOL deliveryWasRead;
@property (nonatomic, copy) NSString *dayText;
@property (nonatomic, assign) uint32_t sideRevision;

@end

#import "TGMessageLayout.h"
#import "TGMessage.h"

@class TGMessageItem;
@class TGChatLayoutContext;

typedef NS_ENUM(uint8_t, TGMessageLayoutGenericBucket) {
	TGMessageLayoutGenericBucketNotApplicable = 0,
	TGMessageLayoutGenericBucketText,
	TGMessageLayoutGenericBucketPhoto,
	TGMessageLayoutGenericBucketSticker,
};

TGMessageLayoutGenericBucket TGMessageLayoutGenericBucketForContent(TGMessageContentKind kind,
	BOOL isLargeEmojiText);

typedef struct {
	CGFloat messageHeight;
	TGMessageLayoutParts parts;
	TGMessageRowFrames row;
	TGMessageBubbleFrames bubble;
	CGFloat bubbleCornerRadius;
	CGFloat bubbleBorderWidth;
	BOOL sitsOnWallpaper;
	TGMessageLayoutRepeatedRow repeatedRows[kMessageLayoutMaxRows];
	NSUInteger repeatedRowCount;
} TGMessageLayoutComputed;

TGMessageLayoutComputed TGMessageLayoutComputedZero(void);

extern const CGFloat kBubbleBudgetReferenceWidth;
extern const CGFloat kMessageLayoutPadH;
extern const CGFloat kMessageLayoutPadV;
extern const CGFloat kMessageLayoutAvatarSide;
extern const CGFloat kMessageLayoutBubbleMinW;
extern const CGFloat kMessageLayoutBubbleMinH;
extern const CGFloat kMessageLayoutBubbleMaxW;
extern const CGFloat kMessageLayoutBubbleTailOverhang;
extern const CGFloat kMessageLayoutForwardJumpSide;
extern const CGFloat kMessageLayoutForwardJumpGap;
extern const CGFloat kMessageLayoutDayRowHeight;
extern const CGFloat kMessageLayoutUnreadRowHeight;
extern const CGFloat kMessageLayoutSignatureHeight;
extern const CGFloat kMessageLayoutSignatureTopGap;
extern const CGFloat kMessageLayoutRetinaPixel;
extern const CGFloat kMessageLayoutCaptionMinWrapWidth;

CGFloat TGGapUnderMedia(CGSize body);
CGFloat TGMessageLayoutHeaderHeight(TGMessageItem *item);
CGFloat TGMessageLayoutBubbleWidthBudget(TGChatLayoutContext *context);
CGFloat TGMessageLayoutStampGutterWidth(NSString *viewCountText,
	NSString *stampText,
	BOOL outgoing);
BOOL TGMessageLayoutRowIsAvatarIndented(TGMessageItem *item, TGChatLayoutContext *context);
CGRect TGMessageLayoutAvatarFrame(CGRect bubble, BOOL outgoing);
CGFloat TGMessageLayoutMaxBubbleWidth(TGMessageItem *item, TGChatLayoutContext *context);
CGFloat TGMessageLayoutCaptionWidthCap(TGMessageItem *item);
CGFloat TGMessageLayoutForwardLineWidth(TGMessageItem *item);
CGFloat TGMessageLayoutHeadDecorationHeight(TGMessageItem *item);
CGFloat TGMessageLayoutFootDecorationHeight(TGMessageItem *item,
	TGChatLayoutContext *context,
	BOOL sitsOnWallpaper);
CGFloat TGMessageLayoutDecorationHeight(TGMessageItem *item,
	TGChatLayoutContext *context,
	BOOL sitsOnWallpaper);
CGFloat TGMessageLayoutSignatureBlockHeight(TGMessageItem *item);
CGFloat TGMessageLayoutSignatureWidth(TGMessageItem *item);
CGSize TGMessageLayoutTranscriptSize(TGMessageItem *item, TGChatLayoutContext *context);
CGFloat TGMessageLayoutGenericBubbleWidth(TGMessageItem *item,
	TGChatLayoutContext *context,
	CGSize body,
	CGSize picture,
	BOOL isVoice);

typedef struct {
	BOOL present;
	CGRect frame;
	CGFloat height;
} TGMessageLayoutReactionGeometry;

TGMessageLayoutReactionGeometry TGMessageLayoutReactionBlock(TGMessageItem *item,
	CGFloat contentBottom,
	CGFloat boxWidth,
	CGFloat inset,
	BOOL rightAligned,
	BOOL sitsOnWallpaper);
CGFloat TGMessageLayoutReactionsBlockHeight(TGMessageItem *item, BOOL sitsOnWallpaper);
TGMessageLayoutReactionGeometry TGMessageLayoutCommentsBlock(TGMessageItem *item,
	CGFloat contentBottom,
	CGFloat boxWidth,
	CGFloat inset);
CGFloat TGMessageLayoutCommentsBlockHeight(TGMessageItem *item);
CGFloat TGMessageLayoutBubbleBottomPad(TGMessageItem *item,
	BOOL sitsOnWallpaper,
	CGFloat otherwise);
CGFloat TGMessageLayoutBareBoxTailHeight(TGMessageItem *item, BOOL sitsOnWallpaper);
CGFloat TGMessageLayoutBareStampBoxHeight(TGMessageItem *item,
	CGFloat artSide,
	BOOL sitsOnWallpaper);

UIFont *TGMessageLayoutBodyFont(TGMessageItem *item, TGChatLayoutContext *context);
CGSize TGMessageLayoutBodySize(TGMessageItem *item, TGChatLayoutContext *context);
CGSize TGMessageLayoutLinkPreviewSize(TGMessageItem *item, TGChatLayoutContext *context);
BOOL TGMessageLayoutBubbleArtworkExists(BOOL tall, BOOL outgoing);

typedef struct {
	CGFloat leadPad;
	CGFloat trailPad;
	CGFloat eyeWidth;
	CGFloat eyeGap;
	CGFloat countWidth;
	CGFloat countGap;
	CGFloat timeWidth;
	CGFloat tickGap;
	CGFloat tickWidth;
	CGFloat width;
	CGFloat eyeOffset;
	CGFloat countOffset;
	CGFloat timeOffset;
	CGFloat tickOffset;
	BOOL showsViews;
	BOOL showsTicks;
} TGMessageLayoutStampPlate;

TGMessageLayoutStampPlate TGMessageLayoutStampPlateMake(NSString *countText,
	NSString *timeText,
	UIFont *font,
	CGFloat tickWidth,
	CGFloat leadPad,
	CGFloat trailPad);

typedef struct {
	BOOL showsStamp;
	CGRect platePlate;
	CGRect plateTime;
	BOOL showsViews;
	CGRect plateViews;
	CGRect plateEye;
	BOOL showsTicks;
	CGRect plateTicks;
	BOOL showsForwardJump;
	CGRect forwardJump;
} TGMessageLayoutStampGeometry;

TGMessageLayoutStampGeometry TGMessageLayoutPlaceStampBesideBox(TGMessageItem *item,
	TGChatLayoutContext *context,
	CGRect box,
	BOOL outgoing);

TGMessageLayoutComputed TGMessageLayoutBuildService(TGMessageItem *item,
	TGChatLayoutContext *context);
TGMessageLayoutComputed TGMessageLayoutBuildText(TGMessageItem *item,
	TGChatLayoutContext *context);
TGMessageLayoutComputed TGMessageLayoutBuildPhoto(TGMessageItem *item,
	TGChatLayoutContext *context);
TGMessageLayoutComputed TGMessageLayoutBuildFile(TGMessageItem *item,
	TGChatLayoutContext *context);
TGMessageLayoutComputed TGMessageLayoutBuildVoice(TGMessageItem *item,
	TGChatLayoutContext *context);
TGMessageLayoutComputed TGMessageLayoutBuildSticker(TGMessageItem *item,
	TGChatLayoutContext *context);
TGMessageLayoutComputed TGMessageLayoutBuildAnimatedSticker(TGMessageItem *item,
	TGChatLayoutContext *context);
TGMessageLayoutComputed TGMessageLayoutBuildBareEmoji(TGMessageItem *item,
	TGChatLayoutContext *context);
TGMessageLayoutComputed TGMessageLayoutBuildVideoNote(TGMessageItem *item,
	TGChatLayoutContext *context);
TGMessageLayoutComputed TGMessageLayoutBuildAlbum(TGMessageItem *item,
	TGChatLayoutContext *context);
TGMessageLayoutComputed TGMessageLayoutBuildPoll(TGMessageItem *item,
	TGChatLayoutContext *context);
TGMessageLayoutComputed TGMessageLayoutBuildChecklist(TGMessageItem *item,
	TGChatLayoutContext *context);
TGMessageLayoutComputed TGMessageLayoutBuildCall(TGMessageItem *item,
	TGChatLayoutContext *context);
TGMessageLayoutComputed TGMessageLayoutBuildRichMessage(TGMessageItem *item,
	TGChatLayoutContext *context);
TGMessageLayoutComputed TGMessageLayoutBuildLocation(TGMessageItem *item,
	TGChatLayoutContext *context);

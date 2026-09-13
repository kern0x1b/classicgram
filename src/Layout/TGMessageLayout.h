#import <UIKit/UIKit.h>

typedef NS_OPTIONS(uint32_t, TGMessageLayoutParts) {
	TGMessageLayoutPartBubble = 1u << 0,
	TGMessageLayoutPartBubbleArtwork = 1u << 1,
	TGMessageLayoutPartTail = 1u << 2,
	TGMessageLayoutPartSender = 1u << 3,
	TGMessageLayoutPartAvatar = 1u << 4,
	TGMessageLayoutPartForward = 1u << 5,
	TGMessageLayoutPartForwardJump = 1u << 6,
	TGMessageLayoutPartQuote = 1u << 7,
	TGMessageLayoutPartQuoteThumb = 1u << 8,
	TGMessageLayoutPartBody = 1u << 9,
	TGMessageLayoutPartPicture = 1u << 10,
	TGMessageLayoutPartRetryDisc = 1u << 11,
	TGMessageLayoutPartFileStatus = 1u << 12,
	TGMessageLayoutPartMediaBadge = 1u << 13,
	TGMessageLayoutPartComments = 1u << 14,
	TGMessageLayoutPartPlateBeside = 1u << 15,
	TGMessageLayoutPartPlateTicks = 1u << 16,
	TGMessageLayoutPartPlateViews = 1u << 17,
	TGMessageLayoutPartPreview = 1u << 18,
	TGMessageLayoutPartSignature = 1u << 19,
	TGMessageLayoutPartReactions = 1u << 20,
	TGMessageLayoutPartTranscript = 1u << 21,
	TGMessageLayoutPartWaveform = 1u << 22,
	TGMessageLayoutPartMediaDisc = 1u << 23,
	TGMessageLayoutPartSubtitle = 1u << 24,
	TGMessageLayoutPartAlbum = 1u << 25,
	TGMessageLayoutPartLottie = 1u << 26,
	TGMessageLayoutPartRoundRim = 1u << 27,
	TGMessageLayoutPartRoundBadge = 1u << 28,
	TGMessageLayoutPartDayPlate = 1u << 30,
	TGMessageLayoutPartUnreadBand = 1u << 31
};

typedef struct {
	CGRect bubble;
	CGRect tail;
	CGRect avatar;
	CGRect platePlate;
	CGRect plateTime;
	CGRect plateViews;
	CGRect plateEye;
	CGRect plateTicks;
	CGRect forwardJump;
	CGRect selectionCheck;
	CGRect replyArrow;
} TGMessageRowFrames;

typedef struct {
	CGRect sender;
	CGRect forward;
	CGRect quoteBar;
	CGRect quoteAuthor;
	CGRect quoteText;
	CGRect quoteThumb;
	CGRect quoteTapTarget;
	CGRect body;
	CGRect picture;
	CGRect album;
	CGRect lottie;
	CGRect roundRim;
	CGRect roundBadge;
	CGRect disc;
	CGRect fileStatus;
	CGRect waveform;
	CGRect audioClock;
	CGRect subtitle;
	CGRect transcript;
	CGRect mediaBadge;
	CGRect preview;
	CGRect signature;
	CGRect reactions;
	CGRect comments;
} TGMessageBubbleFrames;

#define kMessageLayoutMaxRows 32

typedef NS_ENUM(uint16_t, TGMessageLayoutRowKind) {
	TGMessageLayoutRowAlbumTile = 0,
	TGMessageLayoutRowPollOption,
	TGMessageLayoutRowPollRetract,
	TGMessageLayoutRowPollAdd,
	TGMessageLayoutRowChecklistTask,
	TGMessageLayoutRowChecklistAdd,
	TGMessageLayoutRowPollExplanation
};

typedef struct {
	CGRect frame;
	uint16_t index;
	TGMessageLayoutRowKind kind;
} TGMessageLayoutRepeatedRow;

@interface TGMessageLayout : NSObject

@property (nonatomic, readonly) CGFloat height;
@property (nonatomic, readonly) CGFloat headerHeight;
@property (nonatomic, readonly) CGFloat messageHeight;
@property (nonatomic, readonly) TGMessageLayoutParts parts;
@property (nonatomic, readonly) TGMessageRowFrames row;
@property (nonatomic, readonly) TGMessageBubbleFrames bubble;
@property (nonatomic, readonly) CGFloat bubbleCornerRadius;
@property (nonatomic, readonly) CGFloat bubbleBorderWidth;
@property (nonatomic, readonly) BOOL outgoing;
@property (nonatomic, readonly) BOOL sitsOnWallpaper;
@property (nonatomic, readonly) NSUInteger repeatedRowCount;

- (TGMessageLayoutRepeatedRow)repeatedRowAtIndex:(NSUInteger)index;

- (instancetype)init NS_UNAVAILABLE;

@end

UIImage *TGMessageLayoutBubbleArtwork(BOOL tall, BOOL outgoing);

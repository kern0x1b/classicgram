#import <UIKit/UIKit.h>

typedef struct {
	CGFloat height;
	CGRect bubbleFrame;
} TGChatMessageLayout;

typedef struct {
	CGFloat artX;
	CGRect tailFrame;
	CGRect avatarFrame;
	CGRect senderFrame;
} TGChatMessageContentFrames;

TGChatMessageLayout TGChatMessageLayoutMakeGeneric(CGSize bodySize,
	CGSize pictureSize,
	CGFloat gapUnderMedia,
	CGFloat senderHeight,
	CGFloat mediaTopPad,
	CGFloat mediaBottomPad,
	CGFloat decorationHeight,
	CGFloat minHeight,
	CGFloat bubbleWidth,
	CGFloat avatarShift,
	CGFloat tableWidth,
	BOOL outgoing);

CGFloat TGChatMessageLayoutVoiceHeight(CGFloat senderHeight,
	CGFloat forwarded,
	CGFloat reactionsBlockHeight,
	CGFloat transcriptHeight);

CGRect TGChatMessageLayoutMakeCenteredDiscFrame(CGFloat pictureX,
	CGFloat pictureY,
	CGFloat pictureWidth,
	CGFloat pictureHeight,
	CGFloat discSide);

TGChatMessageContentFrames TGChatMessageLayoutMakeContentFrames(CGFloat x,
	CGFloat bubbleWidth,
	CGFloat bubbleHeight,
	CGFloat senderHeight,
	CGFloat mediaTopPad,
	BOOL outgoing,
	BOOL isSticker,
	CGFloat artWidth,
	CGFloat padH,
	CGFloat avatarSide,
	CGFloat tailOverhang,
	CGFloat avatarShift);

#import "TGChatMessageLayout.h"

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
	BOOL outgoing) {
	CGFloat bubbleH = senderHeight + mediaTopPad + mediaBottomPad + decorationHeight;
	if (pictureSize.height > 0)
		bubbleH += pictureSize.height + gapUnderMedia;
	if (bodySize.height > 0)
		bubbleH += bodySize.height;
	bubbleH = MAX(bubbleH, minHeight);
	if (bubbleH > minHeight)
		bubbleH += 1;

	CGFloat x = outgoing ? (tableWidth - bubbleWidth - 8 - avatarShift) : (8 + avatarShift);

	TGChatMessageLayout layout;
	layout.height = bubbleH + 3;
	layout.bubbleFrame = CGRectMake(x, 0, bubbleWidth, bubbleH);
	return layout;
}

CGFloat TGChatMessageLayoutVoiceHeight(CGFloat senderHeight,
	CGFloat forwarded,
	CGFloat reactionsBlockHeight,
	CGFloat transcriptHeight) {
	return 56 + senderHeight + forwarded + reactionsBlockHeight + transcriptHeight;
}

CGRect TGChatMessageLayoutMakeCenteredDiscFrame(CGFloat pictureX,
	CGFloat pictureY,
	CGFloat pictureWidth,
	CGFloat pictureHeight,
	CGFloat discSide) {
	return CGRectMake(pictureX + (pictureWidth - discSide) / 2,
		pictureY + (pictureHeight - discSide) / 2,
		discSide, discSide);
}

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
	CGFloat avatarShift) {
	CGFloat unshiftedX = x - avatarShift;
	CGFloat avatarX = unshiftedX - tailOverhang + 4;

	TGChatMessageContentFrames frames;
	frames.artX = (isSticker && outgoing)
		? MAX(padH, bubbleWidth - padH - artWidth)
		: padH;
	frames.tailFrame = outgoing
		? CGRectMake(x + bubbleWidth - 1, bubbleHeight - 10, 6, 10)
		: CGRectMake(x - 5, bubbleHeight - 10, 6, 10);
	frames.avatarFrame = CGRectMake(avatarX, bubbleHeight - avatarSide - 1,
		avatarSide, avatarSide);
	frames.senderFrame = CGRectMake(padH, mediaTopPad,
		bubbleWidth - 2 * padH, senderHeight - 1);
	return frames;
}

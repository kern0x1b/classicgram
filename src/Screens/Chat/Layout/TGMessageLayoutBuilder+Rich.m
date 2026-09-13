#import "TGMessageLayoutBuilder+Private.h"
#import "TGMessageItem.h"
#import "TGChatLayoutContext.h"
#import "TGMessage.h"
#import "TGTheme.h"

TGMessageLayoutComputed TGMessageLayoutBuildRichMessage(TGMessageItem *item,
	TGChatLayoutContext *context) {
	TGMessageLayoutComputed computed = TGMessageLayoutComputedZero();

	BOOL outgoing = item.message.outgoing;
	BOOL hasSender = item.senderDisplayName.length > 0;
	BOOL hasAvatar = TGMessageLayoutRowIsAvatarIndented(item, context);
	CGFloat senderH = hasSender ? 17 : 0;
	CGFloat avatarShift = hasAvatar ? (kMessageLayoutAvatarSide + 4) : 0;

	CGFloat width = TGMessageLayoutMaxBubbleWidth(item, context);
	CGFloat x = outgoing ? (context.tableWidth - width - 8 - avatarShift) : (8 + avatarShift);

	CGFloat fwd = item.forwardDisplayName.length ? 18 : 0;
	CGFloat top = senderH + fwd + kMessageLayoutPadV;

	CGSize contentSize = TGMessageLayoutLinkPreviewSize(item, context);
	CGFloat contentWidth = width - 2 * kMessageLayoutPadH;
	CGFloat afterRow = top + ceilf(contentSize.height);

	TGMessageLayoutReactionGeometry reactions = TGMessageLayoutReactionBlock(
		item, afterRow, width, kMessageLayoutPadH, NO, NO);
	CGFloat bottomPad = TGMessageLayoutBubbleBottomPad(item, NO, kMessageLayoutPadV);
	CGFloat bubbleH = kMessageLayoutPadV + bottomPad + senderH + fwd + ceilf(contentSize.height) +
		reactions.height;

	computed.messageHeight = bubbleH + 3;
	computed.row.bubble = CGRectMake(x, 0, width, bubbleH);
	computed.parts = TGMessageLayoutPartBubble | TGMessageLayoutPartPreview;
	computed.sitsOnWallpaper = NO;
	computed.bubble.preview = CGRectMake(kMessageLayoutPadH, top, contentWidth,
		ceilf(contentSize.height));
	if (reactions.present) {
		computed.bubble.reactions = reactions.frame;
		computed.parts |= TGMessageLayoutPartReactions;
	}

	BOOL tall = bubbleH >= 48.0f;
	if (TGMessageLayoutBubbleArtworkExists(tall, outgoing)) {
		computed.parts |= TGMessageLayoutPartBubbleArtwork;
		computed.bubbleCornerRadius = 0;
		computed.bubbleBorderWidth = 0;
	} else {
		computed.bubbleCornerRadius = [TGTheme shared].bubbleCornerRadius;
		computed.bubbleBorderWidth = [TGTheme shared].bubbleBorderWidth;
		computed.parts |= TGMessageLayoutPartTail;
		computed.row.tail = outgoing
			? CGRectMake(x + width - 1, bubbleH - 10, 6, 10)
			: CGRectMake(x - 5, bubbleH - 10, 6, 10);
	}

	if (fwd > 0) {
		computed.bubble.forward = CGRectMake(kMessageLayoutPadH, kMessageLayoutPadV + senderH,
			MAX(width - 2 * kMessageLayoutPadH, 20), 16);
		computed.parts |= TGMessageLayoutPartForward;
	}

	if (hasSender) {
		computed.bubble.sender = CGRectMake(kMessageLayoutPadH, kMessageLayoutPadV,
			width - 2 * kMessageLayoutPadH, senderH - 1);
		computed.parts |= TGMessageLayoutPartSender;
	}
	if (hasAvatar) {
		computed.row.avatar = TGMessageLayoutAvatarFrame(computed.row.bubble, outgoing);
		computed.parts |= TGMessageLayoutPartAvatar;
	}

	computed.parts |= TGMessageLayoutPartPlateBeside;
	TGMessageLayoutStampGeometry stamp = TGMessageLayoutPlaceStampBesideBox(
		item, context, computed.row.bubble, outgoing);
	if (stamp.showsStamp) {
		computed.row.platePlate = stamp.platePlate;
		computed.row.plateTime = stamp.plateTime;
		if (stamp.showsViews) {
			computed.row.plateViews = stamp.plateViews;
			computed.row.plateEye = stamp.plateEye;
			computed.parts |= TGMessageLayoutPartPlateViews;
		}
		if (stamp.showsTicks) {
			computed.row.plateTicks = stamp.plateTicks;
			computed.parts |= TGMessageLayoutPartPlateTicks;
		}
	}
	if (stamp.showsForwardJump) {
		computed.row.forwardJump = stamp.forwardJump;
		computed.parts |= TGMessageLayoutPartForwardJump;
	}

	return computed;
}

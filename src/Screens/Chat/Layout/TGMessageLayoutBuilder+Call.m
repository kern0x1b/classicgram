#import "TGMessageLayoutBuilder+Private.h"
#import "TGMessageItem.h"
#import "TGChatLayoutContext.h"
#import "TGMessage.h"
#import "TGTheme.h"

static const CGFloat kCallGlyphSide = 30.0f;
static const CGFloat kCallGlyphGap = 10.0f;
static const CGFloat kCallTitleHeight = 20.0f;
static const CGFloat kCallDetailHeight = 16.0f;

TGMessageLayoutComputed TGMessageLayoutBuildCall(TGMessageItem *item,
	TGChatLayoutContext *context) {
	NSString *title = item.callTitleText.length ? item.callTitleText : item.bodyText;
	if (!title.length)
		return TGMessageLayoutBuildText(item, context);

	TGMessageLayoutComputed computed = TGMessageLayoutComputedZero();

	BOOL outgoing = item.message.outgoing;
	BOOL hasSender = item.senderDisplayName.length > 0;
	BOOL hasAvatar = TGMessageLayoutRowIsAvatarIndented(item, context);
	CGFloat senderH = hasSender ? 17 : 0;
	CGFloat forwardH = item.forwardDisplayName.length ? 18 : 0;
	CGFloat reactionsH = TGMessageLayoutReactionsBlockHeight(item, NO);

	CGFloat titleW = ceilf([title sizeWithFont:[UIFont boldSystemFontOfSize:15]].width);
	CGFloat detailW = item.callDetailText.length
		? ceilf([item.callDetailText sizeWithFont:[UIFont systemFontOfSize:13]].width)
		: 0;
	CGFloat textW = MAX(titleW, detailW);

	CGFloat contentW = kCallGlyphSide + kCallGlyphGap + textW;
	if (hasSender) {
		CGFloat nameW = ceilf([item.senderDisplayName
							sizeWithFont:[UIFont boldSystemFontOfSize:13]]
								.width) +
			4;
		contentW = MAX(contentW, nameW);
	}
	CGFloat bubbleW = MIN(contentW + 2 * kMessageLayoutPadH,
		TGMessageLayoutMaxBubbleWidth(item, context));

	CGFloat rowsH = kCallTitleHeight + (item.callDetailText.length ? kCallDetailHeight : 0);
	CGFloat contentH = MAX(rowsH, kCallGlyphSide);
	CGFloat bottomPad = TGMessageLayoutBubbleBottomPad(item, NO, kMessageLayoutPadV);
	CGFloat bubbleH = senderH + forwardH + contentH + kMessageLayoutPadV + bottomPad + reactionsH;

	CGFloat avatarShift = hasAvatar ? (kMessageLayoutAvatarSide + 4) : 0;
	CGFloat x = outgoing ? (context.tableWidth - bubbleW - 8 - avatarShift) : (8 + avatarShift);

	computed.messageHeight = bubbleH + 3;
	computed.row.bubble = CGRectMake(x, 0, bubbleW, bubbleH);
	computed.parts = TGMessageLayoutPartBubble;
	computed.sitsOnWallpaper = NO;

	BOOL tall = bubbleH >= 48.0f;
	if (TGMessageLayoutBubbleArtworkExists(tall, outgoing)) {
		computed.parts |= TGMessageLayoutPartBubbleArtwork;
		computed.bubbleCornerRadius = 0;
		computed.bubbleBorderWidth = 0;
	} else {
		computed.parts |= TGMessageLayoutPartTail;
		computed.row.tail = outgoing
			? CGRectMake(x + bubbleW - 1, bubbleH - 10, 6, 10)
			: CGRectMake(x - 5, bubbleH - 10, 6, 10);
		computed.bubbleCornerRadius = [TGTheme shared].bubbleCornerRadius;
		computed.bubbleBorderWidth = [TGTheme shared].bubbleBorderWidth;
	}

	if (hasSender) {
		computed.bubble.sender = CGRectMake(kMessageLayoutPadH, kMessageLayoutPadV,
			bubbleW - 2 * kMessageLayoutPadH, senderH - 1);
		computed.parts |= TGMessageLayoutPartSender;
	}
	if (hasAvatar) {
		computed.row.avatar = TGMessageLayoutAvatarFrame(computed.row.bubble, outgoing);
		computed.parts |= TGMessageLayoutPartAvatar;
	}

	CGFloat top = kMessageLayoutPadV + senderH;
	if (forwardH > 0) {
		computed.bubble.forward = CGRectMake(kMessageLayoutPadH, top,
			MAX(bubbleW - 2 * kMessageLayoutPadH, 20), 16);
		computed.parts |= TGMessageLayoutPartForward;
		top += forwardH;
	}

	CGFloat textLeft = kMessageLayoutPadH + kCallGlyphSide + kCallGlyphGap;
	CGFloat available = MAX(bubbleW - textLeft - kMessageLayoutPadH, 20);

	computed.bubble.disc = CGRectMake(kMessageLayoutPadH,
		top + (contentH - kCallGlyphSide) / 2,
		kCallGlyphSide, kCallGlyphSide);
	computed.parts |= TGMessageLayoutPartMediaDisc;

	CGFloat textTop = top + (contentH - rowsH) / 2;
	computed.bubble.body = CGRectMake(textLeft, textTop, available, kCallTitleHeight);
	computed.parts |= TGMessageLayoutPartBody;

	if (item.callDetailText.length) {
		computed.bubble.subtitle = CGRectMake(textLeft, textTop + kCallTitleHeight,
			available, kCallDetailHeight);
		computed.parts |= TGMessageLayoutPartSubtitle;
	}

	TGMessageLayoutReactionGeometry reactions = TGMessageLayoutReactionBlock(
		item, top + contentH, bubbleW, kMessageLayoutPadH, NO, NO);
	if (reactions.present) {
		computed.bubble.reactions = reactions.frame;
		computed.parts |= TGMessageLayoutPartReactions;
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

#import "TGMessageLayoutBuilder+Private.h"
#import "TGMessageItem.h"
#import "TGChatLayoutContext.h"
#import "TGMessage.h"

static const CGFloat kRoundNoteRimInset = 2.5f;
static const CGFloat kRoundNoteBadgeSide = 24.0f;
static const CGFloat kRoundNoteMaxSide = 178.0f;

TGMessageLayoutComputed TGMessageLayoutBuildVideoNote(TGMessageItem *item,
	TGChatLayoutContext *context) {
	TGMessageLayoutComputed computed = TGMessageLayoutComputedZero();

	BOOL outgoing = item.message.outgoing;
	BOOL hasSender = item.senderDisplayName.length > 0;
	BOOL hasAvatar = TGMessageLayoutRowIsAvatarIndented(item, context);
	CGFloat senderH = hasSender ? 17 : 0;

	CGSize pic = item.pictureSize;
	CGFloat declared = MIN(pic.width, pic.height);
	CGFloat side = declared >= 1 ? MIN(declared, kRoundNoteMaxSide) : kRoundNoteMaxSide;
	CGFloat boxW = MAX(side, item.reactionRowSize.width);
	CGFloat avatarShift = hasAvatar ? (kMessageLayoutAvatarSide + 4) : 0;
	CGFloat boxX = outgoing ? (context.tableWidth - boxW - 8 - avatarShift) : (8 + avatarShift);
	CGFloat circleX = outgoing ? (boxW - side) : 0;

	CGFloat headerY = senderH;
	CGFloat forwardH = item.forwardDisplayName.length ? 18 : 0;
	BOOL hasQuote = item.quoteBodyText.length > 0;
	CGFloat quoteH = hasQuote ? 38 : 0;
	CGFloat headerH = forwardH + quoteH;

	CGFloat tailH = TGMessageLayoutBareBoxTailHeight(item, YES);
	CGFloat boxH = senderH + headerH + side + tailH;

	computed.messageHeight = boxH + 3;
	computed.row.bubble = CGRectMake(boxX, 0, boxW, boxH);
	computed.parts = TGMessageLayoutPartBubble;
	computed.sitsOnWallpaper = YES;
	computed.bubbleCornerRadius = 0;
	computed.bubbleBorderWidth = 0;

	if (hasSender) {
		computed.bubble.sender = CGRectMake(kMessageLayoutPadH, 0,
			boxW - 2 * kMessageLayoutPadH, senderH - 1);
		computed.parts |= TGMessageLayoutPartSender;
	}
	if (hasAvatar) {
		computed.row.avatar = TGMessageLayoutAvatarFrame(computed.row.bubble, outgoing);
		computed.parts |= TGMessageLayoutPartAvatar;
	}

	if (forwardH > 0) {
		computed.bubble.forward = CGRectMake(kMessageLayoutPadH, headerY,
			MAX(boxW - 2 * kMessageLayoutPadH, 20), 16);
		computed.parts |= TGMessageLayoutPartForward;
		headerY += forwardH;
	}

	if (hasQuote) {
		computed.bubble.quoteBar = CGRectMake(kMessageLayoutPadH, headerY, 2, 34);
		BOOL hasThumb = item.quoteThumbnailSize.width > 0 && item.quoteThumbnailSize.height > 0;
		CGFloat textX = kMessageLayoutPadH + (hasThumb ? 45 : 8);
		if (hasThumb) {
			computed.bubble.quoteThumb = CGRectMake(kMessageLayoutPadH + 7, headerY + 1, 32, 32);
			computed.parts |= TGMessageLayoutPartQuoteThumb;
		}
		CGFloat quoteW = MAX(boxW - textX - kMessageLayoutPadH, 40);
		computed.bubble.quoteAuthor = CGRectMake(textX, headerY, quoteW, 16);
		computed.bubble.quoteText = CGRectMake(textX, headerY + 17, quoteW, 17);
		computed.bubble.quoteTapTarget = CGRectMake(kMessageLayoutPadH, headerY,
			boxW - 2 * kMessageLayoutPadH, 38);
		computed.parts |= TGMessageLayoutPartQuote;
		headerY += quoteH;
	}

	computed.bubble.roundRim = CGRectMake(circleX, senderH + headerH, side, side);
	computed.parts |= TGMessageLayoutPartRoundRim;

	CGFloat inner = side - kRoundNoteRimInset * 2;
	computed.bubble.picture = CGRectMake(circleX + kRoundNoteRimInset,
		senderH + headerH + kRoundNoteRimInset, inner, inner);
	computed.parts |= TGMessageLayoutPartPicture;

	CGFloat pillAnchorX = floorf(circleX + side / 2 - kRoundNoteBadgeSide / 2);

	CGFloat pillW = ceilf([item.roundNoteDurationText
						sizeWithFont:[UIFont systemFontOfSize:11]]
							.width) +
		11;
	computed.bubble.roundBadge = CGRectMake(floorf(pillAnchorX - 6 - pillW),
		senderH + headerH + side - 16,
		pillW, 18);
	computed.parts |= TGMessageLayoutPartRoundBadge;

	CGFloat contentBottom = senderH + headerH + side;
	TGMessageLayoutReactionGeometry reactions = TGMessageLayoutReactionBlock(
		item, contentBottom, boxW, 0, outgoing, YES);
	if (reactions.present) {
		computed.bubble.reactions = reactions.frame;
		computed.parts |= TGMessageLayoutPartReactions;
	}

	computed.parts |= TGMessageLayoutPartPlateBeside;
	CGRect stampBox = CGRectMake(boxX + circleX, senderH + headerH, side,
		TGMessageLayoutBareStampBoxHeight(item, side, YES));
	TGMessageLayoutStampGeometry stamp = TGMessageLayoutPlaceStampBesideBox(
		item, context, stampBox, outgoing);
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

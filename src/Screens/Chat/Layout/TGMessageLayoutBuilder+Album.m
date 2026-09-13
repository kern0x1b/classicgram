#import "TGMessageLayoutBuilder+Private.h"
#import "TGMessageItem.h"
#import "TGChatLayoutContext.h"
#import "TGMessage.h"
#import "TGTheme.h"

TGMessageLayoutComputed TGMessageLayoutBuildAlbum(TGMessageItem *item,
	TGChatLayoutContext *context) {
	TGMessageLayoutComputed computed = TGMessageLayoutComputedZero();

	CGSize mosaic = item.mosaicSize;
	if (mosaic.height < 1)
		return computed;

	BOOL outgoing = item.message.outgoing;
	BOOL hasSender = item.senderDisplayName.length > 0;
	BOOL hasAvatar = TGMessageLayoutRowIsAvatarIndented(item, context);
	CGFloat senderH = hasSender ? 17 : 0;
	CGSize body = TGMessageLayoutBodySize(item, context);

	CGFloat inset = kMessageLayoutPadH;
	CGFloat contentW = MAX(mosaic.width, body.width);
	if (item.reactionChips.count)
		contentW = MAX(contentW, item.reactionRowSize.width);
	contentW = MAX(contentW, TGMessageLayoutSignatureWidth(item));
	CGFloat bubbleW = contentW + 2 * inset;
	CGFloat avatarShift = hasAvatar ? (kMessageLayoutAvatarSide + 4) : 0;
	CGFloat x = outgoing ? (context.tableWidth - bubbleW - 8 - avatarShift) : (8 + avatarShift);

	CGFloat headDecor = TGMessageLayoutHeadDecorationHeight(item);
	CGFloat footDecorNoPreview = TGMessageLayoutSignatureBlockHeight(item) +
		TGMessageLayoutReactionsBlockHeight(item, NO) +
		TGMessageLayoutCommentsBlockHeight(item);

	CGFloat topPad = (senderH < 0.5f && headDecor < 0.5f)
		? kMessageLayoutPadH
		: kMessageLayoutPadV;
	CGFloat bottomPad = (body.height < 0.5f && footDecorNoPreview < 0.5f)
		? kMessageLayoutPadH
		: kMessageLayoutPadV;
	bottomPad = TGMessageLayoutBubbleBottomPad(item, NO, bottomPad);

	CGFloat h = bottomPad + topPad + headDecor + footDecorNoPreview + mosaic.height +
		(body.height > 0 ? 4 : 0) + senderH;
	if (item.forwardDisplayName.length)
		h += 2;
	h += body.height;
	CGFloat bubbleH = MAX(h, kMessageLayoutBubbleMinH);

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
		computed.bubble.sender = CGRectMake(kMessageLayoutPadH, topPad,
			bubbleW - 2 * kMessageLayoutPadH, senderH - 1);
		computed.parts |= TGMessageLayoutPartSender;
	}
	if (hasAvatar) {
		computed.row.avatar = TGMessageLayoutAvatarFrame(computed.row.bubble, outgoing);
		computed.parts |= TGMessageLayoutPartAvatar;
	}

	CGFloat y = topPad + senderH;

	if (item.forwardDisplayName.length) {
		computed.bubble.forward = CGRectMake(kMessageLayoutPadH, y,
			MAX(bubbleW - 2 * kMessageLayoutPadH, 20), 16);
		computed.parts |= TGMessageLayoutPartForward;
		y += 18;
		y += 2;
	}

	if (item.quoteBodyText.length) {
		computed.bubble.quoteBar = CGRectMake(kMessageLayoutPadH, y, 2, 34);
		BOOL hasThumb = item.quoteThumbnailSize.width > 0 && item.quoteThumbnailSize.height > 0;
		CGFloat textX = kMessageLayoutPadH + (hasThumb ? 45 : 8);
		if (hasThumb) {
			computed.bubble.quoteThumb = CGRectMake(kMessageLayoutPadH + 7, y + 1, 32, 32);
			computed.parts |= TGMessageLayoutPartQuoteThumb;
		}
		CGFloat quoteW = MAX(bubbleW - textX - kMessageLayoutPadH, 40);
		computed.bubble.quoteAuthor = CGRectMake(textX, y, quoteW, 16);
		computed.bubble.quoteText = CGRectMake(textX, y + 17, quoteW, 17);
		computed.bubble.quoteTapTarget = CGRectMake(kMessageLayoutPadH, y,
			bubbleW - 2 * kMessageLayoutPadH, 38);
		computed.parts |= TGMessageLayoutPartQuote;
		y += 38;
	}

	computed.bubble.album = CGRectMake(inset, y, mosaic.width, mosaic.height);
	computed.parts |= TGMessageLayoutPartAlbum;

	NSInteger tileCount = MIN(item.mosaicTileCount, (NSInteger)kMessageLayoutMaxRows);
	for (NSInteger i = 0; i < tileCount; i++) {
		computed.repeatedRows[computed.repeatedRowCount++] = (TGMessageLayoutRepeatedRow){
			.frame = [item mosaicTileFrameAtIndex:i],
			.index = (uint16_t)[item mosaicTilePositionAtIndex:i],
			.kind = TGMessageLayoutRowAlbumTile,
		};
	}

	CGFloat afterAlbum = y + mosaic.height + (body.height > 0 ? 4 : 0);
	if (body.height > 0) {
		computed.bubble.body = CGRectMake(inset, afterAlbum, body.width, body.height);
		computed.parts |= TGMessageLayoutPartBody;
		afterAlbum += body.height;
	}

	if (item.signatureText.length) {
		CGFloat top = afterAlbum + kMessageLayoutSignatureTopGap;
		CGFloat available = MAX(bubbleW - 2 * kMessageLayoutPadH, 20);
		CGFloat textW = MIN(TGMessageLayoutSignatureWidth(item), available);
		computed.bubble.signature = CGRectMake(bubbleW - kMessageLayoutPadH - textW, top,
			textW, kMessageLayoutSignatureHeight);
		computed.parts |= TGMessageLayoutPartSignature;
		afterAlbum += kMessageLayoutSignatureTopGap + kMessageLayoutSignatureHeight;
	}

	TGMessageLayoutReactionGeometry reactions = TGMessageLayoutReactionBlock(
		item, afterAlbum, bubbleW, inset, NO, NO);
	if (reactions.present) {
		computed.bubble.reactions = reactions.frame;
		computed.parts |= TGMessageLayoutPartReactions;
	}

	TGMessageLayoutReactionGeometry comments = TGMessageLayoutCommentsBlock(
		item, afterAlbum + reactions.height, bubbleW, inset);
	if (comments.present) {
		computed.bubble.comments = comments.frame;
		computed.parts |= TGMessageLayoutPartComments;
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

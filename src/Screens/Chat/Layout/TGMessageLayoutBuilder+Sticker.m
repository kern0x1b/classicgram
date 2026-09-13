#import "TGMessageLayoutBuilder+Private.h"
#import "TGMessageItem.h"
#import "TGChatLayoutContext.h"
#import "TGMessage.h"
#import "TGChatMessageLayout.h"

TGMessageLayoutComputed TGMessageLayoutBuildSticker(TGMessageItem *item,
	TGChatLayoutContext *context) {
	TGMessageLayoutComputed computed = TGMessageLayoutComputedZero();

	BOOL outgoing = item.message.outgoing;
	BOOL hasSender = item.senderDisplayName.length > 0;
	BOOL hasAvatar = TGMessageLayoutRowIsAvatarIndented(item, context);
	CGFloat senderH = hasSender ? 17 : 0;

	CGSize body = TGMessageLayoutBodySize(item, context);
	CGSize picture = item.pictureSize;

	CGFloat headDecoration = TGMessageLayoutHeadDecorationHeight(item);
	CGFloat footDecoration = TGMessageLayoutFootDecorationHeight(item, context, YES);
	CGFloat decorationHeight = headDecoration + footDecoration;

	CGFloat topPad = (senderH < 0.5f && headDecoration < 0.5f)
		? kMessageLayoutPadH
		: kMessageLayoutPadV;
	BOOL mediaOnly = body.height < 0.5f && footDecoration < 0.5f;
	CGFloat bottomPad = TGMessageLayoutBubbleBottomPad(
		item, YES, mediaOnly ? kMessageLayoutPadH : kMessageLayoutPadV);

	CGFloat bubbleW = TGMessageLayoutGenericBubbleWidth(item, context, body, picture, NO);
	CGFloat avatarShift = hasAvatar ? (kMessageLayoutAvatarSide + 4) : 0;

	TGChatMessageLayout genericLayout = TGChatMessageLayoutMakeGeneric(
		body, picture, TGGapUnderMedia(body), senderH, topPad, bottomPad,
		decorationHeight, kMessageLayoutBubbleMinH,
		bubbleW, avatarShift, context.tableWidth, outgoing);

	computed.messageHeight = genericLayout.height;
	computed.row.bubble = genericLayout.bubbleFrame;
	computed.parts = TGMessageLayoutPartBubble;
	computed.sitsOnWallpaper = YES;
	computed.bubbleCornerRadius = 0;
	computed.bubbleBorderWidth = 0;

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

	CGFloat artWidth = picture.height > 0 ? picture.width : body.width;
	CGFloat artX = outgoing
		? MAX(kMessageLayoutPadH, bubbleW - kMessageLayoutPadH - artWidth)
		: kMessageLayoutPadH;

	computed.bubble.picture = CGRectMake(artX, y, picture.width, picture.height);
	computed.parts |= TGMessageLayoutPartPicture;

	y += picture.height + TGGapUnderMedia(body);

	CGSize previewSize = TGMessageLayoutLinkPreviewSize(item, context);
	BOOL previewAboveBody = previewSize.height > 0 && [item.linkPreview[@"showAboveText"] boolValue];
	if (previewAboveBody) {
		computed.bubble.preview = CGRectMake(kMessageLayoutPadH, y,
			bubbleW - 2 * kMessageLayoutPadH, previewSize.height);
		computed.parts |= TGMessageLayoutPartPreview;
		y += previewSize.height + 6;
	}

	computed.bubble.body = CGRectMake(artX, y, body.width, body.height);
	if (body.height > 0)
		computed.parts |= TGMessageLayoutPartBody;

	CGFloat afterBody = y + body.height;

	if (!previewAboveBody && previewSize.height > 0) {
		computed.bubble.preview = CGRectMake(kMessageLayoutPadH, afterBody + 6,
			bubbleW - 2 * kMessageLayoutPadH, previewSize.height);
		computed.parts |= TGMessageLayoutPartPreview;
		afterBody += previewSize.height + 6;
	}

	if (item.signatureText.length) {
		CGFloat top = afterBody + kMessageLayoutSignatureTopGap;
		CGFloat available = MAX(bubbleW - 2 * kMessageLayoutPadH, 20);
		CGFloat textW = MIN(TGMessageLayoutSignatureWidth(item), available);
		computed.bubble.signature = CGRectMake(bubbleW - kMessageLayoutPadH - textW, top,
			textW, kMessageLayoutSignatureHeight);
		computed.parts |= TGMessageLayoutPartSignature;
		afterBody += kMessageLayoutSignatureTopGap + kMessageLayoutSignatureHeight;
	}

	TGMessageLayoutReactionGeometry reactions = TGMessageLayoutReactionBlock(
		item, afterBody, bubbleW, kMessageLayoutPadH, outgoing, YES);
	if (reactions.present) {
		computed.bubble.reactions = reactions.frame;
		computed.parts |= TGMessageLayoutPartReactions;
	}

	TGMessageLayoutReactionGeometry comments = TGMessageLayoutCommentsBlock(
		item, afterBody + reactions.height, bubbleW, kMessageLayoutPadH);
	if (comments.present) {
		computed.bubble.comments = comments.frame;
		computed.parts |= TGMessageLayoutPartComments;
	}

	computed.parts |= TGMessageLayoutPartPlateBeside;
	CGRect stampBox = computed.row.bubble;
	stampBox.size.height -= TGMessageLayoutReactionsBlockHeight(item, YES) + comments.height;
	if (artWidth > 0) {
		stampBox.origin.x += artX;
		stampBox.size.width = artWidth;
	}
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

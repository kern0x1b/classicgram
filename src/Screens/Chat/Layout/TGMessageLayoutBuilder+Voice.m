#import "TGMessageLayoutBuilder+Private.h"
#import "TGMessageItem.h"
#import "TGChatLayoutContext.h"
#import "TGMessage.h"
#import "TGChatMessageLayout.h"
#import "TGTheme.h"

TGMessageLayoutComputed TGMessageLayoutBuildVoice(TGMessageItem *item,
	TGChatLayoutContext *context) {
	TGMessageLayoutComputed computed = TGMessageLayoutComputedZero();

	BOOL outgoing = item.message.outgoing;
	BOOL hasSender = item.senderDisplayName.length > 0;
	BOOL hasAvatar = TGMessageLayoutRowIsAvatarIndented(item, context);
	CGFloat senderH = hasSender ? 17 : 0;

	CGSize body = TGMessageLayoutBodySize(item, context);
	CGFloat bubbleW = TGMessageLayoutGenericBubbleWidth(item, context, body, CGSizeZero, YES);
	CGFloat avatarShift = hasAvatar ? (kMessageLayoutAvatarSide + 4) : 0;
	CGFloat x = outgoing ? (context.tableWidth - bubbleW - 8 - avatarShift) : (8 + avatarShift);

	CGFloat forwardH = item.forwardDisplayName.length ? 18 : 0;
	CGFloat reactionsH = TGMessageLayoutReactionsBlockHeight(item, NO);
	CGSize transcript = TGMessageLayoutTranscriptSize(item, context);
	CGFloat bubbleH = TGChatMessageLayoutVoiceHeight(senderH, forwardH, reactionsH, transcript.height);

	computed.messageHeight = bubbleH + 3;
	computed.row.bubble = CGRectMake(x, 0, bubbleW, bubbleH);
	computed.parts = TGMessageLayoutPartBubble;
	computed.sitsOnWallpaper = NO;

	BOOL tall = bubbleH >= 48.0f;
	BOOL hasArtwork = TGMessageLayoutBubbleArtworkExists(tall, outgoing);
	if (hasArtwork) {
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

	CGFloat localH = bubbleH - reactionsH - transcript.height;
	CGFloat disc = 36;
	CGFloat left = kMessageLayoutPadH + disc + 8;

	if (forwardH > 0) {
		computed.bubble.forward = CGRectMake(kMessageLayoutPadH, kMessageLayoutPadV + senderH,
			MAX(bubbleW - 2 * kMessageLayoutPadH, 20), 16);
		computed.parts |= TGMessageLayoutPartForward;
	}

	computed.bubble.disc = CGRectMake(kMessageLayoutPadH,
		senderH + forwardH + (localH - senderH - forwardH - disc) / 2, disc, disc);
	computed.parts |= TGMessageLayoutPartMediaDisc;

	CGSize waveSize = CGSizeMake(bubbleW - left - kMessageLayoutPadH, 18);
	computed.bubble.waveform = CGRectMake(left, senderH + forwardH + 10, waveSize.width, waveSize.height);
	computed.parts |= TGMessageLayoutPartWaveform;

	computed.bubble.body = CGRectMake(left, localH - 20, 44, 14);
	computed.parts |= TGMessageLayoutPartBody;

	CGFloat afterVoice = localH;
	if (transcript.height > 0) {
		computed.bubble.transcript = CGRectMake(kMessageLayoutPadH, localH,
			bubbleW - 2 * kMessageLayoutPadH,
			transcript.height - 8);
		computed.parts |= TGMessageLayoutPartTranscript;
		afterVoice = localH + transcript.height;
	}

	TGMessageLayoutReactionGeometry reactions = TGMessageLayoutReactionBlock(
		item, afterVoice, bubbleW, kMessageLayoutPadH, NO, NO);
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

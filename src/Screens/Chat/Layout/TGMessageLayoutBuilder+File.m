#import "TGMessageLayoutBuilder+Private.h"
#import "TGMessageItem.h"
#import "TGChatLayoutContext.h"
#import "TGMessage.h"
#import "TGTheme.h"

static const CGFloat kAudioPairHeight = 40.0f;
static const CGFloat kAudioClockGap = 10.0f;
static const CGFloat kAudioCoverDisc = 32.0f;
static const CGFloat kFileCellPairHeight = 38.0f;
static const CGFloat kAudioProgressLineHeight = 2.0f;

TGMessageLayoutComputed TGMessageLayoutBuildFile(TGMessageItem *item,
	TGChatLayoutContext *context) {
	TGMessageLayoutComputed computed = TGMessageLayoutComputedZero();

	BOOL outgoing = item.message.outgoing;
	BOOL isAudio = item.message.kind == TGMessageContentKindAudio;
	BOOL isContact = item.message.kind == TGMessageContentKindContact;
	BOOL hasThumb = item.fileShowsThumbnail;
	BOOL hasCover = item.fileHasCoverArt;
	BOOL hasSender = item.senderDisplayName.length > 0;
	BOOL hasAvatar = TGMessageLayoutRowIsAvatarIndented(item, context);
	CGFloat senderH = hasSender ? 17 : 0;
	CGFloat avatarShift = hasAvatar ? (kMessageLayoutAvatarSide + 4) : 0;

	CGFloat tile = item.fileTileSide;
	UIFont *titleFont = [UIFont systemFontOfSize:15];
	UIFont *metaFont = [UIFont systemFontOfSize:13];
	CGFloat textX = kMessageLayoutPadH + tile + 10;

	CGFloat clockW = isAudio
		? (kAudioClockGap + ceilf([item.audioClockTemplate sizeWithFont:metaFont].width))
		: 0;
	CGFloat textW = MAX(ceilf([item.fileTitleText sizeWithFont:titleFont].width),
		ceilf([item.fileMetaText sizeWithFont:metaFont].width) + clockW);
	textW = MAX(textW, 84.0f);

	CGFloat wanted = textX + textW + kMessageLayoutPadH +
		TGMessageLayoutStampGutterWidth(item.viewCountText, item.stampText, outgoing);
	CGFloat cap = TGMessageLayoutMaxBubbleWidth(item, context);
	CGFloat captionCap = item.fileCaptionText.length ? cap : 0;
	CGFloat chips = item.reactionRowSize.width;
	if (chips > 0)
		chips += 2 * kMessageLayoutPadH;
	CGFloat width = MIN(cap, MAX(MAX(wanted, captionCap), chips));

	CGFloat pairs = isAudio ? kAudioPairHeight : kFileCellPairHeight;
	CGFloat rows = MAX(tile, pairs);

	CGFloat captionMeasuredHeight = 0;
	CGFloat captionBlockHeight = 0;
	if (item.fileCaptionText.length) {
		CGSize measured = [item.fileCaptionText
				 sizeWithFont:TGMessageLayoutBodyFont(item, context)
			constrainedToSize:CGSizeMake(width - 2 * kMessageLayoutPadH, 10000)
				lineBreakMode:NSLineBreakByWordWrapping];
		captionMeasuredHeight = ceilf(measured.height);
		captionBlockHeight = captionMeasuredHeight + 4;
	}

	CGFloat forwardH = item.forwardDisplayName.length ? 18 : 0;
	CGFloat height = rows + kMessageLayoutPadV +
		TGMessageLayoutBubbleBottomPad(item, NO, kMessageLayoutPadV) +
		senderH + forwardH + captionBlockHeight + TGMessageLayoutReactionsBlockHeight(item, NO) +
		TGMessageLayoutCommentsBlockHeight(item);

	computed.messageHeight = height + 3;
	CGFloat x = outgoing ? (context.tableWidth - width - 8 - avatarShift) : (8 + avatarShift);
	computed.row.bubble = CGRectMake(x, 0, width, height);
	computed.parts = TGMessageLayoutPartBubble;
	computed.sitsOnWallpaper = NO;

	BOOL tall = height >= 48.0f;
	if (TGMessageLayoutBubbleArtworkExists(tall, outgoing)) {
		computed.parts |= TGMessageLayoutPartBubbleArtwork;
		computed.bubbleCornerRadius = 0;
		computed.bubbleBorderWidth = 0;
	} else {
		computed.bubbleCornerRadius = [TGTheme shared].bubbleCornerRadius;
		computed.bubbleBorderWidth = [TGTheme shared].bubbleBorderWidth;
		computed.parts |= TGMessageLayoutPartTail;
		computed.row.tail = outgoing
			? CGRectMake(x + width - 1, height - 10, 6, 10)
			: CGRectMake(x - 5, height - 10, 6, 10);
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

	if (forwardH > 0) {
		computed.bubble.forward = CGRectMake(kMessageLayoutPadH, kMessageLayoutPadV + senderH,
			MAX(width - 2 * kMessageLayoutPadH, 20), 16);
		computed.parts |= TGMessageLayoutPartForward;
	}
	CGFloat top = senderH + forwardH + kMessageLayoutPadV;

	BOOL showsPicture = isContact || hasThumb || (isAudio && hasCover);
	if (showsPicture) {
		computed.bubble.picture = CGRectMake(kMessageLayoutPadH, top, tile, tile);
		computed.parts |= TGMessageLayoutPartPicture;
	}

	if (!isContact) {
		CGFloat disc = hasThumb ? 36.0f : (hasCover ? kAudioCoverDisc : tile);
		computed.bubble.fileStatus = CGRectMake(kMessageLayoutPadH + (tile - disc) / 2,
			top + (tile - disc) / 2, disc, disc);
		computed.parts |= TGMessageLayoutPartFileStatus;
	}

	CGFloat pairTop = top + MAX((CGFloat)0, (tile - pairs) / 2);
	CGFloat metaW = textW;
	if (isAudio)
		metaW = MAX(20.0f, textW - kAudioClockGap - ceilf([item.audioClockTemplate sizeWithFont:metaFont].width));

	computed.bubble.body = CGRectMake(textX, pairTop, textW, 20);
	computed.parts |= TGMessageLayoutPartBody;
	computed.bubble.subtitle = CGRectMake(textX, pairTop + 19, metaW, 17);
	computed.parts |= TGMessageLayoutPartSubtitle;

	if (isAudio) {
		CGFloat right = width - kMessageLayoutPadH;
		CGFloat clockW = ceilf([item.audioClockTemplate sizeWithFont:metaFont].width);
		if (clockW > right - textX - kAudioClockGap)
			clockW = MAX((CGFloat)0, right - textX - kAudioClockGap);
		computed.bubble.audioClock = CGRectMake(right - clockW, pairTop + 19, clockW, 17);

		CGFloat lineWidth = MAX((CGFloat)8, right - textX);
		computed.bubble.waveform = CGRectMake(textX, pairTop + kAudioPairHeight - kAudioProgressLineHeight,
			lineWidth, kAudioProgressLineHeight);
	}

	CGFloat afterRow = top + rows;
	if (item.fileCaptionText.length) {
		computed.bubble.transcript = CGRectMake(kMessageLayoutPadH, afterRow + 4,
			width - 2 * kMessageLayoutPadH,
			captionMeasuredHeight);
		computed.parts |= TGMessageLayoutPartTranscript;
		afterRow += captionBlockHeight;
	}

	TGMessageLayoutReactionGeometry reactions = TGMessageLayoutReactionBlock(
		item, afterRow, width, kMessageLayoutPadH, NO, NO);
	if (reactions.present) {
		computed.bubble.reactions = reactions.frame;
		computed.parts |= TGMessageLayoutPartReactions;
	}

	TGMessageLayoutReactionGeometry comments = TGMessageLayoutCommentsBlock(
		item, afterRow + reactions.height, width, kMessageLayoutPadH);
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

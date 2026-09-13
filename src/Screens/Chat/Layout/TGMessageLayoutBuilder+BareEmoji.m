#import "TGMessageLayoutBuilder+Private.h"
#import "TGMessageItem.h"
#import "TGChatLayoutContext.h"
#import "TGMessage.h"
#import "TGEmoji.h"

static const CGFloat kBareEmojiFontSize = 94.0f;
static const CGFloat kBareEmojiMeasureWidth = 300.0f;

TGMessageLayoutComputed TGMessageLayoutBuildBareEmoji(TGMessageItem *item,
	TGChatLayoutContext *context) {
	TGMessageLayoutComputed computed = TGMessageLayoutComputedZero();

	BOOL outgoing = item.message.outgoing;
	BOOL hasSender = item.senderDisplayName.length > 0;
	BOOL hasAvatar = TGMessageLayoutRowIsAvatarIndented(item, context);
	CGFloat senderH = hasSender ? 17 : 0;

	UIFont *glyphFont = [UIFont systemFontOfSize:kBareEmojiFontSize];
	NSString *text = item.bodyText ?: @"";
	CGSize measured = TGEmojiTextSize(text, glyphFont,
		CGSizeMake(kBareEmojiMeasureWidth, kBareEmojiFontSize * 1.4f),
		NSLineBreakByClipping, 1);
	CGSize glyph = CGSizeMake(ceilf(measured.width), ceilf(measured.height));
	if (glyph.width < 1 || glyph.height < 1)
		glyph = CGSizeMake(kBareEmojiFontSize, kBareEmojiFontSize);

	CGFloat boxW = MAX(glyph.width, item.reactionRowSize.width);
	CGFloat avatarShift = hasAvatar ? (kMessageLayoutAvatarSide + 4) : 0;
	CGFloat boxX = outgoing ? (context.tableWidth - boxW - 8 - avatarShift) : (8 + avatarShift);
	CGFloat glyphX = outgoing ? (boxW - glyph.width) : 0;

	CGFloat tailH = TGMessageLayoutBareBoxTailHeight(item, YES);
	CGFloat boxH = senderH + glyph.height + tailH;

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

	computed.bubble.body = CGRectMake(glyphX, senderH, glyph.width, glyph.height);
	computed.parts |= TGMessageLayoutPartBody;

	CGFloat contentBottom = senderH + glyph.height;
	TGMessageLayoutReactionGeometry reactions = TGMessageLayoutReactionBlock(
		item, contentBottom, boxW, 0, outgoing, YES);
	if (reactions.present) {
		computed.bubble.reactions = reactions.frame;
		computed.parts |= TGMessageLayoutPartReactions;
	}

	computed.parts |= TGMessageLayoutPartPlateBeside;
	CGRect stampBox = CGRectMake(boxX + glyphX, senderH, glyph.width,
		TGMessageLayoutBareStampBoxHeight(item, glyph.height, YES));
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

#import "TGMessageLayoutBuilder+Private.h"
#import "TGMessageItem.h"
#import "TGChatLayoutContext.h"
#import "TGMessage.h"
#import "TGPollContent.h"
#import "TGPollOption.h"
#import "TGTheme.h"

static const CGFloat kPollRow = 30.0f;
static const CGFloat kPollBottomPad = 18.0f;

TGMessageLayoutComputed TGMessageLayoutBuildPoll(TGMessageItem *item,
	TGChatLayoutContext *context) {
	TGMessageLayoutComputed computed = TGMessageLayoutComputedZero();

	BOOL outgoing = item.message.outgoing;
	TGPollContent *poll = (TGPollContent *)item.message.content;
	NSString *question = item.pollQuestionText;
	NSArray<TGPollOption *> *options = poll.options;

	BOOL canRetract = NO;
	if (!poll.closed && !poll.quiz && poll.allowsRevoting) {
		for (TGPollOption *option in options) {
			if (option.chosen) {
				canRetract = YES;
				break;
			}
		}
	}
	BOOL canAdd = !poll.closed && poll.canAddOption;

	BOOL hasSender = item.senderDisplayName.length > 0;
	BOOL hasAvatar = TGMessageLayoutRowIsAvatarIndented(item, context);
	CGFloat senderH = hasSender ? 17 : 0;
	CGFloat avatarShift = hasAvatar ? (kMessageLayoutAvatarSide + 4) : 0;

	CGFloat width = TGMessageLayoutMaxBubbleWidth(item, context);
	CGFloat x = outgoing ? (context.tableWidth - width - 8 - avatarShift) : (8 + avatarShift);

	CGSize qs = [question sizeWithFont:[UIFont boldSystemFontOfSize:15]
					 constrainedToSize:CGSizeMake(width - 2 * kMessageLayoutPadH, 200)
						 lineBreakMode:NSLineBreakByWordWrapping];

	computed.bubble.body = CGRectMake(kMessageLayoutPadH, kMessageLayoutPadV + senderH,
		width - 2 * kMessageLayoutPadH, qs.height);
	computed.parts |= TGMessageLayoutPartBody;
	computed.bubble.subtitle = CGRectMake(kMessageLayoutPadH,
		kMessageLayoutPadV + senderH + qs.height + 2,
		width - 2 * kMessageLayoutPadH, 16);
	computed.parts |= TGMessageLayoutPartSubtitle;

	CGFloat y = kMessageLayoutPadV + senderH + qs.height + 22;
	NSInteger optionCount = MIN(options.count, (NSInteger)kMessageLayoutMaxRows);
	for (NSInteger i = 0; i < optionCount; i++) {
		computed.repeatedRows[computed.repeatedRowCount++] = (TGMessageLayoutRepeatedRow){
			.frame = CGRectMake(kMessageLayoutPadH, y, width - 2 * kMessageLayoutPadH, kPollRow),
			.index = (uint16_t)i,
			.kind = TGMessageLayoutRowPollOption,
		};
		y += kPollRow;
	}
	if (canAdd && computed.repeatedRowCount < kMessageLayoutMaxRows) {
		computed.repeatedRows[computed.repeatedRowCount++] = (TGMessageLayoutRepeatedRow){
			.frame = CGRectMake(kMessageLayoutPadH, y, width - 2 * kMessageLayoutPadH, kPollRow),
			.index = 0,
			.kind = TGMessageLayoutRowPollAdd,
		};
		y += kPollRow;
	}
	if (canRetract && computed.repeatedRowCount < kMessageLayoutMaxRows) {
		computed.repeatedRows[computed.repeatedRowCount++] = (TGMessageLayoutRepeatedRow){
			.frame = CGRectMake(kMessageLayoutPadH, y, width - 2 * kMessageLayoutPadH, 22),
			.index = 0,
			.kind = TGMessageLayoutRowPollRetract,
		};
		y += 24;
	}

	BOOL quizAnswered = poll.quiz && poll.correctOptionId >= 0;
	if (quizAnswered && poll.explanation.length &&
		computed.repeatedRowCount < kMessageLayoutMaxRows) {
		CGSize es = [poll.explanation sizeWithFont:[UIFont systemFontOfSize:13]
								 constrainedToSize:CGSizeMake(width - 2 * kMessageLayoutPadH, 400)
									 lineBreakMode:NSLineBreakByWordWrapping];
		CGFloat explanationH = es.height + 10;
		computed.repeatedRows[computed.repeatedRowCount++] = (TGMessageLayoutRepeatedRow){
			.frame = CGRectMake(kMessageLayoutPadH, y, width - 2 * kMessageLayoutPadH, explanationH),
			.index = 0,
			.kind = TGMessageLayoutRowPollExplanation,
		};
		y += explanationH;
	}

	TGMessageLayoutReactionGeometry reactions = TGMessageLayoutReactionBlock(
		item, y, width, kMessageLayoutPadH, NO, NO);
	CGFloat bottomPad = reactions.present ? reactions.height : kPollBottomPad;
	CGFloat bubbleH = y + bottomPad;

	computed.messageHeight = bubbleH + 3;
	computed.row.bubble = CGRectMake(x, 0, width, bubbleH);
	computed.parts |= TGMessageLayoutPartBubble;
	computed.sitsOnWallpaper = NO;
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

#import "TGMessageLayoutBuilder+Private.h"
#import "TGMessageItem.h"
#import "TGChatLayoutContext.h"
#import "TGMessage.h"
#import "TGChecklistContent.h"
#import "TGChecklistTask.h"
#import "TGTheme.h"

static const CGFloat kChecklistRow = 26.0f;
static const CGFloat kChecklistBottomPad = 14.0f;

TGMessageLayoutComputed TGMessageLayoutBuildChecklist(TGMessageItem *item,
	TGChatLayoutContext *context) {
	TGMessageLayoutComputed computed = TGMessageLayoutComputedZero();

	BOOL outgoing = item.message.outgoing;
	TGChecklistContent *checklist = (TGChecklistContent *)item.message.content;
	NSString *title = item.checklistTitleText;
	NSArray<TGChecklistTask *> *tasks = checklist.tasks;

	BOOL hasSender = item.senderDisplayName.length > 0;
	BOOL hasAvatar = TGMessageLayoutRowIsAvatarIndented(item, context);
	CGFloat senderH = hasSender ? 17 : 0;
	CGFloat avatarShift = hasAvatar ? (kMessageLayoutAvatarSide + 4) : 0;

	CGFloat width = TGMessageLayoutMaxBubbleWidth(item, context);
	CGFloat x = outgoing ? (context.tableWidth - width - 8 - avatarShift) : (8 + avatarShift);

	CGSize ts = [title sizeWithFont:[UIFont boldSystemFontOfSize:15]
				  constrainedToSize:CGSizeMake(width - 2 * kMessageLayoutPadH, 200)
					  lineBreakMode:NSLineBreakByWordWrapping];

	computed.bubble.body = CGRectMake(kMessageLayoutPadH, kMessageLayoutPadV + senderH,
		width - 2 * kMessageLayoutPadH, ts.height);
	computed.parts |= TGMessageLayoutPartBody;

	CGFloat y = kMessageLayoutPadV + senderH + ts.height + 10;
	NSInteger taskCount = MIN(tasks.count, (NSInteger)kMessageLayoutMaxRows);
	for (NSInteger i = 0; i < taskCount; i++) {
		computed.repeatedRows[computed.repeatedRowCount++] = (TGMessageLayoutRepeatedRow){
			.frame = CGRectMake(kMessageLayoutPadH, y, width - 2 * kMessageLayoutPadH, kChecklistRow),
			.index = (uint16_t)i,
			.kind = TGMessageLayoutRowChecklistTask,
		};
		y += kChecklistRow;
	}
	if (checklist.canAddTasks && computed.repeatedRowCount < kMessageLayoutMaxRows) {
		computed.repeatedRows[computed.repeatedRowCount++] = (TGMessageLayoutRepeatedRow){
			.frame = CGRectMake(kMessageLayoutPadH, y, width - 2 * kMessageLayoutPadH, kChecklistRow),
			.index = 0,
			.kind = TGMessageLayoutRowChecklistAdd,
		};
		y += kChecklistRow;
	}

	TGMessageLayoutReactionGeometry reactions = TGMessageLayoutReactionBlock(
		item, y, width, kMessageLayoutPadH, NO, NO);
	CGFloat bottomPad = reactions.present ? reactions.height : kChecklistBottomPad;
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

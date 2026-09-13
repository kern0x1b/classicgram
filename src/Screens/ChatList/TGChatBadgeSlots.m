#import "TGChatBadgeSlots.h"

static const CGFloat kBadgeRightInset = 28.0f;
static const CGFloat kBadgeTop = 29.0f;
static const CGFloat kBadgeHeight = 21.0f;
static const CGFloat kBadgeMinWidth = 27.0f;
static const CGFloat kBadgeGap = 6.0f;
static const CGFloat kBadgeTrailingGap = 7.0f;

TGChatBadgeSlots TGChatBadgeSlotsInWidth(CGFloat width,
	CGFloat countTextWidth,
	BOOL hasCount,
	BOOL hasMention,
	BOOL hasReaction,
	BOOL hasPin) {
	TGChatBadgeSlots slots;
	slots.count = CGRectZero;
	slots.mention = CGRectZero;
	slots.reaction = CGRectZero;
	slots.pin = CGRectZero;
	slots.consumedWidth = 0;

	CGFloat cursor = width - kBadgeRightInset;
	CGFloat used = 0;

	CGFloat countWidth = MAX(kBadgeMinWidth, countTextWidth + 10.0f);
	slots.count = CGRectMake(cursor - countWidth, kBadgeTop, countWidth, kBadgeHeight);
	if (hasCount) {
		cursor -= countWidth + kBadgeGap;
		used += countWidth + kBadgeGap;
	}

	if (hasMention) {
		slots.mention = CGRectMake(cursor - kBadgeMinWidth, kBadgeTop, kBadgeMinWidth, kBadgeHeight);
		cursor -= kBadgeMinWidth + kBadgeGap;
		used += kBadgeMinWidth + kBadgeGap;
	}

	if (hasReaction) {
		slots.reaction = CGRectMake(cursor - kBadgeMinWidth, kBadgeTop, kBadgeMinWidth, kBadgeHeight);
		cursor -= kBadgeMinWidth + kBadgeGap;
		used += kBadgeMinWidth + kBadgeGap;
	}

	if (hasPin && !hasCount && !hasMention && !hasReaction) {
		slots.pin = CGRectMake(cursor - kBadgeMinWidth, kBadgeTop, kBadgeMinWidth, kBadgeHeight);
		used += kBadgeMinWidth + kBadgeGap;
	}

	if (used > 0)
		slots.consumedWidth = used - kBadgeGap + kBadgeTrailingGap;

	return slots;
}

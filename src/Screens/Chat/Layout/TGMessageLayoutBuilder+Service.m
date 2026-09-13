#import "TGMessageLayoutBuilder+Private.h"
#import "TGMessageItem.h"
#import "TGChatLayoutContext.h"
#import "TGMessage.h"
#import "TGEmoji.h"

static const CGFloat kServicePhotoSide = 70.0f;
static const CGFloat kServicePhotoGap = 8.0f;
static const CGFloat kSystemPlateHeight = 21.0f;

TGMessageLayoutComputed TGMessageLayoutBuildService(TGMessageItem *item,
	TGChatLayoutContext *context) {
	TGMessageLayoutComputed computed = TGMessageLayoutComputedZero();

	CGFloat full = context.tableWidth;
	NSString *line = item.serviceLineText;
	UIFont *font = [UIFont boldSystemFontOfSize:13];
	CGFloat limit = MAX(full - 60, 60);
	CGSize text = line.length
		? TGEmojiTextSize(line, font, CGSizeMake(limit, 10000), NSLineBreakByWordWrapping, 0)
		: CGSizeZero;

	CGFloat oneLine = font.lineHeight;
	CGFloat grown = 0;
	if (oneLine >= 1 && text.height > 0) {
		NSInteger lines = (NSInteger)floorf(text.height / oneLine + 0.5f);
		grown = lines > 1 ? ceilf((lines - 1) * oneLine) : 0;
	}

	CGFloat plateW = MIN(text.width, full - 60) + 20;
	CGFloat plateH = kSystemPlateHeight + grown;
	CGFloat side = item.pictureSize.width > 0 ? kServicePhotoSide : 0;

	computed.messageHeight = kMessageLayoutDayRowHeight + grown +
		(side > 0 ? side + kServicePhotoGap : 0);

	computed.row.bubble = CGRectMake(floorf((full - plateW) / 2),
		floorf((kMessageLayoutDayRowHeight - kSystemPlateHeight) / 2), plateW, plateH);

	computed.bubble.body = CGRectMake(0, 1, plateW, plateH - 2);
	computed.parts = TGMessageLayoutPartBubble | TGMessageLayoutPartBody;
	if (side > 0) {
		computed.bubble.picture = CGRectMake(floorf((plateW - side) / 2),
			plateH + kServicePhotoGap, side, side);
		computed.parts |= TGMessageLayoutPartPicture;
	}

	computed.bubbleCornerRadius = kSystemPlateHeight / 2;
	computed.bubbleBorderWidth = 0;
	computed.sitsOnWallpaper = NO;
	return computed;
}

#import "TGChatTitleMute.h"

const CGFloat kTGChatTitleMuteIconGap = 4.0f;

static const CGFloat kIconTopOffset = 6.0f;
static const CGFloat kMinimumTitleWidth = 20.0f;

CGFloat TGChatTitleWidthWithMuteIcon(CGFloat width, CGFloat iconWidth, CGFloat maxWidth) {
	CGFloat room = iconWidth + kTGChatTitleMuteIconGap;
	if (width + room <= maxWidth)
		return width;
	return MAX(kMinimumTitleWidth, maxWidth - room);
}

CGRect TGChatTitleMuteIconFrame(CGFloat titleWidth, CGFloat nameTextWidth, CGSize iconSize,
	CGFloat nameTop) {
	CGFloat textWidth = MIN(titleWidth, nameTextWidth);
	CGFloat left = (titleWidth - textWidth) / 2 + textWidth + kTGChatTitleMuteIconGap;
	return CGRectMake(left, nameTop + kIconTopOffset, iconSize.width, iconSize.height);
}

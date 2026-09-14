#import "TGChatTitlePremium.h"

const CGFloat kTGChatTitlePremiumSide = 16.0f;

static const CGFloat kPremiumTopOffset = 4.0f;
static const CGFloat kPremiumIconGap = 4.0f;

static BOOL TGChatTitlePremiumBool(id value) {
	return [value isKindOfClass:NSNumber.class] && [value boolValue];
}

BOOL TGChatTitleShowsPremium(NSDictionary *badges) {
	if (![badges isKindOfClass:NSDictionary.class])
		return NO;
	return TGChatTitlePremiumBool(badges[@"isPremium"]);
}

CGFloat TGChatTitlePremiumRoom(CGFloat iconWidth) {
	if (iconWidth <= 0.0f)
		return 0.0f;
	return iconWidth + kPremiumIconGap;
}

CGRect TGChatTitlePremiumFrame(CGFloat titleWidth, CGFloat precedingWidth, CGSize iconSize,
	CGFloat nameTop) {
	CGFloat textWidth = MIN(titleWidth, precedingWidth);
	CGFloat left = (titleWidth - textWidth) / 2 + textWidth + kPremiumIconGap;
	return CGRectMake(left, nameTop + kPremiumTopOffset, iconSize.width, iconSize.height);
}

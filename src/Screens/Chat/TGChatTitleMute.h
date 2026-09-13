#import <UIKit/UIKit.h>

extern const CGFloat kTGChatTitleMuteIconGap;

CGFloat TGChatTitleWidthWithMuteIcon(CGFloat width, CGFloat iconWidth, CGFloat maxWidth);
CGRect TGChatTitleMuteIconFrame(CGFloat titleWidth, CGFloat nameTextWidth, CGSize iconSize,
	CGFloat nameTop);

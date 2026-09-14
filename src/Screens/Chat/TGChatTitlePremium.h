#import <UIKit/UIKit.h>

BOOL TGChatTitleShowsPremium(NSDictionary *badges);

CGFloat TGChatTitlePremiumRoom(CGFloat iconWidth);

CGRect TGChatTitlePremiumFrame(CGFloat titleWidth, CGFloat precedingWidth, CGSize iconSize,
	CGFloat nameTop);

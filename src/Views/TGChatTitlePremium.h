#import <UIKit/UIKit.h>

extern const CGFloat kTGChatTitlePremiumSide;

UIImage *TGChatTitlePremiumImage(void);

BOOL TGChatTitleShowsPremium(NSDictionary *badges);

CGFloat TGChatTitlePremiumRoom(CGFloat iconWidth);

CGRect TGChatTitlePremiumFrame(CGFloat titleWidth, CGFloat precedingWidth, CGSize iconSize,
	CGFloat nameTop);

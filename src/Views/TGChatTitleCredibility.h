#import <UIKit/UIKit.h>

NSString *TGChatTitleCredibilityMark(NSDictionary *badges);

BOOL TGChatTitleCredibilityMarkIsWarning(NSDictionary *badges);

CGFloat TGChatTitleCredibilityRoom(CGFloat markWidth);

CGRect TGChatTitleCredibilityFrame(CGFloat titleWidth, CGFloat nameTextWidth, CGSize markSize,
	CGFloat nameTop);

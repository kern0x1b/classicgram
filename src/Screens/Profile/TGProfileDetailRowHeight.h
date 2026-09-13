#import <UIKit/UIKit.h>

extern const CGFloat kTGProfileDetailValueLeft;

CGFloat TGProfileDetailValueWidthForContentWidth(CGFloat contentWidth);
CGFloat TGProfileDetailValueHeight(NSString *value, UIFont *font, CGFloat contentWidth);
CGFloat TGProfileDetailRowHeightForValue(NSString *value, UIFont *font, CGFloat contentWidth);

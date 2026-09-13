#import <UIKit/UIKit.h>

UIImage *TGQRCodeImage(NSString *text, CGFloat maximumSide);

@interface TGQRCodeView : UIView
@property (nonatomic, copy) NSString *text;
@end

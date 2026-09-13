#import <UIKit/UIKit.h>

@interface TGContactsProgressWindow : NSObject
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIView *containerView;
- (void)show;
- (void)dismiss;
@end

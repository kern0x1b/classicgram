#import <UIKit/UIKit.h>

@interface TGWebViewController : UIViewController <UIWebViewDelegate>

- (instancetype)initWithURLString:(NSString *)urlString;

+ (BOOL)openURLString:(NSString *)urlString fromViewController:(UIViewController *)viewController;

+ (UIViewController *)controllerForURLString:(NSString *)urlString;

@end

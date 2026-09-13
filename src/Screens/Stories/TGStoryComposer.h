#import <UIKit/UIKit.h>

@interface TGStoryComposer : NSObject

+ (void)presentFrom:(UIViewController *)controller
		 completion:(void (^)(BOOL posted))completion;

+ (void)cancelAllForAccountSwitch;

@end

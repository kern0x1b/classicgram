#import <UIKit/UIKit.h>

@interface TGMusicPlayerBar : UIView

+ (void)activate;

+ (void)setHostProvider:(UIView * (^)(void))provider;
+ (void)setFullPlayerPresenter:(void (^)(void))presenter;

+ (CGFloat)barHeight;

@end

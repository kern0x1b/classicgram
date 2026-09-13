#import <UIKit/UIKit.h>

#import "TGReusableView.h"

@interface TGViewRecycler : NSObject

- (UIView<TGReusableView> *)dequeueReusableViewWithIdentifier:(NSString *)reuseIdentifier;
- (void)recycleView:(UIView<TGReusableView> *)view;
- (void)removeAllViews;

@end

#import "UIView+SafeTint.h"

@implementation UIView (SafeTint)

- (void)tg_setTintColor:(UIColor *)color {
	if ([self respondsToSelector:@selector(setTintColor:)])
		[self performSelector:@selector(setTintColor:) withObject:color];
}

@end

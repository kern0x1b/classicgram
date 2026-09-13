#import "TGTabsContainerViewDelegate.h"

@implementation TGTabsContainerViewDelegate

- (void)layoutSubviews:(UIView *)view {
	static Class containerClass = NULL;
	static Class transitionViewClass = NULL;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		containerClass = NSClassFromString(@"UILayoutContainerView");
		transitionViewClass = NSClassFromString(@"UITransitionView");
	});

	if ([view isKindOfClass:containerClass]) {
		for (UIView *subview in view.subviews) {
			if ([subview isKindOfClass:transitionViewClass]) {
				subview.frame = view.bounds;
				break;
			}
		}
	} else {
		for (UIView *subview in view.subviews)
			subview.frame = view.bounds;
	}
}

@end

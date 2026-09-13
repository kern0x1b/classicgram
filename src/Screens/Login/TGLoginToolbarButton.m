#import "TGLoginToolbarButton.h"

@implementation TGLoginToolbarButton

- (CGRect)backgroundRectForBounds:(CGRect)bounds {
	CGRect frame = [super backgroundRectForBounds:bounds];
	if (_backSemantics) {
		frame.origin.x -= 1;
		frame.size.width += 1;
		if ([UIScreen mainScreen].scale > 1.0f)
			frame.origin.y += 0.5f;
	}
	return frame;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(__unused UIEvent *)event {
	if (self.alpha < 0.01f || self.hidden)
		return nil;
	if (CGRectContainsPoint(CGRectInset(self.bounds, -8, -8), point))
		return self;
	return nil;
}

@end

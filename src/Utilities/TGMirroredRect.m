#import "TGMirroredRect.h"

CGRect TGMirroredRectInContainer(CGRect rect, CGFloat containerWidth, BOOL isRightToLeft) {
	if (!isRightToLeft)
		return rect;
	return CGRectMake(containerWidth - rect.origin.x - rect.size.width,
		rect.origin.y, rect.size.width, rect.size.height);
}

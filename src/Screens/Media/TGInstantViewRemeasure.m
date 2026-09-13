#import "TGInstantViewRemeasure.h"

BOOL TGInstantViewNeedsRemeasure(CGFloat currentWidth, CGFloat measuredWidth, NSUInteger blockCount) {
	if (blockCount == 0 || currentWidth < 1)
		return NO;
	return fabs(currentWidth - measuredWidth) > 0.5f;
}

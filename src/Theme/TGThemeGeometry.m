#import "TGThemeGeometry.h"
#import <math.h>

void TGWallpaperGradientPoints(CGFloat rotationDegrees, CGSize size, CGPoint *startPoint, CGPoint *endPoint) {
	CGFloat radians = (CGFloat)((double)rotationDegrees * M_PI / 180.0);
	CGFloat dx = (CGFloat)sin(radians);
	CGFloat dy = (CGFloat)cos(radians);
	CGPoint startFraction = CGPointMake(0.5f - dx / 2.0f, 0.5f - dy / 2.0f);
	CGPoint endFraction = CGPointMake(0.5f + dx / 2.0f, 0.5f + dy / 2.0f);
	if (startPoint)
		*startPoint = CGPointMake(startFraction.x * size.width, startFraction.y * size.height);
	if (endPoint)
		*endPoint = CGPointMake(endFraction.x * size.width, endFraction.y * size.height);
}

CGFloat TGGroupedCommentInset(CGFloat width) {
	if (width < 400.0f)
		return 0.0f;
	return (CGFloat)(int)((width - MIN(width, 678.0f)) / 2.0f);
}

#import "TGLiveLocationFix.h"

NSInteger TGLiveLocationHeadingFromCourse(double course) {
	if (course < 0)
		return 0;
	NSInteger heading = (NSInteger)(course + 0.5);
	if (heading <= 0)
		heading = 360;
	if (heading > 360)
		heading = 360;
	return heading;
}

double TGLiveLocationAccuracyFromFix(double accuracy) {
	return accuracy < 0 ? 0.0 : accuracy;
}

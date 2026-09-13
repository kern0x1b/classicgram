#import "TGDayWindow.h"

#import "TGDateDayDifference.h"

BOOL TGTimestampFallsOnDayStartingAt(NSTimeInterval when, NSTimeInterval dayStart) {
	if (when < dayStart)
		return NO;

	time_t whenSeconds = (time_t)when;
	time_t daySeconds = (time_t)dayStart;
	struct tm whenParts;
	struct tm dayParts;
	localtime_r(&whenSeconds, &whenParts);
	localtime_r(&daySeconds, &dayParts);
	return TGDateDayDifference(whenParts, dayParts) == 0;
}

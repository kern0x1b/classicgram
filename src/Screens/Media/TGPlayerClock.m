#import "TGPlayerClock.h"
#import "TGDurationText.h"

NSString *TGPlayerClock(NSTimeInterval seconds, BOOL negative) {
	if (seconds < 0 || seconds != seconds || seconds > 359999)
		seconds = 0;
	NSInteger total = (int)(seconds + 0.5);
	return [NSString stringWithFormat:@"%@%@", negative ? @"-" : @"",
		TGDurationText(total)];
}

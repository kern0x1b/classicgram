#import "TGDurationText.h"

NSString *TGDurationText(NSInteger seconds) {
	if (seconds < 0)
		seconds = 0;
	if (seconds >= 3600)
		return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)(seconds / 3600),
			(long)((seconds % 3600) / 60), (long)(seconds % 60)];
	return [NSString stringWithFormat:@"%ld:%02ld", (long)(seconds / 60), (long)(seconds % 60)];
}

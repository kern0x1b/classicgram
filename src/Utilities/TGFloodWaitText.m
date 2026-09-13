#import "TGFloodWaitText.h"
#import "TGLocalization.h"

NSString *TGFloodWaitNoticeText(NSInteger seconds) {
	if (seconds <= 0)
		return nil;
	if (seconds < 60)
		return TGLPlural(@"FloodWait.Seconds", seconds,
				@"Too many attempts. Try again in %ld second.",
				@"Too many attempts. Try again in %ld seconds.");
	NSInteger minutes = (seconds + 59) / 60;
	return TGLPlural(@"FloodWait.Minutes", minutes,
			@"Too many attempts. Try again in %ld minute.",
			@"Too many attempts. Try again in %ld minutes.");
}

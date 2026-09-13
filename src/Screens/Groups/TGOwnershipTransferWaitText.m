#import "TGOwnershipTransferWaitText.h"
#import "TGLocalization.h"

NSString *TGOwnershipTransferRetryDurationText(NSInteger retryAfterSeconds) {
	NSInteger seconds = MAX(retryAfterSeconds, (NSInteger)1);
	if (seconds < 60)
		return TGLPlural(@"MessageTimer.Seconds", seconds, @"%ld second", @"%ld seconds");
	if (seconds < 3600)
		return TGLPlural(@"MessageTimer.Minutes", seconds / 60, @"%ld minute", @"%ld minutes");
	if (seconds < 86400)
		return TGLPlural(@"MessageTimer.Hours", seconds / 3600, @"%ld hour", @"%ld hours");
	return TGLPlural(@"MessageTimer.Days", seconds / 86400, @"%ld day", @"%ld days");
}

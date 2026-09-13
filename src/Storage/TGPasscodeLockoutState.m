#import "TGPasscodeLockoutState.h"

const NSInteger TGPasscodeLockoutThreshold = 6;
const NSTimeInterval TGPasscodeLockoutDuration = 60.0;

NSTimeInterval TGPasscodeLockoutRemainingSeconds(NSInteger failedAttempts,
	NSTimeInterval lastFailureAt, NSTimeInterval now,
	NSTimeInterval lastFailureMonotonic, NSTimeInterval nowMonotonic) {
	if (failedAttempts < TGPasscodeLockoutThreshold)
		return 0;
	NSTimeInterval elapsed = now - lastFailureAt;
	if (lastFailureMonotonic > 0) {
		NSTimeInterval monotonicElapsed = nowMonotonic - lastFailureMonotonic;
		if (monotonicElapsed >= 0 && monotonicElapsed < elapsed)
			elapsed = monotonicElapsed;
	}
	NSTimeInterval remaining = TGPasscodeLockoutDuration - elapsed;
	if (remaining > TGPasscodeLockoutDuration)
		remaining = TGPasscodeLockoutDuration;
	return remaining > 0 ? remaining : 0;
}

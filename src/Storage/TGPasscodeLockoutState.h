#import <Foundation/Foundation.h>

extern const NSInteger TGPasscodeLockoutThreshold;
extern const NSTimeInterval TGPasscodeLockoutDuration;

NSTimeInterval TGPasscodeLockoutRemainingSeconds(NSInteger failedAttempts,
	NSTimeInterval lastFailureAt, NSTimeInterval now,
	NSTimeInterval lastFailureMonotonic, NSTimeInterval nowMonotonic);

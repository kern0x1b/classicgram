#import "TGLiveLocationExpiry.h"

BOOL TGLiveLocationHasExpired(NSInteger livePeriod, NSTimeInterval expiresAt, NSTimeInterval now) {
	if (livePeriod <= 0)
		return NO;
	return expiresAt <= now;
}

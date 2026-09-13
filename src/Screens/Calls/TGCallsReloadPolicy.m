#import "TGCallsReloadPolicy.h"

const NSTimeInterval TGCallsLoadStallSeconds = 20.0;
const NSTimeInterval TGCallsFreshSeconds = 20.0;

BOOL TGCallsShouldReloadOnAppear(BOOL loading, NSTimeInterval secondsSinceLoadStarted,
	BOOL loadedOnce, NSTimeInterval secondsSinceLoaded) {
	if (loading)
		return secondsSinceLoadStarted >= TGCallsLoadStallSeconds;
	if (!loadedOnce)
		return YES;
	return secondsSinceLoaded > TGCallsFreshSeconds;
}

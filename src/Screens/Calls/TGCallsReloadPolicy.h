#import <Foundation/Foundation.h>

extern const NSTimeInterval TGCallsLoadStallSeconds;
extern const NSTimeInterval TGCallsFreshSeconds;

BOOL TGCallsShouldReloadOnAppear(BOOL loading, NSTimeInterval secondsSinceLoadStarted,
	BOOL loadedOnce, NSTimeInterval secondsSinceLoaded);

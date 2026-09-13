#import <Foundation/Foundation.h>

extern const long long TGStorageCachePolicyEffectivelyUnlimitedBytes;
extern const NSInteger TGStorageCachePolicyEffectivelyUnlimitedTTLSeconds;

typedef struct {
	BOOL shouldRun;
	long long effectiveMaxBytes;
	NSInteger effectiveTTLSeconds;
} TGStorageCachePolicyEffectiveLimits;

extern TGStorageCachePolicyEffectiveLimits TGStorageCachePolicyEffectiveLimitsForPolicy(
		long long maxBytes, NSInteger ttlSeconds);

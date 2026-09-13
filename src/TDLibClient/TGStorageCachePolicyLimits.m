#import "TGStorageCachePolicyLimits.h"

const long long TGStorageCachePolicyEffectivelyUnlimitedBytes = 1LL << 50;
const NSInteger TGStorageCachePolicyEffectivelyUnlimitedTTLSeconds = 2147483647;

TGStorageCachePolicyEffectiveLimits TGStorageCachePolicyEffectiveLimitsForPolicy(
		long long maxBytes, NSInteger ttlSeconds) {
	BOOL sizeUnlimited = maxBytes < 0;
	BOOL ttlUnlimited = ttlSeconds < 0;

	TGStorageCachePolicyEffectiveLimits limits;
	limits.shouldRun = !(sizeUnlimited && ttlUnlimited);
	limits.effectiveMaxBytes = sizeUnlimited ? TGStorageCachePolicyEffectivelyUnlimitedBytes : maxBytes;
	limits.effectiveTTLSeconds = ttlUnlimited ? TGStorageCachePolicyEffectivelyUnlimitedTTLSeconds : ttlSeconds;
	return limits;
}

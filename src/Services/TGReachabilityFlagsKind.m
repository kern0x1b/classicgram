#import "TGReachabilityFlagsKind.h"

NSString *TGReachabilityNetworkTypeKindForFlags(SCNetworkReachabilityFlags flags) {
	if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
		return @"none";
	BOOL requiresConnection = (flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0;
	BOOL canConnectAutomatically =
		(flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0 ||
		(flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0;
	BOOL needsUserIntervention = (flags & kSCNetworkReachabilityFlagsInterventionRequired) != 0;
	if (requiresConnection && (!canConnectAutomatically || needsUserIntervention))
		return @"none";
	if ((flags & TGReachabilityFlagIsWWAN) != 0)
		return @"mobile";
	return @"wifi";
}

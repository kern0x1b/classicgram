#import "tg_reachability_tests.h"
#import "../../src/Services/TGReachabilityFlagsKind.h"

TGTestOutcome TGReachabilityTestUnreachableMapsToNone(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGReachabilityNetworkTypeKindForFlags(0) isEqualToString:@"none"],
			"no flags set must map to none");
	TGTestExpectTrue(&outcome,
			[TGReachabilityNetworkTypeKindForFlags(TGReachabilityFlagIsWWAN) isEqualToString:@"none"],
			"isWWAN without reachable must still map to none");

	return outcome;
}

TGTestOutcome TGReachabilityTestReachableWifiMapsToWifi(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGReachabilityNetworkTypeKindForFlags(kSCNetworkReachabilityFlagsReachable) isEqualToString:@"wifi"],
			"reachable with no WWAN flag must map to wifi");

	return outcome;
}

TGTestOutcome TGReachabilityTestReachableWwanMapsToMobile(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	SCNetworkReachabilityFlags flags =
		kSCNetworkReachabilityFlagsReachable | TGReachabilityFlagIsWWAN;
	TGTestExpectTrue(&outcome,
			[TGReachabilityNetworkTypeKindForFlags(flags) isEqualToString:@"mobile"],
			"reachable with the WWAN flag must map to mobile, never roaming");

	return outcome;
}

TGTestOutcome TGReachabilityTestConnectionRequiredWithoutAutomaticConnectMapsToNone(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	SCNetworkReachabilityFlags flags =
		kSCNetworkReachabilityFlagsReachable | kSCNetworkReachabilityFlagsConnectionRequired;
	TGTestExpectTrue(&outcome,
			[TGReachabilityNetworkTypeKindForFlags(flags) isEqualToString:@"none"],
			"reachable but requiring a connection with no automatic path must map to none");

	return outcome;
}

TGTestOutcome TGReachabilityTestConnectionOnDemandMapsToReachableKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	SCNetworkReachabilityFlags flags =
		kSCNetworkReachabilityFlagsReachable |
		kSCNetworkReachabilityFlagsConnectionRequired |
		kSCNetworkReachabilityFlagsConnectionOnDemand;
	TGTestExpectTrue(&outcome,
			[TGReachabilityNetworkTypeKindForFlags(flags) isEqualToString:@"wifi"],
			"a connection that comes up on demand automatically must still count as reachable");

	return outcome;
}

TGTestOutcome TGReachabilityTestInterventionRequiredMapsToNoneEvenWithOnDemand(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	SCNetworkReachabilityFlags flags =
		kSCNetworkReachabilityFlagsReachable |
		kSCNetworkReachabilityFlagsConnectionRequired |
		kSCNetworkReachabilityFlagsConnectionOnDemand |
		kSCNetworkReachabilityFlagsInterventionRequired;
	TGTestExpectTrue(&outcome,
			[TGReachabilityNetworkTypeKindForFlags(flags) isEqualToString:@"none"],
			"a connection that needs user intervention must map to none even if it can also come up on demand");

	return outcome;
}

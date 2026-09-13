#import "tg_storage_cache_policy_limits_tests.h"
#import "../../src/TDLibClient/TGStorageCachePolicyLimits.h"

TGTestOutcome TGStorageCachePolicyTestBothUnlimitedSkipsTheDailyJob(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGStorageCachePolicyEffectiveLimits limits = TGStorageCachePolicyEffectiveLimitsForPolicy(-1, -1);
	TGTestExpectTrue(&outcome, !limits.shouldRun,
			"with both axes left at Forever/No Limit, the daily job must not call optimizeStorage at all");

	return outcome;
}

TGTestOutcome TGStorageCachePolicyTestOnlySizeSetLeavesTTLGenuinelyUnlimited(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	long long oneGigabyte = 1024LL * 1024 * 1024;
	TGStorageCachePolicyEffectiveLimits limits = TGStorageCachePolicyEffectiveLimitsForPolicy(oneGigabyte, -1);

	TGTestExpectTrue(&outcome, limits.shouldRun,
			"a real size cap with TTL left at Forever must still run, constrained by size alone");
	TGTestExpectEqualLongLong(&outcome, limits.effectiveMaxBytes, oneGigabyte,
			"the user's real size cap must be passed through unchanged");
	TGTestExpectTrue(&outcome, limits.effectiveTTLSeconds != -1,
			"the TTL sent to TDLib must never be the -1 sentinel once the call is not skipped, "
			"or TDLib substitutes its own ~23 hour default and deletes media the UI still calls Forever");
	TGTestExpectEqualInteger(&outcome, limits.effectiveTTLSeconds,
			TGStorageCachePolicyEffectivelyUnlimitedTTLSeconds,
			"TTL left at Forever must translate to the effectively-unlimited TTL constant");

	return outcome;
}

TGTestOutcome TGStorageCachePolicyTestOnlyTTLSetLeavesSizeGenuinelyUnlimited(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSInteger thirtyDays = 30 * 24 * 60 * 60;
	TGStorageCachePolicyEffectiveLimits limits = TGStorageCachePolicyEffectiveLimitsForPolicy(-1, thirtyDays);

	TGTestExpectTrue(&outcome, limits.shouldRun,
			"a real TTL with size left at No Limit must still run, constrained by TTL alone");
	TGTestExpectEqualInteger(&outcome, limits.effectiveTTLSeconds, thirtyDays,
			"the user's real TTL must be passed through unchanged");
	TGTestExpectTrue(&outcome, limits.effectiveMaxBytes != -1,
			"the size sent to TDLib must never be the -1 sentinel once the call is not skipped, "
			"or TDLib substitutes its own ~100 MB default and deletes media the UI still calls No Limit");
	TGTestExpectEqualLongLong(&outcome, limits.effectiveMaxBytes,
			TGStorageCachePolicyEffectivelyUnlimitedBytes,
			"size left at No Limit must translate to the effectively-unlimited size constant");

	return outcome;
}

TGTestOutcome TGStorageCachePolicyTestBothSetPassThroughUnchanged(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	long long fiveHundredMegabytes = 500LL * 1024 * 1024;
	NSInteger sevenDays = 7 * 24 * 60 * 60;
	TGStorageCachePolicyEffectiveLimits limits =
			TGStorageCachePolicyEffectiveLimitsForPolicy(fiveHundredMegabytes, sevenDays);

	TGTestExpectTrue(&outcome, limits.shouldRun,
			"two real, finite axes must always run");
	TGTestExpectEqualLongLong(&outcome, limits.effectiveMaxBytes, fiveHundredMegabytes,
			"a real size cap must not be altered when both axes are already finite");
	TGTestExpectEqualInteger(&outcome, limits.effectiveTTLSeconds, sevenDays,
			"a real TTL must not be altered when both axes are already finite");

	return outcome;
}

TGTestOutcome TGStorageCachePolicyTestZeroIsARealFiniteValueNotUnlimited(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGStorageCachePolicyEffectiveLimits limits = TGStorageCachePolicyEffectiveLimitsForPolicy(0, -1);

	TGTestExpectTrue(&outcome, limits.shouldRun,
			"zero is a real, finite size cap, not the unlimited sentinel, so the job must still run");
	TGTestExpectEqualLongLong(&outcome, limits.effectiveMaxBytes, 0,
			"a size cap of exactly zero must be passed through, not replaced");

	return outcome;
}

TGTestOutcome TGStorageCachePolicyTestEffectivelyUnlimitedValuesNeverSubstituteTDLibDefault(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGStorageCachePolicyEffectivelyUnlimitedBytes >= 0,
			"the unlimited size constant must be non-negative, or TDLib treats it as its own -1 default sentinel again");
	TGTestExpectTrue(&outcome, TGStorageCachePolicyEffectivelyUnlimitedTTLSeconds >= 0,
			"the unlimited TTL constant must be non-negative, or TDLib treats it as its own -1 default sentinel again");
	TGTestExpectTrue(&outcome, TGStorageCachePolicyEffectivelyUnlimitedBytes > (100LL << 20),
			"the unlimited size constant must comfortably exceed any real device's cache, "
			"far past TDLib's own ~100 MB default");
	TGTestExpectTrue(&outcome, TGStorageCachePolicyEffectivelyUnlimitedTTLSeconds > 60 * 60 * 23,
			"the unlimited TTL constant must comfortably exceed a day, far past TDLib's own ~23 hour default");

	return outcome;
}

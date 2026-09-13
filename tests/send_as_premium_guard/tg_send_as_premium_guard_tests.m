#import "tg_send_as_premium_guard_tests.h"
#import "../../src/Screens/Chat/TGSendAsPremiumGuard.h"

TGTestOutcome TGSendAsPremiumGuardTestNilSenderIsNotBlocked(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGSendAsSenderRequiresPremiumUpgrade(nil, NO),
			"a nil sender must never be treated as premium-gated");

	return outcome;
}

TGTestOutcome TGSendAsPremiumGuardTestNonDictionarySenderIsNotBlocked(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGSendAsSenderRequiresPremiumUpgrade((NSDictionary *)@"not a dictionary", NO),
			"a non-dictionary sender must never be treated as premium-gated");

	return outcome;
}

TGTestOutcome TGSendAsPremiumGuardTestFreeSenderIsNeverBlocked(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *sender = @{ @"senderId" : @123, @"isChat" : @YES, @"needsPremium" : @NO };
	TGTestExpectTrue(&outcome, !TGSendAsSenderRequiresPremiumUpgrade(sender, NO),
			"a sender that does not need Premium must be selectable by a free account");
	TGTestExpectTrue(&outcome, !TGSendAsSenderRequiresPremiumUpgrade(sender, YES),
			"a sender that does not need Premium must be selectable by a Premium account");

	return outcome;
}

TGTestOutcome TGSendAsPremiumGuardTestPremiumGatedSenderIsBlockedForFreeAccount(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *sender = @{ @"senderId" : @123, @"isChat" : @YES, @"needsPremium" : @YES };
	TGTestExpectTrue(&outcome, TGSendAsSenderRequiresPremiumUpgrade(sender, NO),
			"a sender flagged needs_premium by TDLib must be blocked for a non-Premium account");

	return outcome;
}

TGTestOutcome TGSendAsPremiumGuardTestPremiumGatedSenderIsNotBlockedForPremiumAccount(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *sender = @{ @"senderId" : @123, @"isChat" : @YES, @"needsPremium" : @YES };
	TGTestExpectTrue(&outcome, !TGSendAsSenderRequiresPremiumUpgrade(sender, YES),
			"a sender flagged needs_premium by TDLib must be selectable once the account is Premium");

	return outcome;
}

TGTestOutcome TGSendAsPremiumGuardTestMissingNeedsPremiumKeyIsNotBlocked(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *sender = @{ @"senderId" : @123, @"isChat" : @NO };
	TGTestExpectTrue(&outcome, !TGSendAsSenderRequiresPremiumUpgrade(sender, NO),
			"a sender dictionary with no needsPremium key must default to not blocked");

	return outcome;
}

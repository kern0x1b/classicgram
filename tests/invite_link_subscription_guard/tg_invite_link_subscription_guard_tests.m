#import "tg_invite_link_subscription_guard_tests.h"
#import "../../src/Screens/Contacts/TGInviteLinkSubscriptionGuard.h"

TGTestOutcome TGInviteLinkSubscriptionGuardTestNilLinkIsNotSubscription(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGInviteLinkIsSubscriptionLink(nil),
			"a nil link must never be treated as a paid subscription link");

	return outcome;
}

TGTestOutcome TGInviteLinkSubscriptionGuardTestNonDictionaryLinkIsNotSubscription(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGInviteLinkIsSubscriptionLink((NSDictionary *)@"not a dictionary"),
			"a non-dictionary link must never be treated as a paid subscription link");

	return outcome;
}

TGTestOutcome TGInviteLinkSubscriptionGuardTestZeroStarCountIsNotSubscription(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *link = @{ @"subscriptionStarCount" : @0 };
	TGTestExpectTrue(&outcome, !TGInviteLinkIsSubscriptionLink(link),
			"a zero star count must not offer expiry/uses/approval editing as a subscription link");

	return outcome;
}

TGTestOutcome TGInviteLinkSubscriptionGuardTestMissingStarCountIsNotSubscription(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *link = @{ @"link" : @"https://t.me/joinchat/abc" };
	TGTestExpectTrue(&outcome, !TGInviteLinkIsSubscriptionLink(link),
			"an ordinary link with no subscription field must edit via editChatInviteLink");

	return outcome;
}

TGTestOutcome TGInviteLinkSubscriptionGuardTestPositiveStarCountIsSubscription(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *link = @{ @"subscriptionStarCount" : @10 };
	TGTestExpectTrue(&outcome, TGInviteLinkIsSubscriptionLink(link),
			"a link with a positive subscription star count must never offer expiry/uses/approval editing, per td_api.tl's editChatInviteLink note that expiration_date, member_limit and creates_join_request must not be used for a subscription link");

	return outcome;
}

TGTestOutcome TGInviteLinkSubscriptionGuardTestNegativeStarCountIsNotSubscription(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *link = @{ @"subscriptionStarCount" : @(-1) };
	TGTestExpectTrue(&outcome, !TGInviteLinkIsSubscriptionLink(link),
			"a negative star count is not a valid subscription price and must not be treated as one");

	return outcome;
}

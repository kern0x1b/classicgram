#import "TGInviteLinkSubscriptionGuard.h"

BOOL TGInviteLinkIsSubscriptionLink(NSDictionary *link) {
	if (![link isKindOfClass:[NSDictionary class]])
		return NO;
	return [link[@"subscriptionStarCount"] longLongValue] > 0;
}

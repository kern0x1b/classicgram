#import "TGCloseFriendsStatus.h"
#import "TGLocalization.h"

NSString *TGCloseFriendsFooterText(BOOL loaded, BOOL failed, NSUInteger chosenCount) {
	if (!loaded)
		return TGL(@"Channel.NotificationLoading", @"Loading…");
	if (failed)
		return TGL(@"CloseFriends.LoadFailedFooter",
				@"Your Close Friends list could not be read, so this screen cannot show who is "
				@"on it. Leave and come back rather than saving over it.");
	if (!chosenCount)
		return TGL(@"CloseFriends.EmptyFooter",
				@"Nobody is on your Close Friends list. Pick the people who may see a story you "
				@"post to Close Friends.");
	return TGL(@"CloseFriends.Footer",
			@"These people see a story you post to Close Friends.");
}

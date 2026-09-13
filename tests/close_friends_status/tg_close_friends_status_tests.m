#import "tg_close_friends_status_tests.h"

#import "../../src/Screens/Settings/TGCloseFriendsStatus.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGCloseFriendsStatusTestTheFooterSaysWhichItIs(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *failed = TGCloseFriendsFooterText(YES, YES, 0);
	NSString *empty = TGCloseFriendsFooterText(YES, NO, 0);
	NSString *loading = TGCloseFriendsFooterText(NO, NO, 0);
	NSString *chosen = TGCloseFriendsFooterText(YES, NO, 4);

	TGTestExpectTrue(&outcome, ![failed isEqualToString:empty],
			"a failed read does not claim nobody is on the list");
	TGTestExpectTrue(&outcome, ![loading isEqualToString:empty] && loading.length,
			"a list still arriving says neither");
	TGTestExpectTrue(&outcome, ![chosen isEqualToString:empty],
			"and a list with people on it explains what they can see instead");

	return outcome;
}

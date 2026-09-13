#import "tg_rights_diff_tests.h"
#import "../../src/TDLibClient/TGRightsDiff.h"

TGTestOutcome TGRightsDiffTestTheEventLogCountsOnlyRightsThatActuallyChanged(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;
	NSArray *fields = TGAdminRightsDiffFields();

	TGTestExpectTrue(&outcome, fields.count > 0, "the admin rights the event log compares are listed");
	TGTestExpectTrue(&outcome, [fields containsObject:@"can_pin_messages"],
			"pinning is one of the rights a promotion can change");
	TGTestExpectTrue(&outcome, TGRightsDiffCount(nil, nil, fields) == 0,
			"an event with no rights on either side reports nothing changed");

	NSDictionary *none = @{};
	NSDictionary *pinning = @{ @"can_pin_messages" : @YES };
	NSDictionary *pinningAndInviting = @{ @"can_pin_messages" : @YES, @"can_invite_users" : @YES };

	TGTestExpectTrue(&outcome, TGRightsDiffCount(none, pinning, fields) == 1,
			"one granted right is one changed permission");
	TGTestExpectTrue(&outcome, TGRightsDiffCount(pinning, none, fields) == 1,
			"one revoked right counts the same as one granted");
	TGTestExpectTrue(&outcome, TGRightsDiffCount(none, pinningAndInviting, fields) == 2,
			"two granted rights read as two changed permissions, so the line reads plural");
	TGTestExpectTrue(&outcome, TGRightsDiffCount(pinning, pinningAndInviting, fields) == 1,
			"a right left untouched is not counted alongside the one that moved");

	TGTestExpectTrue(&outcome, TGRightsDiffCount(@{ @"can_pin_messages" : @NO }, none, fields) == 0,
			"a right spelled out as false matches an absent one");
	TGTestExpectTrue(&outcome, TGRightsDiffCount(@{ @"can_pin_messages" : @"yes" }, pinning, fields) == 1,
			"a right arriving as a string is not a granted right");
	TGTestExpectTrue(&outcome, TGRightsDiffCount(pinning, pinning, @[]) == 0,
			"with no fields to compare nothing can have changed");
	TGTestExpectTrue(&outcome, TGRightsDiffCount(@{ @"can_send_polls" : @YES }, none,
			@[ @"can_send_polls" ]) == 1,
			"the same helper counts chat permissions when handed their own field list");

	return outcome;
}

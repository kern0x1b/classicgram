#import "tg_bot_admin_rights_tests.h"
#import "../../src/Utilities/TGBotAdminRights.h"

TGTestOutcome TGBotAdminRightsTestWhenALinkAsksForRights(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGBotAdminRightsRequested(nil),
		"a link that names no rights asks for none");
	TGTestExpectTrue(&outcome, !TGBotAdminRightsRequested(@{}),
		"an empty set of rights asks for none");
	TGTestExpectTrue(&outcome,
		!TGBotAdminRightsRequested(@{@"can_invite_users" : @NO, @"can_pin_messages" : @NO}),
		"rights that are all switched off ask for none");
	TGTestExpectTrue(&outcome, TGBotAdminRightsRequested(@{@"can_pin_messages" : @YES}),
		"a single right switched on is a request to promote");
	TGTestExpectTrue(&outcome, !TGBotAdminRightsRequested((id)@"not a dictionary"),
		"anything that is not a set of rights asks for none");

	return outcome;
}

TGTestOutcome TGBotAdminRightsTestWhatTheRequestCarries(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *names = TGBotAdminRightNames();
	NSDictionary *request = TGBotAdminRightsNormalised(@{
		@"can_invite_users" : @YES,
		@"can_eat_biscuits" : @YES,
	});

	TGTestExpectEqualInteger(&outcome, (NSInteger)request.count, (NSInteger)names.count,
		"every right the schema knows is named, and nothing else is");
	TGTestExpectTrue(&outcome, [request[@"can_invite_users"] boolValue],
		"a right the link asked for is carried through");
	TGTestExpectTrue(&outcome, request[@"can_pin_messages"] != nil,
		"a right the link left out is still named");
	TGTestExpectTrue(&outcome, ![request[@"can_pin_messages"] boolValue],
		"and it is switched off rather than missing");
	TGTestExpectTrue(&outcome, request[@"can_eat_biscuits"] == nil,
		"a right that is not in the schema does not travel");
	TGTestExpectTrue(&outcome, [names containsObject:@"is_anonymous"],
		"the anonymity flag counts as a right like any other");

	return outcome;
}

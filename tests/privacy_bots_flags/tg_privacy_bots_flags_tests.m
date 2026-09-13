#import "tg_privacy_bots_flags_tests.h"
#import "../../src/Screens/Settings/TGPrivacyBotsFlags.h"

TGTestOutcome TGPrivacyBotsFlagsTestEverybodyKeepsOnlyTheRestriction(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	BOOL allow = YES;
	BOOL restricted = YES;
	TGPrivacyEffectiveBotsFlags(@"everybody", YES, YES, &allow, &restricted);

	TGTestExpectTrue(&outcome, !allow,
			"with the base set to everybody the only bots exception the screen offers is a restriction, so an "
			"allow flag left over from another base must never be sent");
	TGTestExpectTrue(&outcome, restricted,
			"the restriction the user actually toggled is kept");

	return outcome;
}

TGTestOutcome TGPrivacyBotsFlagsTestContactsAndNobodyKeepOnlyTheAllowance(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	BOOL allow = NO;
	BOOL restricted = NO;
	TGPrivacyEffectiveBotsFlags(@"contacts", YES, YES, &allow, &restricted);
	TGTestExpectTrue(&outcome, allow && !restricted,
			"with the base set to contacts the bots exception is an allowance, so a stale restriction must be "
			"dropped: TDLib takes the first matching rule and the composer emits restrictBots first, so a "
			"leftover restriction silently out-ranks the allowance the user just switched on");

	TGPrivacyEffectiveBotsFlags(@"nobody", YES, YES, &allow, &restricted);
	TGTestExpectTrue(&outcome, allow && !restricted,
			"nobody behaves like contacts: only the allowance applies");

	return outcome;
}

TGTestOutcome TGPrivacyBotsFlagsTestSwitchingBaseDropsTheStaleFlag(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	BOOL allow = NO;
	BOOL restricted = NO;

	TGPrivacyEffectiveBotsFlags(@"everybody", NO, YES, &allow, &restricted);
	TGTestExpectTrue(&outcome, !allow && restricted, "start from everybody with bots restricted");

	TGPrivacyEffectiveBotsFlags(@"contacts", NO, restricted, &allow, &restricted);
	TGTestExpectTrue(&outcome, !allow && !restricted,
			"switching to contacts must carry neither flag forward until the user toggles again");

	TGPrivacyEffectiveBotsFlags(@"contacts", YES, restricted, &allow, &restricted);
	TGTestExpectTrue(&outcome, allow && !restricted,
			"toggling the allowance at the new base now actually reaches the server");

	return outcome;
}

TGTestOutcome TGPrivacyBotsFlagsTestToleratesMissingBaseAndNullOutputs(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	BOOL allow = YES;
	BOOL restricted = YES;
	TGPrivacyEffectiveBotsFlags(nil, YES, YES, &allow, &restricted);
	TGTestExpectTrue(&outcome, allow && !restricted,
			"a missing base value is not everybody, so it behaves like the allow-side bases rather than "
			"sending a restriction nobody asked for");

	TGPrivacyEffectiveBotsFlags(@"everybody", YES, YES, NULL, NULL);
	TGTestExpectTrue(&outcome, YES,
			"passing no out-pointers must be safe for a caller that wants only one of the two");

	return outcome;
}

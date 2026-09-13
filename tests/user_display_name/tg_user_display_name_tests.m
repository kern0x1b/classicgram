#import "tg_user_display_name_tests.h"
#import "../../src/Wire/Flatten/TGUserDisplayName.h"

TGTestOutcome TGUserDisplayNameTestADeletedAccountStillHasAName(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGUserDisplayName(@{@"first_name" : @"Marianna", @"last_name" : @"K"})
					isEqualToString:@"Marianna K"],
			"both halves of a name are joined");
	TGTestExpectTrue(&outcome,
			[TGUserDisplayName(@{@"first_name" : @"Marianna"}) isEqualToString:@"Marianna"],
			"a first name alone carries no trailing space");
	TGTestExpectTrue(&outcome,
			[TGUserDisplayName(@{@"last_name" : @"K"}) isEqualToString:@"K"],
			"and neither does a last name alone");
	TGTestExpectTrue(&outcome,
			[TGUserDisplayName(@{@"usernames" : @{@"active_usernames" : @[ @"marianna" ]}})
					isEqualToString:@"marianna"],
			"a user with no name at all is known by their username");
	TGTestExpectTrue(&outcome,
			[TGUserDisplayName(@{@"first_name" : @"", @"last_name" : @"",
				@"usernames" : @{@"active_usernames" : @[]}})
					isEqualToString:@"Deleted Account"],
			"a user with neither is a deleted account, which is what Telegram calls it and "
			"what eight screens were each substituting on their own");
	TGTestExpectTrue(&outcome, [TGUserDisplayName(@{}) isEqualToString:@"Deleted Account"],
			"an empty user record says the same");
	TGTestExpectTrue(&outcome, [TGUserDisplayName(nil) isEqualToString:@""],
			"no record at all is not a deleted account: nothing has been loaded yet, and the "
			"caller must be free to wait rather than print a name");

	return outcome;
}

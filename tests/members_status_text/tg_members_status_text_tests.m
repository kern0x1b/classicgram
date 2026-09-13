#import "tg_members_status_text_tests.h"
#import "../../src/Screens/Groups/TGMembersStatusText.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGMembersStatusTextTestBannedWithCustomTitlePrefersBanOverTitle(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *member = @{
		@"status" : @"banned",
		@"customTitle" : @"Owner",
		@"untilDate" : @(0),
	};
	TGTestExpectTrue(&outcome, [TGMembersStatusText(member) isEqualToString:@"removed"],
			"a permanently banned member's custom title must not hide the ban from the admin browsing the banned list");

	return outcome;
}

TGTestOutcome TGMembersStatusTextTestBannedWithDurationAndCustomTitleShowsDurationNotTitle(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *member = @{
		@"status" : @"banned",
		@"customTitle" : @"Owner",
		@"untilDate" : @([[NSDate date] timeIntervalSince1970] + 86400),
	};
	NSString *result = TGMembersStatusText(member);
	TGTestExpectTrue(&outcome, [result hasPrefix:@"banned until "],
			"a temporarily banned member with a custom title must still show the ban duration");
	TGTestExpectTrue(&outcome, ![result isEqualToString:@"Owner"],
			"the custom title must never fully replace the ban duration in the banned list");

	return outcome;
}

TGTestOutcome TGMembersStatusTextTestRestrictedWithCustomTitlePrefersRestrictionOverTitle(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *member = @{
		@"status" : @"restricted",
		@"customTitle" : @"Owner",
		@"untilDate" : @(0),
	};
	TGTestExpectTrue(&outcome, [TGMembersStatusText(member) isEqualToString:@"restricted"],
			"a permanently restricted member's custom title must not hide the restriction from the admin browsing that list");

	return outcome;
}

TGTestOutcome TGMembersStatusTextTestRestrictedWithDurationAndCustomTitleShowsDurationNotTitle(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *member = @{
		@"status" : @"restricted",
		@"customTitle" : @"Owner",
		@"untilDate" : @([[NSDate date] timeIntervalSince1970] + 86400),
	};
	NSString *result = TGMembersStatusText(member);
	TGTestExpectTrue(&outcome, [result hasPrefix:@"restricted until "],
			"a temporarily restricted member with a custom title must still show the restriction duration");
	TGTestExpectTrue(&outcome, ![result isEqualToString:@"Owner"],
			"the custom title must never fully replace the restriction duration in that list");

	return outcome;
}

TGTestOutcome TGMembersStatusTextTestAdministratorWithCustomTitleStillShowsTitle(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *member = @{
		@"status" : @"administrator",
		@"customTitle" : @"Owner",
	};
	TGTestExpectTrue(&outcome, [TGMembersRoleText(member) isEqualToString:@"Owner"],
			"an administrator's custom title is the relevant, non-hidden information and must still take priority in the role label");

	return outcome;
}

TGTestOutcome TGMembersStatusTextTestPlainMemberWithCustomTitleStillShowsTitle(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *member = @{
		@"status" : @"member",
		@"customTitle" : @"VIP",
	};
	TGTestExpectTrue(&outcome, [TGMembersRoleText(member) isEqualToString:@"VIP"],
			"an ordinary member's custom title must still take priority over having no role label at all");

	return outcome;
}

TGTestOutcome TGMembersStatusTextTestCreatorWithoutCustomTitleShowsOwner(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *member = @{
		@"status" : @"creator",
	};
	TGTestExpectTrue(&outcome, [TGMembersStatusText(member) isEqualToString:@"owner"],
			"a creator with no custom title and no known presence must fall back to the owner label");
	TGTestExpectTrue(&outcome, [TGMembersRoleText(member) isEqualToString:@"owner"],
			"a creator with no custom title must show the owner role label");

	return outcome;
}

TGTestOutcome TGMembersStatusTextTestPlainMemberWithoutCustomTitleShowsMemberFallback(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *member = @{
		@"status" : @"member",
	};
	TGTestExpectTrue(&outcome, [TGMembersStatusText(member) isEqualToString:@"member"],
			"a plain member with no custom title and no known presence must fall back to the generic member label");
	TGTestExpectTrue(&outcome, TGMembersRoleText(member) == nil,
			"a plain member with no custom title must show no role label at all");

	return outcome;
}

TGTestOutcome TGMembersStatusTextTestMemberWithKnownPresencePrefersPresenceOverRoleWord(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *member = @{
		@"status" : @"member",
		@"presenceText" : @"last seen recently",
	};
	TGTestExpectTrue(&outcome, [TGMembersStatusText(member) isEqualToString:@"last seen recently"],
			"a plain member's real presence must be shown instead of the literal word \"member\"");

	return outcome;
}

TGTestOutcome TGMembersStatusTextTestAdministratorWithKnownPresenceShowsPresenceNotRoleWord(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *member = @{
		@"status" : @"administrator",
		@"presenceText" : @"online",
	};
	TGTestExpectTrue(&outcome, [TGMembersStatusText(member) isEqualToString:@"online"],
			"an administrator's presence belongs in the status line; the role belongs in the separate role label");
	TGTestExpectTrue(&outcome, [TGMembersRoleText(member) isEqualToString:@"admin"],
			"an administrator with no custom title must still show the admin role label alongside their presence");

	return outcome;
}

TGTestOutcome TGMembersStatusTextTestBannedMemberShowsNoRoleLabel(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *member = @{
		@"status" : @"banned",
		@"customTitle" : @"Owner",
		@"untilDate" : @(0),
	};
	TGTestExpectTrue(&outcome, TGMembersRoleText(member) == nil,
			"a banned member must show no role label, even if they once carried a custom title");

	return outcome;
}

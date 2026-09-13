#import "tg_flatten_groups_tests.h"
#import "../../src/Wire/Flatten/TGFlattenGroups.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenGroupsTestProfileTabNameStripsPrefixAndLowercases(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *tab = @{@"@type" : @"profileTabMedia"};

	TGTestExpectTrue(&outcome, [TGGroupProfileTabName(tab) isEqualToString:@"media"],
			"a profileTabMedia tab must strip the profileTab prefix and lowercase the remainder");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestProfileTabNameReturnsEmptyForMissingPrefixOrShortOrNilOrNonDictionary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGGroupProfileTabName(@{@"@type" : @"somethingElse"}) isEqualToString:@""],
			"a type without the profileTab prefix must flatten to an empty string");
	TGTestExpectTrue(&outcome, [TGGroupProfileTabName(@{@"@type" : @"profileTab"}) isEqualToString:@""],
			"a type equal to the bare prefix with nothing after it must flatten to an empty string");
	TGTestExpectTrue(&outcome, [TGGroupProfileTabName(nil) isEqualToString:@""],
			"a nil tab must flatten to an empty string, not crash");
	TGTestExpectTrue(&outcome, [TGGroupProfileTabName(@"not a dictionary") isEqualToString:@""],
			"a non-dictionary tab must flatten to an empty string, not crash");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestUserSenderBuildsMessageSenderUserDict(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *sender = TGUserSender(555);

	TGTestExpectTrue(&outcome, [sender[@"@type"] isEqualToString:@"messageSenderUser"],
			"TGUserSender must build a messageSenderUser discriminator");
	TGTestExpectEqualLongLong(&outcome, [sender[@"user_id"] longLongValue], 555,
			"TGUserSender must carry the given user id");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestFlattenMemberIdentityReadsUserIdForMessageSenderUser(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *identity = TGFlattenMemberIdentity(@{@"@type" : @"messageSenderUser", @"user_id" : @777});

	TGTestExpectTrue(&outcome, [identity[@"isChat"] boolValue] == NO,
			"a messageSenderUser member_id must not be flagged as a chat");
	TGTestExpectEqualLongLong(&outcome, [identity[@"userId"] longLongValue], 777,
			"a messageSenderUser member_id must carry its user_id through as userId");
	TGTestExpectEqualLongLong(&outcome, [identity[@"chatId"] longLongValue], 0,
			"a messageSenderUser member_id must report a zero chatId");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestFlattenMemberIdentityReadsChatIdForMessageSenderChat(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *identity = TGFlattenMemberIdentity(
		@{@"@type" : @"messageSenderChat", @"chat_id" : @(-1001234567890)});

	TGTestExpectTrue(&outcome, [identity[@"isChat"] boolValue] == YES,
			"a messageSenderChat member_id must be flagged as a chat, the anonymous-admin/linked-channel case");
	TGTestExpectEqualLongLong(&outcome, [identity[@"chatId"] longLongValue], -1001234567890,
			"a messageSenderChat member_id must carry its chat_id through as chatId");
	TGTestExpectEqualLongLong(&outcome, [identity[@"userId"] longLongValue], 0,
			"a messageSenderChat member_id must report a zero userId, never borrow the chat_id");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestFlattenMemberIdentityDefaultsSafelyForNilOrNonDictionary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *fromNil = TGFlattenMemberIdentity(nil);
	TGTestExpectTrue(&outcome, [fromNil[@"isChat"] boolValue] == NO,
			"a nil member_id must not crash and must not be flagged as a chat");
	TGTestExpectEqualLongLong(&outcome, [fromNil[@"userId"] longLongValue], 0,
			"a nil member_id must default userId to zero");

	NSDictionary *fromGarbage = TGFlattenMemberIdentity((NSDictionary *)@"not a dictionary");
	TGTestExpectTrue(&outcome, [fromGarbage[@"isChat"] boolValue] == NO,
			"a non-dictionary member_id must not crash and must not be flagged as a chat");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestPermissionKeysContainsExpectedKeysInOrder(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *keys = TGPermissionKeys();

	TGTestExpectEqualInteger(&outcome, (NSInteger)keys.count, 16,
			"the member permission key list must have exactly sixteen entries");
	TGTestExpectTrue(&outcome, [keys.firstObject isEqualToString:@"can_send_basic_messages"],
			"the first permission key must be can_send_basic_messages");
	TGTestExpectTrue(&outcome, [keys.lastObject isEqualToString:@"can_create_topics"],
			"the last permission key must be can_create_topics");
	TGTestExpectTrue(&outcome, [keys containsObject:@"can_react_to_messages"],
			"the permission key list must include can_react_to_messages");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestAdminRightKeysContainsExpectedKeysInOrder(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *keys = TGAdminRightKeys();

	TGTestExpectEqualInteger(&outcome, (NSInteger)keys.count, 17,
			"the administrator right key list must have exactly seventeen entries");
	TGTestExpectTrue(&outcome, [keys.firstObject isEqualToString:@"can_manage_chat"],
			"the first administrator right key must be can_manage_chat");
	TGTestExpectTrue(&outcome, [keys.lastObject isEqualToString:@"is_anonymous"],
			"the last administrator right key must be is_anonymous");
	TGTestExpectTrue(&outcome, [keys containsObject:@"can_manage_direct_messages"],
			"the administrator right key list must include can_manage_direct_messages");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestBuildFlagsSetsTypeAndReadsEachKeyAsBool(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *source = @{@"can_pin_messages" : @YES, @"can_invite_users" : @NO};
	NSArray *keys = @[ @"can_pin_messages", @"can_invite_users" ];

	NSDictionary *flags = TGBuildFlags(source, keys, @"chatPermissions");

	TGTestExpectTrue(&outcome, [flags[@"@type"] isEqualToString:@"chatPermissions"],
			"TGBuildFlags must stamp the given @type discriminator");
	TGTestExpectTrue(&outcome, [flags[@"can_pin_messages"] boolValue] == YES,
			"TGBuildFlags must read a truthy source value as YES");
	TGTestExpectTrue(&outcome, [flags[@"can_invite_users"] boolValue] == NO,
			"TGBuildFlags must read a falsy source value as NO");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestBuildFlagsDefaultsMissingSourceKeysToFalse(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flags = TGBuildFlags(@{}, @[ @"can_change_info" ], @"chatPermissions");

	TGTestExpectTrue(&outcome, [flags[@"can_change_info"] boolValue] == NO,
			"a key absent from the source dictionary must default to NO rather than crash");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestReadFlagsReadsEachKeyAsBoolWithoutType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *source = @{@"can_send_photos" : @YES, @"can_send_videos" : @NO};
	NSArray *keys = @[ @"can_send_photos", @"can_send_videos" ];

	NSDictionary *flags = TGReadFlags(source, keys);

	TGTestExpectTrue(&outcome, flags[@"@type"] == nil,
			"TGReadFlags must not add an @type discriminator, unlike TGBuildFlags");
	TGTestExpectTrue(&outcome, [flags[@"can_send_photos"] boolValue] == YES,
			"TGReadFlags must read a truthy source value as YES");
	TGTestExpectTrue(&outcome, [flags[@"can_send_videos"] boolValue] == NO,
			"TGReadFlags must read a falsy source value as NO");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestReadFlagsDefaultsMissingSourceKeysToFalse(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flags = TGReadFlags(@{}, @[ @"can_send_polls" ]);

	TGTestExpectTrue(&outcome, [flags[@"can_send_polls"] boolValue] == NO,
			"a key absent from the source dictionary must default to NO rather than crash");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestStatusNameMapsAllKnownStatuses(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStatusName(@"chatMemberStatusCreator") isEqualToString:@"creator"],
			"chatMemberStatusCreator must map to creator");
	TGTestExpectTrue(&outcome,
			[TGStatusName(@"chatMemberStatusAdministrator") isEqualToString:@"administrator"],
			"chatMemberStatusAdministrator must map to administrator");
	TGTestExpectTrue(&outcome,
			[TGStatusName(@"chatMemberStatusMember") isEqualToString:@"member"],
			"chatMemberStatusMember must map to member");
	TGTestExpectTrue(&outcome,
			[TGStatusName(@"chatMemberStatusRestricted") isEqualToString:@"restricted"],
			"chatMemberStatusRestricted must map to restricted");
	TGTestExpectTrue(&outcome,
			[TGStatusName(@"chatMemberStatusBanned") isEqualToString:@"banned"],
			"chatMemberStatusBanned must map to banned");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestStatusNameFallsBackToLeftForUnknownOrEmptyType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGStatusName(@"chatMemberStatusSomeFutureCase") isEqualToString:@"left"],
			"an unrecognised status type must fall back to left, not crash");
	TGTestExpectTrue(&outcome, [TGStatusName(@"") isEqualToString:@"left"],
			"an empty status type must fall back to left");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestSupergroupFilterMapsNamedFiltersAndCarriesQueryWhereApplicable(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSupergroupFilter(@"administrators", nil)[@"@type"]
					isEqualToString:@"supergroupMembersFilterAdministrators"],
			"administrators must map to supergroupMembersFilterAdministrators");

	NSDictionary *restricted = TGSupergroupFilter(@"restricted", @"tom");
	TGTestExpectTrue(&outcome,
			[restricted[@"@type"] isEqualToString:@"supergroupMembersFilterRestricted"],
			"restricted must map to supergroupMembersFilterRestricted");
	TGTestExpectTrue(&outcome, [restricted[@"query"] isEqualToString:@"tom"],
			"restricted must carry the query text through");

	NSDictionary *banned = TGSupergroupFilter(@"banned", nil);
	TGTestExpectTrue(&outcome, [banned[@"@type"] isEqualToString:@"supergroupMembersFilterBanned"],
			"banned must map to supergroupMembersFilterBanned");
	TGTestExpectTrue(&outcome, [banned[@"query"] isEqualToString:@""],
			"banned with a nil query must default the query to an empty string");

	TGTestExpectTrue(&outcome,
			[TGSupergroupFilter(@"bots", nil)[@"@type"] isEqualToString:@"supergroupMembersFilterBots"],
			"bots must map to supergroupMembersFilterBots");

	NSDictionary *contacts = TGSupergroupFilter(@"contacts", @"jerry");
	TGTestExpectTrue(&outcome,
			[contacts[@"@type"] isEqualToString:@"supergroupMembersFilterContacts"],
			"contacts must map to supergroupMembersFilterContacts");
	TGTestExpectTrue(&outcome, [contacts[@"query"] isEqualToString:@"jerry"],
			"contacts must carry the query text through");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestSupergroupFilterFallsBackToSearchWhenQueryPresentAndFilterUnknown(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *search = TGSupergroupFilter(@"unknownFilter", @"anna");

	TGTestExpectTrue(&outcome, [search[@"@type"] isEqualToString:@"supergroupMembersFilterSearch"],
			"an unknown filter name with a non-empty query must fall back to supergroupMembersFilterSearch");
	TGTestExpectTrue(&outcome, [search[@"query"] isEqualToString:@"anna"],
			"the search fallback must carry the query text through");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestSupergroupFilterFallsBackToRecentWhenNoQueryAndFilterUnknown(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *recent = TGSupergroupFilter(@"unknownFilter", nil);

	TGTestExpectTrue(&outcome, [recent[@"@type"] isEqualToString:@"supergroupMembersFilterRecent"],
			"an unknown filter name with no query must fall back to supergroupMembersFilterRecent");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestChatMembersFilterMapsNamedFilters(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGChatMembersFilter(@"administrators")[@"@type"]
					isEqualToString:@"chatMembersFilterAdministrators"],
			"administrators must map to chatMembersFilterAdministrators");
	TGTestExpectTrue(&outcome,
			[TGChatMembersFilter(@"restricted")[@"@type"] isEqualToString:@"chatMembersFilterRestricted"],
			"restricted must map to chatMembersFilterRestricted");
	TGTestExpectTrue(&outcome,
			[TGChatMembersFilter(@"banned")[@"@type"] isEqualToString:@"chatMembersFilterBanned"],
			"banned must map to chatMembersFilterBanned");
	TGTestExpectTrue(&outcome,
			[TGChatMembersFilter(@"bots")[@"@type"] isEqualToString:@"chatMembersFilterBots"],
			"bots must map to chatMembersFilterBots");
	TGTestExpectTrue(&outcome,
			[TGChatMembersFilter(@"contacts")[@"@type"] isEqualToString:@"chatMembersFilterContacts"],
			"contacts must map to chatMembersFilterContacts");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestChatMembersFilterFallsBackToMembersForUnknownFilter(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGChatMembersFilter(@"somethingUnrecognised")[@"@type"]
					isEqualToString:@"chatMembersFilterMembers"],
			"an unrecognised filter name must fall back to chatMembersFilterMembers");
	TGTestExpectTrue(&outcome, [TGChatMembersFilter(nil)[@"@type"] isEqualToString:@"chatMembersFilterMembers"],
			"a nil filter name must fall back to chatMembersFilterMembers, not crash");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestFlattenInviteLinkMapsAllFieldsForValidLink(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *link = @{
		@"@type" : @"chatInviteLink",
		@"invite_link" : @"https://t.me/joinchat/abc",
		@"name" : @"General",
		@"creator_user_id" : @101,
		@"date" : @1700000000,
		@"expiration_date" : @1700003600,
		@"member_limit" : @50,
		@"member_count" : @12,
		@"pending_join_request_count" : @3,
		@"creates_join_request" : @YES,
		@"is_primary" : @YES,
		@"is_revoked" : @NO,
	};

	NSDictionary *flat = TGFlattenInviteLink(link);

	TGTestExpectTrue(&outcome, [flat[@"link"] isEqualToString:@"https://t.me/joinchat/abc"],
			"the flattened invite link must carry the invite_link string through");
	TGTestExpectTrue(&outcome, [flat[@"name"] isEqualToString:@"General"],
			"the flattened invite link must carry the name string through");
	TGTestExpectEqualLongLong(&outcome, [flat[@"creatorUserId"] longLongValue], 101,
			"the flattened invite link must carry creator_user_id through as creatorUserId");
	TGTestExpectEqualLongLong(&outcome, [flat[@"memberLimit"] longLongValue], 50,
			"the flattened invite link must carry member_limit through as memberLimit");
	TGTestExpectEqualLongLong(&outcome, [flat[@"memberCount"] longLongValue], 12,
			"the flattened invite link must carry member_count through as memberCount");
	TGTestExpectEqualLongLong(&outcome, [flat[@"pendingJoinRequestCount"] longLongValue], 3,
			"the flattened invite link must carry pending_join_request_count through");
	TGTestExpectTrue(&outcome, [flat[@"createsJoinRequest"] boolValue] == YES,
			"the flattened invite link must carry creates_join_request through as a bool");
	TGTestExpectTrue(&outcome, [flat[@"isPrimary"] boolValue] == YES,
			"the flattened invite link must carry is_primary through as a bool");
	TGTestExpectTrue(&outcome, [flat[@"isRevoked"] boolValue] == NO,
			"the flattened invite link must carry is_revoked through as a bool");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestFlattenInviteLinkDefaultsMissingNumericAndBooleanFields(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *link = @{@"@type" : @"chatInviteLink", @"invite_link" : @"https://t.me/x"};

	NSDictionary *flat = TGFlattenInviteLink(link);

	TGTestExpectEqualLongLong(&outcome, [flat[@"creatorUserId"] longLongValue], 0,
			"a missing creator_user_id must default to 0, not crash");
	TGTestExpectEqualLongLong(&outcome, [flat[@"memberLimit"] longLongValue], 0,
			"a missing member_limit must default to 0, not crash");
	TGTestExpectTrue(&outcome, [flat[@"isRevoked"] boolValue] == NO,
			"a missing is_revoked must default to NO, not crash");
	TGTestExpectTrue(&outcome, [flat[@"name"] isEqualToString:@""],
			"a missing name must default to an empty string, not crash");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestFlattenInviteLinkReturnsNilForWrongTypeOrNonDictionaryOrNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGFlattenInviteLink(nil) == nil,
			"a nil invite link must flatten to nil, not crash");
	TGTestExpectTrue(&outcome, TGFlattenInviteLink((NSDictionary *)@"not a dictionary") == nil,
			"a non-dictionary invite link must flatten to nil, not crash");
	TGTestExpectTrue(&outcome, TGFlattenInviteLink(@{@"@type" : @"someOtherType"}) == nil,
			"an invite link with the wrong @type discriminator must flatten to nil");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestTitleForAdministratorRightKeyKnownKeysReturnHumanReadableTitles(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGTitleForAdministratorRightKey(@"can_manage_chat") isEqualToString:@"Manage Group"],
			"can_manage_chat must resolve to the Manage Group title");
	TGTestExpectTrue(&outcome,
			[TGTitleForAdministratorRightKey(@"is_anonymous") isEqualToString:@"Remain Anonymous"],
			"is_anonymous must resolve to the Remain Anonymous title");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestTitleForAdministratorRightKeyUnknownNonEmptyKeyReturnsKeyItself(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGTitleForAdministratorRightKey(@"can_do_something_new") isEqualToString:@"can_do_something_new"],
			"a non-empty key with no known title must fall back to the raw key itself");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestTitleForAdministratorRightKeyNilOrEmptyReturnsEmptyString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGTitleForAdministratorRightKey(nil) isEqualToString:@""],
			"a nil key must resolve to an empty string, not crash");
	TGTestExpectTrue(&outcome, [TGTitleForAdministratorRightKey(@"") isEqualToString:@""],
			"an empty key must resolve to an empty string");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestTitleForMemberPermissionKeyKnownKeysReturnHumanReadableTitles(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGTitleForMemberPermissionKey(@"can_send_basic_messages") isEqualToString:@"Send Messages"],
			"can_send_basic_messages must resolve to the Send Messages title");
	TGTestExpectTrue(&outcome,
			[TGTitleForMemberPermissionKey(@"can_create_topics") isEqualToString:@"Create Topics"],
			"can_create_topics must resolve to the Create Topics title");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestTitleForMemberPermissionKeyUnknownNonEmptyKeyReturnsKeyItself(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGTitleForMemberPermissionKey(@"can_do_something_new") isEqualToString:@"can_do_something_new"],
			"a non-empty key with no known title must fall back to the raw key itself");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestTitleForMemberPermissionKeyNilOrEmptyReturnsEmptyString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGTitleForMemberPermissionKey(nil) isEqualToString:@""],
			"a nil key must resolve to an empty string, not crash");
	TGTestExpectTrue(&outcome, [TGTitleForMemberPermissionKey(@"") isEqualToString:@""],
			"an empty key must resolve to an empty string");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestMentionCandidateJoinsFirstAndLastName(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *candidate = TGMentionCandidate(42, @"johnd", @"John", @"Doe", @"fallback");

	TGTestExpectEqualLongLong(&outcome, [candidate[@"id"] longLongValue], 42,
			"the candidate must carry the given user id");
	TGTestExpectTrue(&outcome, [candidate[@"username"] isEqualToString:@"johnd"],
			"the candidate must carry the given username verbatim");
	TGTestExpectTrue(&outcome, [candidate[@"name"] isEqualToString:@"John Doe"],
			"a present first and last name must take priority over the fallback name and the username");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestMentionCandidateFallsBackToFallbackNameThenUsername(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *withFallback = TGMentionCandidate(1, @"alice", nil, nil, @"cached name");
	TGTestExpectTrue(&outcome, [withFallback[@"name"] isEqualToString:@"cached name"],
			"a blank first and last name must fall through to the fallback name before the username");

	NSDictionary *withoutFallback = TGMentionCandidate(2, @"bob", @"", @"", @"");
	TGTestExpectTrue(&outcome, [withoutFallback[@"name"] isEqualToString:@"bob"],
			"a blank first, last and fallback name must fall through to the username");

	NSDictionary *withNothing = TGMentionCandidate(3, nil, nil, nil, nil);
	TGTestExpectTrue(&outcome, [withNothing[@"name"] isEqualToString:@""],
			"every name source missing must resolve to an empty string, not crash");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestMentionCandidateCarriesUserIdAndUsernameRegardlessOfName(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *candidate = TGMentionCandidate(7, nil, @"Solo", nil, nil);

	TGTestExpectEqualLongLong(&outcome, [candidate[@"id"] longLongValue], 7,
			"the user id must be carried even when there is no username");
	TGTestExpectTrue(&outcome, [candidate[@"username"] isEqualToString:@""],
			"a nil username must resolve to an empty string rather than nil, so callers can check .length safely");
	TGTestExpectTrue(&outcome, [candidate[@"name"] isEqualToString:@"Solo"],
			"a first name alone must be used without a trailing space");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestMemberRestrictionReadsRestrictedAndBannedStatuses(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *restricted = TGFlattenMemberRestriction(@{
		@"@type" : @"chatMemberStatusRestricted",
		@"restricted_until_date" : @1700000000,
		@"permissions" : @{@"can_send_basic_messages" : @YES},
	});

	TGTestExpectTrue(&outcome, [restricted[@"usesChatDefaults"] boolValue] == NO,
			"a restricted member must carry its own permissions, not the chat defaults");
	TGTestExpectTrue(&outcome, [restricted[@"isRestricted"] boolValue] == YES,
			"a restricted member must be reported as restricted");
	TGTestExpectEqualLongLong(&outcome, [restricted[@"untilDate"] longLongValue], 1700000000,
			"a restricted member must carry restricted_until_date as the until date");
	TGTestExpectTrue(&outcome,
			[restricted[@"permissions"][@"can_send_basic_messages"] boolValue] == YES,
			"a restricted member's own permissions must come through unchanged");

	NSDictionary *banned = TGFlattenMemberRestriction(@{
		@"@type" : @"chatMemberStatusBanned",
		@"banned_until_date" : @1800000000,
	});

	TGTestExpectTrue(&outcome, [banned[@"usesChatDefaults"] boolValue] == NO,
			"a banned member must not fall back to the chat defaults");
	TGTestExpectTrue(&outcome, [banned[@"isRestricted"] boolValue] == YES,
			"a banned member must be reported as restricted");
	TGTestExpectEqualLongLong(&outcome, [banned[@"untilDate"] longLongValue], 1800000000,
			"a banned member must carry banned_until_date as the until date");
	TGTestExpectEqualLongLong(&outcome, (long long)[banned[@"permissions"] count], 0,
			"a banned member must carry no permissions of its own");

	return outcome;
}

TGTestOutcome TGFlattenGroupsTestMemberRestrictionFallsBackToChatDefaultsForEveryOtherStatus(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *statuses = @[
		@{@"@type" : @"chatMemberStatusLeft"},
		@{@"@type" : @"chatMemberStatusMember"},
		@{@"@type" : @"chatMemberStatusAdministrator"},
		@{@"@type" : @"chatMemberStatusCreator"},
	];

	for (NSDictionary *status in statuses) {
		NSDictionary *state = TGFlattenMemberRestriction(status);
		TGTestExpectTrue(&outcome, [state[@"usesChatDefaults"] boolValue] == YES,
				"an unrestricted member must start from the chat's default permissions");
		TGTestExpectTrue(&outcome, [state[@"isRestricted"] boolValue] == NO,
				"an unrestricted member must not be reported as restricted");
		TGTestExpectEqualLongLong(&outcome, [state[@"untilDate"] longLongValue], 0,
				"an unrestricted member must report no until date");
	}

	NSDictionary *missing = TGFlattenMemberRestriction(nil);
	TGTestExpectTrue(&outcome, [missing[@"usesChatDefaults"] boolValue] == YES,
			"a missing status must fall back to the chat defaults, not crash");
	NSDictionary *wrongType = TGFlattenMemberRestriction(@"not a dictionary");
	TGTestExpectTrue(&outcome, [wrongType[@"isRestricted"] boolValue] == NO,
			"a non-dictionary status must not be reported as restricted");

	return outcome;
}

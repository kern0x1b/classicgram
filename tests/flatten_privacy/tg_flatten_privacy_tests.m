#import "tg_flatten_privacy_tests.h"
#import "../../src/Wire/Flatten/TGFlattenPrivacy.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenPrivacyTestReportReasonTypeForEachKnownReason(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *expected = @{
		@"spam" : @"reportReasonSpam",
		@"violence" : @"reportReasonViolence",
		@"pornography" : @"reportReasonPornography",
		@"childAbuse" : @"reportReasonChildAbuse",
		@"copyright" : @"reportReasonCopyright",
		@"unrelatedLocation" : @"reportReasonUnrelatedLocation",
		@"fake" : @"reportReasonFake",
		@"illegalDrugs" : @"reportReasonIllegalDrugs",
		@"personalDetails" : @"reportReasonPersonalDetails",
		@"custom" : @"reportReasonCustom",
	};

	for (NSString *reason in expected) {
		NSString *result = TGPrivacyReportReasonType(reason);
		TGTestExpectTrue(&outcome, [result isEqualToString:expected[reason]],
				"each known report reason must capitalize to its own reportReason<Name> TDLib type, not fall back to custom");
	}

	return outcome;
}

TGTestOutcome TGFlattenPrivacyTestReportReasonTypeFallsBackForUnknownReason(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGPrivacyReportReasonType(@"somethingWeUpstreamDoNotKnowAbout") isEqualToString:@"reportReasonCustom"],
			"a non-empty reason absent from the known list must fall back to reportReasonCustom, not fabricate a type from the unknown name");

	return outcome;
}

TGTestOutcome TGFlattenPrivacyTestReportReasonTypeFallsBackForEmptyOrNilReason(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPrivacyReportReasonType(@"") isEqualToString:@"reportReasonCustom"],
			"an empty reason must fall back to reportReasonCustom");
	TGTestExpectTrue(&outcome, [TGPrivacyReportReasonType(nil) isEqualToString:@"reportReasonCustom"],
			"a nil reason must fall back to reportReasonCustom, not crash");

	return outcome;
}

TGTestOutcome TGFlattenPrivacyTestRuleIsModelledForModelledRule(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGPrivacyRuleIsModelled(@"userPrivacySettingRuleAllowAll"),
			"userPrivacySettingRuleAllowAll is one of the base rules the caller composes explicitly, so it must be reported as modelled");
	TGTestExpectTrue(&outcome, TGPrivacyRuleIsModelled(@"userPrivacySettingRuleAllowUsers"),
			"userPrivacySettingRuleAllowUsers is composed explicitly from allowedUserIds, so it must be reported as modelled");
	TGTestExpectTrue(&outcome, TGPrivacyRuleIsModelled(@"userPrivacySettingRuleRestrictBots"),
			"userPrivacySettingRuleRestrictBots is composed explicitly from the restrictBots flag, so it must be reported as modelled");
	TGTestExpectTrue(&outcome, TGPrivacyRuleIsModelled(@"userPrivacySettingRuleAllowPremiumUsers"),
			"userPrivacySettingRuleAllowPremiumUsers is composed explicitly from the allowPremiumUsers flag, so it must be reported as modelled");

	return outcome;
}

TGTestOutcome TGFlattenPrivacyTestRuleIsModelledForUnmodelledRule(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGPrivacyRuleIsModelled(@"userPrivacySettingRuleAllowChatsFromDifferentRegion"),
			"a rule type the client never composes itself must be reported as unmodelled, so the write path preserves it verbatim from the server");
	TGTestExpectTrue(&outcome, !TGPrivacyRuleIsModelled(@""),
			"an empty rule type must be reported as unmodelled");

	return outcome;
}

TGTestOutcome TGFlattenPrivacyTestExceptionListRemovingRemovesConflictingIds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *list = @[ @1, @2, @3, @4 ];
	NSArray *toExclude = @[ @2, @4, @5 ];
	NSArray *result = TGPrivacyExceptionListRemoving(list, toExclude);

	TGTestExpectTrue(&outcome, [result isEqualToArray:(@[ @1, @3 ])],
			"a user id just added to the opposite exception list must be dropped from this one, so the same contact can never sit in both Always Share With and Never Share With");

	return outcome;
}

TGTestOutcome TGFlattenPrivacyTestExceptionListRemovingPreservesOrderWhenNoConflict(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *list = @[ @10, @20, @30 ];
	NSArray *result = TGPrivacyExceptionListRemoving(list, @[ @999 ]);

	TGTestExpectTrue(&outcome, [result isEqualToArray:list],
			"a list with no ids in common with the opposite list must come back unchanged, in the same order");

	return outcome;
}

TGTestOutcome TGFlattenPrivacyTestExceptionListRemovingHandlesNilOrEmptyInputsSafely(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGPrivacyExceptionListRemoving(nil, @[ @1 ]).count == 0,
			"a nil list must come back as an empty array rather than crash");
	TGTestExpectTrue(&outcome, [TGPrivacyExceptionListRemoving(@[ @1, @2 ], nil) isEqualToArray:(@[ @1, @2 ])],
			"a nil exclusion list must leave the original list untouched");
	TGTestExpectTrue(&outcome, [TGPrivacyExceptionListRemoving(@[ @1, @2 ], @[]) isEqualToArray:(@[ @1, @2 ])],
			"an empty exclusion list must leave the original list untouched");

	return outcome;
}

TGTestOutcome TGFlattenPrivacyTestRuleDictForTypeReturnsNilWhenValueIsEmpty(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGPrivacyRuleDictForType(@"userPrivacySettingRuleRestrictUsers", nil, @[], nil, nil, NO, NO, NO) == nil,
			"an empty restricted-users list must not produce a rule");
	TGTestExpectTrue(&outcome, TGPrivacyRuleDictForType(@"userPrivacySettingRuleAllowUsers", @[], nil, nil, nil, NO, NO, NO) == nil,
			"an empty allowed-users list must not produce a rule");
	TGTestExpectTrue(&outcome, TGPrivacyRuleDictForType(@"userPrivacySettingRuleRestrictChatMembers", nil, nil, nil, @[], NO, NO, NO) == nil,
			"an empty restricted-chats list must not produce a rule");
	TGTestExpectTrue(&outcome, TGPrivacyRuleDictForType(@"userPrivacySettingRuleAllowChatMembers", nil, nil, @[], nil, NO, NO, NO) == nil,
			"an empty allowed-chats list must not produce a rule");
	TGTestExpectTrue(&outcome, TGPrivacyRuleDictForType(@"userPrivacySettingRuleRestrictBots", nil, nil, nil, nil, NO, NO, NO) == nil,
			"restrictBots false must not produce a rule");
	TGTestExpectTrue(&outcome, TGPrivacyRuleDictForType(@"userPrivacySettingRuleAllowBots", nil, nil, nil, nil, NO, NO, NO) == nil,
			"allowBots false must not produce a rule");
	TGTestExpectTrue(&outcome, TGPrivacyRuleDictForType(@"userPrivacySettingRuleAllowPremiumUsers", nil, nil, nil, nil, NO, NO, NO) == nil,
			"allowPremiumUsers false must not produce a rule");

	return outcome;
}

TGTestOutcome TGFlattenPrivacyTestRuleDictForTypeReturnsRuleWhenValueIsPresent(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *restrictUsers = TGPrivacyRuleDictForType(@"userPrivacySettingRuleRestrictUsers", nil, @[ @7 ], nil, nil, NO, NO, NO);
	TGTestExpectTrue(&outcome, [restrictUsers isEqualToDictionary:(@{@"@type" : @"userPrivacySettingRuleRestrictUsers", @"user_ids" : @[ @7 ]})],
			"a non-empty restricted-users list must carry its ids into the rule");

	NSDictionary *allowUsers = TGPrivacyRuleDictForType(@"userPrivacySettingRuleAllowUsers", @[ @8, @9 ], nil, nil, nil, NO, NO, NO);
	TGTestExpectTrue(&outcome, [allowUsers isEqualToDictionary:(@{@"@type" : @"userPrivacySettingRuleAllowUsers", @"user_ids" : @[ @8, @9 ]})],
			"a non-empty allowed-users list must carry its ids into the rule");

	NSDictionary *restrictBots = TGPrivacyRuleDictForType(@"userPrivacySettingRuleRestrictBots", nil, nil, nil, nil, NO, YES, NO);
	TGTestExpectTrue(&outcome, [restrictBots isEqualToDictionary:(@{@"@type" : @"userPrivacySettingRuleRestrictBots"})],
			"restrictBots true must produce the bare restrict-bots rule");

	NSDictionary *allowPremium = TGPrivacyRuleDictForType(@"userPrivacySettingRuleAllowPremiumUsers", nil, nil, nil, nil, NO, NO, YES);
	TGTestExpectTrue(&outcome, [allowPremium isEqualToDictionary:(@{@"@type" : @"userPrivacySettingRuleAllowPremiumUsers"})],
			"allowPremiumUsers true must produce the bare allow-premium-users rule");

	return outcome;
}

TGTestOutcome TGFlattenPrivacyTestRebuiltRulesPreservesExistingAllowBeforeRestrictOrder(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *current = @[
		@{@"@type" : @"userPrivacySettingRuleAllowUsers", @"user_ids" : @[ @1, @2 ]},
		@{@"@type" : @"userPrivacySettingRuleRestrictUsers", @"user_ids" : @[ @3 ]},
	];

	NSArray *rebuilt = TGPrivacyRebuiltRules(current, @"userPrivacySettingRuleRestrictAll",
			@[ @1, @2 ], @[ @3 ], nil, nil, NO, NO, YES);

	NSArray *expected = @[
		@{@"@type" : @"userPrivacySettingRuleAllowUsers", @"user_ids" : @[ @1, @2 ]},
		@{@"@type" : @"userPrivacySettingRuleRestrictUsers", @"user_ids" : @[ @3 ]},
		@{@"@type" : @"userPrivacySettingRuleAllowPremiumUsers"},
		@{@"@type" : @"userPrivacySettingRuleRestrictAll"},
	];

	TGTestExpectTrue(&outcome, [rebuilt isEqualToArray:expected],
			"an unrelated edit (turning on allowPremiumUsers) must not reorder the pre-existing allow/restrict-specific-user rules, since their relative order is what decides which one wins for a user in both lists");

	return outcome;
}

TGTestOutcome TGFlattenPrivacyTestRebuiltRulesAppendsNewCategoriesInCanonicalOrder(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *rebuilt = TGPrivacyRebuiltRules(nil, @"userPrivacySettingRuleAllowAll",
			@[ @1 ], @[ @2 ], nil, nil, YES, YES, YES);

	NSArray *expected = @[
		@{@"@type" : @"userPrivacySettingRuleRestrictUsers", @"user_ids" : @[ @2 ]},
		@{@"@type" : @"userPrivacySettingRuleRestrictBots"},
		@{@"@type" : @"userPrivacySettingRuleAllowUsers", @"user_ids" : @[ @1 ]},
		@{@"@type" : @"userPrivacySettingRuleAllowBots"},
		@{@"@type" : @"userPrivacySettingRuleAllowPremiumUsers"},
		@{@"@type" : @"userPrivacySettingRuleAllowAll"},
	];

	TGTestExpectTrue(&outcome, [rebuilt isEqualToArray:expected],
			"when there is no current rule list to preserve an order from, brand new categories must fall back to the conventional restrict-before-allow order");

	return outcome;
}

TGTestOutcome TGFlattenPrivacyTestRebuiltRulesPreservesUnmodelledRuleInPlace(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *current = @[
		@{@"@type" : @"userPrivacySettingRuleAllowUsers", @"user_ids" : @[ @1 ]},
		@{@"@type" : @"userPrivacySettingRuleAllowChatsFromDifferentRegion"},
		@{@"@type" : @"userPrivacySettingRuleRestrictUsers", @"user_ids" : @[ @2 ]},
	];

	NSArray *rebuilt = TGPrivacyRebuiltRules(current, @"userPrivacySettingRuleRestrictAll",
			@[ @1 ], @[ @2 ], nil, nil, NO, NO, NO);

	NSArray *expected = @[
		@{@"@type" : @"userPrivacySettingRuleAllowUsers", @"user_ids" : @[ @1 ]},
		@{@"@type" : @"userPrivacySettingRuleAllowChatsFromDifferentRegion"},
		@{@"@type" : @"userPrivacySettingRuleRestrictUsers", @"user_ids" : @[ @2 ]},
		@{@"@type" : @"userPrivacySettingRuleRestrictAll"},
	];

	TGTestExpectTrue(&outcome, [rebuilt isEqualToArray:expected],
			"a rule type this client does not model must be preserved verbatim in its original position, not moved to the end");

	return outcome;
}

TGTestOutcome TGFlattenPrivacyTestRebuiltRulesDropsCategoryWhenNowEmpty(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *current = @[
		@{@"@type" : @"userPrivacySettingRuleAllowUsers", @"user_ids" : @[ @1, @2 ]},
	];

	NSArray *rebuilt = TGPrivacyRebuiltRules(current, @"userPrivacySettingRuleRestrictAll",
			nil, nil, nil, nil, NO, NO, NO);

	NSArray *expected = @[
		@{@"@type" : @"userPrivacySettingRuleRestrictAll"},
	];

	TGTestExpectTrue(&outcome, [rebuilt isEqualToArray:expected],
			"clearing the allowed-users list must drop the rule from its old position, not leave a stale copy behind");

	return outcome;
}

TGTestOutcome TGFlattenPrivacyTestRebuiltRulesAlwaysEndsWithBaseRule(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *rebuilt = TGPrivacyRebuiltRules(nil, @"userPrivacySettingRuleAllowContacts",
			nil, nil, nil, nil, NO, NO, NO);

	TGTestExpectTrue(&outcome, rebuilt.count == 1,
			"with no exceptions of any kind, only the base rule must be present");
	TGTestExpectTrue(&outcome, [rebuilt.lastObject isEqualToDictionary:(@{@"@type" : @"userPrivacySettingRuleAllowContacts"})],
			"the base rule must always be the last rule in the rebuilt list, matching TDLib's first-match-wins semantics");

	return outcome;
}

TGTestOutcome TGFlattenPrivacyTestSettingSupportsExceptionsFalseForFindingByPhoneNumber(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGPrivacySettingSupportsExceptions(@"AllowFindingByPhoneNumber"),
			"AllowFindingByPhoneNumber can only be Allow-contacts or Allow-all per the schema, so it must never report support for exception lists");

	return outcome;
}

TGTestOutcome TGFlattenPrivacyTestSettingSupportsExceptionsTrueForOtherSettings(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGPrivacySettingSupportsExceptions(@"LastSeen"),
			"a setting other than AllowFindingByPhoneNumber must still support exception lists");
	TGTestExpectTrue(&outcome, TGPrivacySettingSupportsExceptions(@"ShowPhoneNumber"),
			"a setting other than AllowFindingByPhoneNumber must still support exception lists");

	return outcome;
}

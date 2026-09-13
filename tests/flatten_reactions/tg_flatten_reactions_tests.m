#import "tg_flatten_reactions_tests.h"
#import "../../src/Wire/Flatten/TGFlattenReactions.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenReactionsTestUnavailabilityForAnonymousAdministrator(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *reason = @{@"@type" : @"reactionUnavailabilityReasonAnonymousAdministrator"};

	TGTestExpectTrue(&outcome,
			[TGReactionUnavailability(reason) isEqualToString:@"You cannot send reactions in this chat."],
			"reactionUnavailabilityReasonAnonymousAdministrator must explain that reacting is not allowed");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestUnavailabilityForGuest(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *reason = @{@"@type" : @"reactionUnavailabilityReasonGuest"};

	TGTestExpectTrue(&outcome,
			[TGReactionUnavailability(reason) isEqualToString:@"You cannot send reactions in this chat."],
			"reactionUnavailabilityReasonGuest must explain that reacting is not allowed");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestUnavailabilityForRestricted(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *reason = @{@"@type" : @"reactionUnavailabilityReasonRestricted"};

	TGTestExpectTrue(&outcome,
			[TGReactionUnavailability(reason) isEqualToString:@"You cannot send reactions in this chat."],
			"reactionUnavailabilityReasonRestricted must explain that reacting is not allowed");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestUnavailabilityFallsBackForUnknownReason(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *reason = @{@"@type" : @"reactionUnavailabilityReasonSomeFutureCase"};

	TGTestExpectTrue(&outcome, [TGReactionUnavailability(reason) isEqualToString:@""],
			"an unrecognised unavailability reason must flatten to an empty string, not crash");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestUnavailabilityFallsBackForNilOrNonDictionaryReason(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGReactionUnavailability(nil) isEqualToString:@""],
			"a nil unavailability reason must flatten to an empty string, not crash");
	TGTestExpectTrue(&outcome,
			[TGReactionUnavailability((NSDictionary *)@"not a dictionary") isEqualToString:@""],
			"a non-dictionary unavailability reason must flatten to an empty string, not crash");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestChipSignatureComposesMultipleChips(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *chips = @[
		@{@"emoji" : @"\U0001F44D", @"count" : @3, @"chosen" : @YES},
		@{@"emoji" : @"\U0001F525", @"count" : @0, @"chosen" : @NO},
	];

	NSString *signature = TGReactionChipSignature(chips);

	TGTestExpectTrue(&outcome,
			[signature isEqualToString:@"\U0001F44D|3|1;\U0001F525|0|0;"],
			"the signature must concatenate emoji, count and chosen flag for every chip in order");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestChipSignatureTreatsMissingEmojiAsEmptyString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *chips = @[
		@{@"count" : @2, @"chosen" : @NO},
		@{@"emoji" : @42, @"count" : @1, @"chosen" : @YES},
	];

	NSString *signature = TGReactionChipSignature(chips);

	TGTestExpectTrue(&outcome, [signature isEqualToString:@"|2|0;|1|1;"],
			"a chip with no emoji string (missing or wrong type) must contribute an empty emoji segment, not crash");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestChipSignatureSkipsNonDictionaryEntries(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *chips = @[
		@"not a dictionary",
		@{@"emoji" : @"\U00002764", @"count" : @5, @"chosen" : @YES},
	];

	NSString *signature = TGReactionChipSignature(chips);

	TGTestExpectTrue(&outcome, [signature isEqualToString:@"\U00002764|5|1;"],
			"a non-dictionary entry in the chip list must be skipped rather than crash the signature");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestChipSignatureReturnsEmptyForNilOrNonArrayOrEmptyInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGReactionChipSignature(nil) isEqualToString:@""],
			"a nil chip list must flatten to an empty signature, not crash");
	TGTestExpectTrue(&outcome,
			[TGReactionChipSignature((NSArray *)@{@"not" : @"an array"}) isEqualToString:@""],
			"a non-array chip list must flatten to an empty signature, not crash");
	TGTestExpectTrue(&outcome, [TGReactionChipSignature(@[]) isEqualToString:@""],
			"an empty chip list must flatten to an empty signature");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestSenderIdForUser(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *sender = @{@"@type" : @"messageSenderUser", @"user_id" : @12345};

	TGTestExpectEqualLongLong(&outcome, TGReactionSenderId(sender), 12345,
			"a messageSenderUser must resolve to its user_id");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestSenderIdForChat(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *sender = @{@"@type" : @"messageSenderChat", @"chat_id" : @(-6789)};

	TGTestExpectEqualLongLong(&outcome, TGReactionSenderId(sender), -6789,
			"a messageSenderChat must resolve to its chat_id, which is negative for channels and supergroups");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestSenderIdReturnsZeroForNilOrNonDictionaryOrEmptySender(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualLongLong(&outcome, TGReactionSenderId(nil), 0,
			"a nil sender must resolve to 0, not crash");
	TGTestExpectEqualLongLong(&outcome, TGReactionSenderId((NSDictionary *)@"not a dictionary"), 0,
			"a non-dictionary sender must resolve to 0, not crash");
	TGTestExpectEqualLongLong(&outcome, TGReactionSenderId(@{}), 0,
			"a sender dictionary missing both @type and user_id must resolve to 0 via the default user_id branch");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestUserQuotaIsOneForNonPremium(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualInteger(&outcome, TGReactionUserQuota(NO), 1,
			"a non-Premium account may have at most 1 chosen reaction on a single message");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestUserQuotaIsThreeForPremium(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualInteger(&outcome, TGReactionUserQuota(YES), 3,
			"a Premium account may have at most 3 chosen reactions on a single message");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestHasRoomForMoreDeniesNonPremiumUserAtQuota(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	BOOL room = TGReactionHasRoomForMore(1, 1, 11, NO);

	TGTestExpectTrue(&outcome, room == NO,
			"a non-Premium user who already chose 1 reaction must not be allowed to add another, "
			"even though the chat allows up to 11 distinct reaction types in total");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestHasRoomForMoreAllowsPremiumUserBelowQuotaWithChatRoom(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	BOOL room = TGReactionHasRoomForMore(1, 2, 11, YES);

	TGTestExpectTrue(&outcome, room == YES,
			"a Premium user who chose only 1 of their 3 allowed reactions must still be able to add "
			"another when the chat is nowhere near its own distinct-reaction-type cap");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestHasRoomForMoreDeniesWhenChatWideCapIsReachedEvenUnderUserQuota(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	BOOL room = TGReactionHasRoomForMore(0, 1, 1, YES);

	TGTestExpectTrue(&outcome, room == NO,
			"even a Premium user under their own quota must not be offered a new reaction type once "
			"the message has already reached the chat-wide cap on distinct reaction types");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestHasRoomForMoreTreatsNonPositiveChatMaxAsOne(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGReactionHasRoomForMore(0, 0, 0, NO) == YES,
			"a chat-wide cap of 0 must fall back to an effective cap of 1, not forbid every reaction");
	TGTestExpectTrue(&outcome, TGReactionHasRoomForMore(0, 1, 0, NO) == NO,
			"once a single distinct reaction already exists, the 0-falls-back-to-1 cap leaves no more room");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestTypeExistsOnMessageFindsMatchingEmoji(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *existing = @[@"\U0001F44D", @"\U0001F525"];

	TGTestExpectTrue(&outcome, TGReactionTypeExistsOnMessage(@"\U0001F525", existing) == YES,
			"a reaction type already carried by the message must be reported as existing, "
			"so the picker can exempt it from the chat's distinct-reaction-type cap");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestTypeExistsOnMessageReturnsNoWhenAbsent(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *existing = @[@"\U0001F44D"];

	TGTestExpectTrue(&outcome, TGReactionTypeExistsOnMessage(@"\U0001F525", existing) == NO,
			"a reaction type the message does not already carry must not be reported as existing, "
			"so a brand new type still counts against the cap");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestTypeExistsOnMessageReturnsNoForNilOrEmptyInputs(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGReactionTypeExistsOnMessage(nil, @[@"\U0001F44D"]) == NO,
			"a nil emoji must resolve to NO, not crash");
	TGTestExpectTrue(&outcome, TGReactionTypeExistsOnMessage(@"", @[@"\U0001F44D"]) == NO,
			"an empty emoji must resolve to NO, not crash");
	TGTestExpectTrue(&outcome, TGReactionTypeExistsOnMessage(@"\U0001F44D", nil) == NO,
			"a nil existing-types list must resolve to NO, not crash");
	TGTestExpectTrue(&outcome,
			TGReactionTypeExistsOnMessage(@"\U0001F44D", (NSArray *)@"not an array") == NO,
			"a non-array existing-types list must resolve to NO, not crash");
	TGTestExpectTrue(&outcome, TGReactionTypeExistsOnMessage(@"\U0001F44D", @[]) == NO,
			"an empty existing-types list must resolve to NO");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestChatIsSavedMessagesTrueWhenChatIdMatches(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGChatIsSavedMessages(777, 777) == YES,
			"a chat whose id equals the account's own Saved Messages chat id must be recognised as Saved Messages, "
			"so a renamed tag's label can be shown on its bubble only there");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestChatIsSavedMessagesFalseWhenChatIdDiffers(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGChatIsSavedMessages(777, 888) == NO,
			"an ordinary chat must never be treated as Saved Messages just because both ids are non-zero, "
			"otherwise a plain reaction in a normal chat would grow a tag label");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestChatIsSavedMessagesFalseWhenEitherIdIsZero(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGChatIsSavedMessages(0, 0) == NO,
			"two zero chat ids must not be reported as a Saved Messages match, since 0 means unknown, not equal");
	TGTestExpectTrue(&outcome, TGChatIsSavedMessages(777, 0) == NO,
			"a zero Saved Messages chat id (not yet known) must never match any real chat");
	TGTestExpectTrue(&outcome, TGChatIsSavedMessages(0, 777) == NO,
			"a zero chat id (not yet known) must never match a real Saved Messages chat");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestSavedMessagesTagLookupKeyPrefersEmoji(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *key = TGSavedMessagesTagLookupKey(@"\U0001F44D", 555);

	TGTestExpectTrue(&outcome, [key isEqualToString:@"\U0001F44D"],
			"an emoji tag must be keyed by its own emoji even when a custom emoji id is also present, "
			"matching the key scheme the Tags screen already uses");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestSavedMessagesTagLookupKeyBuildsCustomKeyWhenNoEmoji(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *key = TGSavedMessagesTagLookupKey(nil, 555);

	TGTestExpectTrue(&outcome, [key isEqualToString:@"custom:555"],
			"a custom emoji tag with no plain emoji must be keyed as custom:<id>, "
			"matching the key scheme the Tags screen already uses");

	return outcome;
}

TGTestOutcome TGFlattenReactionsTestSavedMessagesTagLookupKeyReturnsNilWhenNeitherIsSet(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGSavedMessagesTagLookupKey(nil, 0) == nil,
			"a tag with neither an emoji nor a custom emoji id must have no lookup key, not crash or fabricate one");
	TGTestExpectTrue(&outcome, TGSavedMessagesTagLookupKey(@"", 0) == nil,
			"an empty emoji string must be treated the same as no emoji at all");

	return outcome;
}

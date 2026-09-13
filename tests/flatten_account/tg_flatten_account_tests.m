#import "tg_flatten_account_tests.h"
#import "../../src/Wire/Flatten/TGFlattenAccount.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenAccountTestCodeDescriptionAndNextTitleForTelegramMessage(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *type = @{@"@type" : @"authenticationCodeTypeTelegramMessage"};

	TGTestExpectTrue(&outcome,
			[TGAccountCodeDescription(type, @"+1234567890")
					isEqualToString:@"We've sent the code to the Telegram app for +1234567890 on your other device."],
			"authenticationCodeTypeTelegramMessage must describe the code as sent to another Telegram app");
	TGTestExpectTrue(&outcome,
			[TGAccountNextTitle(type) isEqualToString:@"Send code via Telegram"],
			"authenticationCodeTypeTelegramMessage's next-step title must offer to send via Telegram");

	return outcome;
}

TGTestOutcome TGFlattenAccountTestCodeDescriptionAndNextTitleForSms(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *sms = @{@"@type" : @"authenticationCodeTypeSms"};
	NSDictionary *smsWord = @{@"@type" : @"authenticationCodeTypeSmsWord"};
	NSDictionary *smsPhrase = @{@"@type" : @"authenticationCodeTypeSmsPhrase"};

	TGTestExpectTrue(&outcome,
			[TGAccountCodeDescription(sms, @"+1234567890")
					isEqualToString:@"We've sent an SMS with an activation code to your phone +1234567890."],
			"authenticationCodeTypeSms must describe the code as an SMS to the given phone number");
	TGTestExpectTrue(&outcome,
			[TGAccountCodeDescription(sms, @"")
					isEqualToString:@"We've sent an SMS with an activation code to your phone your phone."],
			"authenticationCodeTypeSms with no phone number must fall back to \"your phone\"");
	TGTestExpectTrue(&outcome,
			[TGAccountCodeDescription(smsWord, @"+1234567890")
					isEqualToString:@"We've sent an SMS with an activation code to your phone +1234567890."],
			"authenticationCodeTypeSmsWord must describe the code the same as a plain SMS");
	TGTestExpectTrue(&outcome,
			[TGAccountCodeDescription(smsPhrase, @"+1234567890")
					isEqualToString:@"We've sent an SMS with an activation code to your phone +1234567890."],
			"authenticationCodeTypeSmsPhrase must describe the code the same as a plain SMS");
	TGTestExpectTrue(&outcome, [TGAccountNextTitle(sms) isEqualToString:@"Send the code as an SMS"],
			"authenticationCodeTypeSms's next-step title must offer to send via SMS");
	TGTestExpectTrue(&outcome, [TGAccountNextTitle(smsWord) isEqualToString:@"Send the code as an SMS"],
			"authenticationCodeTypeSmsWord's next-step title must offer to send via SMS");
	TGTestExpectTrue(&outcome, [TGAccountNextTitle(smsPhrase) isEqualToString:@"Send the code as an SMS"],
			"authenticationCodeTypeSmsPhrase's next-step title must offer to send via SMS");

	return outcome;
}

TGTestOutcome TGFlattenAccountTestCodeDescriptionAndNextTitleForCall(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *type = @{@"@type" : @"authenticationCodeTypeCall"};

	TGTestExpectTrue(&outcome,
			[TGAccountCodeDescription(type, @"+1234567890")
					isEqualToString:@"We are calling your phone to dictate a code."],
			"authenticationCodeTypeCall must describe the code as dictated over a call");
	TGTestExpectTrue(&outcome, [TGAccountNextTitle(type) isEqualToString:@"Call me to dictate the code"],
			"authenticationCodeTypeCall's next-step title must offer to call again");

	return outcome;
}

TGTestOutcome TGFlattenAccountTestCodeDescriptionAndNextTitleForMissedCall(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *type = @{@"@type" : @"authenticationCodeTypeMissedCall"};

	TGTestExpectTrue(&outcome,
			[TGAccountCodeDescription(type, @"+1234567890")
					isEqualToString:@"Please enter the last digits\nof the number that called."],
			"authenticationCodeTypeMissedCall must warn not to answer and explain the last-digits trick");
	TGTestExpectTrue(&outcome, [TGAccountNextTitle(type) isEqualToString:@"Call me to dictate the code"],
			"authenticationCodeTypeMissedCall's next-step title must offer to call again");

	return outcome;
}

TGTestOutcome TGFlattenAccountTestCodeDescriptionAndNextTitleForFlashCall(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *type = @{@"@type" : @"authenticationCodeTypeFlashCall"};

	TGTestExpectTrue(&outcome,
			[TGAccountCodeDescription(type, @"+1234567890")
					isEqualToString:@"We are calling your phone. Do not answer."],
			"authenticationCodeTypeFlashCall must warn not to answer, without the last-digits explanation");
	TGTestExpectTrue(&outcome, [TGAccountNextTitle(type) isEqualToString:@"Call me to dictate the code"],
			"authenticationCodeTypeFlashCall's next-step title must offer to call again");

	return outcome;
}

TGTestOutcome TGFlattenAccountTestCodeDescriptionAndNextTitleForFragment(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *type = @{@"@type" : @"authenticationCodeTypeFragment"};

	TGTestExpectTrue(&outcome,
			[TGAccountCodeDescription(type, @"+1234567890")
					isEqualToString:@"Get the code for +1234567890 in the Anonymous Numbers section on Fragment."],
			"authenticationCodeTypeFragment must describe the code as sent to the Fragment number");
	TGTestExpectTrue(&outcome, [TGAccountNextTitle(type) isEqualToString:@"Get a code via Fragment"],
			"authenticationCodeTypeFragment's next-step title must offer to get a code via Fragment");

	return outcome;
}

TGTestOutcome TGFlattenAccountTestCodeDescriptionAndNextTitleForFirebase(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *android = @{@"@type" : @"authenticationCodeTypeFirebaseAndroid"};
	NSDictionary *ios = @{@"@type" : @"authenticationCodeTypeFirebaseIos"};

	TGTestExpectTrue(&outcome,
			[TGAccountCodeDescription(android, @"+1234567890")
					isEqualToString:@"We've sent an SMS with an activation code to your phone +1234567890."],
			"authenticationCodeTypeFirebaseAndroid must describe the code the same as a plain SMS");
	TGTestExpectTrue(&outcome,
			[TGAccountCodeDescription(ios, @"+1234567890")
					isEqualToString:@"We've sent an SMS with an activation code to your phone +1234567890."],
			"authenticationCodeTypeFirebaseIos must describe the code the same as a plain SMS");
	TGTestExpectTrue(&outcome, [TGAccountNextTitle(android) isEqualToString:@"Send code again"],
			"authenticationCodeTypeFirebaseAndroid is not one of the call/sms/telegram/fragment next-step groups, so its next-step title must be the generic \"Send code again\"");

	return outcome;
}

TGTestOutcome TGFlattenAccountTestCodeDescriptionAndNextTitleFallsBackForUnknownType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *type = @{@"@type" : @"authenticationCodeTypeSomeFutureKind"};

	TGTestExpectTrue(&outcome,
			[TGAccountCodeDescription(type, @"+1234567890")
					isEqualToString:@"Enter the code you received."],
			"an unrecognised but named authentication code type must fall back to the generic instruction, not crash or return empty");
	TGTestExpectTrue(&outcome, [TGAccountNextTitle(type) isEqualToString:@"Send code again"],
			"an unrecognised but named authentication code type's next-step title must fall back to \"Send code again\"");

	return outcome;
}

TGTestOutcome TGFlattenAccountTestCodeDescriptionAndNextTitleFallsBackForNilType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGAccountCodeDescription(nil, nil) isEqualToString:@""],
			"a nil code type must flatten to an empty description, not crash");
	TGTestExpectTrue(&outcome, [TGAccountNextTitle(nil) isEqualToString:@""],
			"a nil code type must flatten to an empty next-step title, not crash");

	return outcome;
}

TGTestOutcome TGFlattenAccountTestCodeInfoDictComposesRealisticPayload(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *codeInfo = @{
		@"@type" : @"authenticationCodeInfo",
		@"phone_number" : @"+1234567890",
		@"type" : @{@"@type" : @"authenticationCodeTypeSms", @"length" : @5},
		@"timeout" : @60,
		@"next_type" : @{@"@type" : @"authenticationCodeTypeCall"},
	};

	NSDictionary *flat = TGAccountCodeInfoDict(codeInfo);

	TGTestExpectTrue(&outcome, flat != nil,
			"a well-formed authenticationCodeInfo must compose to a dictionary, not nil");
	TGTestExpectTrue(&outcome, [flat[@"phone"] isEqualToString:@"+1234567890"],
			"the composed dict's phone must come from phone_number verbatim");
	TGTestExpectTrue(&outcome, [flat[@"type"] isEqualToString:@"authenticationCodeTypeSms"],
			"the composed dict's type must be the raw TDLib type name");
	TGTestExpectTrue(&outcome,
			[flat[@"description"] isEqualToString:@"We've sent an SMS with an activation code to your phone +1234567890."],
			"the composed dict's description must be produced from the same TGAccountCodeDescription logic");
	TGTestExpectEqualInteger(&outcome, [flat[@"length"] integerValue], 5,
			"the composed dict's length must round-trip from type.length");
	TGTestExpectEqualInteger(&outcome, [flat[@"timeout"] integerValue], 60,
			"the composed dict's timeout must round-trip from the raw info");
	TGTestExpectTrue(&outcome, [flat[@"nextType"] isEqualToString:@"authenticationCodeTypeCall"],
			"the composed dict's nextType must be the raw next_type's TDLib type name");
	TGTestExpectTrue(&outcome, [flat[@"nextDescription"] isEqualToString:@"Call me to dictate the code"],
			"the composed dict's nextDescription must be produced from the same TGAccountNextTitle logic");

	return outcome;
}

TGTestOutcome TGFlattenAccountTestCodeInfoDictReturnsNilForNonDictionaryInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGAccountCodeInfoDict(nil) == nil,
			"a nil code info must compose to nil, not crash or fabricate a dictionary");
	TGTestExpectTrue(&outcome, TGAccountCodeInfoDict((NSDictionary *)@"not a dictionary") == nil,
			"a non-dictionary code info must compose to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenAccountTestEmailCodeInfoComposesPatternAndLength(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *codeInfo = @{
		@"@type" : @"emailAddressAuthenticationCodeInfo",
		@"email_address_pattern" : @"a*b@example.com",
		@"length" : @6,
	};

	NSDictionary *flat = TGAccountEmailCodeInfo(codeInfo);

	TGTestExpectTrue(&outcome, [flat[@"pattern"] isEqualToString:@"a*b@example.com"],
			"the composed email code dict's pattern must round-trip from email_address_pattern");
	TGTestExpectEqualInteger(&outcome, [flat[@"codeLength"] integerValue], 6,
			"the composed email code dict's codeLength must round-trip from length");

	return outcome;
}

TGTestOutcome TGFlattenAccountTestEmailCodeInfoReturnsNilForNonDictionaryInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGAccountEmailCodeInfo(nil) == nil,
			"a nil email code info must compose to nil, not crash or fabricate a dictionary");
	TGTestExpectTrue(&outcome, TGAccountEmailCodeInfo((NSDictionary *)@42) == nil,
			"a non-dictionary email code info must compose to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenAccountTestSessionDictKeepsIdWhenTdlibSendsItAsAString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *session = @{
		@"@type" : @"session",
		@"id" : @"1234567890123456789",
	};

	NSDictionary *flat = TGAccountSessionDict(session);

	TGTestExpectEqualLongLong(&outcome, [flat[@"id"] longLongValue], 1234567890123456789LL,
			"a session id that TDLib's JSON bridge serialised as a string must still resolve to the real id, not 0");

	return outcome;
}

TGTestOutcome TGFlattenAccountTestSessionDictKeepsIdWhenTdlibSendsItAsANumber(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *session = @{
		@"@type" : @"session",
		@"id" : @987654321,
	};

	NSDictionary *flat = TGAccountSessionDict(session);

	TGTestExpectEqualLongLong(&outcome, [flat[@"id"] longLongValue], 987654321LL,
			"a session id that arrives as a plain NSNumber must round-trip unchanged");

	return outcome;
}

TGTestOutcome TGFlattenAccountTestSessionDictCarriesPasswordPendingAndUnconfirmedFlags(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *pending = @{
		@"@type" : @"session",
		@"id" : @"42",
		@"is_password_pending" : @YES,
		@"is_unconfirmed" : @NO,
	};
	NSDictionary *confirmed = @{
		@"@type" : @"session",
		@"id" : @"43",
		@"is_password_pending" : @NO,
		@"is_unconfirmed" : @NO,
	};

	NSDictionary *flatPending = TGAccountSessionDict(pending);
	NSDictionary *flatConfirmed = TGAccountSessionDict(confirmed);

	TGTestExpectTrue(&outcome, [flatPending[@"isPasswordPending"] boolValue],
			"a QR login confirmation whose Session has is_password_pending must surface that flag, not silently report full success");
	TGTestExpectTrue(&outcome, ![flatPending[@"isUnconfirmed"] boolValue],
			"is_unconfirmed must not be conflated with is_password_pending");
	TGTestExpectTrue(&outcome, ![flatConfirmed[@"isPasswordPending"] boolValue],
			"a fully confirmed session must not be reported as password-pending");

	return outcome;
}

TGTestOutcome TGFlattenAccountTestSessionDictReturnsNilForNonDictionaryInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGAccountSessionDict(nil) == nil,
			"a nil session must compose to nil, not crash or fabricate a dictionary");
	TGTestExpectTrue(&outcome, TGAccountSessionDict((NSDictionary *)@"not a dictionary") == nil,
			"a non-dictionary session must compose to nil, not crash");

	return outcome;
}

#import "tg_contact_name_tests.h"
#import "../../src/Utilities/TGContactName.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGContactNameTestFullFirstAndLastName(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *u = @{
		@"first_name" : @"John",
		@"last_name" : @"Doe",
	};

	TGTestExpectTrue(&outcome, [TGContactName(u) isEqualToString:@"John Doe"],
			"first and last name present must join as first, space, last");

	return outcome;
}

TGTestOutcome TGContactNameTestFirstNameOnly(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *u = @{
		@"first_name" : @"John",
	};

	TGTestExpectTrue(&outcome, [TGContactName(u) isEqualToString:@"John"],
			"a missing last name must not leave a trailing space after the first name");

	return outcome;
}

TGTestOutcome TGContactNameTestLastNameOnly(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *u = @{
		@"last_name" : @"Doe",
	};

	TGTestExpectTrue(&outcome, [TGContactName(u) isEqualToString:@"Doe"],
			"a missing first name must not leave a leading space before the last name");

	return outcome;
}

TGTestOutcome TGContactNameTestBlankNameFallsThroughToUsername(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *u = @{
		@"first_name" : @"",
		@"last_name" : @"",
		@"username" : @"alice",
	};

	TGTestExpectTrue(&outcome, [TGContactName(u) isEqualToString:@"@alice"],
			"a blank first and last name must fall through to the @username");

	NSDictionary *withoutNameKeys = @{
		@"username" : @"bob",
	};

	TGTestExpectTrue(&outcome, [TGContactName(withoutNameKeys) isEqualToString:@"@bob"],
			"missing first and last name keys entirely must also fall through to the @username");

	return outcome;
}

TGTestOutcome TGContactNameTestBlankNameAndUsernameFallsThroughToPhone(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *u = @{
		@"username" : @"",
		@"phone" : @"+15551234567",
	};

	TGTestExpectTrue(&outcome, [TGContactName(u) isEqualToString:@"+15551234567"],
			"a blank name and blank username must fall through to the raw phone number");

	return outcome;
}

TGTestOutcome TGContactNameTestEverythingMissingReturnsEmptyString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *u = @{};

	TGTestExpectTrue(&outcome, [TGContactName(u) isEqualToString:@""],
			"a dictionary with no name, username or phone must fall through to an empty string");

	return outcome;
}

TGTestOutcome TGContactNameTestWrongTypeValueDoesNotCrash(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *partiallyWrong = @{
		@"first_name" : @42,
		@"last_name" : @"Doe",
	};

	TGTestExpectTrue(&outcome, [TGContactName(partiallyWrong) isEqualToString:@"Doe"],
			"a non-string first_name must be treated as blank rather than crashing or stringifying the number");

	NSDictionary *allWrong = @{
		@"first_name" : @1,
		@"last_name" : @2,
		@"username" : @3,
		@"phone" : @4,
	};

	TGTestExpectTrue(&outcome, [TGContactName(allWrong) isEqualToString:@""],
			"every field being the wrong type must fall all the way through to an empty string without crashing");

	return outcome;
}

TGTestOutcome TGContactStringTestReturnsEmptyForMissingOrWrongTypeKey(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *u = @{
		@"phone" : @"+15551234567",
		@"username" : @99,
	};

	TGTestExpectTrue(&outcome, [TGContactString(u, @"phone") isEqualToString:@"+15551234567"],
			"a present string key must be returned verbatim");
	TGTestExpectTrue(&outcome, [TGContactString(u, @"missing_key") isEqualToString:@""],
			"a key absent from the dictionary must resolve to an empty string");
	TGTestExpectTrue(&outcome, [TGContactString(u, @"username") isEqualToString:@""],
			"a key present but holding a non-string value must resolve to an empty string");

	return outcome;
}

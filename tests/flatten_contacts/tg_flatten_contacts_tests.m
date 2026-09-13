#import "tg_flatten_contacts_tests.h"
#import "../../src/Wire/Flatten/TGFlattenContacts.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenContactsTestBirthdateWithDayMonthAndYear(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *birthdate = @{@"@type" : @"birthdate", @"day" : @14, @"month" : @7, @"year" : @1990};
	NSDictionary *flat = TGBirthdateInfo(birthdate);

	TGTestExpectTrue(&outcome, flat != nil,
			"a birthdate with a day, month and year must compose to a dictionary, not nil");
	TGTestExpectEqualInteger(&outcome, [flat[@"day"] integerValue], 14,
			"the composed birthdate's day must round-trip verbatim");
	TGTestExpectEqualInteger(&outcome, [flat[@"month"] integerValue], 7,
			"the composed birthdate's month must round-trip verbatim");
	TGTestExpectEqualInteger(&outcome, [flat[@"year"] integerValue], 1990,
			"the composed birthdate's year must round-trip verbatim");
	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@"14 July 1990"],
			"a birthdate with a year must render as \"<day> <month name> <year>\"");

	return outcome;
}

TGTestOutcome TGFlattenContactsTestBirthdateWithDayAndMonthOnly(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *birthdate = @{@"@type" : @"birthdate", @"day" : @1, @"month" : @1};
	NSDictionary *flat = TGBirthdateInfo(birthdate);

	TGTestExpectTrue(&outcome, flat != nil,
			"a birthdate with a day and month but no year must still compose to a dictionary");
	TGTestExpectEqualInteger(&outcome, [flat[@"year"] integerValue], 0,
			"a birthdate with no year must report year 0");
	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@"1 January"],
			"a birthdate with no year must render as \"<day> <month name>\", with no year suffix");

	return outcome;
}

TGTestOutcome TGFlattenContactsTestBirthdateRejectsInvalidDay(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGBirthdateInfo(@{@"day" : @0, @"month" : @5}) == nil,
			"a day of 0 must compose to nil, not a fabricated date");
	TGTestExpectTrue(&outcome, TGBirthdateInfo(@{@"day" : @(-3), @"month" : @5}) == nil,
			"a negative day must compose to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenContactsTestBirthdateRejectsInvalidMonth(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGBirthdateInfo(@{@"day" : @10, @"month" : @0}) == nil,
			"a month of 0 must compose to nil, not a fabricated date");
	TGTestExpectTrue(&outcome, TGBirthdateInfo(@{@"day" : @10, @"month" : @13}) == nil,
			"a month of 13 must compose to nil, not index past the month name table");
	TGTestExpectTrue(&outcome, TGBirthdateInfo(@{@"day" : @31, @"month" : @12, @"year" : @2000}) != nil,
			"day 31 / month 12 is the last valid calendar month and must compose successfully");

	return outcome;
}

TGTestOutcome TGFlattenContactsTestBirthdateRejectsNonDictionaryInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGBirthdateInfo(nil) == nil,
			"a nil birthdate must compose to nil, not crash");
	TGTestExpectTrue(&outcome, TGBirthdateInfo(@"not a dictionary") == nil,
			"a non-dictionary birthdate must compose to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenContactsTestBirthdateIsTodayMatchesTodaysDayAndMonth(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDateComponents *today = [[NSCalendar currentCalendar]
		components:(NSDayCalendarUnit | NSMonthCalendarUnit)
		  fromDate:[NSDate date]];
	NSDictionary *birthdate = @{@"day" : @(today.day), @"month" : @(today.month)};

	TGTestExpectTrue(&outcome, TGBirthdateIsToday(birthdate),
			"a birthdate whose day and month match today's date must report YES");

	return outcome;
}

TGTestOutcome TGFlattenContactsTestBirthdateIsTodayRejectsADifferentMonth(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDateComponents *today = [[NSCalendar currentCalendar]
		components:(NSDayCalendarUnit | NSMonthCalendarUnit)
		  fromDate:[NSDate date]];
	NSInteger otherMonth = (today.month % 12) + 1;
	NSDictionary *birthdate = @{@"day" : @(today.day), @"month" : @(otherMonth)};

	TGTestExpectTrue(&outcome, TGBirthdateIsToday(birthdate) == NO,
			"a birthdate whose month does not match today's month must report NO, even with a matching day");

	return outcome;
}

TGTestOutcome TGFlattenContactsTestBirthdateIsTodayRejectsInvalidDayOrMonth(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGBirthdateIsToday(@{@"day" : @0, @"month" : @5}) == NO,
			"a day of 0 must report NO, not crash");
	TGTestExpectTrue(&outcome, TGBirthdateIsToday(@{@"day" : @10, @"month" : @0}) == NO,
			"a month of 0 must report NO, not crash");

	return outcome;
}

TGTestOutcome TGFlattenContactsTestBirthdateIsTodayRejectsNonDictionaryInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGBirthdateIsToday(nil) == NO,
			"a nil birthdate must report NO, not crash");
	TGTestExpectTrue(&outcome, TGBirthdateIsToday((NSDictionary *)@"not a dictionary") == NO,
			"a non-dictionary birthdate must report NO, not crash");

	return outcome;
}

TGTestOutcome TGFlattenContactsTestFlatUserComposesRealisticPayload(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *user = @{
		@"@type" : @"user",
		@"id" : @42,
		@"first_name" : @"Ada",
		@"last_name" : @"Lovelace",
		@"phone_number" : @"+1234567890",
		@"usernames" : @{@"active_usernames" : @[ @"ada" ]},
		@"profile_photo" : @{@"small" : @{@"id" : @555}},
		@"is_contact" : @YES,
		@"is_mutual_contact" : @YES,
		@"is_close_friend" : @NO,
		@"is_premium" : @YES,
	};

	NSDictionary *flat = TGFlatUser(user);

	TGTestExpectTrue(&outcome, flat != nil,
			"a well-formed user payload must compose to a dictionary, not nil");
	TGTestExpectEqualLongLong(&outcome, [flat[@"id"] longLongValue], 42,
			"the composed user's id must round-trip verbatim");
	TGTestExpectTrue(&outcome, [flat[@"first_name"] isEqualToString:@"Ada"],
			"the composed user's first_name must round-trip verbatim");
	TGTestExpectTrue(&outcome, [flat[@"last_name"] isEqualToString:@"Lovelace"],
			"the composed user's last_name must round-trip verbatim");
	TGTestExpectTrue(&outcome, [flat[@"phone"] isEqualToString:@"+1234567890"],
			"the composed user's phone must come from phone_number verbatim");
	TGTestExpectTrue(&outcome, [flat[@"username"] isEqualToString:@"ada"],
			"the composed user's username must be produced from the same TGFirstUsername logic");
	TGTestExpectEqualLongLong(&outcome, [flat[@"photoFileId"] longLongValue], 555,
			"the composed user's photoFileId must come from profile_photo.small.id");
	TGTestExpectTrue(&outcome, [flat[@"isContact"] boolValue] == YES,
			"the composed user's isContact must round-trip verbatim");
	TGTestExpectTrue(&outcome, [flat[@"isMutualContact"] boolValue] == YES,
			"the composed user's isMutualContact must round-trip verbatim");
	TGTestExpectTrue(&outcome, [flat[@"isCloseFriend"] boolValue] == NO,
			"the composed user's isCloseFriend must round-trip verbatim");
	TGTestExpectTrue(&outcome, [flat[@"isPremium"] boolValue] == YES,
			"the composed user's isPremium must round-trip verbatim");

	return outcome;
}

TGTestOutcome TGFlattenContactsTestFlatUserRejectsWrongType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGFlatUser(nil) == nil,
			"a nil user must compose to nil, not crash");
	TGTestExpectTrue(&outcome, TGFlatUser(@{@"@type" : @"error"}) == nil,
			"a payload whose @type is not \"user\" must compose to nil");
	TGTestExpectTrue(&outcome, TGFlatUser((NSDictionary *)@"not a dictionary") == nil,
			"a non-dictionary input must compose to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenContactsTestFirstUsernamePrefersActiveUsername(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *user = @{
		@"usernames" : @{
			@"active_usernames" : @[ @"primary", @"secondary" ],
			@"editable_username" : @"editable",
		},
	};

	TGTestExpectTrue(&outcome, [TGFirstUsername(user) isEqualToString:@"primary"],
			"when active_usernames is non-empty, the first active username must win over the editable one");

	return outcome;
}

TGTestOutcome TGFlattenContactsTestFirstUsernameFallsBackToEditableUsername(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *user = @{
		@"usernames" : @{
			@"active_usernames" : @[],
			@"editable_username" : @"editable",
		},
	};

	TGTestExpectTrue(&outcome, [TGFirstUsername(user) isEqualToString:@"editable"],
			"when active_usernames is empty, the editable username must be used");

	return outcome;
}

TGTestOutcome TGFlattenContactsTestFirstUsernameEmptyWhenNoUsernames(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGFirstUsername(@{}) isEqualToString:@""],
			"a user with no usernames dictionary at all must fall back to an empty string, not crash");
	TGTestExpectTrue(&outcome, [TGFirstUsername(nil) isEqualToString:@""],
			"a nil user must fall back to an empty string, not crash");

	return outcome;
}

TGTestOutcome TGFlattenContactsTestProfileTabNameMapsEachKnownTab(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *cases = @{
		@"profileTabPosts" : @"posts",
		@"profileTabGifts" : @"gifts",
		@"profileTabMedia" : @"media",
		@"profileTabFiles" : @"files",
		@"profileTabLinks" : @"links",
		@"profileTabMusic" : @"music",
		@"profileTabVoice" : @"voice",
		@"profileTabGifs" : @"gifs",
	};

	for (NSString *type in cases) {
		NSDictionary *tab = @{@"@type" : type};
		NSString *result = TGProfileTabName(tab);
		TGTestExpectTrue(&outcome, [result isEqualToString:cases[type]],
				"each profileTab<Name> TDLib type must map to its lowercase tab name");
	}

	return outcome;
}

TGTestOutcome TGFlattenContactsTestProfileTabNameRejectsUnrelatedType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGProfileTabName(@{@"@type" : @"somethingElse"}) == nil,
			"a type without the profileTab prefix must map to nil");
	TGTestExpectTrue(&outcome, TGProfileTabName(@{@"@type" : @"profileTab"}) == nil,
			"the bare \"profileTab\" type with no suffix must map to nil, not an empty string");
	TGTestExpectTrue(&outcome, TGProfileTabName(nil) == nil,
			"a nil tab must map to nil, not crash");

	return outcome;
}

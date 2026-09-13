#import "tg_phone_strip_tests.h"
#import "../../src/Utilities/TGPhoneFormat.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGPhoneStripTestKeepsOnlyDigitsFromLettersSpacesAndDashes(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *stripped = [TGPhoneFormat strip:@"Call +1 (555) 123-4567 now"];

	TGTestExpectTrue(&outcome, [stripped isEqualToString:@"+15551234567"],
			"letters, spaces, dashes and parentheses must all be dropped, keeping only the digits and the leading +");

	return outcome;
}

TGTestOutcome TGPhoneStripTestKeepsLeadingPlus(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *stripped = [TGPhoneFormat strip:@"+44 20 7946 0958"];

	TGTestExpectTrue(&outcome, [stripped isEqualToString:@"+442079460958"],
			"a leading + together with spaced digit groups must collapse to the + followed by the digits alone");

	return outcome;
}

TGTestOutcome TGPhoneStripTestKeepsStarAndHash(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *stripped = [TGPhoneFormat strip:@"*123#456*"];

	TGTestExpectTrue(&outcome, [stripped isEqualToString:@"*123#456*"],
			"* and # are members of the allowed character set and must survive stripping unchanged");

	return outcome;
}

TGTestOutcome TGPhoneStripTestAllInvalidCharactersYieldsEmptyString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *stripped = [TGPhoneFormat strip:@"Hello World!"];

	TGTestExpectTrue(&outcome, [stripped isEqualToString:@""],
			"a string with no digits, +, *, or # must strip down to an empty string, not nil or the original text");

	return outcome;
}

TGTestOutcome TGPhoneStripTestAlreadyCleanNumericStringIsUnchanged(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *stripped = [TGPhoneFormat strip:@"1234567890"];

	TGTestExpectTrue(&outcome, [stripped isEqualToString:@"1234567890"],
			"a string that is already only digits must pass through unchanged");

	return outcome;
}

TGTestOutcome TGPhoneStripTestEmptyStringYieldsEmptyString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *stripped = [TGPhoneFormat strip:@""];

	TGTestExpectTrue(&outcome, [stripped isEqualToString:@""],
			"an empty input string must strip down to an empty string, not crash");

	return outcome;
}

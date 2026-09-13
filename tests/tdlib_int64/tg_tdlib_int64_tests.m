#import "tg_tdlib_int64_tests.h"
#import "../../src/Wire/Types/TGTDLibInt64.h"

TGTestOutcome TGTDLibInt64TestAnIdentifierSurvivesTheWayTDLibSendsIt(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGTDLibInt64(@(1234567890123LL)) == 1234567890123LL,
			"an int53 field arrives as a number and reads back unchanged");
	TGTestExpectTrue(&outcome, TGTDLibInt64(@"1234567890123") == 1234567890123LL,
			"an int64 field arrives as a string, which is the whole reason this exists");
	TGTestExpectTrue(&outcome, TGTDLibInt64(@"-1001234567890123") == -1001234567890123LL,
			"a supergroup identifier keeps its sign and all sixteen digits");
	TGTestExpectTrue(&outcome, TGTDLibInt64(@"9007199254740993") == 9007199254740993LL,
			"a value past what a double can hold exactly is read digit for digit, not through "
			"floating point");
	TGTestExpectTrue(&outcome, TGTDLibInt64(@"0") == 0, "a zero identifier is zero");
	TGTestExpectTrue(&outcome, TGTDLibInt64(nil) == 0, "a missing field is zero");
	TGTestExpectTrue(&outcome, TGTDLibInt64([NSNull null]) == 0, "a null field is zero");
	TGTestExpectTrue(&outcome, TGTDLibInt64(@"") == 0, "an empty string is zero");
	TGTestExpectTrue(&outcome, TGTDLibInt64(@"not a number") == 0,
			"a field that is a real string and not an identifier reads as zero rather than as "
			"whatever leading digits it happens to have");
	TGTestExpectTrue(&outcome, TGTDLibInt64(@{}) == 0, "a dictionary is not an identifier");

	return outcome;
}

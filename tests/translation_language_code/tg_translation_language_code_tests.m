#import "tg_translation_language_code_tests.h"
#import "../../src/Screens/Chat/TGTranslationLanguageCode.h"

TGTestOutcome TGTranslationLanguageCodeTestOrdinaryTwoLetterLocaleTruncates(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *code = TGTranslationLanguageCodeForLocaleIdentifier(@"en-US");
	TGTestExpectTrue(&outcome, [code isEqualToString:@"en"],
			"an ordinary BCP-47 locale must still truncate to its ISO 639-1 language subtag");

	return outcome;
}

TGTestOutcome TGTranslationLanguageCodeTestNorwegianBokmalMapsToNo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *code = TGTranslationLanguageCodeForLocaleIdentifier(@"nb-NO");
	TGTestExpectTrue(&outcome, [code isEqualToString:@"no"],
			"a device reporting Norwegian Bokmal as nb-NO must be translated using TDLib's accepted \"no\" code, not the unsupported \"nb\"");

	return outcome;
}

TGTestOutcome TGTranslationLanguageCodeTestNorwegianNynorskMapsToNo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *code = TGTranslationLanguageCodeForLocaleIdentifier(@"nn-NO");
	TGTestExpectTrue(&outcome, [code isEqualToString:@"no"],
			"a device reporting Norwegian Nynorsk as nn-NO must fall back to TDLib's accepted \"no\" code");

	return outcome;
}

TGTestOutcome TGTranslationLanguageCodeTestFilipinoMapsToTl(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *code = TGTranslationLanguageCodeForLocaleIdentifier(@"fil-PH");
	TGTestExpectTrue(&outcome, [code isEqualToString:@"tl"],
			"a device reporting Filipino as fil-PH must not be truncated to \"fi\", which is Finnish in TDLib's accepted codes");

	return outcome;
}

TGTestOutcome TGTranslationLanguageCodeTestHawaiianKeepsFullCode(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *code = TGTranslationLanguageCodeForLocaleIdentifier(@"haw-US");
	TGTestExpectTrue(&outcome, [code isEqualToString:@"haw"],
			"a device reporting Hawaiian must keep the full three-letter code, since truncating to \"ha\" would request Hausa instead");

	return outcome;
}

TGTestOutcome TGTranslationLanguageCodeTestNilLocaleFallsBackToEnglish(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *code = TGTranslationLanguageCodeForLocaleIdentifier(nil);
	TGTestExpectTrue(&outcome, [code isEqualToString:@"en"],
			"a missing preferred locale must fall back to English rather than crashing or sending an empty code");

	return outcome;
}

TGTestOutcome TGTranslationLanguageCodeTestEmptyLocaleFallsBackToEnglish(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *code = TGTranslationLanguageCodeForLocaleIdentifier(@"");
	TGTestExpectTrue(&outcome, [code isEqualToString:@"en"],
			"an empty preferred locale must fall back to English rather than sending an empty code");

	return outcome;
}

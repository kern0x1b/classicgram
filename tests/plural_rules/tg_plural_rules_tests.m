#import "tg_plural_rules_tests.h"
#import "../../src/Utilities/TGPluralRules.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGPluralRulesTestArabicSixForm(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPluralFormName(0, @"ar") isEqualToString:@"zero"],
			"Arabic n=0 must resolve to the zero form");
	TGTestExpectTrue(&outcome, [TGPluralFormName(1, @"ar") isEqualToString:@"one"],
			"Arabic n=1 must resolve to the one form");
	TGTestExpectTrue(&outcome, [TGPluralFormName(2, @"ar") isEqualToString:@"two"],
			"Arabic n=2 must resolve to the two form");
	TGTestExpectTrue(&outcome, [TGPluralFormName(3, @"ar") isEqualToString:@"few"],
			"Arabic n=3 falls in the 3-10 band and must resolve to few");
	TGTestExpectTrue(&outcome, [TGPluralFormName(10, @"ar") isEqualToString:@"few"],
			"Arabic n=10 is the top edge of the 3-10 few band");
	TGTestExpectTrue(&outcome, [TGPluralFormName(11, @"ar") isEqualToString:@"many"],
			"Arabic n=11 is the bottom edge of the 11-99 many band");
	TGTestExpectTrue(&outcome, [TGPluralFormName(99, @"ar") isEqualToString:@"many"],
			"Arabic n=99 is the top edge of the 11-99 many band");
	TGTestExpectTrue(&outcome, [TGPluralFormName(100, @"ar") isEqualToString:@"other"],
			"Arabic n=100 falls outside every named band and must resolve to other");

	return outcome;
}

TGTestOutcome TGPluralRulesTestBalticLithuanian(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPluralFormName(1, @"lt") isEqualToString:@"one"],
			"Lithuanian n=1 must resolve to one");
	TGTestExpectTrue(&outcome, [TGPluralFormName(2, @"lt") isEqualToString:@"few"],
			"Lithuanian n=2 must resolve to few");
	TGTestExpectTrue(&outcome, [TGPluralFormName(9, @"lt") isEqualToString:@"few"],
			"Lithuanian n=9 is the top edge of the last-digit-2-9 few band");
	TGTestExpectTrue(&outcome, [TGPluralFormName(10, @"lt") isEqualToString:@"other"],
			"Lithuanian n=10 ends in 0, which is neither the one nor the few band");
	TGTestExpectTrue(&outcome, [TGPluralFormName(11, @"lt") isEqualToString:@"other"],
			"Lithuanian n=11 ends in 1 but falls in the 11-19 exception band, so it is not one");
	TGTestExpectTrue(&outcome, [TGPluralFormName(12, @"lt") isEqualToString:@"other"],
			"Lithuanian n=12 ends in 2 but falls in the 11-19 exception band, so it is not few");
	TGTestExpectTrue(&outcome, [TGPluralFormName(21, @"lt") isEqualToString:@"one"],
			"Lithuanian n=21 ends in 1 and is outside the 11-19 exception band, so it is one");

	return outcome;
}

TGTestOutcome TGPluralRulesTestCzechSlovak(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPluralFormName(1, @"cs") isEqualToString:@"one"],
			"Czech n=1 must resolve to one");
	TGTestExpectTrue(&outcome, [TGPluralFormName(2, @"cs") isEqualToString:@"few"],
			"Czech n=2 is the bottom edge of the 2-4 few band");
	TGTestExpectTrue(&outcome, [TGPluralFormName(4, @"cs") isEqualToString:@"few"],
			"Czech n=4 is the top edge of the 2-4 few band");
	TGTestExpectTrue(&outcome, [TGPluralFormName(5, @"cs") isEqualToString:@"other"],
			"Czech n=5 sits just past the 2-4 few band and must resolve to other");
	TGTestExpectTrue(&outcome, [TGPluralFormName(0, @"cs") isEqualToString:@"other"],
			"Czech n=0 is not covered by the one or few bands");
	TGTestExpectTrue(&outcome, [TGPluralFormName(11, @"sk") isEqualToString:@"other"],
			"Slovak shares the Czech rule verbatim and uses raw n, not n%10, so n=11 is other, not few");

	return outcome;
}

TGTestOutcome TGPluralRulesTestRomanian(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPluralFormName(1, @"ro") isEqualToString:@"one"],
			"Romanian n=1 must resolve to one");
	TGTestExpectTrue(&outcome, [TGPluralFormName(0, @"ro") isEqualToString:@"few"],
			"Romanian n=0 is explicitly included in the few form");
	TGTestExpectTrue(&outcome, [TGPluralFormName(19, @"ro") isEqualToString:@"few"],
			"Romanian n=19 is the top edge of the n%100 1-19 few band");
	TGTestExpectTrue(&outcome, [TGPluralFormName(20, @"ro") isEqualToString:@"other"],
			"Romanian n=20 falls just past the n%100 1-19 few band");
	TGTestExpectTrue(&outcome, [TGPluralFormName(101, @"ro") isEqualToString:@"few"],
			"Romanian n=101 has n%100=1, back inside the few band despite being three digits");
	TGTestExpectTrue(&outcome, [TGPluralFormName(120, @"ro") isEqualToString:@"other"],
			"Romanian n=120 has n%100=20, outside the few band");

	return outcome;
}

TGTestOutcome TGPluralRulesTestSlavicThreeForm(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPluralFormName(1, @"ru") isEqualToString:@"one"],
			"Russian n=1 must resolve to one");
	TGTestExpectTrue(&outcome, [TGPluralFormName(2, @"ru") isEqualToString:@"few"],
			"Russian n=2 must resolve to few");
	TGTestExpectTrue(&outcome, [TGPluralFormName(11, @"ru") isEqualToString:@"many"],
			"Russian n=11 ends in 1 but n%100=11 is the one-form exception, so it must be many, not one or few");
	TGTestExpectTrue(&outcome, [TGPluralFormName(21, @"ru") isEqualToString:@"one"],
			"Russian n=21 ends in 1 and n%100=21 is outside the exception band, so it is one");
	TGTestExpectTrue(&outcome, [TGPluralFormName(100, @"ru") isEqualToString:@"many"],
			"Russian n=100 ends in 0, which is neither the one nor the few band, so it is many");
	TGTestExpectTrue(&outcome, [TGPluralFormName(101, @"ru") isEqualToString:@"one"],
			"Russian n=101 ends in 1 and n%100=1 is outside the exception band, so it is one");
	TGTestExpectTrue(&outcome, [TGPluralFormName(12, @"ru") isEqualToString:@"many"],
			"Russian n=12 ends in 2 but n%100=12 is the few-form exception band, so it must be many");
	TGTestExpectTrue(&outcome, [TGPluralFormName(14, @"ru") isEqualToString:@"many"],
			"Russian n=14 ends in 4 but n%100=14 is the few-form exception band, so it must be many");

	return outcome;
}

TGTestOutcome TGPluralRulesTestPolish(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPluralFormName(1, @"pl") isEqualToString:@"one"],
			"Polish one is strictly n=1, unlike Russian's n%10==1 exception rule");
	TGTestExpectTrue(&outcome, [TGPluralFormName(21, @"pl") isEqualToString:@"many"],
			"Polish n=21 ends in 1 but is not exactly 1, so it must be many, not one like Russian gives it");
	TGTestExpectTrue(&outcome, [TGPluralFormName(2, @"pl") isEqualToString:@"few"],
			"Polish n=2 is in the few range");
	TGTestExpectTrue(&outcome, [TGPluralFormName(22, @"pl") isEqualToString:@"few"],
			"Polish n=22 ends in 2 and n%100=22 is outside the exception band, so it is few");
	TGTestExpectTrue(&outcome, [TGPluralFormName(12, @"pl") isEqualToString:@"many"],
			"Polish n=12 ends in 2 but n%100=12 is the few-form exception band, so it must be many");
	TGTestExpectTrue(&outcome, [TGPluralFormName(14, @"pl") isEqualToString:@"many"],
			"Polish n=14 ends in 4 but n%100=14 is the few-form exception band, so it must be many");
	TGTestExpectTrue(&outcome, [TGPluralFormName(5, @"pl") isEqualToString:@"many"],
			"Polish n=5 is outside both one and few, so it is many");
	TGTestExpectTrue(&outcome, [TGPluralFormName(0, @"pl") isEqualToString:@"many"],
			"Polish n=0 is outside both one and few, so it is many");
	TGTestExpectTrue(&outcome, [TGPluralFormName(100, @"pl") isEqualToString:@"many"],
			"Polish n=100 ends in 0, which is neither the one nor the few band, so it is many");

	return outcome;
}

TGTestOutcome TGPluralRulesTestFrenchZeroAsOne(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPluralFormName(0, @"fr") isEqualToString:@"one"],
			"French treats n=0 as the one form, unlike the English default rule");
	TGTestExpectTrue(&outcome, [TGPluralFormName(1, @"fr") isEqualToString:@"one"],
			"French n=1 must resolve to one");
	TGTestExpectTrue(&outcome, [TGPluralFormName(2, @"fr") isEqualToString:@"other"],
			"French n=2 must resolve to other");

	return outcome;
}

TGTestOutcome TGPluralRulesTestEnglishDefault(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPluralFormName(0, @"en") isEqualToString:@"other"],
			"English n=0 must resolve to other, unlike the French zero-as-one rule");
	TGTestExpectTrue(&outcome, [TGPluralFormName(1, @"en") isEqualToString:@"one"],
			"English n=1 must resolve to one");
	TGTestExpectTrue(&outcome, [TGPluralFormName(2, @"en") isEqualToString:@"other"],
			"English n=2 must resolve to other");

	return outcome;
}

TGTestOutcome TGPluralRulesTestNegativeCountsUseAbsoluteValue(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPluralFormName(-1, @"en") isEqualToString:@"one"],
			"a negative count must be reduced to its absolute value before the English rule is applied");
	TGTestExpectTrue(&outcome, [TGPluralFormName(-2, @"en") isEqualToString:@"other"],
			"a negative count of magnitude 2 must resolve exactly like a positive count of 2");
	TGTestExpectTrue(&outcome, [TGPluralFormName(-11, @"ru") isEqualToString:@"many"],
			"a negative count must still trip the Russian n%100=11 exception band once made absolute");
	TGTestExpectTrue(&outcome, [TGPluralFormName(-21, @"ru") isEqualToString:@"one"],
			"a negative count outside the exception band must resolve to one once made absolute, matching the positive case");

	return outcome;
}

TGTestOutcome TGPluralRulesTestUnknownLanguageCodeFallsBackToDefaultRule(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPluralFormName(1, nil) isEqualToString:@"one"],
			"a nil plural code must fall back to the English default rule and resolve n=1 to one");
	TGTestExpectTrue(&outcome, [TGPluralFormName(0, nil) isEqualToString:@"other"],
			"a nil plural code must fall back to the English default rule and resolve n=0 to other");
	TGTestExpectTrue(&outcome, [TGPluralFormName(1, @"") isEqualToString:@"one"],
			"an empty plural code must fall back to the English default rule and resolve n=1 to one");
	TGTestExpectTrue(&outcome, [TGPluralFormName(1, @"xx-unknown") isEqualToString:@"one"],
			"a plural code that matches none of the known language sets must still fall through to the default n==1 rule");
	TGTestExpectTrue(&outcome, [TGPluralFormName(2, @"xx-unknown") isEqualToString:@"other"],
			"a plural code that matches none of the known language sets must fall through to the default rule for n=2 as well");

	return outcome;
}

TGTestOutcome TGPluralRulesTestSubstituteCountReplacesPlaceholders(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPluralSubstituteCount(@"%d apples", 5) isEqualToString:@"5 apples"],
			"a %d placeholder must be replaced with the count's decimal string");
	TGTestExpectTrue(&outcome, [TGPluralSubstituteCount(@"%ld apples", 1000) isEqualToString:@"1000 apples"],
			"a %ld placeholder must be replaced with the count's decimal string");
	TGTestExpectTrue(&outcome, [TGPluralSubstituteCount(@"%lu apples", 42) isEqualToString:@"42 apples"],
			"a %lu placeholder must be replaced with the count's decimal string");
	TGTestExpectTrue(&outcome, [TGPluralSubstituteCount(@"%@ apples", 7) isEqualToString:@"7 apples"],
			"an %@ placeholder must be replaced with the count's decimal string");
	TGTestExpectTrue(&outcome, [TGPluralSubstituteCount(@"%d of %d total", 3) isEqualToString:@"3 of 3 total"],
			"every occurrence of a placeholder token is replaced independently, so a pattern with two %d tokens gets the same count substituted into both");
	TGTestExpectTrue(&outcome, [TGPluralSubstituteCount(@"%d items", -3) isEqualToString:@"-3 items"],
			"a negative count must substitute in with its sign, unlike the absolute-valued plural form lookup");

	return outcome;
}

TGTestOutcome TGPluralRulesTestSubstituteCountReplacesEveryIntegerForm(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPluralSubstituteCount(@"%lld Stars", 9) isEqualToString:@"9 Stars"],
			"a %lld placeholder is the one the Stars strings use, and leaving it alone put "
			"the characters %lld in front of a user reading a notification");
	TGTestExpectTrue(&outcome, [TGPluralSubstituteCount(@"%llu Stars", 9) isEqualToString:@"9 Stars"],
			"the unsigned long long form is substituted too");
	TGTestExpectTrue(&outcome, [TGPluralSubstituteCount(@"%i items", 4) isEqualToString:@"4 items"],
			"and so is %i");
	TGTestExpectTrue(&outcome, [TGPluralSubstituteCount(@"%u items", 4) isEqualToString:@"4 items"],
			"and %u");
	TGTestExpectTrue(&outcome, [TGPluralSubstituteCount(@"%zd items", 4) isEqualToString:@"4 items"],
			"and the size-typed form");

	TGTestExpectTrue(&outcome, [TGPluralSubstituteCount(@"%d%% done", 40) isEqualToString:@"40%% done"],
			"an escaped per-cent sign is not a placeholder and is left exactly as it was");
	TGTestExpectTrue(&outcome, [TGPluralSubstituteCount(@"%s files", 4) isEqualToString:@"%s files"],
			"a string placeholder is not the count and must be left for the caller");
	TGTestExpectTrue(&outcome, [TGPluralSubstituteCount(@"100% of %d", 4) isEqualToString:@"100% of 4"],
			"a lone per-cent sign in the middle of a sentence is text, not a placeholder");
	TGTestExpectTrue(&outcome, TGPluralSubstituteCount(nil, 4) == nil,
			"a missing pattern stays missing");

	return outcome;
}

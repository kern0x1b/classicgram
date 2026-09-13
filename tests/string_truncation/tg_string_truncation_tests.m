#import "tg_string_truncation_tests.h"
#import "../../src/Utilities/TGStringTruncation.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGStringTruncationTestToIndexBelowLengthIsUnchanged(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *result = TGSafeSubstringToIndex(@"hello", 3);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"hel"],
			"an ascii cut point that lands on a grapheme boundary must be honoured exactly");

	return outcome;
}

TGTestOutcome TGStringTruncationTestToIndexAtExactSequenceBoundaryIsUnchanged(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *source = @"a\U0001F600b";
	NSString *result = TGSafeSubstringToIndex(source, 3);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"a\U0001F600"],
			"a cut point exactly after a surrogate pair must keep the whole pair intact");

	return outcome;
}

TGTestOutcome TGStringTruncationTestToIndexInsideSurrogatePairDropsWholeCharacter(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *source = @"a\U0001F600b";
	NSString *result = TGSafeSubstringToIndex(source, 2);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"a"],
			"a cut point that lands inside a surrogate pair must drop the whole pair, never a lone surrogate");
	TGTestExpectTrue(&outcome, result.length == 1,
			"the dropped-pair result must not contain a stray unpaired surrogate unit");

	return outcome;
}

TGTestOutcome TGStringTruncationTestToIndexAtOrAboveLengthReturnsWholeString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGSafeSubstringToIndex(@"abc", 3) isEqualToString:@"abc"],
			"a cut point exactly at the string length must return the whole string");
	TGTestExpectTrue(&outcome, [TGSafeSubstringToIndex(@"abc", 10) isEqualToString:@"abc"],
			"a cut point past the string length must return the whole string");

	return outcome;
}

TGTestOutcome TGStringTruncationTestToIndexInsideZWJSequenceDropsWholeCluster(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *zwj = [NSString stringWithFormat:@"%C", (unichar)0x200D];
	NSString *family = [@[@"\U0001F468", @"\U0001F469", @"\U0001F467", @"\U0001F466"]
			componentsJoinedByString:zwj];
	NSString *source = [NSString stringWithFormat:@"a%@b", family];
	NSString *result = TGSafeSubstringToIndex(source, 5);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"a"],
			"a cut point inside a ZWJ family emoji must drop the whole composed cluster, never half of it");

	return outcome;
}

TGTestOutcome TGStringTruncationTestFromIndexZeroReturnsWholeString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGSafeSubstringFromIndex(@"hello", 0) isEqualToString:@"hello"],
			"an index of zero must return the string unchanged");

	return outcome;
}

TGTestOutcome TGStringTruncationTestFromIndexAtExactSequenceBoundaryIsUnchanged(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *source = @"a\U0001F600b";
	NSString *result = TGSafeSubstringFromIndex(source, 3);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"b"],
			"an index that lands exactly on a grapheme boundary must be honoured exactly");

	return outcome;
}

TGTestOutcome TGStringTruncationTestFromIndexInsideSurrogatePairSkipsWholeCharacter(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *source = @"a\U0001F600b";
	NSString *result = TGSafeSubstringFromIndex(source, 2);

	TGTestExpectTrue(&outcome, [result isEqualToString:@"b"],
			"an index that lands inside a surrogate pair must skip past the whole pair, never keep a lone surrogate");

	return outcome;
}

TGTestOutcome TGStringTruncationTestFromIndexAtOrAboveLengthReturnsEmptyString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGSafeSubstringFromIndex(@"abc", 3) isEqualToString:@""],
			"an index exactly at the string length must return an empty string");
	TGTestExpectTrue(&outcome, [TGSafeSubstringFromIndex(@"abc", 10) isEqualToString:@""],
			"an index past the string length must return an empty string");

	return outcome;
}

TGTestOutcome TGStringTruncationTestFirstCharacterKeepsWholeGlyphs(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGSafeFirstCharacter(@"Marianna") isEqualToString:@"M"],
			"an ordinary name gives its first letter");

	NSString *emoji = [[NSString alloc] initWithUTF8String:"\xF0\x9F\x98\x80"];
	NSString *emojiName = [emoji stringByAppendingString:@" Bot"];
	TGTestExpectTrue(&outcome, [TGSafeFirstCharacter(emojiName) isEqualToString:emoji],
			"a name starting with an emoji gives the whole emoji, where taking one unichar "
			"would have left half a surrogate pair for the avatar to draw");
	TGTestExpectTrue(&outcome, [TGSafeFirstCharacter(emoji) isEqualToString:emoji],
			"a name that is nothing but one emoji comes back whole rather than recursing");

	NSString *family = [[NSString alloc] initWithUTF8String:
			"\xF0\x9F\x91\xA8\xE2\x80\x8D\xF0\x9F\x91\xA9\xE2\x80\x8D\xF0\x9F\x91\xA7"];
	NSString *familyName = [family stringByAppendingString:@" family"];
	TGTestExpectTrue(&outcome, [TGSafeFirstCharacter(familyName) isEqualToString:family],
			"a joined emoji cluster is one character, not three");

	NSString *cyrillic = [[NSString alloc] initWithUTF8String:"\xD0\x98\xD0\xB2\xD0\xB0\xD0\xBD"];
	NSString *cyrillicFirst = [[NSString alloc] initWithUTF8String:"\xD0\x98"];
	TGTestExpectTrue(&outcome, [TGSafeFirstCharacter(cyrillic) isEqualToString:cyrillicFirst],
			"a Cyrillic name gives its own first letter");

	TGTestExpectTrue(&outcome, [TGSafeFirstCharacter(@"") isEqualToString:@""],
			"an empty name has no first character rather than raising");
	TGTestExpectTrue(&outcome, [TGSafeFirstCharacter(nil) isEqualToString:@""],
			"and neither does a missing one");

	return outcome;
}

TGTestOutcome TGStringTruncationTestFirstCharacterCaseChangeKeepsTheRest(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStringWithFirstCharacterUppercased(@"personalDetails")
				isEqualToString:@"PersonalDetails"],
			"a TDLib enum name is capitalised without losing the rest of it");
	TGTestExpectTrue(&outcome,
			[TGStringWithFirstCharacterLowercased(@"PersonalDetails")
				isEqualToString:@"personalDetails"],
			"and the other direction keeps the rest too");

	NSString *emoji = [[NSString alloc] initWithUTF8String:"\xF0\x9F\x98\x80"];
	NSString *tagged = [emoji stringByAppendingString:@"tag"];
	TGTestExpectTrue(&outcome,
			[TGStringWithFirstCharacterUppercased(tagged) isEqualToString:tagged],
			"a name starting with an emoji comes back whole, never split across the pair");

	TGTestExpectTrue(&outcome, [TGStringWithFirstCharacterUppercased(@"") isEqualToString:@""],
			"an empty name has no first character to change");
	TGTestExpectTrue(&outcome, TGStringWithFirstCharacterLowercased(nil) == nil,
			"and a missing one stays missing rather than raising");

	return outcome;
}

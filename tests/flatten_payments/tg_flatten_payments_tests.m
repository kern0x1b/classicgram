#import "tg_flatten_payments_tests.h"
#import "../../src/Wire/Flatten/TGFlattenPayments.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenPaymentsTestShortTypeStripsKnownPrefix(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGPayShortType(@"starTransactionTypeFragmentDeposit", @"starTransactionType")
					isEqualToString:@"FragmentDeposit"],
			"a type carrying the known prefix must have the prefix stripped, leaving the raw suffix");
	TGTestExpectTrue(&outcome,
			[TGPayShortType(@"starTransactionTypePremiumPurchase", @"starTransactionType")
					isEqualToString:@"PremiumPurchase"],
			"stripping the prefix must work for any suffix, not just one example");

	return outcome;
}

TGTestOutcome TGFlattenPaymentsTestShortTypeFallsBackWhenPrefixMissing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGPayShortType(@"somethingUnrelated", @"starTransactionType")
					isEqualToString:@"somethingUnrelated"],
			"a type without the expected prefix must be returned unchanged, not truncated");
	TGTestExpectTrue(&outcome, [TGPayShortType(nil, @"starTransactionType") isEqualToString:@""],
			"a nil type must flatten to an empty string, not crash");
	TGTestExpectTrue(&outcome,
			[TGPayShortType((NSString *)@42, @"starTransactionType") isEqualToString:@""],
			"a non-string type must flatten to an empty string, not crash");

	return outcome;
}

TGTestOutcome TGFlattenPaymentsTestHumanTypeLooksUpKnownShortTypes(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPayHumanType(@"FragmentDeposit") isEqualToString:@"Stars Top-Up"],
			"a known short type must resolve to its real localized title, not a camelCase-split guess");
	TGTestExpectTrue(&outcome, [TGPayHumanType(@"GiftUpgrade") isEqualToString:@"Gift Upgrade"],
			"another known short type must resolve to its own real localized title");
	TGTestExpectTrue(&outcome, [TGPayHumanType(@"PremiumPurchase") isEqualToString:@"Telegram Premium"],
			"the premium-purchase short type must reuse the same real title as the rest of the app");

	return outcome;
}

TGTestOutcome TGFlattenPaymentsTestHumanTypeFallsBackForUnknownOrEmptyShortType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPayHumanType(@"somethingElse") isEqualToString:@"Unsupported"],
			"a short type with no known mapping must fall back to the generic \"Unsupported\" title");
	TGTestExpectTrue(&outcome, [TGPayHumanType(@"") isEqualToString:@"Unsupported"],
			"an empty short type must fall back to the generic \"Unsupported\" title");
	TGTestExpectTrue(&outcome, [TGPayHumanType(nil) isEqualToString:@"Unsupported"],
			"a nil short type must fall back to the generic \"Unsupported\" title, not crash");

	return outcome;
}

TGTestOutcome TGFlattenPaymentsTestShortTypeAndHumanTypeRoundTrip(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *shortType = TGPayShortType(@"starTransactionTypeFragmentDeposit", @"starTransactionType");
	TGTestExpectTrue(&outcome, [TGPayHumanType(shortType) isEqualToString:@"Stars Top-Up"],
			"stripping a prefixed type and then humanising it must produce the same real title as humanising the bare suffix directly");

	NSString *unprefixed = TGPayShortType(@"PremiumPurchase", @"starTransactionType");
	TGTestExpectTrue(&outcome, [unprefixed isEqualToString:@"PremiumPurchase"],
			"a type that already lacks the prefix must round-trip through TGPayShortType unchanged");
	TGTestExpectTrue(&outcome, [TGPayHumanType(unprefixed) isEqualToString:@"Telegram Premium"],
			"humanising a type that round-tripped through TGPayShortType unchanged must still resolve its real title");

	return outcome;
}

TGTestOutcome TGFlattenPaymentsTestStarsFromDictionaryRepresentation(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualLongLong(&outcome, TGPayStars(@{@"star_count" : @150}), 150,
			"a starAmount dictionary must yield its star_count as the stars value");
	TGTestExpectEqualLongLong(&outcome,
			TGPayStars(@{@"@type" : @"starAmount", @"star_count" : @999}), 999,
			"a starAmount dictionary carrying an @type discriminator must still yield its star_count");

	return outcome;
}

TGTestOutcome TGFlattenPaymentsTestStarsFromNumberRepresentation(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualLongLong(&outcome, TGPayStars(@500), 500,
			"a bare NSNumber star amount must be read directly as the stars value");
	TGTestExpectEqualLongLong(&outcome, TGPayStars(@0), 0,
			"a bare NSNumber star amount of zero must yield zero, not fall through to some other path");

	return outcome;
}

TGTestOutcome TGFlattenPaymentsTestStarsReturnsZeroForUnrecognisedInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualLongLong(&outcome, TGPayStars(nil), 0,
			"a nil star amount must yield zero, not crash");
	TGTestExpectEqualLongLong(&outcome, TGPayStars(@"not a number or dictionary"), 0,
			"a string star amount must yield zero, since it is neither a dictionary nor a number");
	TGTestExpectEqualLongLong(&outcome, TGPayStars(@[]), 0,
			"an array star amount must yield zero, since it is neither a dictionary nor a number");

	return outcome;
}

TGTestOutcome TGFlattenPaymentsTestStarsNanosFromDictionaryRepresentation(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualLongLong(&outcome,
			TGPayStarsNanos(@{@"star_count" : @12, @"nanostar_count" : @250000000}), 250000000,
			"a starAmount dictionary must yield its nanostar_count as the fractional remainder");
	TGTestExpectEqualLongLong(&outcome,
			TGPayStarsNanos(@{@"star_count" : @-3, @"nanostar_count" : @-500000000}), -500000000,
			"a negative starAmount must keep the sign of its nanostar_count, matching the negative star_count");
	TGTestExpectEqualLongLong(&outcome, TGPayStarsNanos(@{@"star_count" : @5}), 0,
			"a starAmount dictionary with no nanostar_count field must yield zero, not crash");

	return outcome;
}

TGTestOutcome TGFlattenPaymentsTestStarsNanosReturnsZeroForUnrecognisedInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualLongLong(&outcome, TGPayStarsNanos(nil), 0,
			"a nil star amount must yield zero nanostars, not crash");
	TGTestExpectEqualLongLong(&outcome, TGPayStarsNanos(@500), 0,
			"a bare NSNumber star amount carries no fractional part, so it must yield zero nanostars");
	TGTestExpectEqualLongLong(&outcome, TGPayStarsNanos(@"not a dictionary"), 0,
			"a string star amount must yield zero nanostars, since it is not a dictionary");

	return outcome;
}

TGTestOutcome TGFlattenPaymentsTestPhotoFileIdPicksWidestOfMultipleSizes(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *photo = @{
		@"sizes" : @[
			@{@"width" : @100, @"photo" : @{@"id" : @111}},
			@{@"width" : @800, @"photo" : @{@"id" : @222}},
			@{@"width" : @400, @"photo" : @{@"id" : @333}},
		],
	};

	NSNumber *fileId = TGPayPhotoFileId(photo);
	TGTestExpectTrue(&outcome, fileId != nil, "a photo with several sizes must resolve a file id, not nil");
	TGTestExpectEqualLongLong(&outcome, fileId.longLongValue, 222,
			"the widest of several photo sizes must be the one whose file id is returned");

	return outcome;
}

TGTestOutcome TGFlattenPaymentsTestPhotoFileIdPicksTheSingleSize(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *photo = @{
		@"sizes" : @[
			@{@"width" : @300, @"photo" : @{@"id" : @777}},
		],
	};

	NSNumber *fileId = TGPayPhotoFileId(photo);
	TGTestExpectTrue(&outcome, fileId != nil, "a photo with exactly one size must resolve a file id, not nil");
	TGTestExpectEqualLongLong(&outcome, fileId.longLongValue, 777,
			"a photo with exactly one size must return that size's file id");

	return outcome;
}

TGTestOutcome TGFlattenPaymentsTestPhotoFileIdReturnsNilForEmptySizes(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGPayPhotoFileId(@{@"sizes" : @[]}) == nil,
			"a photo with no sizes at all must resolve to nil, not crash");
	TGTestExpectTrue(&outcome, TGPayPhotoFileId(nil) == nil,
			"a nil photo must resolve to nil, not crash");
	TGTestExpectTrue(&outcome, TGPayPhotoFileId(@{@"sizes" : @[@"garbage"]}) == nil,
			"a photo whose sizes array holds no dictionaries must resolve to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenPaymentsTestDecimalAmountDividesMinorUnitsByOneHundred(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPayDecimalAmount(1999, @"USD") isEqualToString:@"19.99"],
			"1999 minor units of a currency like USD cents must render as 19.99, not the raw integer");
	TGTestExpectTrue(&outcome, [TGPayDecimalAmount(150000, @"USD") isEqualToString:@"1500.00"],
			"a large minor-unit amount must still be divided by one hundred, not just thousands-grouped");

	return outcome;
}

TGTestOutcome TGFlattenPaymentsTestDecimalAmountKeepsTwoDecimalPlacesForRoundAmounts(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPayDecimalAmount(100, @"USD") isEqualToString:@"1.00"],
			"a whole-currency-unit amount must still show two decimal places, not drop the trailing zeros");
	TGTestExpectTrue(&outcome, [TGPayDecimalAmount(0, @"USD") isEqualToString:@"0.00"],
			"a zero amount must render as 0.00, not an empty string");

	return outcome;
}

TGTestOutcome TGFlattenPaymentsTestDecimalAmountHandlesNegativeAndZeroAmounts(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPayDecimalAmount(-1999, @"USD") isEqualToString:@"-19.99"],
			"a negative amount, as seen on a refund, must keep its sign after the conversion");
	TGTestExpectTrue(&outcome, [TGPayDecimalAmount(1, @"USD") isEqualToString:@"0.01"],
			"the smallest possible minor-unit amount must not be truncated away to 0.00");

	return outcome;
}

TGTestOutcome TGFlattenPaymentsTestDecimalAmountHonoursPerCurrencyExponent(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPayDecimalAmount(500, @"JPY") isEqualToString:@"500"],
			"JPY has no minor unit, so total_amount already is the whole yen count and must not be divided by 100");
	TGTestExpectTrue(&outcome, [TGPayDecimalAmount(500, @"jpy") isEqualToString:@"500"],
			"the currency code lookup must be case-insensitive, since TDLib always sends it uppercase but callers should not rely on that");
	TGTestExpectTrue(&outcome, [TGPayDecimalAmount(1999, @"KWD") isEqualToString:@"1.999"],
			"KWD has three decimal places, so 1999 fils must render as 1.999 dinars, not 19.99");
	TGTestExpectTrue(&outcome, [TGPayDecimalAmount(1999, nil) isEqualToString:@"19.99"],
			"a missing currency code must fall back to the common two-decimal case rather than crashing");

	return outcome;
}

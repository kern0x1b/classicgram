#import "tg_flatten_premium_tests.h"
#import "../../src/Wire/Flatten/TGFlattenPremium.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenPremiumTestHumanizeAllLowercase(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGPremiumHumanize(@"increasedlimits") isEqualToString:@"Increasedlimits"],
			"an all-lowercase tag with no camelCase humps must get only its first letter uppercased");

	return outcome;
}

TGTestOutcome TGFlattenPremiumTestHumanizeAllUppercaseFirstLetter(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGPremiumHumanize(@"IncreasedLimits") isEqualToString:@"Increased limits"],
			"a tag already starting with an uppercase letter must keep that first letter as-is and lowercase later humps behind a space");

	return outcome;
}

TGTestOutcome TGFlattenPremiumTestHumanizeAlreadySpacedString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGPremiumHumanize(@"profile badge") isEqualToString:@"Profile badge"],
			"a tag that already contains a space must pass the space through untouched, only capitalising the first letter");

	return outcome;
}

TGTestOutcome TGFlattenPremiumTestHumanizeEmptyString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPremiumHumanize(@"") isEqualToString:@""],
			"an empty tag must humanize to an empty string, not crash");
	TGTestExpectTrue(&outcome, [TGPremiumHumanize(nil) isEqualToString:@""],
			"a nil tag must humanize to an empty string, not crash");

	return outcome;
}

TGTestOutcome TGFlattenPremiumTestFullTypeAddsPrefixToShortTag(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGPremiumFullType(@"increasedLimits", @"premiumFeature")
					isEqualToString:@"premiumFeatureIncreasedLimits"],
			"a short tag must gain the prefix with its own first letter capitalised");
	TGTestExpectTrue(&outcome,
			[TGPremiumFullType(@"premiumFeatureIncreasedLimits", @"premiumFeature")
					isEqualToString:@"premiumFeatureIncreasedLimits"],
			"a tag that already carries the prefix must be returned unchanged");
	TGTestExpectTrue(&outcome, TGPremiumFullType(@"", @"premiumFeature") == nil,
			"an empty tag must produce no full type, not a bare prefix");

	return outcome;
}

TGTestOutcome TGFlattenPremiumTestTagStripsPrefixFromFullType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *object = @{@"@type" : @"premiumFeatureIncreasedLimits"};

	NSString *tag = TGPremiumTag(object, @"premiumFeature");

	TGTestExpectTrue(&outcome, [tag isEqualToString:@"increasedLimits"],
			"a full TDLib type must have its prefix stripped and its first letter lowercased");
	TGTestExpectTrue(&outcome,
			[TGPremiumFullType(tag, @"premiumFeature")
					isEqualToString:@"premiumFeatureIncreasedLimits"],
			"tag-then-full-type must round-trip back to the exact original TDLib type name");
	TGTestExpectTrue(&outcome, [TGPremiumTag(@{@"@type" : @"otherType"}, @"premiumFeature")
					isEqualToString:@"otherType"],
			"a type that does not carry the prefix must be returned unchanged");

	return outcome;
}

TGTestOutcome TGFlattenPremiumTestFeatureSupportedForKnownUnsupportedFeature(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGPremiumFeatureSupported(@"customEmoji") == NO,
			"customEmoji is in the unsupported set and must report as not supported");

	return outcome;
}

TGTestOutcome TGFlattenPremiumTestFeatureSupportedForUnknownFeature(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGPremiumFeatureSupported(@"increasedLimits") == YES,
			"a feature absent from the unsupported set must report as supported");

	return outcome;
}

TGTestOutcome TGFlattenPremiumTestFeatureSubtitleLooksUpKnownAndUnknownTags(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGPremiumFeatureSubtitle(@"increasedLimits")
					isEqualToString:@"Double the limits on folders, pinned chats and more"],
			"a known feature tag must resolve to its table subtitle");
	TGTestExpectTrue(&outcome, [TGPremiumFeatureSubtitle(@"notARealFeature") isEqualToString:@""],
			"an unknown feature tag must resolve to an empty subtitle, not crash");

	return outcome;
}

TGTestOutcome TGFlattenPremiumTestBusinessSubtitleLooksUpKnownAndUnknownTags(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGPremiumBusinessSubtitle(@"location")
					isEqualToString:@"Show your address on your profile"],
			"a known business feature tag must resolve to its table subtitle");
	TGTestExpectTrue(&outcome, [TGPremiumBusinessSubtitle(@"notARealFeature") isEqualToString:@""],
			"an unknown business feature tag must resolve to an empty subtitle, not crash");

	return outcome;
}

TGTestOutcome TGFlattenPremiumTestFeatureTitleIsLocalizedNotHumanized(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGPremiumFeatureTitle(@"improvedDownloadSpeed") isEqualToString:@"Faster Download Speed"],
			"a feature row's title must come from the localization table, not from splitting the schema tag: "
			"TGPremiumHumanize would render this as \"Improved download speed\"");
	TGTestExpectTrue(&outcome,
			[TGPremiumFeatureTitle(@"voiceRecognition") isEqualToString:@"Voice-to-Text Conversion"],
			"the title table must use the wording the modern client uses, not the raw tag");

	return outcome;
}

TGTestOutcome TGFlattenPremiumTestBusinessAndLimitTitlesAreLocalized(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGPremiumBusinessTitle(@"openingHours") isEqualToString:@"Opening Hours"],
			"a business feature row's title must come from its own table");
	TGTestExpectTrue(&outcome,
			[TGPremiumLimitTitle(@"pinnedChatCount") isEqualToString:@"Pinned Chats"],
			"a doubled-limit row's title must come from its own table rather than reading \"Pinned chat count\"");

	return outcome;
}

TGTestOutcome TGFlattenPremiumTestUnknownTitleTagFallsBackToHumanize(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGPremiumFeatureTitle(@"someFutureFeature") isEqualToString:@"Some future feature"],
			"a tag added by a newer TDLib than this table knows must still render as readable text rather than "
			"an empty row");
	TGTestExpectTrue(&outcome, [TGPremiumLimitTitle(@"") isEqualToString:@""],
			"an empty tag must produce an empty title, not crash");

	return outcome;
}

TGTestOutcome TGFlattenPremiumTestSubtitlesCoverEveryUnsupportedFeature(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *tags = @[ @"disabledAds", @"textComposition", @"richMessages", @"customEmoji",
		@"accentColor", @"checklists", @"realTimeChatTranslation" ];
	for (NSString *tag in tags) {
		TGTestExpectTrue(&outcome, TGPremiumFeatureSubtitle(tag).length > 0,
				"an unsupported premium feature is still drawn (greyed) rather than hidden, so every tag in the "
				"unsupported set needs a subtitle: a missing one renders as a blank line");
	}

	return outcome;
}


#import "tg_flatten_translation_tests.h"
#import "../../src/Wire/Flatten/TGFlattenTranslation.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenTranslationTestFormattedTextWrapsRealisticText(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flat = TGTrFormattedText(@"hello world", nil);

	TGTestExpectTrue(&outcome, [flat[@"@type"] isEqualToString:@"formattedText"],
			"a wrapped text must carry the formattedText discriminator");
	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@"hello world"],
			"a wrapped text must round-trip the given text verbatim");
	TGTestExpectTrue(&outcome, [flat[@"entities"] isKindOfClass:NSArray.class] && [flat[@"entities"] count] == 0,
			"a wrapped text with no entities must carry an empty entities array");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestFormattedTextHandlesNilText(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flat = TGTrFormattedText(nil, nil);

	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@""],
			"a nil text must wrap to an empty string, not crash or produce nil");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestFormattedTextCarriesGivenEntities(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *entities = @[
		@{@"@type" : @"textEntity", @"offset" : @0, @"length" : @5,
			@"type" : @{@"@type" : @"textEntityTypeBold"}},
	];
	NSDictionary *flat = TGTrFormattedText(@"hello world", entities);

	TGTestExpectTrue(&outcome, [flat[@"entities"] isEqual:entities],
			"a wrapped text with real entities must carry those entities through unchanged, not discard them");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestPackFlattensRealisticPayload(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"languagePackInfo",
		@"id" : @"en",
		@"native_name" : @"English",
		@"name" : @"English",
		@"base_language_pack_id" : @"",
		@"plural_code" : @"en",
		@"is_official" : @YES,
		@"is_rtl" : @NO,
		@"is_beta" : @NO,
		@"is_installed" : @YES,
		@"total_string_count" : @1200,
		@"translated_string_count" : @1180,
		@"local_string_count" : @3,
		@"translation_url" : @"https://translations.telegram.org/en/",
	};

	NSDictionary *flat = TGTrPack(raw);

	TGTestExpectTrue(&outcome, [flat[@"id"] isEqualToString:@"en"],
			"a flattened pack must carry its id");
	TGTestExpectTrue(&outcome, [flat[@"name"] isEqualToString:@"English"],
			"a flattened pack must carry the language's English name");
	TGTestExpectTrue(&outcome, [flat[@"nativeName"] isEqualToString:@"English"],
			"a flattened pack must carry the language's own name for itself");
	TGTestExpectTrue(&outcome, [flat[@"official"] boolValue],
			"a flattened pack must carry its official flag");
	TGTestExpectEqualInteger(&outcome, [flat[@"totalStrings"] integerValue], 1200,
			"a flattened pack must carry its total string count");
	TGTestExpectTrue(&outcome, [flat[@"translationUrl"] isEqualToString:@"https://translations.telegram.org/en/"],
			"a flattened pack must carry its translation url");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestPackReturnsNilWithoutId(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGTrPack(@{@"name" : @"English"}) == nil,
			"a pack with no id must flatten to nil, not a half-built dict");
	TGTestExpectTrue(&outcome, TGTrPack(nil) == nil,
			"a nil pack must flatten to nil, not crash");
	TGTestExpectTrue(&outcome, TGTrPack(@"not a dict") == nil,
			"a non-dictionary pack payload must flatten to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestPackNameFallsBackWhenNativeNameMissing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *usesName = TGTrPack(@{@"id" : @"de", @"name" : @"German"});
	TGTestExpectTrue(&outcome, [usesName[@"name"] isEqualToString:@"German"],
			"a pack with no native_name keeps its English name");
	TGTestExpectTrue(&outcome, [usesName[@"nativeName"] isEqualToString:@"German"],
			"a pack with no native_name falls back to the English name for the native one");

	NSDictionary *both = TGTrPack(@{@"id" : @"be", @"name" : @"Belarusian",
		@"native_name" : @"\u0411\u0435\u043b\u0430\u0440\u0443\u0441\u043a\u0430\u044f"});
	TGTestExpectTrue(&outcome, [both[@"name"] isEqualToString:@"Belarusian"],
			"the English name and the native name stay separate, so a row can show both");
	TGTestExpectTrue(&outcome, ![both[@"nativeName"] isEqualToString:both[@"name"]],
			"a language whose own name differs from its English name keeps both");

	NSDictionary *usesId = TGTrPack(@{@"id" : @"xx"});
	TGTestExpectTrue(&outcome, [usesId[@"name"] isEqualToString:@"xx"],
			"a pack with neither native_name nor name must fall back to its id for a display name");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestPacksFlattensArraySkippingInvalidEntries(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *target = @{
		@"language_packs" : @[
			@{@"id" : @"en", @"native_name" : @"English"},
			@{@"native_name" : @"Missing id, must be skipped"},
			@{@"id" : @"de", @"native_name" : @"Deutsch"},
		],
	};

	NSArray *packs = TGTrPacks(target);

	TGTestExpectEqualInteger(&outcome, packs.count, 2,
			"packs with no id must be dropped, leaving only the valid entries");
	TGTestExpectTrue(&outcome, [packs[0][@"id"] isEqualToString:@"en"],
			"the first valid pack must keep its original order");
	TGTestExpectTrue(&outcome, [packs[1][@"id"] isEqualToString:@"de"],
			"the second valid pack must keep its original order");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestPacksReturnsEmptyArrayWithoutLanguagePacksField(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualInteger(&outcome, TGTrPacks(@{}).count, 0,
			"a target with no language_packs field must flatten to an empty array");
	TGTestExpectEqualInteger(&outcome, TGTrPacks(nil).count, 0,
			"a nil target must flatten to an empty array, not crash");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestTranscriptFlattensTextResult(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flat = TGTrTranscript(@{
		@"@type" : @"speechRecognitionResultText",
		@"text" : @"hello there",
	});

	TGTestExpectTrue(&outcome, [flat[@"state"] isEqualToString:@"text"],
			"a speechRecognitionResultText must flatten with state \"text\"");
	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@"hello there"],
			"a speechRecognitionResultText must carry its recognized text");
	TGTestExpectTrue(&outcome, [flat[@"error"] isEqualToString:@""],
			"a successful transcript must carry an empty error");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestTranscriptFlattensPendingResult(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flat = TGTrTranscript(@{
		@"@type" : @"speechRecognitionResultPending",
		@"partial_text" : @"hello th",
	});

	TGTestExpectTrue(&outcome, [flat[@"state"] isEqualToString:@"pending"],
			"a speechRecognitionResultPending must flatten with state \"pending\"");
	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@"hello th"],
			"a pending transcript must carry its partial_text as text");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestTranscriptFlattensErrorResultWithMessage(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flat = TGTrTranscript(@{
		@"@type" : @"speechRecognitionResultError",
		@"error" : @{@"@type" : @"error", @"code" : @400, @"message" : @"Audio too short"},
	});

	TGTestExpectTrue(&outcome, [flat[@"state"] isEqualToString:@"error"],
			"a speechRecognitionResultError must flatten with state \"error\"");
	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@""],
			"an error transcript must carry an empty text");
	TGTestExpectTrue(&outcome, [flat[@"error"] isEqualToString:@"Audio too short"],
			"an error transcript with a message must carry that message verbatim");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestTranscriptFallsBackWhenErrorHasNoMessage(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flat = TGTrTranscript(@{
		@"@type" : @"speechRecognitionResultError",
		@"error" : @{@"@type" : @"error", @"code" : @400},
	});

	TGTestExpectTrue(&outcome, [flat[@"error"] length] > 0,
			"an error transcript with no message must still carry a non-empty fallback error string");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestTranscriptReturnsNilForUnknownType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGTrTranscript(@{@"@type" : @"somethingElse"}) == nil,
			"an unrecognized transcript type must flatten to nil");
	TGTestExpectTrue(&outcome, TGTrTranscript(nil) == nil,
			"a nil transcript payload must flatten to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestNoteOfMessageExtractsVoiceNote(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"content" : @{
			@"@type" : @"messageVoiceNote",
			@"voice_note" : @{@"@type" : @"voiceNote", @"duration" : @12},
		},
	};

	NSDictionary *note = TGTrNoteOfMessage(message);

	TGTestExpectTrue(&outcome, [note[@"@type"] isEqualToString:@"voiceNote"],
			"a message with a voice_note must yield that voice note");
	TGTestExpectEqualInteger(&outcome, [note[@"duration"] integerValue], 12,
			"the extracted voice note must keep its own fields intact");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestNoteOfMessageFallsBackToVideoNote(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"content" : @{
			@"@type" : @"messageVideoNote",
			@"video_note" : @{@"@type" : @"videoNote", @"duration" : @7},
		},
	};

	NSDictionary *note = TGTrNoteOfMessage(message);

	TGTestExpectTrue(&outcome, [note[@"@type"] isEqualToString:@"videoNote"],
			"a message with no voice_note but a video_note must fall back to the video note");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestNoteOfMessageReturnsNilWithoutEitherNote(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"content" : @{@"@type" : @"messageText", @"text" : @{@"text" : @"hi"}},
	};

	TGTestExpectTrue(&outcome, TGTrNoteOfMessage(message) == nil,
			"a message with neither a voice_note nor a video_note must yield nil");
	TGTestExpectTrue(&outcome, TGTrNoteOfMessage(nil) == nil,
			"a nil message must yield nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestStringValueReturnsOrdinaryString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	id value = TGTrStringValue(@{
		@"@type" : @"languagePackStringValueOrdinary",
		@"value" : @"Cancel",
	});

	TGTestExpectTrue(&outcome, [value isKindOfClass:NSString.class] && [value isEqualToString:@"Cancel"],
			"an ordinary string value must flatten to its plain string");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestStringValueBuildsPluralDictFromPresentForms(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	id value = TGTrStringValue(@{
		@"@type" : @"languagePackStringValuePluralized",
		@"one_value" : @"%d message",
		@"other_value" : @"%d messages",
	});

	TGTestExpectTrue(&outcome, [value isKindOfClass:NSDictionary.class],
			"a pluralized string value must flatten to a dictionary of forms");
	TGTestExpectTrue(&outcome, [value[@"one"] isEqualToString:@"%d message"],
			"a present plural form must be carried through under its own key");
	TGTestExpectTrue(&outcome, [value[@"other"] isEqualToString:@"%d messages"],
			"the other form must be carried through as well");
	TGTestExpectTrue(&outcome, value[@"few"] == nil,
			"a plural form that was not supplied must be absent from the flattened dictionary");

	return outcome;
}

TGTestOutcome TGFlattenTranslationTestStringValueReturnsNilForUnknownType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGTrStringValue(@{@"@type" : @"somethingElse"}) == nil,
			"an unrecognized string value type must flatten to nil");
	TGTestExpectTrue(&outcome, TGTrStringValue(nil) == nil,
			"a nil string value payload must flatten to nil, not crash");

	return outcome;
}

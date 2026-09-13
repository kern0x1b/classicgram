#import "TGFlattenTranslation.h"
#import "TGLocalization.h"

static NSString *TGTrString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSNumber *TGTrNumber(id value) {
	return [value isKindOfClass:NSNumber.class] ? value : @(0);
}

static NSArray *TGTrArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : nil;
}

static NSDictionary *TGTrDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

NSDictionary *TGTrFormattedText(NSString *text, NSArray *entities) {
	return @{@"@type" : @"formattedText",
		@"text" : text ?: @"",
		@"entities" : entities ?: @[]};
}

NSDictionary *TGTrPack(id raw) {
	NSDictionary *p = TGTrDict(raw);
	if (!TGTrString(p[@"id"]).length)
		return nil;
	NSString *name = TGTrString(p[@"name"]);
	if (!name.length)
		name = TGTrString(p[@"native_name"]);
	if (!name.length)
		name = TGTrString(p[@"id"]);
	NSString *nativeName = TGTrString(p[@"native_name"]);
	if (!nativeName.length)
		nativeName = name;
	return @{
		@"id" : TGTrString(p[@"id"]),
		@"name" : name,
		@"nativeName" : nativeName,
		@"baseId" : TGTrString(p[@"base_language_pack_id"]),
		@"pluralCode" : TGTrString(p[@"plural_code"]),
		@"official" : @([p[@"is_official"] boolValue]),
		@"rtl" : @([p[@"is_rtl"] boolValue]),
		@"beta" : @([p[@"is_beta"] boolValue]),
		@"installed" : @([p[@"is_installed"] boolValue]),
		@"totalStrings" : TGTrNumber(p[@"total_string_count"]),
		@"translatedStrings" : TGTrNumber(p[@"translated_string_count"]),
		@"localStrings" : TGTrNumber(p[@"local_string_count"]),
		@"translationUrl" : TGTrString(p[@"translation_url"]),
	};
}

NSArray *TGTrPacks(NSDictionary *target) {
	NSArray *raw = TGTrArray(TGTrDict(target)[@"language_packs"]);
	NSMutableArray *out = [NSMutableArray array];
	for (id item in raw) {
		NSDictionary *pack = TGTrPack(item);
		if (pack)
			[out addObject:pack];
	}
	return out;
}

NSDictionary *TGTrTranscript(id raw) {
	NSDictionary *r = TGTrDict(raw);
	NSString *type = TGTrString(r[@"@type"]);
	if ([type isEqualToString:@"speechRecognitionResultText"])
		return @{@"state" : @"text",
			@"text" : TGTrString(r[@"text"]),
			@"error" : @""};
	if ([type isEqualToString:@"speechRecognitionResultPending"])
		return @{@"state" : @"pending",
			@"text" : TGTrString(r[@"partial_text"]),
			@"error" : @""};
	if ([type isEqualToString:@"speechRecognitionResultError"]) {
		NSString *message = TGTrString(TGTrDict(r[@"error"])[@"message"]);
		return @{@"state" : @"error",
			@"text" : @"",
			@"error" : message.length ? message : TGL(@"Message.AudioTranscription.ErrorEmpty", @"No speech was recognised.")};
	}
	return nil;
}

NSDictionary *TGTrNoteOfMessage(NSDictionary *message) {
	NSDictionary *content = TGTrDict(TGTrDict(message)[@"content"]);
	NSDictionary *note = TGTrDict(content[@"voice_note"]);
	if (!note)
		note = TGTrDict(content[@"video_note"]);
	return note;
}

id TGTrStringValue(id raw) {
	NSDictionary *v = TGTrDict(raw);
	NSString *type = TGTrString(v[@"@type"]);
	if ([type isEqualToString:@"languagePackStringValueOrdinary"])
		return TGTrString(v[@"value"]);
	if (![type isEqualToString:@"languagePackStringValuePluralized"])
		return nil;

	NSArray *forms = @[ @"zero", @"one", @"two", @"few", @"many", @"other" ];
	NSMutableDictionary *plural = [NSMutableDictionary dictionary];
	for (NSString *form in forms) {
		NSString *value = TGTrString(v[[form stringByAppendingString:@"_value"]]);
		if (value.length)
			[plural setObject:value forKey:form];
	}
	return plural.count ? plural : nil;
}

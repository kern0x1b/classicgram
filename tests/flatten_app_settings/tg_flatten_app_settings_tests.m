#import "tg_flatten_app_settings_tests.h"
#import "../../src/Wire/Flatten/TGFlattenAppSettings.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenAppSettingsTestApplyFillAndFillFromRowRoundTripSolid(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *fill = @{@"@type" : @"backgroundFillSolid", @"color" : @123456};
	NSMutableDictionary *row = [NSMutableDictionary dictionary];
	TGASApplyFill(row, fill);

	TGTestExpectEqualInteger(&outcome, [row[@"topColor"] integerValue], 123456,
			"a solid fill must flatten to a row whose topColor is the fill's color");
	TGTestExpectEqualInteger(&outcome, [row[@"bottomColor"] integerValue], 123456,
			"a solid fill must flatten to a row whose bottomColor equals its topColor");

	NSDictionary *rebuilt = TGASFillFromRow(row);

	TGTestExpectTrue(&outcome, [rebuilt[@"@type"] isEqualToString:@"backgroundFillSolid"],
			"a row with equal top and bottom colors must round-trip back to a solid fill");
	TGTestExpectEqualInteger(&outcome, [rebuilt[@"color"] integerValue], 123456,
			"the rebuilt solid fill's color must match the original fill's color");

	return outcome;
}

TGTestOutcome TGFlattenAppSettingsTestApplyFillAndFillFromRowRoundTripGradient(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *fill = @{@"@type" : @"backgroundFillGradient",
		@"top_color" : @111,
		@"bottom_color" : @222,
		@"rotation_angle" : @90};
	NSMutableDictionary *row = [NSMutableDictionary dictionary];
	TGASApplyFill(row, fill);

	TGTestExpectEqualInteger(&outcome, [row[@"topColor"] integerValue], 111,
			"a gradient fill must flatten to a row whose topColor is the fill's top_color");
	TGTestExpectEqualInteger(&outcome, [row[@"bottomColor"] integerValue], 222,
			"a gradient fill must flatten to a row whose bottomColor is the fill's bottom_color");
	TGTestExpectEqualInteger(&outcome, [row[@"rotation"] integerValue], 90,
			"a gradient fill must flatten to a row whose rotation is the fill's rotation_angle");

	NSDictionary *rebuilt = TGASFillFromRow(row);

	TGTestExpectTrue(&outcome, [rebuilt[@"@type"] isEqualToString:@"backgroundFillGradient"],
			"a row with distinct top and bottom colors must round-trip back to a gradient fill");
	TGTestExpectEqualInteger(&outcome, [rebuilt[@"top_color"] integerValue], 111,
			"the rebuilt gradient fill's top_color must match the original fill's top_color");
	TGTestExpectEqualInteger(&outcome, [rebuilt[@"bottom_color"] integerValue], 222,
			"the rebuilt gradient fill's bottom_color must match the original fill's bottom_color");
	TGTestExpectEqualInteger(&outcome, [rebuilt[@"rotation_angle"] integerValue], 90,
			"the rebuilt gradient fill's rotation_angle must match the original fill's rotation, already a multiple of 45");

	return outcome;
}

TGTestOutcome TGFlattenAppSettingsTestApplyFillAndFillFromRowRoundTripFreeformGradient(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *fill = @{@"@type" : @"backgroundFillFreeformGradient",
		@"colors" : @[@10, @20, @30, @40]};
	NSMutableDictionary *row = [NSMutableDictionary dictionary];
	TGASApplyFill(row, fill);

	TGTestExpectEqualInteger(&outcome, [row[@"topColor"] integerValue], 10,
			"a freeform gradient fill must flatten to a row whose topColor is the first color");
	TGTestExpectEqualInteger(&outcome, [row[@"bottomColor"] integerValue], 40,
			"a freeform gradient fill must flatten to a row whose bottomColor is the last color");

	NSDictionary *rebuilt = TGASFillFromRow(row);

	TGTestExpectTrue(&outcome, [rebuilt[@"@type"] isEqualToString:@"backgroundFillGradient"],
			"a freeform gradient's flattened row must round-trip back to a plain two-stop gradient fill");
	TGTestExpectEqualInteger(&outcome, [rebuilt[@"top_color"] integerValue], 10,
			"the rebuilt gradient's top_color must be the freeform gradient's first color");
	TGTestExpectEqualInteger(&outcome, [rebuilt[@"bottom_color"] integerValue], 40,
			"the rebuilt gradient's bottom_color must be the freeform gradient's last color");
	TGTestExpectEqualInteger(&outcome, [rebuilt[@"rotation_angle"] integerValue], 0,
			"a freeform gradient carries no rotation, so the rebuilt gradient's rotation_angle must default to 0");

	return outcome;
}

TGTestOutcome TGFlattenAppSettingsTestFillFromRowNormalizesAngleAtBoundaries(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	struct {
		NSInteger input;
		NSInteger expected;
	} cases[] = {
		{0, 0},
		{44, 0},
		{45, 45},
		{46, 45},
		{359, 315},
		{360, 0},
		{361, 0},
		{-1, 315},
		{-44, 315},
		{-45, 315},
	};

	for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
		NSDictionary *row = @{@"topColor" : @1, @"bottomColor" : @2, @"rotation" : @(cases[i].input)};
		NSDictionary *fill = TGASFillFromRow(row);
		TGTestExpectEqualInteger(&outcome, [fill[@"rotation_angle"] integerValue], cases[i].expected,
				"a rotation angle must wrap modulo 360 and snap down to the nearest multiple of 45");
	}

	return outcome;
}

TGTestOutcome TGFlattenAppSettingsTestBackgroundRowClassifiesWallpaperKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *background = @{
		@"id" : @12345,
		@"name" : @"Nice Wallpaper",
		@"is_dark" : @YES,
		@"is_default" : @NO,
		@"document" : @{
			@"document" : @{@"id" : @111},
			@"thumbnail" : @{@"file" : @{@"id" : @222}},
		},
		@"type" : @{
			@"@type" : @"backgroundTypeWallpaper",
			@"is_blurred" : @YES,
			@"is_moving" : @NO,
		},
	};

	NSDictionary *row = TGASBackgroundRow(background);

	TGTestExpectTrue(&outcome, [row[@"id"] isEqualToString:@"12345"],
			"a numeric TDLib background id must flatten to its string form");
	TGTestExpectTrue(&outcome, [row[@"name"] isEqualToString:@"Nice Wallpaper"],
			"the row's name must round-trip from the background's name");
	TGTestExpectTrue(&outcome, [row[@"isDark"] boolValue],
			"the row's isDark must round-trip from is_dark");
	TGTestExpectTrue(&outcome, ![row[@"isDefault"] boolValue],
			"the row's isDefault must round-trip from is_default");
	TGTestExpectEqualInteger(&outcome, [row[@"fileId"] integerValue], 111,
			"the row's fileId must come from document.document.id");
	TGTestExpectEqualInteger(&outcome, [row[@"thumbFileId"] integerValue], 222,
			"the row's thumbFileId must come from document.thumbnail.file.id");
	TGTestExpectTrue(&outcome, [row[@"kind"] isEqualToString:@"wallpaper"],
			"backgroundTypeWallpaper must classify as the wallpaper kind");
	TGTestExpectTrue(&outcome, [row[@"isBlurred"] boolValue],
			"the row's isBlurred must round-trip from type.is_blurred");
	TGTestExpectTrue(&outcome, ![row[@"isMoving"] boolValue],
			"the row's isMoving must round-trip from type.is_moving");
	TGTestExpectTrue(&outcome, row[@"intensity"] == nil,
			"a wallpaper type carries no intensity, so the row must not fabricate one");

	return outcome;
}

TGTestOutcome TGFlattenAppSettingsTestBackgroundRowClassifiesPatternKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *background = @{
		@"id" : @1,
		@"type" : @{
			@"@type" : @"backgroundTypePattern",
			@"is_blurred" : @NO,
			@"is_moving" : @YES,
			@"intensity" : @70,
			@"is_inverted" : @YES,
			@"fill" : @{@"@type" : @"backgroundFillSolid", @"color" : @654321},
		},
	};

	NSDictionary *row = TGASBackgroundRow(background);

	TGTestExpectTrue(&outcome, [row[@"kind"] isEqualToString:@"pattern"],
			"backgroundTypePattern must classify as the pattern kind");
	TGTestExpectEqualInteger(&outcome, [row[@"intensity"] integerValue], 70,
			"the row's intensity must round-trip from type.intensity when it is present");
	TGTestExpectTrue(&outcome, [row[@"isInverted"] boolValue],
			"the row's isInverted must round-trip from type.is_inverted");
	TGTestExpectTrue(&outcome, [row[@"isMoving"] boolValue],
			"the row's isMoving must round-trip from type.is_moving");
	TGTestExpectEqualInteger(&outcome, [row[@"topColor"] integerValue], 654321,
			"the pattern's nested fill must still be flattened onto the row");
	TGTestExpectEqualInteger(&outcome, [row[@"bottomColor"] integerValue], 654321,
			"the pattern's nested solid fill must produce equal top and bottom colors");

	return outcome;
}

TGTestOutcome TGFlattenAppSettingsTestBackgroundRowClassifiesFillKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *background = @{
		@"id" : @2,
		@"type" : @{
			@"@type" : @"backgroundTypeFill",
			@"fill" : @{@"@type" : @"backgroundFillGradient",
				@"top_color" : @111,
				@"bottom_color" : @222,
				@"rotation_angle" : @90},
		},
	};

	NSDictionary *row = TGASBackgroundRow(background);

	TGTestExpectTrue(&outcome, [row[@"kind"] isEqualToString:@"fill"],
			"backgroundTypeFill must classify as the fill kind");
	TGTestExpectEqualInteger(&outcome, [row[@"topColor"] integerValue], 111,
			"the fill kind's topColor must come from the nested fill's top_color");
	TGTestExpectEqualInteger(&outcome, [row[@"bottomColor"] integerValue], 222,
			"the fill kind's bottomColor must come from the nested fill's bottom_color");
	TGTestExpectEqualInteger(&outcome, [row[@"rotation"] integerValue], 90,
			"the fill kind's rotation must come from the nested fill's rotation_angle");

	return outcome;
}

TGTestOutcome TGFlattenAppSettingsTestBackgroundRowClassifiesThemeKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *background = @{
		@"id" : @3,
		@"type" : @{@"@type" : @"backgroundTypeChatTheme"},
	};

	NSDictionary *row = TGASBackgroundRow(background);

	TGTestExpectTrue(&outcome, [row[@"kind"] isEqualToString:@"theme"],
			"backgroundTypeChatTheme must classify as the theme kind");

	return outcome;
}

TGTestOutcome TGFlattenAppSettingsTestBackgroundRowReturnsNilForNonDictionaryInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGASBackgroundRow(nil) == nil,
			"a nil background must flatten to nil, not crash or fabricate a row");
	TGTestExpectTrue(&outcome, TGASBackgroundRow(@"not a dictionary") == nil,
			"a non-dictionary background must flatten to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenAppSettingsTestBackgroundTypeForKindReturnsPatternType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *type = TGASBackgroundTypeForKind(@"pattern");

	TGTestExpectTrue(&outcome, [type[@"@type"] isEqualToString:@"backgroundTypePattern"],
			"the pattern kind must produce a backgroundTypePattern type object");
	TGTestExpectEqualInteger(&outcome, [type[@"intensity"] integerValue], 50,
			"the default pattern type object must carry the default intensity of 50");
	TGTestExpectTrue(&outcome, [type[@"fill"][@"@type"] isEqualToString:@"backgroundFillSolid"],
			"the default pattern type object must carry a solid placeholder fill");

	return outcome;
}

TGTestOutcome TGFlattenAppSettingsTestBackgroundTypeForKindReturnsFillType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *type = TGASBackgroundTypeForKind(@"fill");

	TGTestExpectTrue(&outcome, [type[@"@type"] isEqualToString:@"backgroundTypeFill"],
			"the fill kind must produce a backgroundTypeFill type object");
	TGTestExpectTrue(&outcome, [type[@"fill"][@"@type"] isEqualToString:@"backgroundFillSolid"],
			"the default fill type object must carry a solid placeholder fill");

	return outcome;
}

TGTestOutcome TGFlattenAppSettingsTestBackgroundTypeForKindFallsBackToWallpaperType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *wallpaperType = TGASBackgroundTypeForKind(@"wallpaper");
	NSDictionary *unknownType = TGASBackgroundTypeForKind(@"theme");
	NSDictionary *nilType = TGASBackgroundTypeForKind(nil);

	TGTestExpectTrue(&outcome, [wallpaperType[@"@type"] isEqualToString:@"backgroundTypeWallpaper"],
			"the wallpaper kind must produce a backgroundTypeWallpaper type object");
	TGTestExpectTrue(&outcome, [unknownType[@"@type"] isEqualToString:@"backgroundTypeWallpaper"],
			"a kind other than pattern or fill must fall back to backgroundTypeWallpaper");
	TGTestExpectTrue(&outcome, [nilType[@"@type"] isEqualToString:@"backgroundTypeWallpaper"],
			"a nil kind must fall back to backgroundTypeWallpaper, not crash");

	return outcome;
}

TGTestOutcome TGFlattenAppSettingsTestWebDomainExceptionsParsesRealisticList(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *raw = @[
		@{@"domain" : @"example.com", @"url" : @"https://example.com", @"title" : @"Example"},
		@{@"domain" : @"foo.example.org", @"url" : @"https://foo.example.org", @"title" : @"Foo"},
		@{@"url" : @"https://no-domain.example.com"},
		@"not a dictionary",
	];

	NSArray *exceptions = TGASWebDomainExceptions(raw);

	TGTestExpectEqualInteger(&outcome, exceptions.count, 2,
			"entries missing a domain and non-dictionary entries must both be skipped");
	TGTestExpectTrue(&outcome, [exceptions[0][@"domain"] isEqualToString:@"example.com"],
			"the first surviving exception's domain must round-trip verbatim");
	TGTestExpectTrue(&outcome, [exceptions[0][@"url"] isEqualToString:@"https://example.com"],
			"the first surviving exception's url must round-trip verbatim");
	TGTestExpectTrue(&outcome, [exceptions[0][@"title"] isEqualToString:@"Example"],
			"the first surviving exception's title must round-trip verbatim");
	TGTestExpectTrue(&outcome, [exceptions[1][@"domain"] isEqualToString:@"foo.example.org"],
			"the second surviving exception's domain must round-trip verbatim");

	return outcome;
}

TGTestOutcome TGFlattenAppSettingsTestWebDomainExceptionsReturnsEmptyForEmptyInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualInteger(&outcome, TGASWebDomainExceptions(nil).count, 0,
			"a nil exception list must flatten to an empty array, not nil or a crash");
	TGTestExpectEqualInteger(&outcome, TGASWebDomainExceptions(@[]).count, 0,
			"an already-empty exception list must flatten to an empty array");
	TGTestExpectEqualInteger(&outcome, TGASWebDomainExceptions(@"not an array").count, 0,
			"a non-array exception list must flatten to an empty array, not crash");

	return outcome;
}

TGTestOutcome TGFlattenAppSettingsTestThemeColoursFromSettingsExtractsAccentAndOutgoingFill(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *settings = @{
		@"accent_color" : @0xff5a3c,
		@"outgoing_message_fill" : @{@"@type" : @"backgroundFillSolid", @"color" : @0x2ea6ff},
	};

	NSDictionary *colours = TGASThemeColoursFromSettings(settings);

	TGTestExpectEqualInteger(&outcome, [colours[@"accentColour"] integerValue], 0xff5a3c,
			"the theme's accent_color must flatten straight into accentColour");
	TGTestExpectEqualInteger(&outcome, [colours[@"bubbleMineColour"] integerValue], 0x2ea6ff,
			"a solid outgoing_message_fill's color must flatten into bubbleMineColour");

	return outcome;
}

TGTestOutcome TGFlattenAppSettingsTestThemeColoursFromSettingsIgnoresGradientBottomColour(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *settings = @{
		@"outgoing_message_fill" : @{@"@type" : @"backgroundFillGradient",
			@"top_color" : @111,
			@"bottom_color" : @222,
			@"rotation_angle" : @90},
	};

	NSDictionary *colours = TGASThemeColoursFromSettings(settings);

	TGTestExpectEqualInteger(&outcome, [colours[@"bubbleMineColour"] integerValue], 111,
			"a gradient outgoing_message_fill must flatten to its top_color, since bubbles in this "
			"client are drawn as a single flat colour");
	TGTestExpectTrue(&outcome, colours[@"accentColour"] == nil,
			"a settings dictionary without accent_color must not fabricate one");

	return outcome;
}

TGTestOutcome TGFlattenAppSettingsTestThemeColoursFromSettingsReturnsNilWithoutUsableFields(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGASThemeColoursFromSettings(nil) == nil,
			"nil settings must flatten to nil, not crash or fabricate a row");
	TGTestExpectTrue(&outcome, TGASThemeColoursFromSettings(@{}) == nil,
			"settings with neither accent_color nor outgoing_message_fill must flatten to nil");

	return outcome;
}

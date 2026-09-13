#import "tg_wallpaper_row_text_tests.h"
#import "../../src/Screens/Settings/TGWallpaperRowText.h"

TGTestOutcome TGWallpaperRowTextTestKindDefaultsToWallpaper(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGWallpaperKindOfBackground(@{@"kind" : @"fill"}) isEqualToString:@"fill"],
			"a real kind passes through");
	TGTestExpectTrue(&outcome, [TGWallpaperKindOfBackground(@{}) isEqualToString:@"wallpaper"],
			"a background with no kind is a photo wallpaper, the shape every other branch falls back to");
	TGTestExpectTrue(&outcome, [TGWallpaperKindOfBackground(@{@"kind" : @""}) isEqualToString:@"wallpaper"],
			"an empty kind is treated as absent rather than matching no branch at all");
	TGTestExpectTrue(&outcome, [TGWallpaperKindOfBackground(nil) isEqualToString:@"wallpaper"],
			"a nil background must not crash the row");
	TGTestExpectTrue(&outcome, [TGWallpaperKindOfBackground((NSDictionary *)@"x") isEqualToString:@"wallpaper"],
			"a non-dictionary off the wire must not be subscripted");

	return outcome;
}

TGTestOutcome TGWallpaperRowTextTestColourWordForSolidAndGradient(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGWallpaperColourWord(@{@"topColor" : @0xFF0000}) isEqualToString:@"#FF0000"],
			"one colour reads as a single hex value, upper case, six digits");
	TGTestExpectTrue(&outcome,
			[TGWallpaperColourWord(@{@"topColor" : @0x0000FF, @"bottomColor" : @0x0000FF})
					isEqualToString:@"#0000FF"],
			"a gradient whose ends are equal is a solid colour, not a range");
	TGTestExpectTrue(&outcome,
			[TGWallpaperColourWord(@{@"topColor" : @0x000000, @"bottomColor" : @0xFFFFFF})
					isEqualToString:@"#000000 to #FFFFFF"],
			"two different ends read as a range");
	TGTestExpectTrue(&outcome, TGWallpaperColourWord(@{}) == nil,
			"a background with no colour has no colour word, so the detail line omits it entirely");
	TGTestExpectTrue(&outcome, TGWallpaperColourWord(@{@"topColor" : @"red"}) == nil,
			"a non-number colour is treated as absent");

	return outcome;
}

TGTestOutcome TGWallpaperRowTextTestColourWordIgnoresTheAlphaByte(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGWallpaperColourWord(@{@"topColor" : @0xFF112233}) isEqualToString:@"#112233"],
			"a colour arriving with a high byte set must print six digits, not eight");
	TGTestExpectTrue(&outcome,
			[TGWallpaperColourWord(@{@"topColor" : @0xFF112233, @"bottomColor" : @0x00112233})
					isEqualToString:@"#112233"],
			"two colours that differ only in the ignored high byte are the same colour, so the row must not "
			"claim a gradient");

	return outcome;
}

TGTestOutcome TGWallpaperRowTextTestTitleNamesGradientOnlyWhenTheEndsDiffer(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *gradient = TGWallpaperTitleForBackground(
			@{@"kind" : @"fill", @"topColor" : @0x000000, @"bottomColor" : @0xFFFFFF}, 0);
	NSString *solid = TGWallpaperTitleForBackground(
			@{@"kind" : @"fill", @"topColor" : @0x123456, @"bottomColor" : @0x123456}, 0);
	NSString *single = TGWallpaperTitleForBackground(@{@"kind" : @"fill", @"topColor" : @0x123456}, 0);

	TGTestExpectTrue(&outcome, [gradient isEqualToString:@"Gradient"],
			"a fill with two different ends is titled Gradient");
	TGTestExpectTrue(&outcome, [solid isEqualToString:@"Solid colour"],
			"a fill whose ends match is a solid colour");
	TGTestExpectTrue(&outcome, [single isEqualToString:@"Solid colour"],
			"a fill with only a top colour is a solid colour, not a gradient with a missing end");
	TGTestExpectTrue(&outcome,
			[TGWallpaperTitleForBackground(@{@"kind" : @"theme"}, 3) isEqualToString:@"Chat theme"],
			"a theme background is named, not numbered");

	return outcome;
}

TGTestOutcome TGWallpaperRowTextTestTitleNumbersPatternsAndPhotographsFromOne(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGWallpaperTitleForBackground(@{@"kind" : @"pattern"}, 0) isEqualToString:@"Pattern 1"],
			"the first pattern reads as 1, not 0: the index is a row position, the title is what the user counts");
	TGTestExpectTrue(&outcome,
			[TGWallpaperTitleForBackground(@{@"kind" : @"pattern"}, 4) isEqualToString:@"Pattern 5"],
			"and the fifth reads as 5");
	TGTestExpectTrue(&outcome,
			[TGWallpaperTitleForBackground(@{}, 0) isEqualToString:@"Photograph 1"],
			"an unknown or absent kind is a photograph, numbered the same way");

	return outcome;
}

TGTestOutcome TGWallpaperRowTextTestDetailJoinsOnlyThePartsThatApply(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGWallpaperDetailForBackground(@{@"kind" : @"wallpaper"}) isEqualToString:@"photo"],
			"a plain photo wallpaper says so");
	TGTestExpectTrue(&outcome,
			[TGWallpaperDetailForBackground(@{@"kind" : @"fill", @"topColor" : @0x112233})
					isEqualToString:@"#112233"],
			"a fill is not a photo, so the detail line carries only its colour");
	TGTestExpectTrue(&outcome,
			[TGWallpaperDetailForBackground(@{@"kind" : @"wallpaper", @"topColor" : @0x112233,
				@"isBlurred" : @YES, @"isMoving" : @YES, @"isDefault" : @YES})
					isEqualToString:@"photo, #112233, blurred, moving, built in"],
			"every applicable part appears once, in this order, joined with a comma and a space");
	TGTestExpectTrue(&outcome, [TGWallpaperDetailForBackground(@{@"kind" : @"theme"}) isEqualToString:@""],
			"a background with nothing to say about it gets an empty detail line rather than a stray comma");

	return outcome;
}

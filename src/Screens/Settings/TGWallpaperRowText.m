#import "TGWallpaperRowText.h"
#import "TGLocalization.h"

NSString *TGWallpaperKindOfBackground(NSDictionary *background) {
	NSString *kind = [background isKindOfClass:[NSDictionary class]] && [background[@"kind"] isKindOfClass:[NSString class]]
		? background[@"kind"]
		: nil;
	return kind.length ? kind : @"wallpaper";
}

NSString *TGWallpaperColourWord(NSDictionary *background) {
	NSNumber *top = background[@"topColor"];
	NSNumber *bottom = background[@"bottomColor"];
	if (![top isKindOfClass:[NSNumber class]])
		return nil;
	unsigned int topValue = [top unsignedIntValue] & 0xffffffu;
	if (![bottom isKindOfClass:[NSNumber class]] || ([bottom unsignedIntValue] & 0xffffffu) == topValue)
		return [NSString stringWithFormat:@"#%06X", topValue];
	return [NSString stringWithFormat:@"#%06X to #%06X", topValue,
		[bottom unsignedIntValue] & 0xffffffu];
}

NSString *TGWallpaperTitleForBackground(NSDictionary *background, NSInteger index) {
	NSString *kind = TGWallpaperKindOfBackground(background);
	if ([kind isEqualToString:@"fill"]) {
		NSNumber *top = background[@"topColor"];
		NSNumber *bottom = background[@"bottomColor"];
		BOOL gradient = [top isKindOfClass:[NSNumber class]] && [bottom isKindOfClass:[NSNumber class]] && [top unsignedIntValue] != [bottom unsignedIntValue];
		return gradient ? TGL(@"Wallpaper.Gradient", @"Gradient") : TGL(@"Wallpaper.SolidColourLowercase", @"Solid colour");
	}
	if ([kind isEqualToString:@"theme"])
		return TGL(@"Wallpaper.ChatTheme", @"Chat theme");
	if ([kind isEqualToString:@"pattern"])
		return [NSString stringWithFormat:TGL(@"Wallpaper.PatternNumbered", @"Pattern %ld"), (long)(index + 1)];
	return [NSString stringWithFormat:TGL(@"Wallpaper.PhotographNumbered", @"Photograph %ld"), (long)(index + 1)];
}

NSString *TGWallpaperDetailForBackground(NSDictionary *background) {
	NSString *kind = TGWallpaperKindOfBackground(background);
	NSMutableArray *parts = [NSMutableArray array];
	NSString *colours = TGWallpaperColourWord(background);
	if ([kind isEqualToString:@"wallpaper"])
		[parts addObject:TGL(@"Wallpaper.DetailPhoto", @"photo")];
	if (colours.length)
		[parts addObject:colours];
	if ([background[@"isBlurred"] boolValue])
		[parts addObject:TGL(@"Wallpaper.DetailBlurred", @"blurred")];
	if ([background[@"isMoving"] boolValue])
		[parts addObject:TGL(@"Wallpaper.DetailMoving", @"moving")];
	if ([background[@"isDefault"] boolValue])
		[parts addObject:TGL(@"Wallpaper.DetailBuiltIn", @"built in")];
	return [parts componentsJoinedByString:@", "];
}

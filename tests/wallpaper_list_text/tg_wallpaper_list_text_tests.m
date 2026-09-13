#import "tg_wallpaper_list_text_tests.h"

#import "../../src/Screens/Settings/TGWallpaperListText.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGWallpaperListTextTestThreeStatesNotOne(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *loading = TGWallpaperListText(NO, NO);
	NSString *failed = TGWallpaperListText(YES, YES);
	NSString *empty = TGWallpaperListText(YES, NO);

	TGTestExpectTrue(&outcome, ![loading isEqualToString:failed],
			"a list that failed no longer says Loading… forever, which is what both wallpaper "
			"screens showed after an error");
	TGTestExpectTrue(&outcome, ![empty isEqualToString:loading],
			"and an account with no saved wallpapers says so rather than loading for good");
	TGTestExpectTrue(&outcome, ![empty isEqualToString:failed],
			"the two ends - nothing saved, and could not ask - read differently");
	TGTestExpectTrue(&outcome, TGWallpaperListText(NO, YES).length &&
			[TGWallpaperListText(NO, YES) isEqualToString:loading],
			"a failure that arrives before the list has loaded still reads as loading, since "
			"the screen has not finished asking");

	return outcome;
}

#import "TGWallpaperListText.h"
#import "TGListStateText.h"
#import "TGLocalization.h"

NSString *TGWallpaperListText(BOOL loaded, BOOL failed) {
	return TGListStateText(loaded, failed,
		TGL(@"Channel.NotificationLoading", @"Loading…"),
		TGL(@"Wallpaper.ListLoadFailed",
				@"The wallpapers on your account could not be loaded."),
		TGL(@"Wallpaper.ListEmpty",
			@"No wallpapers are saved on your account yet."));
}

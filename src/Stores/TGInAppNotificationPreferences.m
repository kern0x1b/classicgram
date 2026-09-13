#import "TGInAppNotificationPreferences.h"

NSString *const TGSettingsInAppSoundsKey = @"TGInAppSounds";
NSString *const TGSettingsInAppVibrateKey = @"TGInAppVibrate";
NSString *const TGSettingsInAppPreviewKey = @"TGInAppPreview";
NSString *const TGSettingsShowTranslateKey = @"TGShowTranslateButton";

@implementation TGInAppNotificationPreferences

+ (BOOL)inAppSoundsEnabled {
	id stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGSettingsInAppSoundsKey];
	return [stored respondsToSelector:@selector(boolValue)] ? [stored boolValue] : YES;
}

+ (BOOL)inAppVibrateEnabled {
	id stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGSettingsInAppVibrateKey];
	return [stored respondsToSelector:@selector(boolValue)] ? [stored boolValue] : YES;
}

+ (BOOL)inAppPreviewEnabled {
	id stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGSettingsInAppPreviewKey];
	return [stored respondsToSelector:@selector(boolValue)] ? [stored boolValue] : YES;
}

+ (BOOL)showTranslateButton {
	id stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGSettingsShowTranslateKey];
	if (![stored respondsToSelector:@selector(boolValue)])
		return YES;
	return [stored boolValue];
}

@end

#import "TGDemoMode.h"

NSString *const TGDemoModeDefaultsKey = @"TGDemoMode";

NSString *TGDemoModeMarkerPath(void) {
	NSString *library = [NSSearchPathForDirectoriesInDomains(
		NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
	return [library stringByAppendingPathComponent:@"Preferences/TGDemoMode"];
}

BOOL TGDemoModeWanted(NSString *environmentValue, BOOL storedFlag, BOOL markerPresent) {
	if (environmentValue.length) {
		NSString *value = [environmentValue lowercaseString];
		if ([value isEqualToString:@"0"] || [value isEqualToString:@"no"] ||
			[value isEqualToString:@"false"])
			return NO;
		return YES;
	}
	return storedFlag || markerPresent;
}

BOOL TGDemoModeEnabled(void) {
	static BOOL enabled = NO;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		NSString *value = [NSProcessInfo processInfo].environment[@"TG_DEMO_MODE"];
		BOOL stored = [[NSUserDefaults standardUserDefaults] boolForKey:TGDemoModeDefaultsKey];
		BOOL marker = [[NSFileManager defaultManager]
			fileExistsAtPath:TGDemoModeMarkerPath()];
		enabled = TGDemoModeWanted(value, stored, marker);
	});
	return enabled;
}

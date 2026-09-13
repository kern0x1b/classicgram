#import "TGTestDCMode.h"

static NSString *const TGTestDCEnabledKey = @"TGUseTestDC";

NSString *TGTestDCMarkerPath(void) {
	NSString *library = [NSSearchPathForDirectoriesInDomains(
		NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
	return [library stringByAppendingPathComponent:@"Preferences/TGUseTestDC"];
}

BOOL TGTestDCWanted(NSString *environmentValue, BOOL storedFlag, BOOL markerPresent) {
	if (environmentValue.length) {
		NSString *value = [environmentValue lowercaseString];
		if ([value isEqualToString:@"0"] || [value isEqualToString:@"no"] ||
			[value isEqualToString:@"false"])
			return NO;
		return YES;
	}
	return storedFlag || markerPresent;
}

BOOL TGTestDCEnabled(void) {
	NSString *value = [NSProcessInfo processInfo].environment[@"TG_TEST_DC"];
	BOOL stored = [[NSUserDefaults standardUserDefaults] boolForKey:TGTestDCEnabledKey];
	BOOL marker = [[NSFileManager defaultManager] fileExistsAtPath:TGTestDCMarkerPath()];
	return TGTestDCWanted(value, stored, marker);
}

void TGSetTestDCEnabled(BOOL enabled) {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:enabled forKey:TGTestDCEnabledKey];
	[defaults synchronize];
}

NSString *TGTestDCScopeForScope(NSString *scope) {
	return [@"testdc" stringByAppendingString:scope ?: @""];
}

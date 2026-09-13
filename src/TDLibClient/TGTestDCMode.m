#import "TGTestDCMode.h"

static NSString *const TGTestDCEnabledKey = @"TGUseTestDC";

BOOL TGTestDCEnabled(void) {
	return [[NSUserDefaults standardUserDefaults] boolForKey:TGTestDCEnabledKey];
}

void TGSetTestDCEnabled(BOOL enabled) {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:enabled forKey:TGTestDCEnabledKey];
	[defaults synchronize];
}

NSString *TGTestDCScopeForScope(NSString *scope) {
	return [@"testdc" stringByAppendingString:scope ?: @""];
}

#import "TGSettingValueText.h"

#import "TGLocalization.h"

NSString *TGSettingValueText(BOOL loaded, BOOL failed, NSString *value) {
	if (failed)
		return TGL(@"Settings.ValueUnavailable", @"Unavailable");
	if (!loaded)
		return @"...";
	return [value isKindOfClass:[NSString class]] ? value : @"";
}

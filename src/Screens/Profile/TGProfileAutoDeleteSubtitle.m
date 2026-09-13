#import "TGProfileAutoDeleteSubtitle.h"
#import "TGLocalization.h"

NSString *TGProfileAutoDeleteSubtitleForSeconds(NSInteger seconds) {
	if (seconds <= 0)
		return TGL(@"PrivacySettings.PasscodeOff", @"Off");
	if (seconds == 86400)
		return TGL(@"Notification.MessageLifetime1d", @"1 day");
	if (seconds == 604800)
		return TGL(@"Notification.MessageLifetime1w", @"1 week");
	if (seconds == 2592000)
		return TGLPlural(@"MessageTimer.Months", 1, @"%ld month", @"%ld months");
	if (seconds < 60)
		return TGLPlural(@"MessageTimer.Seconds", seconds, @"%ld second", @"%ld seconds");
	if (seconds < 3600)
		return TGLPlural(@"MessageTimer.Minutes", seconds / 60, @"%ld minute", @"%ld minutes");
	if (seconds < 86400)
		return TGLPlural(@"MessageTimer.Hours", seconds / 3600, @"%ld hour", @"%ld hours");
	if (seconds < 604800)
		return TGLPlural(@"MessageTimer.Days", seconds / 86400, @"%ld day", @"%ld days");
	return TGLPlural(@"MessageTimer.Weeks", seconds / 604800, @"%ld week", @"%ld weeks");
}

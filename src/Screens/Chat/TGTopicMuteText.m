#import "TGTopicMuteText.h"
#import "TGLocalization.h"

NSString *TGTopicMuteText(NSInteger seconds) {
	if (seconds <= 0)
		return TGL(@"UserInfo.NotificationsEnabled", @"Enabled");
	if (seconds >= 366 * 24 * 3600)
		return TGL(@"Notifications.ExceptionsMuted", @"Muted");
	if (seconds >= 24 * 3600)
		return [NSString stringWithFormat:TGL(@"MutedForTime.Prefix", @"Muted for %@"),
			TGLPlural(@"MutedForTime.Days", (long)(seconds / (24 * 3600)), @"1 day", @"%ld days")];
	if (seconds >= 3600)
		return [NSString stringWithFormat:TGL(@"MutedForTime.Prefix", @"Muted for %@"),
			TGLPlural(@"MutedForTime.Hours", (long)(seconds / 3600), @"1 hour", @"%ld hours")];
	return [NSString stringWithFormat:TGL(@"MutedForTime.Prefix", @"Muted for %@"),
		TGLPlural(@"MutedForTime.Minutes", (long)MAX((NSInteger)1, seconds / 60), @"1 minute", @"%ld minutes")];
}

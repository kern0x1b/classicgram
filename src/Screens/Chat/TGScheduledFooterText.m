#import "TGScheduledFooterText.h"
#import "TGLocalization.h"

NSString *TGScheduledFooterText(BOOL loaded, BOOL failed, NSUInteger count, BOOL remindersStyle) {
	if (!loaded)
		return TGL(@"Channel.NotificationLoading", @"Loading…");
	if (failed)
		return TGL(@"ScheduledMessages.LoadFailedFooter",
				@"The list could not be loaded. It is not that there is nothing waiting - leave "
				@"this screen and come back to try again.");
	if (!count)
		return remindersStyle
			? TGL(@"ScheduledMessages.NothingToRemindFooter", @"Nothing is waiting to remind you.")
			: TGL(@"ScheduledMessages.NothingToSendFooter", @"Nothing is waiting to be sent in this chat.");
	return remindersStyle
		? TGL(@"ScheduledMessages.TapReminderFooter", @"Tap a reminder to fire it now, move it or throw it away.")
		: TGL(@"ScheduledMessages.TapMessageFooter", @"Tap a message to send it now, move it or throw it away.");
}

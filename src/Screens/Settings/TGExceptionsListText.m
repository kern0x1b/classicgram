#import "TGExceptionsListText.h"
#import "TGListStateText.h"
#import "TGLocalization.h"

NSString *TGExceptionsListText(BOOL loaded, BOOL failed) {
	return TGListStateText(loaded, failed,
		TGL(@"Channel.NotificationLoading", @"Loading…"),
		TGL(@"Notifications.ExceptionsLoadFailed",
				@"The chats with their own notification settings could not be read."),
		TGL(@"Notifications.ExceptionsNone", @"No exceptions"));
}

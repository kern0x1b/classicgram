#import "TGCallEndText.h"
#import "TGLocalization.h"

NSString *TGCallEndText(NSString *reason, NSString *fallback) {
	if (![reason isKindOfClass:[NSString class]] || reason.length == 0)
		return fallback;
	if ([reason isEqualToString:@"No answer"])
		return TGL(@"Call.StatusNoAnswer", @"No Answer");
	if ([reason isEqualToString:@"Declined"])
		return TGL(@"Call.StatusBusy", @"Busy");
	if ([reason isEqualToString:@"Disconnected"])
		return TGL(@"Call.StatusFailed", @"Call Failed");
	if ([reason isEqualToString:@"Call ended"])
		return TGL(@"Call.StatusEnded", @"Call Ended");
	if ([reason isEqualToString:@"Moved to a group call"])
		return TGL(@"Call.StatusMovedToGroupCall", @"Moved to a Group Call");
	return fallback;
}

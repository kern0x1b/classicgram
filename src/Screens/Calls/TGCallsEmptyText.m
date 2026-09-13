#import "TGCallsEmptyText.h"

#import "TGListLoadFailure.h"
#import "TGLocalization.h"

NSString *TGCallsEmptyText(BOOL loaded, BOOL failed, BOOL onlyMissed, NSUInteger rowCount) {
	switch (TGListStatusOfList(loaded, failed, rowCount)) {
		case TGListStatusLoading:
			return @"";
		case TGListStatusFailed:
			return TGL(@"Calls.HistoryLoadFailed", @"Your call history could not be loaded.");
		case TGListStatusEmpty:
			return onlyMissed
				? TGL(@"Calls.NoMissedCallsPlacehoder", @"No missed calls")
				: TGL(@"Calls.NoCallsPlaceholder", @"No recent calls");
		case TGListStatusRows:
			break;
	}
	return @"";
}

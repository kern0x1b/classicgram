#import "TGStoryViewersFooter.h"

#import "TGListLoadFailure.h"
#import "TGLocalization.h"

NSString *TGStoryViewersFooterText(BOOL loaded, BOOL failed, NSUInteger rowCount) {
	switch (TGListStatusOfList(loaded, failed, rowCount)) {
		case TGListStatusLoading:
			return TGL(@"Channel.NotificationLoading", @"Loading…");
		case TGListStatusFailed:
			return TGL(@"Story.Viewers.LoadFailed", @"The list of viewers could not be loaded.");
		case TGListStatusEmpty:
			return TGL(@"Story.Viewers.Empty", @"Nobody has seen this story yet.");
		case TGListStatusRows:
			break;
	}
	return @"";
}

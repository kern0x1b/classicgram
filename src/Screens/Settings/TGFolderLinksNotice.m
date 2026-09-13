#import "TGFolderLinksNotice.h"

#import "TGListLoadFailure.h"
#import "TGLocalization.h"

NSString *TGFolderLinksNoticeText(BOOL failed, NSUInteger knownLinkCount) {
	if (!TGListShowsLoadFailureNotice(failed, knownLinkCount))
		return @"";
	return TGL(@"ChatListFilter.LinksLoadFailed",
		@"The links for this folder could not be loaded.");
}

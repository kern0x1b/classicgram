#import "TGListLoadFailure.h"

BOOL TGListShowsLoadFailureNotice(BOOL failed, NSUInteger loadedRowCount) {
	return failed && loadedRowCount == 0;
}

TGListStatus TGListStatusOfList(BOOL loaded, BOOL failed, NSUInteger loadedRowCount) {
	if (loadedRowCount > 0)
		return TGListStatusRows;
	if (TGListShowsLoadFailureNotice(failed, loadedRowCount))
		return TGListStatusFailed;
	if (!loaded)
		return TGListStatusLoading;
	return TGListStatusEmpty;
}

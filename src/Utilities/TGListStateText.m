#import "TGListStateText.h"

NSString *TGListStateText(BOOL loaded,
	BOOL failed,
	NSString *loadingText,
	NSString *failedText,
	NSString *emptyText) {
	if (!loaded)
		return loadingText;
	if (failed)
		return failedText;
	return emptyText;
}

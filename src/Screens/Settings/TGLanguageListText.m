#import "TGLanguageListText.h"
#import "TGListStateText.h"
#import "TGLocalization.h"

NSString *TGLanguageListText(BOOL loaded, BOOL failed) {
	return TGListStateText(loaded, failed,
		TGL(@"Channel.NotificationLoading", @"Loading…"),
		TGL(@"Localization.ListLoadFailed",
				@"The list of languages could not be loaded. The app keeps the language it is "
				@"already using."),
		TGL(@"Localization.NoLanguagesAvailable", @"No languages available"));
}

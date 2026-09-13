#import "TGMemberPickerStatusText.h"

#import "TGLocalization.h"

NSString *TGMemberPickerStatusText(BOOL failed, NSUInteger rowCount) {
	if (rowCount)
		return @"";
	if (failed)
		return TGL(@"Contacts.Search.Failed",
			@"Contacts could not be searched. Check the connection and try again.");
	return TGL(@"Contacts.Search.NoResults",
		@"No contact or Telegram user matches that name.");
}

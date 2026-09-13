#import "TGSavedModeSheetAction.h"

TGSavedModeSheetAction TGSavedModeSheetActionForIndex(NSInteger index, NSInteger cancelIndex) {
	if (index < 0 || index == cancelIndex)
		return TGSavedModeSheetActionNone;
	if (index == 0)
		return TGSavedModeSheetActionViewAsChats;
	if (index == 1)
		return TGSavedModeSheetActionViewAsMessages;
	if (index == 2)
		return TGSavedModeSheetActionMessageTags;
	return TGSavedModeSheetActionNone;
}

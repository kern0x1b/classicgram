#import <Foundation/Foundation.h>

typedef enum {
	TGSavedModeSheetActionNone = 0,
	TGSavedModeSheetActionViewAsChats,
	TGSavedModeSheetActionViewAsMessages,
	TGSavedModeSheetActionMessageTags,
} TGSavedModeSheetAction;

TGSavedModeSheetAction TGSavedModeSheetActionForIndex(NSInteger index, NSInteger cancelIndex);

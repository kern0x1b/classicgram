#import "TGFormSaveState.h"

BOOL TGFormCanSave(BOOL loaded, BOOL failed, BOOL readOnly) {
	if (!loaded || failed)
		return NO;
	return !readOnly;
}

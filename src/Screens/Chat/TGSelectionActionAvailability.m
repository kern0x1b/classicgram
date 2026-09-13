#import "TGSelectionActionAvailability.h"

BOOL TGSelectionActionIsAvailable(BOOL protectionKnown,
	BOOL chatHasProtectedContent,
	BOOL anySelected,
	BOOL anySelectedDisallows) {
	if (!anySelected)
		return NO;
	if (!protectionKnown)
		return NO;
	if (chatHasProtectedContent)
		return NO;
	return !anySelectedDisallows;
}

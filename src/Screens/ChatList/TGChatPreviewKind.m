#import "TGChatPreviewKind.h"

TGChatPreviewKind TGChatPreviewKindForRow(BOOL hasAction,
	BOOL hasHandshake,
	BOOL hasDraft,
	BOOL isAnnouncement,
	BOOL showingSearchResults) {
	if (hasAction)
		return TGChatPreviewKindAction;
	if (hasHandshake)
		return TGChatPreviewKindHandshake;
	if (hasDraft && !showingSearchResults)
		return TGChatPreviewKindDraft;
	if (isAnnouncement)
		return TGChatPreviewKindAnnouncement;
	return TGChatPreviewKindMessage;
}

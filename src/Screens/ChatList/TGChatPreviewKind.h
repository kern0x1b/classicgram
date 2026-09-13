#import <Foundation/Foundation.h>

typedef enum {
	TGChatPreviewKindMessage = 0,
	TGChatPreviewKindAction,
	TGChatPreviewKindHandshake,
	TGChatPreviewKindDraft,
	TGChatPreviewKindAnnouncement,
} TGChatPreviewKind;

TGChatPreviewKind TGChatPreviewKindForRow(BOOL hasAction,
	BOOL hasHandshake,
	BOOL hasDraft,
	BOOL isAnnouncement,
	BOOL showingSearchResults);

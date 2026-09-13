#import "tg_chat_preview_kind_tests.h"
#import "../../src/Screens/ChatList/TGChatPreviewKind.h"

TGTestOutcome TGChatPreviewKindTestWhatARowSaysWhenSeveralThingsAreTrue(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			TGChatPreviewKindForRow(NO, NO, NO, NO, NO) == TGChatPreviewKindMessage,
			"with nothing else happening a row shows the last message");
	TGTestExpectTrue(&outcome,
			TGChatPreviewKindForRow(YES, YES, YES, YES, NO) == TGChatPreviewKindAction,
			"someone typing outranks everything else, because it is the only line that is true "
			"right now");
	TGTestExpectTrue(&outcome,
			TGChatPreviewKindForRow(NO, YES, YES, YES, NO) == TGChatPreviewKindHandshake,
			"a secret chat still setting itself up says so before anything else");
	TGTestExpectTrue(&outcome,
			TGChatPreviewKindForRow(NO, NO, YES, YES, NO) == TGChatPreviewKindDraft,
			"an unsent draft is shown ahead of a public service announcement");
	TGTestExpectTrue(&outcome,
			TGChatPreviewKindForRow(NO, NO, YES, NO, YES) == TGChatPreviewKindMessage,
			"in search results the draft belongs to the chat list, not to the result, so the "
			"message is shown instead");
	TGTestExpectTrue(&outcome,
			TGChatPreviewKindForRow(NO, NO, NO, YES, NO) == TGChatPreviewKindAnnouncement,
			"an announcement row names its source above the message");

	return outcome;
}

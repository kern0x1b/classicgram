#import "tg_chat_list_preview_author_tests.h"
#import "../../src/Wire/Flatten/TGChatListPreviewAuthor.h"

TGTestOutcome TGChatListPreviewAuthorTestNamesWhoSpokeInAGroup(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
		[TGChatListPreviewWithAuthor(@"Боремся до конца", YES, NO, NO, @"Anastasiia", nil)
			isEqualToString:@"Anastasiia: Боремся до конца"],
		"someone else's message in a group is prefixed with their name");
	TGTestExpectTrue(&outcome,
		[TGChatListPreviewWithAuthor(@"Боремся до конца", YES, YES, NO, nil, @"You")
			isEqualToString:@"You: Боремся до конца"],
		"our own message in a group says You, which is what the original shows");
	TGTestExpectTrue(&outcome,
		[TGChatListPreviewWithAuthor(@"", YES, YES, NO, nil, @"You") isEqualToString:@"You: "],
		"a message with no preview text still names who sent it");

	return outcome;
}

TGTestOutcome TGChatListPreviewAuthorTestLeavesEveryOtherChatAlone(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
		[TGChatListPreviewWithAuthor(@"Видимо не голодная", NO, NO, NO, @"Дима", nil)
			isEqualToString:@"Видимо не голодная"],
		"a one-to-one chat has only one other person, so no name is prefixed");
	TGTestExpectTrue(&outcome,
		[TGChatListPreviewWithAuthor(@"ПВО уже второй день", YES, NO, YES, @"Україна 24/7", nil)
			isEqualToString:@"ПВО уже второй день"],
		"a channel post is the channel speaking, so its own name is not repeated");
	TGTestExpectTrue(&outcome,
		[TGChatListPreviewWithAuthor(@"text", YES, NO, NO, @"", nil) isEqualToString:@"text"],
		"a sender whose name is not loaded yet leaves the preview as it is");
	TGTestExpectTrue(&outcome,
		[TGChatListPreviewWithAuthor(nil, YES, YES, NO, nil, @"You") isEqualToString:@"You: "],
		"a missing preview is an empty one, not a crash");

	return outcome;
}

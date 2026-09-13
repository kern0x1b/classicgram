#import "tg_flatten_direct_messages_tests.h"
#import "../../src/Wire/Flatten/TGFlattenDirectMessages.h"
#import <Foundation/Foundation.h>

static NSDictionary *TGFlattenDirectMessagesMessageOfType(NSString *type) {
	return @{@"content" : @{@"@type" : type}};
}

TGTestOutcome TGFlattenDirectMessagesTestPreviewForPhoto(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGDMPreview(TGFlattenDirectMessagesMessageOfType(@"messagePhoto")) isEqualToString:@"Photo"],
			"messagePhoto with no text or caption must preview as \"Photo\"");

	return outcome;
}

TGTestOutcome TGFlattenDirectMessagesTestPreviewForVideo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGDMPreview(TGFlattenDirectMessagesMessageOfType(@"messageVideo")) isEqualToString:@"Video"],
			"messageVideo with no text or caption must preview as \"Video\"");

	return outcome;
}

TGTestOutcome TGFlattenDirectMessagesTestPreviewForVideoNote(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGDMPreview(TGFlattenDirectMessagesMessageOfType(@"messageVideoNote"))
					isEqualToString:@"Video Message"],
			"messageVideoNote must preview as \"Video Message\"");

	return outcome;
}

TGTestOutcome TGFlattenDirectMessagesTestPreviewForVoiceNote(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGDMPreview(TGFlattenDirectMessagesMessageOfType(@"messageVoiceNote"))
					isEqualToString:@"Voice message"],
			"messageVoiceNote must preview as \"Voice message\"");

	return outcome;
}

TGTestOutcome TGFlattenDirectMessagesTestPreviewForSticker(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGDMPreview(TGFlattenDirectMessagesMessageOfType(@"messageSticker")) isEqualToString:@"Sticker"],
			"messageSticker must preview as \"Sticker\"");

	return outcome;
}

TGTestOutcome TGFlattenDirectMessagesTestPreviewForDocument(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGDMPreview(TGFlattenDirectMessagesMessageOfType(@"messageDocument")) isEqualToString:@"File"],
			"messageDocument must preview as \"File\"");

	return outcome;
}

TGTestOutcome TGFlattenDirectMessagesTestPreviewPrefersTextOverKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"content" : @{
			@"@type" : @"messagePhoto",
			@"text" : @{@"text" : @"hello"},
		},
	};

	TGTestExpectTrue(&outcome, [TGDMPreview(message) isEqualToString:@"hello"],
			"a non-empty content.text must take priority over the content kind's fixed label");

	return outcome;
}

TGTestOutcome TGFlattenDirectMessagesTestPreviewFallsBackToCaptionWhenNoText(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"content" : @{
			@"@type" : @"messagePhoto",
			@"caption" : @{@"text" : @"a caption"},
		},
	};

	TGTestExpectTrue(&outcome, [TGDMPreview(message) isEqualToString:@"a caption"],
			"with no content.text, a non-empty content.caption must take priority over the content kind's fixed label");

	return outcome;
}

TGTestOutcome TGFlattenDirectMessagesTestPreviewForAudio(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGDMPreview(TGFlattenDirectMessagesMessageOfType(@"messageAudio")) isEqualToString:@"Audio"],
			"an audio file must preview as Audio, the same noun the forum-topic preview builder uses");

	return outcome;
}

TGTestOutcome TGFlattenDirectMessagesTestPreviewForAnimation(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGDMPreview(TGFlattenDirectMessagesMessageOfType(@"messageAnimation")) isEqualToString:@"GIF"],
			"a GIF must preview as GIF rather than leaving the topic row's preview line blank");

	return outcome;
}

TGTestOutcome TGFlattenDirectMessagesTestPreviewForLocation(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGDMPreview(TGFlattenDirectMessagesMessageOfType(@"messageLocation")) isEqualToString:@"Location"],
			"a shared location must preview as Location");

	return outcome;
}

TGTestOutcome TGFlattenDirectMessagesTestPreviewForContact(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGDMPreview(TGFlattenDirectMessagesMessageOfType(@"messageContact")) isEqualToString:@"Contact"],
			"a shared contact must preview as Contact");

	return outcome;
}

TGTestOutcome TGFlattenDirectMessagesTestPreviewForPoll(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGDMPreview(TGFlattenDirectMessagesMessageOfType(@"messagePoll")) isEqualToString:@"Poll"],
			"a poll must preview as Poll");

	return outcome;
}

TGTestOutcome TGFlattenDirectMessagesTestPreviewFallsBackForUnknownKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGDMPreview(TGFlattenDirectMessagesMessageOfType(@"messagePinMessage")) isEqualToString:@""],
			"a content kind with no case in this mapper must preview as empty, not crash");

	return outcome;
}

TGTestOutcome TGFlattenDirectMessagesTestPreviewFallsBackForNilMessage(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGDMPreview(nil) isEqualToString:@""],
			"a nil message must preview as empty, not crash");

	return outcome;
}

TGTestOutcome TGFlattenDirectMessagesTestFlattenTopicComposesRealisticPayload(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *topic = @{
		@"id" : @9,
		@"chat_id" : @1002,
		@"sender_id" : @{@"user_id" : @55},
		@"order" : @123456,
		@"can_send_unpaid_messages" : @YES,
		@"is_marked_as_unread" : @YES,
		@"unread_count" : @4,
		@"unread_reaction_count" : @2,
		@"last_message" : @{
			@"content" : @{@"@type" : @"messageSticker"},
			@"date" : @5000,
			@"is_outgoing" : @YES,
		},
	};

	NSDictionary *flat = TGDMFlattenTopic(topic);

	TGTestExpectTrue(&outcome, flat != nil, "a well-formed direct-messages topic must flatten, not return nil");
	TGTestExpectEqualLongLong(&outcome, [flat[@"topicId"] longLongValue], 9,
			"topicId must round-trip from topic.id");
	TGTestExpectEqualLongLong(&outcome, [flat[@"chatId"] longLongValue], 1002,
			"chatId must round-trip from topic.chat_id");
	TGTestExpectEqualLongLong(&outcome, [flat[@"senderUserId"] longLongValue], 55,
			"senderUserId must come from sender_id.user_id");
	TGTestExpectEqualLongLong(&outcome, [flat[@"order"] longLongValue], 123456,
			"order must round-trip from topic.order");
	TGTestExpectTrue(&outcome, [flat[@"canSendUnpaidMessages"] boolValue],
			"canSendUnpaidMessages must round-trip from topic.can_send_unpaid_messages");
	TGTestExpectTrue(&outcome, [flat[@"isMarkedAsUnread"] boolValue],
			"isMarkedAsUnread must round-trip from topic.is_marked_as_unread");
	TGTestExpectEqualInteger(&outcome, [flat[@"unread"] integerValue], 4,
			"unread must round-trip from topic.unread_count");
	TGTestExpectEqualInteger(&outcome, [flat[@"unreadReactions"] integerValue], 2,
			"unreadReactions must round-trip from topic.unread_reaction_count");
	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@"Sticker"],
			"text must be the preview of last_message");
	TGTestExpectEqualLongLong(&outcome, [flat[@"date"] longLongValue], 5000,
			"date must come from last_message.date");
	TGTestExpectTrue(&outcome, [flat[@"outgoing"] boolValue],
			"outgoing must come from last_message.is_outgoing");

	return outcome;
}

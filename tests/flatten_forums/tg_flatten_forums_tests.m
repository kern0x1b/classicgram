#import "tg_flatten_forums_tests.h"
#import "../../src/Wire/Flatten/TGFlattenForums.h"
#import <Foundation/Foundation.h>

static NSDictionary *TGFlattenForumsMessageOfType(NSString *type) {
	return @{@"content" : @{@"@type" : type}};
}

TGTestOutcome TGFlattenForumsTestMessagePreviewForPhoto(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(TGFlattenForumsMessageOfType(@"messagePhoto"))
					isEqualToString:@"Photo"],
			"messagePhoto with no caption must preview as \"Photo\"");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestMessagePreviewForVideo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(TGFlattenForumsMessageOfType(@"messageVideo"))
					isEqualToString:@"Video"],
			"messageVideo with no caption must preview as \"Video\"");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestMessagePreviewForVideoNote(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(TGFlattenForumsMessageOfType(@"messageVideoNote"))
					isEqualToString:@"Video Message"],
			"messageVideoNote must preview as \"Video Message\"");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestMessagePreviewForVoiceNote(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(TGFlattenForumsMessageOfType(@"messageVoiceNote"))
					isEqualToString:@"Voice message"],
			"messageVoiceNote must preview as \"Voice message\"");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestMessagePreviewForAudio(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(TGFlattenForumsMessageOfType(@"messageAudio"))
					isEqualToString:@"Audio"],
			"messageAudio must preview as \"Audio\"");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestMessagePreviewForDocument(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(TGFlattenForumsMessageOfType(@"messageDocument"))
					isEqualToString:@"File"],
			"messageDocument must preview as \"File\"");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestMessagePreviewForSticker(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(TGFlattenForumsMessageOfType(@"messageSticker"))
					isEqualToString:@"Sticker"],
			"messageSticker must preview as \"Sticker\"");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestMessagePreviewForAnimation(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(TGFlattenForumsMessageOfType(@"messageAnimation"))
					isEqualToString:@"GIF"],
			"messageAnimation must preview as \"GIF\"");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestMessagePreviewForLocation(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(TGFlattenForumsMessageOfType(@"messageLocation"))
					isEqualToString:@"Location"],
			"messageLocation must preview as \"Location\"");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestMessagePreviewForContact(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(TGFlattenForumsMessageOfType(@"messageContact"))
					isEqualToString:@"Contact"],
			"messageContact must preview as \"Contact\"");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestMessagePreviewForPoll(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(TGFlattenForumsMessageOfType(@"messagePoll"))
					isEqualToString:@"Poll"],
			"messagePoll must preview as \"Poll\"");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestMessagePreviewForTopicCreated(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(TGFlattenForumsMessageOfType(@"messageForumTopicCreated"))
					isEqualToString:@"Topic created"],
			"messageForumTopicCreated must preview as \"Topic created\"");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestMessagePreviewForTopicEditedRenamed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"content" : @{@"@type" : @"messageForumTopicEdited", @"name" : @"Bugs"},
	};

	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(message) isEqualToString:@"Topic renamed to \"Bugs\""],
			"messageForumTopicEdited with a new name must preview as \"Topic renamed to "
			"\\\"Bugs\\\"\"");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestMessagePreviewForTopicEditedIconOnly(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"content" : @{
			@"@type" : @"messageForumTopicEdited",
			@"edit_icon_custom_emoji_id" : @YES,
		},
	};

	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(message) isEqualToString:@"Topic icon changed"],
			"messageForumTopicEdited with only an icon change must preview as "
			"\"Topic icon changed\"");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestMessagePreviewForTopicEditedWithNoDetail(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(TGFlattenForumsMessageOfType(@"messageForumTopicEdited"))
					isEqualToString:@""],
			"messageForumTopicEdited with neither a name nor an icon change must preview as "
			"empty, not fabricate text");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestMessagePreviewFallsBackForUnknownKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(TGFlattenForumsMessageOfType(@"messageSomeFutureKind"))
					isEqualToString:@""],
			"an unrecognised content kind must preview as empty, not crash or fabricate text");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestFlattenTopicComposesFullPayload(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *topic = @{
		@"info" : @{
			@"forum_topic_id" : @5,
			@"chat_id" : @1001,
			@"name" : @"General",
			@"icon" : @{@"color" : @123, @"custom_emoji_id" : @"456"},
			@"creator_id" : @{@"user_id" : @42},
			@"creation_date" : @1000,
			@"is_general" : @YES,
			@"is_closed" : @NO,
			@"is_hidden" : @NO,
			@"is_outgoing" : @YES,
		},
		@"last_message" : @{
			@"content" : @{@"@type" : @"messagePhoto"},
			@"date" : @2000,
		},
		@"unread_count" : @3,
		@"unread_mention_count" : @1,
		@"unread_reaction_count" : @2,
		@"is_pinned" : @YES,
		@"notification_settings" : @{@"mute_for" : @600},
		@"order" : @999,
	};

	NSDictionary *flat = TGForumsFlattenTopic(topic, 7);

	TGTestExpectTrue(&outcome, flat != nil, "a well-formed topic must flatten, not return nil");
	TGTestExpectEqualLongLong(&outcome, [flat[@"topicId"] longLongValue], 5,
			"topicId must come from info.forum_topic_id");
	TGTestExpectEqualLongLong(&outcome, [flat[@"threadId"] longLongValue], 5,
			"threadId must mirror topicId");
	TGTestExpectEqualLongLong(&outcome, [flat[@"chatId"] longLongValue], 1001,
			"chatId must come from info.chat_id when present, not the fallback parameter");
	TGTestExpectTrue(&outcome, [flat[@"name"] isEqualToString:@"General"],
			"name must round-trip from info.name");
	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@"Photo"],
			"text must be the preview of last_message");
	TGTestExpectEqualLongLong(&outcome, [flat[@"date"] longLongValue], 2000,
			"date must come from last_message.date");
	TGTestExpectEqualInteger(&outcome, [flat[@"unread"] integerValue], 3,
			"unread must round-trip from unread_count");
	TGTestExpectEqualInteger(&outcome, [flat[@"unreadMentions"] integerValue], 1,
			"unreadMentions must round-trip from unread_mention_count");
	TGTestExpectEqualInteger(&outcome, [flat[@"unreadReactions"] integerValue], 2,
			"unreadReactions must round-trip from unread_reaction_count");
	TGTestExpectTrue(&outcome, [flat[@"isGeneral"] boolValue],
			"isGeneral must come from info.is_general");
	TGTestExpectTrue(&outcome, ![flat[@"isClosed"] boolValue],
			"isClosed must come from info.is_closed");
	TGTestExpectTrue(&outcome, ![flat[@"isHidden"] boolValue],
			"isHidden must come from info.is_hidden");
	TGTestExpectTrue(&outcome, [flat[@"isPinned"] boolValue],
			"isPinned must come from topic.is_pinned, not info");
	TGTestExpectTrue(&outcome, [flat[@"isOutgoing"] boolValue],
			"isOutgoing must come from info.is_outgoing");
	TGTestExpectEqualInteger(&outcome, [flat[@"iconColor"] integerValue], 123,
			"iconColor must come from icon.color");
	TGTestExpectEqualLongLong(&outcome, [flat[@"iconEmojiId"] longLongValue], 456,
			"iconEmojiId must coerce a string custom_emoji_id to its integer value");
	TGTestExpectEqualLongLong(&outcome, [flat[@"muteFor"] longLongValue], 600,
			"muteFor must come from notification_settings.mute_for");
	TGTestExpectEqualLongLong(&outcome, [flat[@"creationDate"] longLongValue], 1000,
			"creationDate must come from info.creation_date");
	TGTestExpectEqualLongLong(&outcome, [flat[@"creatorId"] longLongValue], 42,
			"creatorId must come from info.creator_id.user_id");
	TGTestExpectEqualLongLong(&outcome, [flat[@"order"] longLongValue], 999,
			"order must round-trip through the int64 coercion");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestFlattenTopicDefaultsForMinimalPayload(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *topic = @{@"info" : @{}};

	NSDictionary *flat = TGForumsFlattenTopic(topic, 7);

	TGTestExpectTrue(&outcome, flat != nil,
			"a topic with only an empty info dict must still flatten, not return nil");
	TGTestExpectEqualLongLong(&outcome, [flat[@"topicId"] longLongValue], 0,
			"a missing forum_topic_id must default to 0");
	TGTestExpectEqualLongLong(&outcome, [flat[@"chatId"] longLongValue], 7,
			"a missing info.chat_id must fall back to the chatId parameter");
	TGTestExpectTrue(&outcome, [flat[@"name"] isEqualToString:@""],
			"a missing name must default to an empty string");
	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@""],
			"a missing last_message must preview as an empty string");
	TGTestExpectEqualLongLong(&outcome, [flat[@"date"] longLongValue], 0,
			"a missing last_message date must default to 0");
	TGTestExpectEqualInteger(&outcome, [flat[@"unread"] integerValue], 0,
			"a missing unread_count must default to 0");
	TGTestExpectTrue(&outcome, ![flat[@"isGeneral"] boolValue],
			"a missing is_general must default to NO");
	TGTestExpectTrue(&outcome, ![flat[@"isPinned"] boolValue],
			"a missing is_pinned must default to NO");
	TGTestExpectEqualLongLong(&outcome, [flat[@"iconEmojiId"] longLongValue], 0,
			"a missing icon.custom_emoji_id must coerce to 0");
	TGTestExpectEqualLongLong(&outcome, [flat[@"order"] longLongValue], 0,
			"a missing order must coerce to 0");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestTopicIdForNotificationExtractsForumTopicId(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *notification = @{
		@"type" : @{
			@"@type" : @"notificationTypeNewMessage",
			@"message" : @{
				@"topic_id" : @{
					@"@type" : @"messageTopicForum",
					@"forum_topic_id" : @42,
				},
			},
		},
	};

	TGTestExpectEqualInteger(&outcome, TGForumsTopicIdForNotification(notification), 42,
			"a notification for a forum message must yield its forum_topic_id");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestTopicIdForNotificationIsZeroForNonForumTopic(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *notification = @{
		@"type" : @{
			@"@type" : @"notificationTypeNewMessage",
			@"message" : @{
				@"topic_id" : @{@"@type" : @"messageTopicThread", @"message_thread_id" : @42},
			},
		},
	};

	TGTestExpectEqualInteger(&outcome, TGForumsTopicIdForNotification(notification), 0,
			"a non-forum message topic must not be reported as a forum topic id");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestTopicIdForNotificationIsZeroForNonMessageNotification(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualInteger(&outcome, TGForumsTopicIdForNotification(nil), 0,
			"a nil notification must yield 0, not crash");
	TGTestExpectEqualInteger(&outcome,
			TGForumsTopicIdForNotification(@{@"type" : @{@"@type" : @"notificationTypeMessageTimeout"}}),
			0, "a non-new-message notification type must yield 0");

	return outcome;
}

TGTestOutcome TGFlattenForumsTestTopicRowsNameEveryKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *checklist = @{@"content" : @{@"@type" : @"messageChecklist"}};
	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(checklist) isEqualToString:@"Checklist"],
			"a checklist names itself in a topic row, where the row used to be blank");

	NSDictionary *groupCall = @{@"content" : @{@"@type" : @"messageGroupCall",
		@"was_missed" : @YES}};
	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(groupCall) isEqualToString:@"Missed Group Call"],
			"a missed group call names itself in the words the chat uses");

	NSDictionary *secret = @{@"content" : @{@"@type" : @"messageVideo", @"is_secret" : @YES,
		@"caption" : @{@"text" : @"the words meant to be seen once"}}};
	TGTestExpectTrue(&outcome,
			[TGForumsMessagePreview(secret) isEqualToString:@"Disappearing Video"],
			"a disappearing video names itself rather than lending its caption to the row");

	return outcome;
}

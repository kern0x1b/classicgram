#import "tg_flatten_saved_messages_tests.h"
#import "../../src/Wire/Flatten/TGFlattenSavedMessages.h"
#import <Foundation/Foundation.h>

static NSDictionary *TGFlattenSavedMessagesTopicOfType(NSString *typeName,
		NSDictionary *extraType, BOOL withDraft) {
	NSMutableDictionary *type = [NSMutableDictionary dictionaryWithDictionary:@{@"@type" : typeName}];
	if (extraType)
		[type addEntriesFromDictionary:extraType];

	NSMutableDictionary *topic = [NSMutableDictionary dictionaryWithDictionary:@{
		@"id" : @1,
		@"type" : type,
		@"last_message" : @{
			@"content" : @{@"@type" : @"messagePhoto"},
			@"date" : @100,
			@"id" : @55,
			@"is_outgoing" : @YES,
		},
		@"is_pinned" : @NO,
		@"order" : @10,
	}];
	if (withDraft) {
		topic[@"draft_message"] = @{
			@"content" : @{
				@"@type" : @"draftMessageContentText",
				@"text" : @{@"@type" : @"formattedText", @"text" : @"hello draft"},
			},
		};
	}
	return topic;
}

static NSDictionary *TGFlattenSavedMessagesMessageOfType(NSString *type) {
	return @{@"content" : @{@"@type" : type}};
}

TGTestOutcome TGFlattenSavedMessagesTestFlattenTopicClassifiesMyNotesWithoutDraft(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *topic = TGFlattenSavedMessagesTopicOfType(@"savedMessagesTopicTypeMyNotes", nil, NO);
	NSDictionary *flat = TGSavedFlattenTopic(topic, nil);

	TGTestExpectTrue(&outcome, flat != nil, "a myNotes topic must flatten, not return nil");
	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"myNotes"],
			"savedMessagesTopicTypeMyNotes must classify as kind \"myNotes\"");
	TGTestExpectTrue(&outcome, [flat[@"title"] isEqualToString:@"My Notes"],
			"a myNotes topic's title must be the fixed \"My Notes\" label");
	TGTestExpectEqualLongLong(&outcome, [flat[@"chatId"] longLongValue], 0,
			"a myNotes topic has no origin chat, so chatId must be 0");
	TGTestExpectTrue(&outcome, [flat[@"draft"] isEqualToString:@""],
			"with no draft_message present, draft must be an empty string");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestFlattenTopicClassifiesMyNotesWithDraft(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *topic = TGFlattenSavedMessagesTopicOfType(@"savedMessagesTopicTypeMyNotes", nil, YES);
	NSDictionary *flat = TGSavedFlattenTopic(topic, nil);

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"myNotes"],
			"a myNotes topic with a draft present must still classify as kind \"myNotes\"");
	TGTestExpectTrue(&outcome, [flat[@"draft"] isEqualToString:@"hello draft"],
			"a present draft_message's text must be extracted into draft");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestFlattenTopicClassifiesAuthorHiddenWithoutDraft(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *topic = TGFlattenSavedMessagesTopicOfType(@"savedMessagesTopicTypeAuthorHidden", nil, NO);
	NSDictionary *flat = TGSavedFlattenTopic(topic, nil);

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"authorHidden"],
			"savedMessagesTopicTypeAuthorHidden must classify as kind \"authorHidden\"");
	TGTestExpectTrue(&outcome, [flat[@"title"] isEqualToString:@"Author Hidden"],
			"an authorHidden topic's title must be the fixed \"Author Hidden\" label");
	TGTestExpectEqualLongLong(&outcome, [flat[@"chatId"] longLongValue], 0,
			"an authorHidden topic has no origin chat, so chatId must be 0");
	TGTestExpectTrue(&outcome, [flat[@"draft"] isEqualToString:@""],
			"with no draft_message present, draft must be an empty string");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestFlattenTopicClassifiesAuthorHiddenWithDraft(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *topic = TGFlattenSavedMessagesTopicOfType(@"savedMessagesTopicTypeAuthorHidden", nil, YES);
	NSDictionary *flat = TGSavedFlattenTopic(topic, nil);

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"authorHidden"],
			"an authorHidden topic with a draft present must still classify as kind \"authorHidden\"");
	TGTestExpectTrue(&outcome, [flat[@"draft"] isEqualToString:@"hello draft"],
			"a present draft_message's text must be extracted into draft");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestFlattenTopicClassifiesFromChatWithoutDraft(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *topic = TGFlattenSavedMessagesTopicOfType(@"savedMessagesTopicTypeSavedMessagesChat",
			@{@"chat_id" : @777}, NO);
	NSDictionary *flat = TGSavedFlattenTopic(topic, ^NSString *(int64_t chatId) {
		return chatId == 777 ? @"Alice" : nil;
	});

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"fromChat"],
			"any type name other than myNotes/authorHidden must classify as kind \"fromChat\"");
	TGTestExpectEqualLongLong(&outcome, [flat[@"chatId"] longLongValue], 777,
			"a fromChat topic's chatId must come from type.chat_id");
	TGTestExpectTrue(&outcome, [flat[@"title"] isEqualToString:@"Alice"],
			"a fromChat topic's title must come from the resolveChatName callback when it returns a name");
	TGTestExpectTrue(&outcome, [flat[@"draft"] isEqualToString:@""],
			"with no draft_message present, draft must be an empty string");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestFlattenTopicClassifiesFromChatWithDraft(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *topic = TGFlattenSavedMessagesTopicOfType(@"savedMessagesTopicTypeSavedMessagesChat",
			@{@"chat_id" : @777}, YES);
	NSDictionary *flat = TGSavedFlattenTopic(topic, ^NSString *(int64_t chatId) {
		return chatId == 777 ? @"Alice" : nil;
	});

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"fromChat"],
			"a fromChat topic with a draft present must still classify as kind \"fromChat\"");
	TGTestExpectTrue(&outcome, [flat[@"draft"] isEqualToString:@"hello draft"],
			"a present draft_message's text must be extracted into draft");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestPreviewForPhoto(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSavedPreview(TGFlattenSavedMessagesMessageOfType(@"messagePhoto")) isEqualToString:@"Photo"],
			"messagePhoto with no caption must preview as \"Photo\"");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestPreviewForVideo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSavedPreview(TGFlattenSavedMessagesMessageOfType(@"messageVideo")) isEqualToString:@"Video"],
			"messageVideo with no caption must preview as \"Video\"");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestPreviewForVideoNote(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSavedPreview(TGFlattenSavedMessagesMessageOfType(@"messageVideoNote"))
					isEqualToString:@"Video Message"],
			"messageVideoNote must preview as \"Video Message\"");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestPreviewForVoiceNote(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSavedPreview(TGFlattenSavedMessagesMessageOfType(@"messageVoiceNote"))
					isEqualToString:@"Voice message"],
			"messageVoiceNote must preview as \"Voice message\"");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestPreviewForAudio(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSavedPreview(TGFlattenSavedMessagesMessageOfType(@"messageAudio")) isEqualToString:@"Audio"],
			"messageAudio must preview as \"Audio\"");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestPreviewForDocument(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSavedPreview(TGFlattenSavedMessagesMessageOfType(@"messageDocument"))
					isEqualToString:@"File"],
			"messageDocument must preview as \"File\"");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestPreviewForSticker(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSavedPreview(TGFlattenSavedMessagesMessageOfType(@"messageSticker"))
					isEqualToString:@"Sticker"],
			"messageSticker must preview as \"Sticker\"");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestPreviewForAnimation(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSavedPreview(TGFlattenSavedMessagesMessageOfType(@"messageAnimation")) isEqualToString:@"GIF"],
			"messageAnimation must preview as \"GIF\"");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestPreviewForLocation(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSavedPreview(TGFlattenSavedMessagesMessageOfType(@"messageLocation"))
					isEqualToString:@"Location"],
			"messageLocation must preview as \"Location\"");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestPreviewForVenue(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSavedPreview(TGFlattenSavedMessagesMessageOfType(@"messageVenue")) isEqualToString:@"Location"],
			"messageVenue must preview as \"Location\", the same as messageLocation");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestPreviewForContact(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSavedPreview(TGFlattenSavedMessagesMessageOfType(@"messageContact"))
					isEqualToString:@"Contact"],
			"messageContact must preview as \"Contact\"");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestPreviewForPoll(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSavedPreview(TGFlattenSavedMessagesMessageOfType(@"messagePoll")) isEqualToString:@"Poll"],
			"messagePoll must preview as \"Poll\"");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestPreviewFallsBackForUnknownKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGSavedPreview(TGFlattenSavedMessagesMessageOfType(@"messageSomeFutureKind"))
					isEqualToString:@""],
			"an unrecognised content kind must preview as empty, not crash or fabricate text");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestMessageTagsForRealisticPayload(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"interaction_info" : @{
			@"reactions" : @{
				@"reactions" : @[
					@{@"type" : @{@"emoji" : @"\U0001F44D"}},
					@{@"type" : @{@"emoji" : @"❤"}},
				],
			},
		},
	};

	NSArray *tags = TGSavedMessageTags(message);

	TGTestExpectEqualInteger(&outcome, (NSInteger)tags.count, 2,
			"a realistic reactions payload must yield one tag per reaction");
	TGTestExpectTrue(&outcome, [tags[0] isEqualToString:@"\U0001F44D"],
			"the first tag must be the first reaction's emoji, in order");
	TGTestExpectTrue(&outcome, [tags[1] isEqualToString:@"❤"],
			"the second tag must be the second reaction's emoji, in order");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestMessageTagsForEmptyPayload(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *tags = TGSavedMessageTags(@{});

	TGTestExpectTrue(&outcome, tags != nil,
			"a message with no interaction_info must yield an array, not nil");
	TGTestExpectEqualInteger(&outcome, (NSInteger)tags.count, 0,
			"a message with no interaction_info must yield zero tags");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestMessageTagsForCustomEmojiReactions(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *boxed = @{
		@"interaction_info" : @{
			@"reactions" : @{
				@"reactions" : @[
					@{@"type" : @{@"@type" : @"reactionTypeCustomEmoji",
						@"custom_emoji_id" : @5350305076663608320LL}},
				],
			},
		},
	};
	NSDictionary *stringed = @{
		@"interaction_info" : @{
			@"reactions" : @{
				@"reactions" : @[
					@{@"type" : @{@"@type" : @"reactionTypeCustomEmoji",
						@"custom_emoji_id" : @"5350305076663608320"}},
				],
			},
		},
	};

	NSArray *boxedTags = TGSavedMessageTags(boxed);
	NSArray *stringedTags = TGSavedMessageTags(stringed);

	TGTestExpectEqualInteger(&outcome, (NSInteger)boxedTags.count, 1,
			"a custom-emoji reaction must produce a tag");
	TGTestExpectTrue(&outcome, [boxedTags[0] isEqualToString:@"custom:5350305076663608320"],
			"the tag key is the custom emoji's own id, so two different custom emoji cannot collide");
	TGTestExpectEqualInteger(&outcome, (NSInteger)stringedTags.count, 1,
			"custom_emoji_id is an int64 in the schema, and this bridge hands int64 fields over as strings: "
			"accepting only NSNumber silently dropped every custom-emoji tag");
	TGTestExpectTrue(&outcome, [stringedTags[0] isEqualToString:@"custom:5350305076663608320"],
			"a string-typed id must produce the same tag as a boxed one, or the tag list changes shape with "
			"the bridge's whim");

	NSDictionary *malformed = @{
		@"interaction_info" : @{
			@"reactions" : @{
				@"reactions" : @[
					@{@"type" : @{@"@type" : @"reactionTypeCustomEmoji"}},
					@"not a reaction",
				],
			},
		},
	};
	TGTestExpectEqualInteger(&outcome, (NSInteger)TGSavedMessageTags(malformed).count, 0,
			"a custom-emoji reaction with no id, and a non-dictionary entry, must both be skipped");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestTagCustomEmojiIdAcceptsBothWireShapes(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *asString = @{@"@type" : @"reactionTypeCustomEmoji",
		@"custom_emoji_id" : @"5382170238528226457"};
	TGTestExpectTrue(&outcome,
			[TGSavedTagCustomEmojiId(asString) longLongValue] == 5382170238528226457LL,
			"custom_emoji_id is int64, so it arrives as a string and must still read");

	NSDictionary *asNumber = @{@"@type" : @"reactionTypeCustomEmoji", @"custom_emoji_id" : @123};
	TGTestExpectTrue(&outcome, [TGSavedTagCustomEmojiId(asNumber) longLongValue] == 123,
			"a numeric custom_emoji_id reads too");

	TGTestExpectTrue(&outcome,
			TGSavedTagCustomEmojiId(@{@"@type" : @"reactionTypeEmoji", @"emoji" : @"\U0001F44D"}) == nil,
			"a plain emoji reaction has no custom emoji id");
	TGTestExpectTrue(&outcome,
			TGSavedTagCustomEmojiId(@{@"@type" : @"reactionTypeCustomEmoji"}) == nil,
			"a custom emoji reaction with no id has none");
	TGTestExpectTrue(&outcome,
			TGSavedTagCustomEmojiId(@{@"@type" : @"reactionTypeCustomEmoji", @"custom_emoji_id" : @"0"}) == nil,
			"a zero id is no id, so a tag strip never keys a row on it");
	TGTestExpectTrue(&outcome, TGSavedTagCustomEmojiId(nil) == nil,
			"a nil tag must not crash the tag strip");
	TGTestExpectTrue(&outcome, TGSavedTagCustomEmojiId((NSDictionary *)@"x") == nil,
			"a non-dictionary off the wire must not be subscripted");

	return outcome;
}

TGTestOutcome TGFlattenSavedMessagesTestTopicRowsNameEveryKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *call = @{@"content" : @{@"@type" : @"messageCall",
		@"is_video" : @NO,
		@"discard_reason" : @{@"@type" : @"callDiscardReasonHungUp"}}};
	TGTestExpectTrue(&outcome, [TGSavedPreview(call) isEqualToString:@"Incoming Call"],
			"a saved call names itself, where the topic row used to be blank");

	NSDictionary *expired = @{@"content" : @{@"@type" : @"messageExpiredPhoto"}};
	TGTestExpectTrue(&outcome,
			[TGSavedPreview(expired) isEqualToString:@"Photo has expired"],
			"an expired photo says so");

	NSDictionary *secret = @{@"content" : @{@"@type" : @"messagePhoto", @"is_secret" : @YES,
		@"caption" : @{@"text" : @"the words meant to be seen once"}}};
	TGTestExpectTrue(&outcome,
			[TGSavedPreview(secret) isEqualToString:@"Disappearing Photo"],
			"a disappearing photo names itself rather than lending its caption to the row");

	NSDictionary *unknown = @{@"content" : @{@"@type" : @"messageSomethingTelegramAddedLater"}};
	TGTestExpectTrue(&outcome, [TGSavedPreview(unknown) isEqualToString:@""],
			"a kind this build has never heard of leaves the row empty rather than inventing "
			"a name");

	return outcome;
}

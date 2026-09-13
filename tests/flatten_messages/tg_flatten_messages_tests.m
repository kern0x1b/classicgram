#import "tg_flatten_messages_tests.h"
#import "../../src/Wire/Flatten/TGFlattenMessages.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenMessagesTestBriefMapsSentStateWithTextFallback(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"id" : @1001,
		@"date" : @1700000000,
		@"is_outgoing" : @YES,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @42},
		@"content" : @{@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"Hello there"}},
	};

	NSDictionary *flat = TGMsgBrief(message);

	TGTestExpectTrue(&outcome, flat != nil,
			"a well-formed message must flatten to a dictionary, not nil");
	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@"Hello there"],
			"text must be read from content.text.text when it is present");
	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"messageText"],
			"kind must be the raw content type");
	TGTestExpectEqualLongLong(&outcome, [flat[@"id"] longLongValue], 1001,
			"id must round-trip verbatim");
	TGTestExpectEqualLongLong(&outcome, [flat[@"senderId"] longLongValue], 42,
			"senderId must come from sender_id.user_id");
	TGTestExpectEqualLongLong(&outcome, [flat[@"senderChatId"] longLongValue], 0,
			"a messageSenderUser must flatten to a zero senderChatId");
	TGTestExpectTrue(&outcome, [flat[@"sendingState"] isEqualToString:@"sent"],
			"a message with no sending_state must default to the sent status");
	TGTestExpectTrue(&outcome, [flat[@"canRetry"] boolValue] == NO,
			"a sent message must never report canRetry");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestBriefMapsPendingState(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"id" : @2,
		@"content" : @{@"@type" : @"messageText"},
		@"sending_state" : @{@"@type" : @"messageSendingStatePending"},
	};

	NSDictionary *flat = TGMsgBrief(message);

	TGTestExpectTrue(&outcome, [flat[@"sendingState"] isEqualToString:@"pending"],
			"messageSendingStatePending must map to the pending status");
	TGTestExpectTrue(&outcome, [flat[@"canRetry"] boolValue] == NO,
			"a pending message must never report canRetry, even if can_retry were set");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestBriefMapsFailedStateWithCanRetryTrueAndFalse(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *retryable = @{
		@"id" : @3,
		@"content" : @{@"@type" : @"messageText"},
		@"sending_state" : @{@"@type" : @"messageSendingStateFailed", @"can_retry" : @YES},
	};
	NSDictionary *notRetryable = @{
		@"id" : @4,
		@"content" : @{@"@type" : @"messageText"},
		@"sending_state" : @{@"@type" : @"messageSendingStateFailed", @"can_retry" : @NO},
	};

	NSDictionary *flatRetryable = TGMsgBrief(retryable);
	NSDictionary *flatNotRetryable = TGMsgBrief(notRetryable);

	TGTestExpectTrue(&outcome, [flatRetryable[@"sendingState"] isEqualToString:@"failed"],
			"messageSendingStateFailed must map to the failed status");
	TGTestExpectTrue(&outcome, [flatRetryable[@"canRetry"] boolValue] == YES,
			"a failed message with can_retry true must report canRetry true");
	TGTestExpectTrue(&outcome, [flatNotRetryable[@"sendingState"] isEqualToString:@"failed"],
			"messageSendingStateFailed must map to the failed status regardless of can_retry");
	TGTestExpectTrue(&outcome, [flatNotRetryable[@"canRetry"] boolValue] == NO,
			"a failed message with can_retry false must report canRetry false");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestBriefFallsBackToCaptionWhenNoText(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *withCaption = @{
		@"id" : @5,
		@"content" : @{@"@type" : @"messagePhoto",
			@"caption" : @{@"@type" : @"formattedText", @"text" : @"A caption"}},
	};
	NSDictionary *withNeither = @{
		@"id" : @6,
		@"content" : @{@"@type" : @"messageSticker"},
	};

	NSDictionary *flatWithCaption = TGMsgBrief(withCaption);
	NSDictionary *flatWithNeither = TGMsgBrief(withNeither);

	TGTestExpectTrue(&outcome, [flatWithCaption[@"text"] isEqualToString:@"A caption"],
			"when content.text is absent, text must fall back to content.caption.text");
	TGTestExpectTrue(&outcome, [flatWithNeither[@"text"] isEqualToString:@""],
			"when neither content.text nor content.caption is present, text must be empty, not nil");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestBriefMapsChatSenderIdentity(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"id" : @1002,
		@"date" : @1700000002,
		@"is_outgoing" : @NO,
		@"sender_id" : @{@"@type" : @"messageSenderChat", @"chat_id" : @3003},
		@"content" : @{@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"sent as a channel identity"}},
	};

	NSDictionary *flat = TGMsgBrief(message);

	TGTestExpectEqualLongLong(&outcome, [flat[@"senderId"] longLongValue], 0,
			"a messageSenderChat must not collapse into a fake user id of the chat_id");
	TGTestExpectEqualLongLong(&outcome, [flat[@"senderChatId"] longLongValue], 3003,
			"a messageSenderChat must flatten its chat_id into senderChatId so the identity is not lost");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestBriefExposesRequiredPaidMessageStarCountFromFailedState(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *underpriced = @{
		@"id" : @9,
		@"content" : @{@"@type" : @"messageText"},
		@"sending_state" : @{@"@type" : @"messageSendingStateFailed",
			@"error" : @{@"code" : @400, @"message" : @"ALLOW_PAYMENT_REQUIRED_142"},
			@"required_paid_message_star_count" : @142},
	};
	NSDictionary *sent = @{
		@"id" : @10,
		@"content" : @{@"@type" : @"messageText"},
	};

	NSDictionary *flatUnderpriced = TGMsgBrief(underpriced);
	NSDictionary *flatSent = TGMsgBrief(sent);

	TGTestExpectEqualLongLong(&outcome, [flatUnderpriced[@"requiredPaidMessageStarCount"] longLongValue], 142,
			"a failed message must surface the exact star count TDLib parsed from ALLOW_PAYMENT_REQUIRED_");
	TGTestExpectEqualLongLong(&outcome, [flatSent[@"requiredPaidMessageStarCount"] longLongValue], 0,
			"a message with no sending_state must report a zero required paid star count");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestBriefReturnsNilForNonDictionaryInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGMsgBrief(nil) == nil,
			"a nil message must flatten to nil, not crash");
	TGTestExpectTrue(&outcome, TGMsgBrief((NSDictionary *)@"not a dictionary") == nil,
			"a non-dictionary message must flatten to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestLooksLikeMp3DetectsByMimeType(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGMsgLooksLikeMp3(@"audio/mpeg", @"track.ogg") == YES,
			"audio/mpeg must be recognised as mp3 regardless of file name");
	TGTestExpectTrue(&outcome, TGMsgLooksLikeMp3(@"audio/mp3", @"") == YES,
			"audio/mp3 must be recognised as mp3 even with an empty file name");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestLooksLikeMp3DetectsByFileExtension(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			TGMsgLooksLikeMp3(@"application/octet-stream", @"song.mp3") == YES,
			"a .mp3 file name must be recognised even with a generic mime type");
	TGTestExpectTrue(&outcome, TGMsgLooksLikeMp3(@"application/octet-stream", @"Song.MP3") == YES,
			"the file extension check must be case-insensitive");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestLooksLikeMp3RejectsOtherFormats(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGMsgLooksLikeMp3(@"audio/ogg", @"voice.ogg") == NO,
			"an ogg mime type with an ogg file name must not be recognised as mp3");
	TGTestExpectTrue(&outcome, TGMsgLooksLikeMp3(@"", @"") == NO,
			"an empty mime type and file name must not be recognised as mp3");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestSendOptionsBranchesForScheduledDate(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *out = TGMsgSendOptions(@{@"sendDate" : @1700000000, @"whenOnline" : @YES});
	NSDictionary *schedulingState = out[@"scheduling_state"];

	TGTestExpectTrue(&outcome,
			[schedulingState[@"@type"] isEqualToString:@"messageSchedulingStateSendAtDate"],
			"a positive sendDate must take priority and produce a SendAtDate scheduling state");
	TGTestExpectEqualInteger(&outcome, [schedulingState[@"send_date"] integerValue], 1700000000,
			"the scheduling state's send_date must round-trip from sendDate");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestSendOptionsBranchesForWhenOnline(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *out = TGMsgSendOptions(@{@"whenOnline" : @YES});
	NSDictionary *schedulingState = out[@"scheduling_state"];

	TGTestExpectTrue(&outcome,
			[schedulingState[@"@type"] isEqualToString:@"messageSchedulingStateSendWhenOnline"],
			"whenOnline without a sendDate must produce a SendWhenOnline scheduling state");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestSendOptionsBranchesForNeither(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *out = TGMsgSendOptions(@{@"silent" : @YES, @"protect" : @YES});

	TGTestExpectTrue(&outcome, out[@"scheduling_state"] == nil,
			"neither a sendDate nor whenOnline must leave scheduling_state absent");
	TGTestExpectTrue(&outcome, [out[@"disable_notification"] boolValue] == YES,
			"disable_notification must come from options.silent");
	TGTestExpectTrue(&outcome, [out[@"protect_content"] boolValue] == YES,
			"protect_content must come from options.protect");
	TGTestExpectTrue(&outcome, [out[@"from_background"] boolValue] == NO,
			"from_background must always be false");
	TGTestExpectTrue(&outcome, out[@"effect_id"] == nil,
			"effect_id must be absent when no effectId was supplied");

	NSDictionary *withEffect = TGMsgSendOptions(@{@"effectId" : @123456});
	TGTestExpectEqualLongLong(&outcome, [withEffect[@"effect_id"] longLongValue], 123456,
			"effect_id must round-trip from a non-zero effectId");

	NSDictionary *nilOptions = TGMsgSendOptions(nil);
	TGTestExpectTrue(&outcome, nilOptions[@"scheduling_state"] == nil,
			"nil options must not crash and must leave scheduling_state absent");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestSendOptionsIncludesPaidStarCountWhenPositive(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *withoutStars = TGMsgSendOptions(@{@"silent" : @YES});
	TGTestExpectTrue(&outcome, withoutStars[@"paid_message_star_count"] == nil,
			"paid_message_star_count must be absent when no paidStarCount was supplied");

	NSDictionary *withZeroStars = TGMsgSendOptions(@{@"paidStarCount" : @0});
	TGTestExpectTrue(&outcome, withZeroStars[@"paid_message_star_count"] == nil,
			"a zero paidStarCount must not add paid_message_star_count to the request");

	NSDictionary *withStars = TGMsgSendOptions(@{@"paidStarCount" : @5});
	TGTestExpectEqualLongLong(&outcome, [withStars[@"paid_message_star_count"] longLongValue], 5,
			"a positive paidStarCount must round-trip into paid_message_star_count");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestSendOptionsMultipliesPaidStarCountByMessageCount(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *singleMessage = TGMsgSendOptions(@{@"paidStarCount" : @5});
	TGTestExpectEqualLongLong(&outcome, [singleMessage[@"paid_message_star_count"] longLongValue], 5,
			"with no paidStarMessageCount supplied, a single message must be assumed");

	NSDictionary *album = TGMsgSendOptions(@{@"paidStarCount" : @5, @"paidStarMessageCount" : @3});
	TGTestExpectEqualLongLong(&outcome, [album[@"paid_message_star_count"] longLongValue], 15,
			"an album of 3 paid messages must total the per-message price times the message count");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestCanReactToTrueWhenReactionsAvailable(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *reactions = @{
		@"@type" : @"availableReactions",
		@"top_reactions" : @[ @{@"@type" : @"availableReaction"} ],
		@"recent_reactions" : @[],
		@"popular_reactions" : @[],
	};

	TGTestExpectTrue(&outcome, TGMsgCanReactTo(reactions) == YES,
			"a non-empty top_reactions list must allow reacting");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestCanReactToFalseWhenUnavailable(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *errorResult = @{@"@type" : @"error", @"code" : @400};
	NSDictionary *restricted = @{
		@"@type" : @"availableReactions",
		@"unavailability_reason" : @{@"@type" : @"chatReactionsAllowedReactionsRestricted"},
		@"top_reactions" : @[ @{@"@type" : @"availableReaction"} ],
	};
	NSDictionary *empty = @{
		@"@type" : @"availableReactions",
		@"top_reactions" : @[],
		@"recent_reactions" : @[],
		@"popular_reactions" : @[],
	};

	TGTestExpectTrue(&outcome, TGMsgCanReactTo(errorResult) == NO,
			"an error result must never allow reacting");
	TGTestExpectTrue(&outcome, TGMsgCanReactTo(restricted) == NO,
			"a present unavailability_reason must forbid reacting even with reactions listed");
	TGTestExpectTrue(&outcome, TGMsgCanReactTo(empty) == NO,
			"all-empty reaction lists must forbid reacting");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestQuickReplyContentLabelForEachKnownKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGQuickReplyContentLabel(@"messagePhoto") isEqualToString:@"Photo"],
			"messagePhoto must label as Photo");
	TGTestExpectTrue(&outcome, [TGQuickReplyContentLabel(@"messageVideo") isEqualToString:@"Video"],
			"messageVideo must label as Video");
	TGTestExpectTrue(&outcome,
			[TGQuickReplyContentLabel(@"messageAnimation") isEqualToString:@"GIF"],
			"messageAnimation must label as GIF");
	TGTestExpectTrue(&outcome,
			[TGQuickReplyContentLabel(@"messageSticker") isEqualToString:@"Sticker"],
			"messageSticker must label as Sticker");
	TGTestExpectTrue(&outcome,
			[TGQuickReplyContentLabel(@"messageVoiceNote") isEqualToString:@"Voice message"],
			"messageVoiceNote must label as Voice message");
	TGTestExpectTrue(&outcome,
			[TGQuickReplyContentLabel(@"messageVideoNote") isEqualToString:@"Video Message"],
			"messageVideoNote must label as Video Message");
	TGTestExpectTrue(&outcome,
			[TGQuickReplyContentLabel(@"messageDocument") isEqualToString:@"File"],
			"messageDocument must label as File");
	TGTestExpectTrue(&outcome, [TGQuickReplyContentLabel(@"messageAudio") isEqualToString:@"Audio"],
			"messageAudio must label as Audio");
	TGTestExpectTrue(&outcome,
			[TGQuickReplyContentLabel(@"messageContact") isEqualToString:@"Contact"],
			"messageContact must label as Contact");
	TGTestExpectTrue(&outcome, [TGQuickReplyContentLabel(@"messagePoll") isEqualToString:@"Poll"],
			"messagePoll must label as Poll");
	TGTestExpectTrue(&outcome,
			[TGQuickReplyContentLabel(@"messageLocation") isEqualToString:@"Location"],
			"messageLocation must label as Location");
	TGTestExpectTrue(&outcome,
			[TGQuickReplyContentLabel(@"messageRichMessage") isEqualToString:@"Article"],
			"messageRichMessage must label as Article");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestQuickReplyContentLabelFallsBackForUnknownKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGQuickReplyContentLabel(@"messageDice") isEqualToString:@"Unsupported Message"],
			"an unrecognised but named content kind must fall back to the generic Unsupported Message label");
	TGTestExpectTrue(&outcome, [TGQuickReplyContentLabel(@"") isEqualToString:@""],
			"an empty content kind must flatten to an empty label, not a generic fallback");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestQuickReplyShortcutFromUpdateComposesPreviewFromText(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *shortcut = @{
		@"id" : @7,
		@"name" : @"greeting",
		@"message_count" : @3,
		@"first_message" : @{
			@"content" : @{@"@type" : @"messageText",
				@"text" : @{@"@type" : @"formattedText", @"text" : @"Hi there"}},
		},
	};

	NSDictionary *flat = TGQuickReplyShortcutFromUpdate(shortcut);

	TGTestExpectTrue(&outcome, [flat[@"id"] isEqual:@7],
			"the shortcut id must round-trip verbatim");
	TGTestExpectTrue(&outcome, [flat[@"name"] isEqualToString:@"greeting"],
			"the shortcut name must round-trip verbatim");
	TGTestExpectEqualInteger(&outcome, [flat[@"messageCount"] integerValue], 3,
			"the shortcut messageCount must round-trip verbatim");
	TGTestExpectTrue(&outcome, [flat[@"preview"] isEqualToString:@"Hi there"],
			"the preview must be the first message's text when it has one");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestQuickReplyShortcutFromUpdateComposesPreviewFromContentLabel(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *shortcut = @{
		@"id" : @8,
		@"name" : @"a-photo",
		@"message_count" : @1,
		@"first_message" : @{
			@"content" : @{@"@type" : @"messagePhoto"},
		},
	};

	NSDictionary *flat = TGQuickReplyShortcutFromUpdate(shortcut);

	TGTestExpectTrue(&outcome, [flat[@"preview"] isEqualToString:@"Photo"],
			"when the first message has no text, the preview must fall back to its content label");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestQuickReplyShortcutFromUpdateReturnsNilForInvalidInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGQuickReplyShortcutFromUpdate(nil) == nil,
			"a nil shortcut update must flatten to nil, not crash");
	TGTestExpectTrue(&outcome, TGQuickReplyShortcutFromUpdate((NSDictionary *)@"nope") == nil,
			"a non-dictionary shortcut update must flatten to nil, not crash");
	TGTestExpectTrue(&outcome, TGQuickReplyShortcutFromUpdate(@{@"name" : @"noId"}) == nil,
			"a shortcut update missing a numeric id must flatten to nil");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestCustomEmojiRunsValidRange(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *text = @"Hello";
	NSArray *entities = @[
		@{@"type" : @{@"@type" : @"textEntityTypeBold"}, @"offset" : @0, @"length" : @2},
		@{@"type" : @{@"@type" : @"textEntityTypeCustomEmoji", @"custom_emoji_id" : @777},
			@"offset" : @1, @"length" : @2},
		@"not a dictionary",
		@{@"type" : @{@"@type" : @"textEntityTypeCustomEmoji", @"custom_emoji_id" : @0},
			@"offset" : @0, @"length" : @1},
	];

	NSArray *runs = TGCustomEmojiRunsFromEntities(entities, text);

	TGTestExpectEqualInteger(&outcome, runs.count, 1,
			"only the well-formed custom emoji entity must produce a run");
	NSDictionary *run = runs.firstObject;
	TGTestExpectTrue(&outcome, [run[@"glyph"] isEqualToString:@"el"],
			"the run's glyph must be the substring covered by its range");
	TGTestExpectEqualLongLong(&outcome, [run[@"customEmojiId"] longLongValue], 777,
			"the run's customEmojiId must round-trip from the entity");
	TGTestExpectTrue(&outcome, NSEqualRanges([run[@"range"] rangeValue], NSMakeRange(1, 2)),
			"the run's range must match the entity's offset and length");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestCustomEmojiRunsOutOfBoundsRange(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *text = @"Hello";
	NSArray *entities = @[
		@{@"type" : @{@"@type" : @"textEntityTypeCustomEmoji", @"custom_emoji_id" : @1},
			@"offset" : @4, @"length" : @5},
	];

	NSArray *runs = TGCustomEmojiRunsFromEntities(entities, text);

	TGTestExpectEqualInteger(&outcome, runs.count, 0,
			"a range whose end exceeds the text length must be rejected, not clamped");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestCustomEmojiRunsAtTextLengthBoundary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *text = @"Hello";
	NSArray *entities = @[
		@{@"type" : @{@"@type" : @"textEntityTypeCustomEmoji", @"custom_emoji_id" : @42},
			@"offset" : @3, @"length" : @2},
	];

	NSArray *runs = TGCustomEmojiRunsFromEntities(entities, text);

	TGTestExpectEqualInteger(&outcome, runs.count, 1,
			"a range whose end lands exactly on the text length must be accepted");
	TGTestExpectTrue(&outcome, [runs.firstObject[@"glyph"] isEqualToString:@"lo"],
			"the boundary run's glyph must be the trailing substring it covers");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestMentionNameRunsValidRange(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *text = @"Hi John, welcome";
	NSArray *entities = @[
		@{@"type" : @{@"@type" : @"textEntityTypeBold"}, @"offset" : @0, @"length" : @2},
		@{@"type" : @{@"@type" : @"textEntityTypeMentionName", @"user_id" : @555},
			@"offset" : @3, @"length" : @4},
		@"not a dictionary",
		@{@"type" : @{@"@type" : @"textEntityTypeMentionName", @"user_id" : @0},
			@"offset" : @0, @"length" : @1},
	];

	NSArray *runs = TGMentionNameRunsFromEntities(entities, text);

	TGTestExpectEqualInteger(&outcome, runs.count, 1,
			"only the well-formed mention name entity must produce a run");
	NSDictionary *run = runs.firstObject;
	TGTestExpectTrue(&outcome, [run[@"text"] isEqualToString:@"John"],
			"the run's text must be the substring covered by its range");
	TGTestExpectEqualLongLong(&outcome, [run[@"userId"] longLongValue], 555,
			"the run's userId must round-trip from the entity");
	TGTestExpectTrue(&outcome, NSEqualRanges([run[@"range"] rangeValue], NSMakeRange(3, 4)),
			"the run's range must match the entity's offset and length");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestMentionNameRunsOutOfBoundsRange(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *text = @"Hi John";
	NSArray *entities = @[
		@{@"type" : @{@"@type" : @"textEntityTypeMentionName", @"user_id" : @1},
			@"offset" : @5, @"length" : @9},
	];

	NSArray *runs = TGMentionNameRunsFromEntities(entities, text);

	TGTestExpectEqualInteger(&outcome, runs.count, 0,
			"a range whose end exceeds the text length must be rejected, not clamped");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestMentionNameRunsAtTextLengthBoundary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *text = @"Hi John";
	NSArray *entities = @[
		@{@"type" : @{@"@type" : @"textEntityTypeMentionName", @"user_id" : @42},
			@"offset" : @3, @"length" : @4},
	];

	NSArray *runs = TGMentionNameRunsFromEntities(entities, text);

	TGTestExpectEqualInteger(&outcome, runs.count, 1,
			"a range whose end lands exactly on the text length must be accepted");
	TGTestExpectTrue(&outcome, [runs.firstObject[@"text"] isEqualToString:@"John"],
			"the boundary run's text must be the trailing substring it covers");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestSendFailureMessageReturnsNilForNonFailedOrMissingState(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGSendFailureMessage(nil, NO) == nil,
			"a nil sending state must not be reported as a failure");
	TGTestExpectTrue(&outcome,
			TGSendFailureMessage(@{@"@type" : @"messageSendingStatePending"}, NO) == nil,
			"a pending sending state must not be reported as a failure");
	TGTestExpectTrue(&outcome, TGSendFailureMessage((id)@"not a dictionary", NO) == nil,
			"a sending state of the wrong type must not crash and must report no failure");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestSendFailureMessageParsesSlowmodeWaitPrefix(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *state = @{
		@"@type" : @"messageSendingStateFailed",
		@"error" : @{@"code" : @420, @"message" : @"SLOWMODE_WAIT_45"},
		@"retry_after" : @45.0,
	};

	NSString *message = TGSendFailureMessage(state, NO);

	TGTestExpectTrue(&outcome, message.length > 0,
			"a SLOWMODE_WAIT_ error must produce a non-empty message");
	TGTestExpectTrue(&outcome, [message rangeOfString:@"45"].location != NSNotFound,
			"the slow mode wait time parsed from the error message must appear in the surfaced text");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestSendFailureMessageFallsBackToRetryAfterWhenNoSlowmodePrefix(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *state = @{
		@"@type" : @"messageSendingStateFailed",
		@"error" : @{@"code" : @420, @"message" : @"FLOOD_WAIT_20"},
		@"retry_after" : @20.0,
	};

	NSString *message = TGSendFailureMessage(state, NO);

	TGTestExpectTrue(&outcome, message.length > 0,
			"a non-slow-mode failure with a positive retry_after must still produce a non-empty message");
	TGTestExpectTrue(&outcome, [message rangeOfString:@"20"].location != NSNotFound,
			"the retry_after value must appear in the surfaced text");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestSendFailureMessageDisambiguatesSlowModeFromFloodWaitWhenSlowModeIsActive(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *state = @{
		@"@type" : @"messageSendingStateFailed",
		@"error" : @{@"code" : @429, @"message" : @"Too Many Requests: retry after 300"},
		@"retry_after" : @300.0,
	};

	NSString *slowModeMessage = TGSendFailureMessage(state, YES);
	NSString *floodWaitMessage = TGSendFailureMessage(state, NO);

	TGTestExpectTrue(&outcome, slowModeMessage.length > 0 && floodWaitMessage.length > 0,
			"both the slow-mode and flood-wait readings of the same failed state must produce text");
	TGTestExpectTrue(&outcome, ![slowModeMessage isEqualToString:floodWaitMessage],
			"a chat known to have slow mode active must read differently from a plain personal flood wait");
	TGTestExpectTrue(&outcome, [slowModeMessage rangeOfString:@"5"].location != NSNotFound,
			"300 seconds must be rounded into minutes, not left as a raw second count");
	TGTestExpectTrue(&outcome, [floodWaitMessage rangeOfString:@"5"].location != NSNotFound,
			"the flood-wait reading must also format 300 seconds as minutes");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestSendFailureMessageFormatsLongWaitsAsMinutesAndHours(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *minuteState = @{
		@"@type" : @"messageSendingStateFailed",
		@"error" : @{@"code" : @420, @"message" : @"SLOWMODE_WAIT_90"},
		@"retry_after" : @90.0,
	};
	NSString *minuteMessage = TGSendFailureMessage(minuteState, NO);
	TGTestExpectTrue(&outcome, [minuteMessage rangeOfString:@"90"].location == NSNotFound,
			"90 raw seconds must not be shown as a bare second count once minute formatting applies");
	TGTestExpectTrue(&outcome, [minuteMessage rangeOfString:@"2"].location != NSNotFound,
			"90 seconds must round up to 2 minutes");

	NSDictionary *hourState = @{
		@"@type" : @"messageSendingStateFailed",
		@"error" : @{@"code" : @420, @"message" : @"SLOWMODE_WAIT_3600"},
		@"retry_after" : @3600.0,
	};
	NSString *hourMessage = TGSendFailureMessage(hourState, NO);
	TGTestExpectTrue(&outcome, [hourMessage rangeOfString:@"3600"].location == NSNotFound,
			"3600 raw seconds must not be shown as a bare second count once hour formatting applies");
	TGTestExpectTrue(&outcome, [hourMessage rangeOfString:@"1"].location != NSNotFound,
			"3600 seconds must format as 1 hour");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestSendFailureMessageTranslatesRequiredPaidMessageStarCount(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *state = @{
		@"@type" : @"messageSendingStateFailed",
		@"error" : @{@"code" : @400, @"message" : @"ALLOW_PAYMENT_REQUIRED_142"},
		@"required_paid_message_star_count" : @142,
		@"retry_after" : @0.0,
	};

	NSString *message = TGSendFailureMessage(state, NO);

	TGTestExpectTrue(&outcome, message.length > 0,
			"an underpriced paid message must produce a non-empty, human-readable message");
	TGTestExpectTrue(&outcome, [message rangeOfString:@"ALLOW_PAYMENT_REQUIRED"].location == NSNotFound,
			"the raw ALLOW_PAYMENT_REQUIRED_ server token must never reach the user");
	TGTestExpectTrue(&outcome, [message rangeOfString:@"142"].location != NSNotFound,
			"the required star count must appear in the surfaced text");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestSendFailureMessageFallsBackToRawErrorTextWhenNoRetryAfter(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *state = @{
		@"@type" : @"messageSendingStateFailed",
		@"error" : @{@"code" : @400, @"message" : @"MESSAGE_TOO_LONG"},
		@"retry_after" : @0.0,
	};

	NSString *message = TGSendFailureMessage(state, NO);

	TGTestExpectTrue(&outcome, [message isEqualToString:@"MESSAGE_TOO_LONG"],
			"with no retry_after and no slow mode prefix, the raw error message must be surfaced verbatim");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestSendFailureMessageReturnsNilWhenNothingToReport(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *state = @{@"@type" : @"messageSendingStateFailed"};

	TGTestExpectTrue(&outcome, TGSendFailureMessage(state, NO) == nil,
			"a failed state with no error and no retry_after must report nil rather than an empty toast");

	return outcome;
}

TGTestOutcome TGFlattenMessagesTestBriefKeepsADisappearingCaptionBack(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *viewOnce = @{
		@"id" : @7,
		@"content" : @{@"@type" : @"messagePhoto",
			@"self_destruct_type" : @{@"@type" : @"messageSelfDestructTypeImmediately"},
			@"caption" : @{@"@type" : @"formattedText", @"text" : @"meet me at six"}},
	};
	NSDictionary *secret = @{
		@"id" : @8,
		@"content" : @{@"@type" : @"messageVideo", @"is_secret" : @YES,
			@"caption" : @{@"@type" : @"formattedText", @"text" : @"the codeword"}},
	};

	TGTestExpectTrue(&outcome,
			[TGMsgBrief(viewOnce)[@"text"] isEqualToString:@"Disappearing Photo"],
			"a brief of a photo meant to be seen once names the kind, and never repeats "
			"the caption that was written to disappear with it");
	TGTestExpectTrue(&outcome,
			[TGMsgBrief(secret)[@"text"] isEqualToString:@"Disappearing Video"],
			"and the same holds for secret-chat media");

	return outcome;
}

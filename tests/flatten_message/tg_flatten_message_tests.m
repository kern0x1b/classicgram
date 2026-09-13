#import "tg_flatten_message_tests.h"
#import "../../src/Wire/Flatten/TGFlattenMessage.h"
#import "../support/tg_flatten_message_fixture.h"
#import <Foundation/Foundation.h>

static TGFlattenContext *TGFlattenMessageTestContext(void) {
	return TGFlattenMessageFixtureContext();
}

TGTestOutcome TGFlattenMessageTestFlattensTextMessage(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"@type" : @"message",
		@"id" : @5000000001,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000000,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{
				@"@type" : @"formattedText",
				@"text" : @"hello world",
				@"entities" : @[
					@{@"@type" : @"textEntity", @"offset" : @0, @"length" : @5,
					  @"type" : @{@"@type" : @"textEntityTypeBold"}},
					@{@"@type" : @"textEntity", @"offset" : @6, @"length" : @5,
					  @"type" : @{@"@type" : @"textEntityTypeDateTime", @"unix_time" : @1700000000}},
				],
			},
		},
	};

	NSDictionary *flat = TGFlattenMessage(message, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, flat != nil,
			"a well-formed raw TDLib text message must flatten to a dictionary, not nil");
	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@"hello world"],
			"a plain text message's body must come from content.text.text");
	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"messageText"],
			"the raw TDLib content @type must be preserved verbatim as kind");
	TGTestExpectTrue(&outcome, [flat[@"service"] boolValue] == NO,
			"a plain text message must never be classified as a service message");
	TGTestExpectEqualInteger(&outcome, [flat[@"entities"] count], 2,
			"both formatted text entities on the message body must survive flattening");
	TGTestExpectTrue(&outcome, [flat[@"entities"][0][@"kind"] isEqualToString:@"Bold"],
			"the textEntityType prefix must be stripped, leaving just the entity kind name");
	TGTestExpectTrue(&outcome, [flat[@"entities"][1][@"kind"] isEqualToString:@"DateTime"],
			"textEntityTypeDateTime must flatten to kind DateTime");
	TGTestExpectEqualLongLong(&outcome, [flat[@"entities"][1][@"timestamp"] longLongValue], 1700000000,
			"a DateTime entity's unix_time must round-trip through the shared timestamp field, the same field MediaTimestamp uses");
	TGTestExpectEqualLongLong(&outcome, [flat[@"id"] longLongValue], 5000000001,
			"the message id must round-trip through flattening unchanged");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensPhotoWithCaption(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"@type" : @"message",
		@"id" : @5000000002,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @YES,
		@"date" : @1700000001,
		@"content" : @{
			@"@type" : @"messagePhoto",
			@"photo" : @{
				@"@type" : @"photo",
				@"sizes" : @[
					@{@"@type" : @"photoSize", @"type" : @"m",
					  @"photo" : @{@"@type" : @"file", @"id" : @555},
					  @"width" : @800, @"height" : @600},
				],
			},
			@"caption" : @{
				@"@type" : @"formattedText",
				@"text" : @"look at this",
				@"entities" : @[],
			},
		},
	};

	NSDictionary *flat = TGFlattenMessage(message, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@"look at this"],
			"a photo's caption must become the flattened text when present");
	TGTestExpectTrue(&outcome, [flat[@"caption"] isEqualToString:@"look at this"],
			"the caption must also be exposed separately under its own key");
	TGTestExpectEqualLongLong(&outcome, [flat[@"photoId"] longLongValue], 555,
			"the largest photo size's file id must become the flattened photoId");
	TGTestExpectEqualInteger(&outcome, [flat[@"photoWidth"] integerValue], 800,
			"the largest photo size's width must be exposed as photoWidth");
	TGTestExpectEqualInteger(&outcome, [flat[@"photoHeight"] integerValue], 600,
			"the largest photo size's height must be exposed as photoHeight");
	TGTestExpectTrue(&outcome, flat[@"minithumbnail"] == [NSNull null],
			"a photo with no minithumbnail key must flatten to NSNull, not crash or fabricate one");
	TGTestExpectTrue(&outcome, [flat[@"outgoing"] boolValue] == YES,
			"an outgoing photo message must flatten with outgoing set");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensVoiceNoteWaveform(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	const uint8_t waveformBytes[] = {0x01, 0x02, 0x03, 0x04, 0x05, 0x1F, 0x00, 0xFF};
	NSData *expectedWaveform = [NSData dataWithBytes:waveformBytes length:sizeof(waveformBytes)];

	NSDictionary *message = @{
		@"@type" : @"message",
		@"id" : @5000000003,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000002,
		@"content" : @{
			@"@type" : @"messageVoiceNote",
			@"voice_note" : @{
				@"@type" : @"voiceNote",
				@"duration" : @12,
				@"waveform" : @"AQIDBAUfAP8=",
				@"voice" : @{
					@"@type" : @"file",
					@"id" : @777,
					@"size" : @34500,
					@"local" : @{
						@"@type" : @"localFile",
						@"path" : @"",
						@"is_downloading_active" : @NO,
						@"is_downloading_completed" : @NO,
						@"downloaded_size" : @0,
					},
				},
			},
		},
	};

	NSDictionary *flat = TGFlattenMessage(message, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [flat[@"waveform"] isEqualToData:expectedWaveform],
			"the voice note's base64 waveform must decode to the exact original bytes");
	TGTestExpectEqualLongLong(&outcome, [flat[@"docId"] longLongValue], 777,
			"a voice note carries its audio file id under docId, not photoId");
	TGTestExpectEqualInteger(&outcome, [flat[@"duration"] integerValue], 12,
			"the voice note's duration in seconds must round-trip");
	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@""],
			"a voice note with no caption must flatten to empty text, not a placeholder");
	TGTestExpectEqualLongLong(&outcome, [flat[@"docSize"] longLongValue], 34500,
			"the voice note file's size must flow through the injected file-state resolver");
	TGTestExpectTrue(&outcome, [flat[@"docLocal"] boolValue] == NO,
			"a voice note file not yet downloaded must not be reported as local");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensVoiceNoteTranscript(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *withText = @{
		@"@type" : @"message",
		@"id" : @5000000101,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000010,
		@"content" : @{
			@"@type" : @"messageVoiceNote",
			@"voice_note" : @{
				@"@type" : @"voiceNote",
				@"duration" : @9,
				@"waveform" : @"",
				@"speech_recognition_result" : @{
					@"@type" : @"speechRecognitionResultText",
					@"text" : @"hello there",
				},
				@"voice" : @{@"@type" : @"file", @"id" : @888},
			},
		},
	};

	NSDictionary *flatWithText = TGFlattenMessage(withText, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [flatWithText[@"transcript"][@"state"] isEqualToString:@"text"],
			"a voice note with a finished speech_recognition_result must flatten with transcript state \"text\"");
	TGTestExpectTrue(&outcome, [flatWithText[@"transcript"][@"text"] isEqualToString:@"hello there"],
			"a voice note's recognized text must survive flattening verbatim");

	NSDictionary *withoutResult = @{
		@"@type" : @"message",
		@"id" : @5000000102,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000011,
		@"content" : @{
			@"@type" : @"messageVoiceNote",
			@"voice_note" : @{
				@"@type" : @"voiceNote",
				@"duration" : @9,
				@"waveform" : @"",
				@"voice" : @{@"@type" : @"file", @"id" : @889},
			},
		},
	};

	NSDictionary *flatWithoutResult = TGFlattenMessage(withoutResult, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, flatWithoutResult[@"transcript"] == [NSNull null],
			"a voice note with no speech_recognition_result must flatten its transcript to NSNull, not crash or fabricate one");

	NSDictionary *videoNoteWithPending = @{
		@"@type" : @"message",
		@"id" : @5000000103,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000012,
		@"content" : @{
			@"@type" : @"messageVideoNote",
			@"video_note" : @{
				@"@type" : @"videoNote",
				@"duration" : @6,
				@"length" : @240,
				@"speech_recognition_result" : @{
					@"@type" : @"speechRecognitionResultPending",
					@"partial_text" : @"hello th",
				},
				@"video" : @{@"@type" : @"file", @"id" : @890},
			},
		},
	};

	NSDictionary *flatVideoNote = TGFlattenMessage(videoNoteWithPending, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [flatVideoNote[@"transcript"][@"state"] isEqualToString:@"pending"],
			"a video note mid-recognition must flatten with transcript state \"pending\"");
	TGTestExpectTrue(&outcome, [flatVideoNote[@"transcript"][@"text"] isEqualToString:@"hello th"],
			"a pending video note transcript must carry its partial text");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensQuizPollWithCorrectOptionAndExplanation(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"@type" : @"message",
		@"id" : @5000000004,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000003,
		@"content" : @{
			@"@type" : @"messagePoll",
			@"poll" : @{
				@"@type" : @"poll",
				@"question" : @{@"@type" : @"formattedText", @"text" : @"2+2=?"},
				@"options" : @[
					@{@"@type" : @"pollOption",
					  @"text" : @{@"@type" : @"formattedText", @"text" : @"3"},
					  @"voter_count" : @1, @"vote_percentage" : @25, @"is_chosen" : @NO},
					@{@"@type" : @"pollOption",
					  @"text" : @{@"@type" : @"formattedText", @"text" : @"4"},
					  @"voter_count" : @3, @"vote_percentage" : @75, @"is_chosen" : @YES},
				],
				@"total_voter_count" : @4,
				@"is_anonymous" : @YES,
				@"can_get_voters" : @NO,
				@"is_closed" : @NO,
				@"can_add_option" : @NO,
				@"type" : @{
					@"@type" : @"pollTypeQuiz",
					@"correct_option_ids" : @[ @1 ],
					@"explanation" : @{
						@"@type" : @"formattedText",
						@"text" : @"Basic math",
						@"entities" : @[
							@{@"@type" : @"textEntity", @"offset" : @0, @"length" : @5,
							  @"type" : @{@"@type" : @"textEntityTypeBold"}},
						],
					},
				},
			},
		},
	};

	NSDictionary *flat = TGFlattenMessage(message, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [flat[@"pollIsQuiz"] boolValue] == YES,
			"a poll with a pollTypeQuiz type must flatten with pollIsQuiz set");
	TGTestExpectEqualLongLong(&outcome, [flat[@"pollCorrectOptionId"] longLongValue], 1,
			"the quiz's correct option index must round-trip from the poll type");
	TGTestExpectTrue(&outcome, [flat[@"pollExplanation"] isEqualToString:@"Basic math"],
			"the quiz's explanation text must round-trip from the poll type");
	TGTestExpectEqualInteger(&outcome, [flat[@"pollExplanationEntities"] count], 1,
			"the quiz explanation's formatting entities must survive flattening");
	TGTestExpectTrue(&outcome, [flat[@"pollExplanationEntities"][0][@"kind"] isEqualToString:@"Bold"],
			"the quiz explanation's entity kind must be flattened like any other formatted text");
	TGTestExpectTrue(&outcome, [flat[@"pollQuestion"] isEqualToString:@"2+2=?"],
			"the poll question must round-trip from its formatted text");
	TGTestExpectEqualInteger(&outcome, [flat[@"pollOptions"] count], 2,
			"both poll options must survive flattening");
	TGTestExpectEqualInteger(&outcome, [flat[@"pollTotal"] integerValue], 4,
			"the poll's total voter count must round-trip");
	TGTestExpectTrue(&outcome, [flat[@"pollCanGetVoters"] boolValue] == NO,
			"the poll's can_get_voters flag must round-trip from TDLib, not be re-derived");
	TGTestExpectTrue(&outcome, [flat[@"text"] hasPrefix:@"2+2=?\n"],
			"the poll's rendered summary text must start with the question");
	TGTestExpectTrue(&outcome, [flat[@"text"] rangeOfString:@"4 voted"].location != NSNotFound,
			"the poll's rendered summary text must end with the voter count line");

	return outcome;
}

static NSDictionary *TGFlattenMessageTestPollMessageWithAllowsRevoting(id allowsRevotingValue) {
	NSMutableDictionary *poll = [@{
		@"@type" : @"poll",
		@"question" : @{@"@type" : @"formattedText", @"text" : @"Sure?"},
		@"options" : @[
			@{@"@type" : @"pollOption",
			  @"text" : @{@"@type" : @"formattedText", @"text" : @"Yes"},
			  @"voter_count" : @1, @"vote_percentage" : @100, @"is_chosen" : @YES},
			@{@"@type" : @"pollOption",
			  @"text" : @{@"@type" : @"formattedText", @"text" : @"No"},
			  @"voter_count" : @0, @"vote_percentage" : @0, @"is_chosen" : @NO},
		],
		@"total_voter_count" : @1,
		@"is_anonymous" : @YES,
		@"can_get_voters" : @NO,
		@"is_closed" : @NO,
		@"can_add_option" : @NO,
		@"type" : @{@"@type" : @"pollTypeRegular", @"allow_adding_options" : @NO},
	} mutableCopy];
	if (allowsRevotingValue)
		poll[@"allows_revoting"] = allowsRevotingValue;

	return @{
		@"@type" : @"message",
		@"id" : @5000000006,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000005,
		@"content" : @{
			@"@type" : @"messagePoll",
			@"poll" : [poll copy],
		},
	};
}

TGTestOutcome TGFlattenMessageTestPollAllowsRevotingRoundTrips(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *revotable = TGFlattenMessageTestPollMessageWithAllowsRevoting(@YES);
	NSDictionary *revotableFlat = TGFlattenMessage(revotable, TGFlattenMessageTestContext());
	TGTestExpectTrue(&outcome, [revotableFlat[@"pollAllowsRevoting"] boolValue] == YES,
			"a poll with allows_revoting true must flatten with pollAllowsRevoting set");

	NSDictionary *locked = TGFlattenMessageTestPollMessageWithAllowsRevoting(@NO);
	NSDictionary *lockedFlat = TGFlattenMessage(locked, TGFlattenMessageTestContext());
	TGTestExpectTrue(&outcome, [lockedFlat[@"pollAllowsRevoting"] boolValue] == NO,
			"a poll with allows_revoting false must flatten with pollAllowsRevoting cleared");

	NSDictionary *missing = TGFlattenMessageTestPollMessageWithAllowsRevoting(nil);
	NSDictionary *missingFlat = TGFlattenMessage(missing, TGFlattenMessageTestContext());
	TGTestExpectTrue(&outcome, [missingFlat[@"pollAllowsRevoting"] boolValue] == NO,
			"a poll missing allows_revoting entirely must default pollAllowsRevoting to false");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestPollQuizCorrectOptionIdPicksFirstElement(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualLongLong(&outcome,
			[TGPollQuizCorrectOptionId(@[ @2, @0 ]) longLongValue], 2,
			"a quiz's correct option id must be the array's first element, not derived any other way");
	TGTestExpectEqualLongLong(&outcome,
			[TGPollQuizCorrectOptionId(@[]) longLongValue], -1,
			"an empty correct_option_ids array must fall back to -1, meaning unanswered");
	TGTestExpectEqualLongLong(&outcome,
			[TGPollQuizCorrectOptionId(nil) longLongValue], -1,
			"a missing correct_option_ids value must fall back to -1, not crash");
	TGTestExpectEqualLongLong(&outcome,
			[TGPollQuizCorrectOptionId(@"not an array") longLongValue], -1,
			"a malformed correct_option_ids value must fall back to -1, not crash");

	return outcome;
}

static NSDictionary *TGFlattenMessageTestPollMessageWithPercentages(NSArray<NSNumber *> *percentages,
	NSInteger totalVoterCount) {
	NSMutableArray *options = [NSMutableArray arrayWithCapacity:percentages.count];
	for (NSUInteger i = 0; i < percentages.count; i++) {
		[options addObject:@{
			@"@type" : @"pollOption",
			@"text" : @{@"@type" : @"formattedText",
				@"text" : [NSString stringWithFormat:@"Option %lu", (unsigned long)i]},
			@"voter_count" : @0,
			@"vote_percentage" : percentages[i],
			@"is_chosen" : @NO,
		}];
	}
	return @{
		@"@type" : @"message",
		@"id" : @5000000005,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000004,
		@"content" : @{
			@"@type" : @"messagePoll",
			@"poll" : @{
				@"@type" : @"poll",
				@"question" : @{@"@type" : @"formattedText", @"text" : @"Which one?"},
				@"options" : options,
				@"total_voter_count" : @(totalVoterCount),
				@"is_anonymous" : @YES,
				@"can_get_voters" : @NO,
				@"is_closed" : @NO,
				@"can_add_option" : @NO,
			},
		},
	};
}

TGTestOutcome TGFlattenMessageTestPollOptionPercentagesSurviveFlatteningWithoutFloatTruncation(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray<NSArray<NSNumber *> *> *distributions = @[
		@[ @53, @47 ],
		@[ @33, @33, @34 ],
		@[ @34, @33, @33 ],
	];

	for (NSArray<NSNumber *> *percentages in distributions) {
		NSDictionary *message = TGFlattenMessageTestPollMessageWithPercentages(percentages, 3);
		NSDictionary *flat = TGFlattenMessage(message, TGFlattenMessageTestContext());
		NSArray *pollOptions = flat[@"pollOptions"];

		TGTestExpectEqualInteger(&outcome, pollOptions.count, percentages.count,
				"every option TDLib sent must survive flattening, none dropped or merged");

		NSInteger directSum = 0;
		NSInteger floatRoundTripSum = 0;
		for (NSUInteger i = 0; i < percentages.count; i++) {
			NSInteger votePercentage = [pollOptions[i][@"vote_percentage"] integerValue];
			TGTestExpectEqualInteger(&outcome, votePercentage, percentages[i].integerValue,
					"vote_percentage must round-trip through flattening exactly, untouched");

			directSum += votePercentage;
			CGFloat fraction = votePercentage / 100.0f;
			floatRoundTripSum += (int)(fraction * 100);
		}

		TGTestExpectEqualInteger(&outcome, directSum, 100,
				"reading vote_percentage directly (the fix) must always sum to exactly 100, "
				"matching TDLib's largest-remainder guarantee");
	}

	NSDictionary *message = TGFlattenMessageTestPollMessageWithPercentages(@[ @53, @47 ], 19);
	NSDictionary *flat = TGFlattenMessage(message, TGFlattenMessageTestContext());
	NSArray *pollOptions = flat[@"pollOptions"];
	NSInteger floatRoundTripSum = 0;
	for (NSUInteger i = 0; i < pollOptions.count; i++) {
		NSInteger votePercentage = [pollOptions[i][@"vote_percentage"] integerValue];
		CGFloat fraction = votePercentage / 100.0f;
		floatRoundTripSum += (int)(fraction * 100);
	}
	TGTestExpectTrue(&outcome, floatRoundTripSum != 100,
			"this documents the bug the fix removes: re-deriving the percentage by dividing "
			"vote_percentage by 100.0f and truncating back loses precision (53 -> 52) so a "
			"53/47 split would have visibly summed to 99, not 100");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensDice(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"@type" : @"message",
		@"id" : @5000000005,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000004,
		@"content" : @{
			@"@type" : @"messageDice",
			@"emoji" : @"\U0001F3B2",
			@"value" : @4,
			@"final_state" : @{
				@"@type" : @"diceStickersRegular",
				@"sticker" : @{
					@"@type" : @"sticker",
					@"format" : @{@"@type" : @"stickerFormatWebp"},
					@"sticker" : @{@"@type" : @"file", @"id" : @999},
					@"width" : @512, @"height" : @512, @"set_id" : @123,
				},
			},
		},
	};

	NSDictionary *flat = TGFlattenMessage(message, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"messageDice"],
			"a dice message must keep messageDice as its flattened kind");
	TGTestExpectEqualLongLong(&outcome, [flat[@"photoId"] longLongValue], 999,
			"a webp dice sticker's file id must become the flattened photoId");
	TGTestExpectEqualLongLong(&outcome, [flat[@"stickerSetId"] longLongValue], 123,
			"the dice sticker's set id must round-trip");
	TGTestExpectTrue(&outcome, [flat[@"text"] rangeOfString:@"4"].location != NSNotFound,
			"the dice's rolled value must appear in the flattened text");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensServiceActions(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *joinMessage = @{
		@"@type" : @"message",
		@"id" : @5000000006,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000005,
		@"content" : @{
			@"@type" : @"messageChatAddMembers",
			@"member_user_ids" : @[@1001],
		},
	};

	NSDictionary *joinFlat = TGFlattenMessage(joinMessage, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [joinFlat[@"service"] boolValue] == YES,
			"a member-add service message must flatten with service set");
	TGTestExpectTrue(&outcome, [joinFlat[@"text"] isEqualToString:@"Alice joined the group"],
			"a member joining who is also the sole added user must read as self-join, not an invite");
	TGTestExpectTrue(&outcome, [joinFlat[@"serviceActor"] isEqualToString:@"Alice"],
			"the resolved actor name must be exposed as serviceActor for a service message");

	NSDictionary *photoMessage = @{
		@"@type" : @"message",
		@"id" : @5000000007,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000006,
		@"content" : @{
			@"@type" : @"messageChatChangePhoto",
			@"photo" : @{
				@"@type" : @"chatPhoto",
				@"sizes" : @[
					@{@"@type" : @"photoSize", @"type" : @"m",
					  @"photo" : @{@"@type" : @"file", @"id" : @333},
					  @"width" : @160, @"height" : @160},
				],
			},
		},
	};

	NSDictionary *photoFlat = TGFlattenMessage(photoMessage, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [photoFlat[@"service"] boolValue] == YES,
			"a chat photo change must flatten as a service message");
	TGTestExpectTrue(&outcome, [photoFlat[@"text"] isEqualToString:@"Alice changed group photo"],
			"a named actor changing a non-channel's photo must read as \"<actor> changed group photo\"");
	TGTestExpectEqualLongLong(&outcome, [photoFlat[@"photoId"] longLongValue], 333,
			"the new chat photo's file id must carry through as the service message's photoId");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestPinMessageDescriptorResolvesByContentKind(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *pinMessage = @{
		@"@type" : @"message",
		@"id" : @5000000010,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000009,
		@"content" : @{
			@"@type" : @"messagePinMessage",
			@"message_id" : @5000000000,
		},
	};

	NSDictionary *pinFlat = TGFlattenMessage(pinMessage, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [pinFlat[@"kind"] isEqualToString:@"messagePinMessage"],
			"a pin action must keep its raw content type as kind");
	TGTestExpectEqualLongLong(&outcome, [pinFlat[@"pinnedId"] longLongValue], 5000000000,
			"a pin action must expose the pinned message's id so a downstream lookup can resolve it");
	TGTestExpectTrue(&outcome, [pinFlat[@"text"] isEqualToString:@"Alice pinned a message"],
			"with no resolved target content at flatten time, the pin service line must fall back to the generic wording");

	NSString *photoDescriptor = TGPinnedDescriptorForContentKind(@"messagePhoto");
	TGTestExpectTrue(&outcome, [photoDescriptor isEqualToString:@"a photo"],
			"a resolved messagePhoto target must map to the photo pinned-descriptor string");

	NSString *videoNoteDescriptor = TGPinnedDescriptorForContentKind(@"messageVideoNote");
	TGTestExpectTrue(&outcome, [videoNoteDescriptor isEqualToString:@"a video message"],
			"a resolved messageVideoNote target must map to the video-message pinned-descriptor string");

	NSString *unknownDescriptor = TGPinnedDescriptorForContentKind(@"messageText");
	TGTestExpectTrue(&outcome, unknownDescriptor == nil,
			"plain text has no fixed descriptor noun, so the shared mapper must leave it to the caller");

	NSString *composedForPhoto = TGComposePinnedNotice(@"Alice", photoDescriptor);
	TGTestExpectTrue(&outcome, [composedForPhoto isEqualToString:@"Alice pinned a photo"],
			"composing an actor with a resolved descriptor must read as \"<actor> pinned <descriptor>\"");

	NSString *composedForNilDescriptor = TGComposePinnedNotice(@"Alice", nil);
	TGTestExpectTrue(&outcome, composedForNilDescriptor == nil,
			"composing with no descriptor must return nil so the caller can fall back to the generic wording");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensChatSetBackgroundOldMessageId(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *revertibleMessage = @{
		@"@type" : @"message",
		@"id" : @5000000008,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000007,
		@"content" : @{
			@"@type" : @"messageChatSetBackground",
			@"old_background_message_id" : @5000000000,
			@"background" : @{
				@"@type" : @"chatBackground",
				@"background" : @{@"@type" : @"background", @"id" : @900},
			},
			@"only_for_self" : @NO,
		},
	};

	NSDictionary *revertibleFlat = TGFlattenMessage(revertibleMessage, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [revertibleFlat[@"kind"] isEqualToString:@"messageChatSetBackground"],
			"a wallpaper change must keep its raw content type as kind");
	TGTestExpectEqualLongLong(&outcome, [revertibleFlat[@"oldBackgroundMessageId"] longLongValue], 5000000000,
			"a wallpaper change that replaced an earlier one must expose that earlier message id so the chat can revert to it");
	TGTestExpectTrue(&outcome, ![revertibleFlat[@"onlyForSelf"] boolValue],
			"a background set for both sides must flatten only_for_self as false");
	TGTestExpectEqualLongLong(&outcome, [revertibleFlat[@"backgroundId"] longLongValue], 900,
			"the new background's own id must flatten through so the chat can tell whether it is still the current one");

	NSDictionary *onlyForSelfMessage = @{
		@"@type" : @"message",
		@"id" : @5000000010,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000009,
		@"content" : @{
			@"@type" : @"messageChatSetBackground",
			@"old_background_message_id" : @5000000000,
			@"background" : @{
				@"@type" : @"chatBackground",
				@"background" : @{@"@type" : @"background", @"id" : @901},
			},
			@"only_for_self" : @YES,
		},
	};

	NSDictionary *onlyForSelfFlat = TGFlattenMessage(onlyForSelfMessage, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [onlyForSelfFlat[@"onlyForSelf"] boolValue],
			"a background set only for self must flatten only_for_self as true so the revert action can be gated on it");

	NSDictionary *firstEverMessage = @{
		@"@type" : @"message",
		@"id" : @5000000009,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000008,
		@"content" : @{
			@"@type" : @"messageChatSetBackground",
			@"old_background_message_id" : @0,
			@"background" : @{@"@type" : @"chatBackground"},
			@"only_for_self" : @NO,
		},
	};

	NSDictionary *firstEverFlat = TGFlattenMessage(firstEverMessage, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, firstEverFlat[@"oldBackgroundMessageId"] == [NSNull null],
			"a chat's first-ever wallpaper has nothing to revert to, so oldBackgroundMessageId must flatten to NSNull");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestSecretChatAutoDeleteServiceMessageUsesSecretWording(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *autoDeleteContent = @{
		@"@type" : @"messageChatSetMessageAutoDeleteTime",
		@"message_auto_delete_time" : @60,
		@"from_user_id" : @1001,
	};

	NSDictionary *secretMessage = @{
		@"@type" : @"message",
		@"id" : @5000000100,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @4001,
		@"is_outgoing" : @NO,
		@"date" : @1700000100,
		@"content" : autoDeleteContent,
	};

	NSDictionary *secretFlat = TGFlattenMessage(secretMessage, TGFlattenMessageTestContext());
	TGTestExpectTrue(&outcome, [secretFlat[@"text"] isEqualToString:@"Secret wording: self-destruct timer changed"],
			"a self-destruct-timer service message inside a secret chat must use the secret-specific wording");

	NSDictionary *groupMessage = @{
		@"@type" : @"message",
		@"id" : @5000000101,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000101,
		@"content" : autoDeleteContent,
	};

	NSDictionary *groupFlat = TGFlattenMessage(groupMessage, TGFlattenMessageTestContext());
	TGTestExpectTrue(&outcome, [groupFlat[@"text"] isEqualToString:@"Alice set messages to automatically delete after 1 minute"],
			"the same content in a non-secret chat must keep the existing generic auto-delete wording");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestDestructDeadlineTracksWallClockAcrossReopens(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSTimeInterval openedAt = 1000.0;
	NSTimeInterval deadline = TGDestructDeadlineFromRemaining(10.0, openedAt);
	TGTestExpectTrue(&outcome, deadline == openedAt + 10.0,
			"a freshly-opened message's deadline must be now plus the reported remaining seconds");

	NSTimeInterval remainingRightAway = TGRemainingSecondsUntilDestruct(deadline, openedAt);
	TGTestExpectTrue(&outcome, remainingRightAway == 10.0,
			"reading remaining time at the moment of opening must return the full duration");

	NSTimeInterval remainingAfterSixSeconds = TGRemainingSecondsUntilDestruct(deadline, openedAt + 6.0);
	TGTestExpectTrue(&outcome, remainingAfterSixSeconds == 4.0,
			"reopening a still-live message later must return the decayed remaining time, not the original duration");

	NSTimeInterval remainingAfterExpiry = TGRemainingSecondsUntilDestruct(deadline, openedAt + 30.0);
	TGTestExpectTrue(&outcome, remainingAfterExpiry == 0.0,
			"reading remaining time past the deadline must clamp to zero, never go negative");

	NSTimeInterval deadlineForUnstarted = TGDestructDeadlineFromRemaining(0.0, openedAt);
	TGTestExpectTrue(&outcome, deadlineForUnstarted == 0.0,
			"a message whose self-destruct timer has not started yet must produce no deadline");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensReactionChips(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"@type" : @"message",
		@"id" : @5000000008,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000007,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"nice", @"entities" : @[]},
		},
		@"interaction_info" : @{
			@"@type" : @"messageInteractionInfo",
			@"view_count" : @0,
			@"reactions" : @{
				@"@type" : @"messageReactions",
				@"reactions" : @[
					@{@"type" : @{@"@type" : @"reactionTypeEmoji", @"emoji" : @"\U0001F44D"},
					  @"total_count" : @3, @"is_chosen" : @YES},
					@{@"type" : @{@"@type" : @"reactionTypeEmoji", @"emoji" : @"\U00002764"},
					  @"total_count" : @1, @"is_chosen" : @NO},
				],
			},
		},
	};

	NSDictionary *flat = TGFlattenMessage(message, TGFlattenMessageTestContext());

	TGTestExpectEqualInteger(&outcome, [flat[@"reactionChips"] count], 2,
			"both reactions on the message must survive flattening into reactionChips");
	TGTestExpectTrue(&outcome,
			[flat[@"reactionChips"][0][@"emoji"] isEqualToString:@"\U0001F44D"],
			"the first reaction chip's emoji must round-trip unchanged");
	TGTestExpectTrue(&outcome, [flat[@"reactionChips"][0][@"chosen"] boolValue] == YES,
			"a reaction the account itself picked must round-trip as chosen");
	TGTestExpectTrue(&outcome,
			[flat[@"reactions"] isEqualToString:@"\U0001F44D 3  \U00002764 1"],
			"the reactions summary string must be built from the same chips, in order");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensForwardedMessage(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"@type" : @"message",
		@"id" : @5000000009,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000008,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"look at this", @"entities" : @[]},
		},
		@"forward_info" : @{
			@"@type" : @"messageForwardInfo",
			@"origin" : @{
				@"@type" : @"messageOriginChannel",
				@"chat_id" : @3001,
				@"message_id" : @42,
				@"author_signature" : @"News",
			},
			@"date" : @1699999999,
		},
	};

	NSDictionary *flat = TGFlattenMessage(message, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [flat[@"forward"] isEqualToString:@"News"],
			"a channel forward with an author signature must use that signature as the forward label");
	TGTestExpectEqualLongLong(&outcome, [flat[@"forwardChatId"] longLongValue], 3001,
			"the forward origin's channel chat id must round-trip");
	TGTestExpectEqualLongLong(&outcome, [flat[@"forwardMessageId"] longLongValue], 42,
			"the forward origin's source message id must round-trip");
	TGTestExpectTrue(&outcome, [flat[@"forwardIsChannel"] boolValue] == YES,
			"a messageOriginChannel forward must flag forwardIsChannel");

	NSDictionary *userForwardMessage = @{
		@"@type" : @"message",
		@"id" : @5000000010,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000009,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"hi", @"entities" : @[]},
		},
		@"forward_info" : @{
			@"@type" : @"messageForwardInfo",
			@"origin" : @{@"@type" : @"messageOriginUser", @"sender_user_id" : @1002},
			@"date" : @1699999998,
		},
	};

	NSDictionary *userForwardFlat =
			TGFlattenMessage(userForwardMessage, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [userForwardFlat[@"forward"] isEqualToString:@"Bob"],
			"a messageOriginUser forward must resolve the sender's name through the injected resolver");
	TGTestExpectTrue(&outcome, [userForwardFlat[@"forwardIsChannel"] boolValue] == NO,
			"a user forward must not be flagged as a channel forward");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensReplyThatQuotesAnotherMessage(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"@type" : @"message",
		@"id" : @5000000011,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000010,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"agreed", @"entities" : @[]},
		},
		@"reply_to" : @{
			@"@type" : @"messageReplyToMessage",
			@"chat_id" : @2001,
			@"message_id" : @4000000123,
			@"origin" : @{@"@type" : @"messageOriginUser", @"sender_user_id" : @1002},
			@"quote" : @{
				@"@type" : @"textQuote",
				@"text" : @{@"@type" : @"formattedText", @"text" : @"quoted snippet",
							@"entities" : @[]},
				@"is_manual" : @NO,
			},
			@"content" : @{
				@"@type" : @"messageText",
				@"text" : @{@"@type" : @"formattedText", @"text" : @"quoted snippet"},
			},
		},
	};

	NSDictionary *flat = TGFlattenMessage(message, TGFlattenMessageTestContext());

	TGTestExpectEqualLongLong(&outcome, [flat[@"replyId"] longLongValue], 4000000123,
			"the replied-to message id must round-trip from reply_to.message_id");
	TGTestExpectEqualLongLong(&outcome, [flat[@"replyChatId"] longLongValue], 2001,
			"a same-chat reply must carry reply_to.chat_id even when it equals the message's own chat");
	TGTestExpectTrue(&outcome, [flat[@"replyText"] isEqualToString:@"quoted snippet"],
			"the quoted text must come from the reply's quote, not the reply's fallback content");
	TGTestExpectTrue(&outcome, [flat[@"replyAuthor"] isEqualToString:@"Bob"],
			"the reply's origin user must be resolved through the injected name resolver");
	TGTestExpectTrue(&outcome, [flat[@"replyIsFragment"] boolValue] == NO,
			"a quote that is not manually selected must not be flagged as a fragment");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensReplyFromDiscussionGroupToLinkedChannel(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"@type" : @"message",
		@"id" : @5000000013,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2002,
		@"is_outgoing" : @NO,
		@"date" : @1700000012,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"first!", @"entities" : @[]},
		},
		@"reply_to" : @{
			@"@type" : @"messageReplyToMessage",
			@"chat_id" : @3001,
			@"message_id" : @4000000456,
			@"origin" : @{@"@type" : @"messageOriginChannel", @"chat_id" : @3001,
						  @"message_id" : @4000000456},
			@"quote" : [NSNull null],
			@"content" : @{
				@"@type" : @"messageText",
				@"text" : @{@"@type" : @"formattedText", @"text" : @"channel post"},
			},
		},
	};

	NSDictionary *flat = TGFlattenMessage(message, TGFlattenMessageTestContext());

	TGTestExpectEqualLongLong(&outcome, [flat[@"replyChatId"] longLongValue], 3001,
			"a discussion-group comment's reply must carry the linked channel's chat id, "
			"not the comment's own chat");
	TGTestExpectTrue(&outcome, [flat[@"replyChatId"] longLongValue] != [message[@"chat_id"] longLongValue],
			"the reply's chat id must legitimately differ from the message's own chat when "
			"the reply crosses from a discussion group to its linked channel");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensReplyToStory(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"@type" : @"message",
		@"id" : @5000000012,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @3001,
		@"is_outgoing" : @NO,
		@"date" : @1700000011,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"nice story", @"entities" : @[]},
		},
		@"reply_to" : @{
			@"@type" : @"messageReplyToStory",
			@"story_poster_chat_id" : @3001,
			@"story_id" : @42,
		},
	};

	NSDictionary *flat = TGFlattenMessage(message, TGFlattenMessageTestContext());

	TGTestExpectEqualLongLong(&outcome, [flat[@"replyId"] longLongValue], 42,
			"a story reply must carry the story id so the reply header renders at all");
	TGTestExpectEqualLongLong(&outcome, [flat[@"replyChatId"] longLongValue], 0,
			"a story reply has no messageReplyToMessage.chat_id and must fall back to 0/unknown");
	TGTestExpectTrue(&outcome, [flat[@"replyText"] length] > 0,
			"a story reply must carry non-empty reply text so no bogus message lookup is triggered");
	TGTestExpectTrue(&outcome, [flat[@"replyKindLabel"] length] > 0,
			"a story reply must carry a reply-to-story label");
	TGTestExpectTrue(&outcome, [flat[@"replyAuthor"] isEqualToString:@"News Channel"],
			"a story reply must resolve the poster's chat title for the reply author");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensExpiredMediaMessage(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"@type" : @"message",
		@"id" : @5000000012,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000011,
		@"content" : @{
			@"@type" : @"messageExpiredVideo",
		},
	};

	NSDictionary *flat = TGFlattenMessage(message, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"messageExpiredVideo"],
			"an expired video message must keep messageExpiredVideo as its flattened kind");
	TGTestExpectTrue(&outcome, [flat[@"service"] boolValue] == NO,
			"an expired video is a real bubble message, not a system service line");
	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@"Video has expired"],
			"an expired video must flatten to the fixed \"Video has expired\" placeholder text");
	TGTestExpectTrue(&outcome, flat[@"photoId"] == [NSNull null],
			"an expired video carries no retrievable photo file id");
	TGTestExpectTrue(&outcome, flat[@"docId"] == [NSNull null],
			"an expired video carries no retrievable document file id");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensExpiredPhotoMessage(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"@type" : @"message",
		@"id" : @5000000013,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000012,
		@"content" : @{
			@"@type" : @"messageExpiredPhoto",
		},
	};

	NSDictionary *flat = TGFlattenMessage(message, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"messageExpiredPhoto"],
			"an expired photo message must keep messageExpiredPhoto as its flattened kind");
	TGTestExpectTrue(&outcome, [flat[@"service"] boolValue] == NO,
			"an expired photo is a real bubble message, not a system service line");
	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@"Photo has expired"],
			"an expired photo must flatten to the fixed \"Photo has expired\" placeholder text");
	TGTestExpectTrue(&outcome, flat[@"photoId"] == [NSNull null],
			"an expired photo carries no retrievable photo file id");
	TGTestExpectTrue(&outcome, flat[@"docId"] == [NSNull null],
			"an expired photo carries no retrievable document file id");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensChannelPostComments(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *withComments = @{
		@"@type" : @"message",
		@"id" : @5000000020,
		@"sender_id" : @{@"@type" : @"messageSenderChat", @"chat_id" : @3001},
		@"chat_id" : @3001,
		@"is_outgoing" : @NO,
		@"is_channel_post" : @YES,
		@"date" : @1700000020,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"news", @"entities" : @[]},
		},
		@"interaction_info" : @{
			@"@type" : @"messageInteractionInfo",
			@"view_count" : @1200,
			@"reply_info" : @{
				@"@type" : @"messageReplyInfo",
				@"reply_count" : @7,
				@"last_message_id" : @5000000099,
				@"recent_replier_ids" : @[
					@{@"@type" : @"messageSenderUser", @"user_id" : @1001},
					@{@"@type" : @"messageSenderChat", @"chat_id" : @3002},
					@{@"@type" : @"messageSenderUser", @"user_id" : @1002},
				],
			},
		},
	};

	NSDictionary *flat = TGFlattenMessage(withComments, TGFlattenMessageTestContext());

	TGTestExpectEqualLongLong(&outcome, [flat[@"commentCount"] longLongValue], 7,
			"a channel post's reply_count must round-trip into commentCount");
	TGTestExpectTrue(&outcome, [flat[@"hasCommentThread"] boolValue],
			"a channel post carrying reply_info has a linked discussion thread");
	TGTestExpectEqualLongLong(&outcome, [flat[@"commentLastMessageId"] longLongValue], 5000000099,
			"the discussion thread's last_message_id must round-trip into commentLastMessageId");
	NSArray *repliers = flat[@"commentReplierIds"];
	TGTestExpectEqualLongLong(&outcome, (long long)repliers.count, 2,
			"only messageSenderUser entries count as repliers; an anonymous messageSenderChat replier is dropped");
	TGTestExpectEqualLongLong(&outcome, [repliers[0] longLongValue], 1001,
			"the first user replier id must round-trip in order");

	NSDictionary *withoutDiscussion = @{
		@"@type" : @"message",
		@"id" : @5000000021,
		@"sender_id" : @{@"@type" : @"messageSenderChat", @"chat_id" : @3001},
		@"chat_id" : @3001,
		@"is_outgoing" : @NO,
		@"is_channel_post" : @YES,
		@"date" : @1700000021,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"no comments here", @"entities" : @[]},
		},
	};

	NSDictionary *bareFlat = TGFlattenMessage(withoutDiscussion, TGFlattenMessageTestContext());
	TGTestExpectEqualLongLong(&outcome, [bareFlat[@"commentCount"] longLongValue], 0,
			"a channel post with no reply_info at all must flatten to zero comments, not crash");
	TGTestExpectTrue(&outcome, ![bareFlat[@"hasCommentThread"] boolValue],
			"a channel post with no linked discussion group carries no comment thread");

	NSDictionary *freshDiscussion = @{
		@"@type" : @"message",
		@"id" : @5000000022,
		@"sender_id" : @{@"@type" : @"messageSenderChat", @"chat_id" : @3001},
		@"chat_id" : @3001,
		@"is_outgoing" : @NO,
		@"is_channel_post" : @YES,
		@"date" : @1700000022,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"first post", @"entities" : @[]},
		},
		@"interaction_info" : @{
			@"@type" : @"messageInteractionInfo",
			@"view_count" : @10,
			@"reply_info" : @{
				@"@type" : @"messageReplyInfo",
				@"reply_count" : @0,
				@"last_message_id" : @0,
				@"recent_replier_ids" : @[],
			},
		},
	};

	NSDictionary *freshFlat = TGFlattenMessage(freshDiscussion, TGFlattenMessageTestContext());
	TGTestExpectEqualLongLong(&outcome, [freshFlat[@"commentCount"] longLongValue], 0,
			"a linked discussion group with no comments yet still flattens to zero, not a missing field");
	TGTestExpectTrue(&outcome, [freshFlat[@"hasCommentThread"] boolValue],
			"a channel post with a linked discussion group has a thread even before the first comment arrives");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensMessageEffectId(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *withEffect = @{
		@"@type" : @"message",
		@"id" : @5000000030,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000030,
		@"effect_id" : @1234567890123,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"party time", @"entities" : @[]},
		},
	};
	NSDictionary *flat = TGFlattenMessage(withEffect, TGFlattenMessageTestContext());
	TGTestExpectEqualLongLong(&outcome, [flat[@"effectId"] longLongValue], 1234567890123LL,
			"a message's effect_id must round-trip into effectId");

	NSDictionary *withoutEffect = @{
		@"@type" : @"message",
		@"id" : @5000000031,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000031,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"ordinary message", @"entities" : @[]},
		},
	};
	NSDictionary *bareFlat = TGFlattenMessage(withoutEffect, TGFlattenMessageTestContext());
	TGTestExpectEqualLongLong(&outcome, [bareFlat[@"effectId"] longLongValue], 0,
			"a message with no effect_id at all must flatten to zero, not crash");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensSlotMachineDice(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *message = @{
		@"@type" : @"message",
		@"id" : @5000000040,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000040,
		@"content" : @{
			@"@type" : @"messageDice",
			@"emoji" : @"🎰",
			@"value" : @64,
			@"final_state" : @{
				@"@type" : @"diceStickersSlotMachine",
				@"background" : @{
					@"@type" : @"sticker",
					@"format" : @{@"@type" : @"stickerFormatWebp"},
					@"sticker" : @{@"@type" : @"file", @"id" : @901},
					@"width" : @512, @"height" : @512, @"set_id" : @123,
				},
				@"lever" : @{
					@"@type" : @"sticker",
					@"format" : @{@"@type" : @"stickerFormatWebp"},
					@"sticker" : @{@"@type" : @"file", @"id" : @902},
					@"width" : @512, @"height" : @512, @"set_id" : @123,
				},
				@"left_reel" : @{
					@"@type" : @"sticker",
					@"format" : @{@"@type" : @"stickerFormatWebp"},
					@"sticker" : @{@"@type" : @"file", @"id" : @903},
					@"width" : @512, @"height" : @512, @"set_id" : @123,
				},
				@"center_reel" : @{
					@"@type" : @"sticker",
					@"format" : @{@"@type" : @"stickerFormatWebp"},
					@"sticker" : @{@"@type" : @"file", @"id" : @904},
					@"width" : @512, @"height" : @512, @"set_id" : @123,
				},
				@"right_reel" : @{
					@"@type" : @"sticker",
					@"format" : @{@"@type" : @"stickerFormatWebp"},
					@"sticker" : @{@"@type" : @"file", @"id" : @905},
					@"width" : @512, @"height" : @512, @"set_id" : @123,
				},
			},
		},
	};

	NSDictionary *flat = TGFlattenMessage(message, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"messageDice"],
			"a slot-machine dice must still flatten to the messageDice kind");
	TGTestExpectEqualLongLong(&outcome, [flat[@"photoId"] longLongValue], 904,
			"a slot-machine result must show its center_reel sticker, not the background or an empty slot");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensSenderIdentity(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *fromUser = @{
		@"@type" : @"message",
		@"id" : @5000000041,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000041,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"from a user", @"entities" : @[]},
		},
	};

	NSDictionary *userFlat = TGFlattenMessage(fromUser, TGFlattenMessageTestContext());
	TGTestExpectEqualLongLong(&outcome, [userFlat[@"senderId"] longLongValue], 1001,
			"a messageSenderUser must flatten its user_id into senderId");
	TGTestExpectEqualLongLong(&outcome, [userFlat[@"senderChatId"] longLongValue], 0,
			"a messageSenderUser must flatten to a zero senderChatId, not the missing chat_id");

	NSDictionary *fromChat = @{
		@"@type" : @"message",
		@"id" : @5000000042,
		@"sender_id" : @{@"@type" : @"messageSenderChat", @"chat_id" : @3003},
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000042,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"sent as a channel identity", @"entities" : @[]},
		},
	};

	NSDictionary *chatFlat = TGFlattenMessage(fromChat, TGFlattenMessageTestContext());
	TGTestExpectEqualLongLong(&outcome, [chatFlat[@"senderId"] longLongValue], 0,
			"a messageSenderChat must not collapse into a fake user id of the chat_id");
	TGTestExpectEqualLongLong(&outcome, [chatFlat[@"senderChatId"] longLongValue], 3003,
			"a messageSenderChat must flatten its chat_id into senderChatId so the identity is not lost");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensSchedulingState(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *scheduled = @{
		@"@type" : @"message",
		@"id" : @5000000043,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @YES,
		@"date" : @1700000043,
		@"scheduling_state" : @{@"@type" : @"messageSchedulingStateSendAtDate", @"send_date" : @1800000000},
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"send me later", @"entities" : @[]},
		},
	};

	TGTestExpectTrue(&outcome, TGMessageIsScheduled(scheduled),
			"a raw message with a populated scheduling_state must be recognised as scheduled");
	NSDictionary *scheduledFlat = TGFlattenMessage(scheduled, TGFlattenMessageTestContext());
	TGTestExpectTrue(&outcome, [scheduledFlat[@"scheduled"] boolValue],
			"a scheduled message's flattened form must carry a true scheduled flag");

	NSDictionary *ordinary = @{
		@"@type" : @"message",
		@"id" : @5000000044,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @YES,
		@"date" : @1700000044,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"send me now", @"entities" : @[]},
		},
	};

	TGTestExpectTrue(&outcome, !TGMessageIsScheduled(ordinary),
			"a raw message with no scheduling_state must not be recognised as scheduled");
	NSDictionary *ordinaryFlat = TGFlattenMessage(ordinary, TGFlattenMessageTestContext());
	TGTestExpectTrue(&outcome, ![ordinaryFlat[@"scheduled"] boolValue],
			"an ordinary message's flattened form must carry a false scheduled flag");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestFlattensCaptionAboveMediaAndLinkPreviewOptions(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *photoAboveMedia = @{
		@"@type" : @"message",
		@"id" : @5000000045,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @YES,
		@"date" : @1700000045,
		@"content" : @{
			@"@type" : @"messagePhoto",
			@"photo" : @{
				@"@type" : @"photo",
				@"sizes" : @[
					@{@"@type" : @"photoSize", @"type" : @"m",
					  @"photo" : @{@"@type" : @"file", @"id" : @556},
					  @"width" : @800, @"height" : @600},
				],
			},
			@"caption" : @{@"@type" : @"formattedText", @"text" : @"above the photo", @"entities" : @[]},
			@"show_caption_above_media" : @YES,
		},
	};

	NSDictionary *aboveFlat = TGFlattenMessage(photoAboveMedia, TGFlattenMessageTestContext());
	TGTestExpectTrue(&outcome, [aboveFlat[@"captionAboveMedia"] boolValue],
			"a photo whose caption was placed above the media must flatten captionAboveMedia true, "
			"so an unrelated edit can preserve it instead of silently moving the caption below");

	NSDictionary *photoBelowMedia = @{
		@"@type" : @"message",
		@"id" : @5000000046,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @YES,
		@"date" : @1700000046,
		@"content" : @{
			@"@type" : @"messagePhoto",
			@"photo" : @{
				@"@type" : @"photo",
				@"sizes" : @[
					@{@"@type" : @"photoSize", @"type" : @"m",
					  @"photo" : @{@"@type" : @"file", @"id" : @557},
					  @"width" : @800, @"height" : @600},
				],
			},
			@"caption" : @{@"@type" : @"formattedText", @"text" : @"below the photo", @"entities" : @[]},
		},
	};

	NSDictionary *belowFlat = TGFlattenMessage(photoBelowMedia, TGFlattenMessageTestContext());
	TGTestExpectTrue(&outcome, ![belowFlat[@"captionAboveMedia"] boolValue],
			"a photo with no show_caption_above_media key must flatten captionAboveMedia false, not crash or default true");

	NSDictionary *textWithCustomPreview = @{
		@"@type" : @"message",
		@"id" : @5000000047,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @YES,
		@"date" : @1700000047,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"check example.com", @"entities" : @[]},
			@"link_preview_options" : @{
				@"@type" : @"linkPreviewOptions",
				@"is_disabled" : @YES,
				@"url" : @"",
				@"force_small_media" : @NO,
				@"force_large_media" : @NO,
				@"show_above_text" : @NO,
			},
		},
	};

	NSDictionary *previewFlat = TGFlattenMessage(textWithCustomPreview, TGFlattenMessageTestContext());
	TGTestExpectTrue(&outcome, [previewFlat[@"linkPreviewOptions"] isKindOfClass:NSDictionary.class],
			"a text message's link_preview_options must flatten to a dictionary the edit path can replay unchanged");
	TGTestExpectTrue(&outcome, [previewFlat[@"linkPreviewOptions"][@"is_disabled"] boolValue],
			"a text message whose preview was explicitly disabled must flatten that state so an unrelated edit can preserve it");

	NSDictionary *textWithoutPreviewOptions = @{
		@"@type" : @"message",
		@"id" : @5000000048,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @YES,
		@"date" : @1700000048,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"no preview key at all", @"entities" : @[]},
		},
	};

	NSDictionary *noPreviewFlat = TGFlattenMessage(textWithoutPreviewOptions, TGFlattenMessageTestContext());
	TGTestExpectTrue(&outcome, noPreviewFlat[@"linkPreviewOptions"] == [NSNull null],
			"a text message with no link_preview_options key must flatten to NSNull, not crash or fabricate one");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestSendErrorMessageReadsSlowModeFromChatsById(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *failedSending = @{
		@"@type" : @"messageSendingStateFailed",
		@"error" : @{@"code" : @429, @"message" : @"Too Many Requests: retry after 300"},
		@"retry_after" : @300.0,
	};

	NSDictionary *messageInSlowModeChat = @{
		@"@type" : @"message",
		@"id" : @5000000049,
		@"sender_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"chat_id" : @2001,
		@"is_outgoing" : @YES,
		@"date" : @1700000049,
		@"sending_state" : failedSending,
		@"content" : @{
			@"@type" : @"messageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : @"rate limited", @"entities" : @[]},
		},
	};

	TGFlattenContext *slowModeContext = TGFlattenMessageTestContext();
	NSMutableDictionary *chatsById = [slowModeContext.chatsById mutableCopy];
	NSMutableDictionary *slowModeChat = [chatsById[@2001] mutableCopy];
	slowModeChat[@"slowModeDelay"] = @300;
	chatsById[@2001] = slowModeChat;
	slowModeContext.chatsById = chatsById;

	NSDictionary *flatInSlowModeChat = TGFlattenMessage(messageInSlowModeChat, slowModeContext);
	NSDictionary *flatWithoutSlowMode = TGFlattenMessage(messageInSlowModeChat, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome,
			[flatInSlowModeChat[@"sendErrorMessage"] isKindOfClass:NSString.class] &&
					[flatInSlowModeChat[@"sendErrorMessage"] length] > 0,
			"a failed send in a chat with a known slow mode delay must surface a non-empty error message");
	TGTestExpectTrue(&outcome,
			![flatInSlowModeChat[@"sendErrorMessage"] isEqualToString:flatWithoutSlowMode[@"sendErrorMessage"]],
			"the same failed-send error must read differently once context.chatsById reports slow mode active for the chat");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestCallCarriesItsTitleAndDurationApart(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *answered = @{
		@"id" : @9101,
		@"chat_id" : @2001,
		@"is_outgoing" : @YES,
		@"date" : @1700000060,
		@"content" : @{
			@"@type" : @"messageCall",
			@"is_video" : @NO,
			@"duration" : @5412,
			@"discard_reason" : @{@"@type" : @"callDiscardReasonHungUp"},
		},
	};
	NSDictionary *flatAnswered = TGFlattenMessage(answered, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome,
			[flatAnswered[@"callTitle"] isEqualToString:@"Outgoing Call"],
			"a call carries its title on its own, so the chat bubble never has to parse it back "
			"out of a sentence that another language writes differently");
	TGTestExpectEqualLongLong(&outcome, [flatAnswered[@"callDuration"] integerValue], 5412,
			"and its length in seconds, rather than as words inside brackets");
	TGTestExpectTrue(&outcome,
			[flatAnswered[@"extra"] rangeOfString:@"Outgoing Call"].location != NSNotFound,
			"the one-line form the chat list shows still reads as before");

	NSDictionary *missed = @{
		@"id" : @9102,
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000061,
		@"content" : @{
			@"@type" : @"messageCall",
			@"is_video" : @YES,
			@"duration" : @0,
			@"discard_reason" : @{@"@type" : @"callDiscardReasonMissed"},
		},
	};
	NSDictionary *flatMissed = TGFlattenMessage(missed, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome,
			[flatMissed[@"callTitle"] isEqualToString:@"Missed Video Call"],
			"a missed video call names itself as one");
	TGTestExpectEqualLongLong(&outcome, [flatMissed[@"callDuration"] integerValue], 0,
			"a missed call has no length to show");

	NSDictionary *missedWithDuration = @{
		@"id" : @9103,
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000062,
		@"content" : @{
			@"@type" : @"messageCall",
			@"is_video" : @NO,
			@"duration" : @17,
			@"discard_reason" : @{@"@type" : @"callDiscardReasonMissed"},
		},
	};
	NSDictionary *flatMissedWithDuration =
			TGFlattenMessage(missedWithDuration, TGFlattenMessageTestContext());

	TGTestExpectEqualLongLong(&outcome,
			[flatMissedWithDuration[@"callDuration"] integerValue], 0,
			"a missed call that the server still gave a duration shows none, the way the "
			"one-line form has always behaved");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestDisappearingMediaSaysSoInTheChatList(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *ordinaryPhoto = @{
		@"id" : @9201,
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000070,
		@"content" : @{@"@type" : @"messagePhoto"},
	};
	TGTestExpectTrue(&outcome,
			[TGMessagePreview(ordinaryPhoto, TGFlattenMessageTestContext())
					isEqualToString:@"Photo"],
			"an ordinary photo reads as a photo in the chat list");

	NSDictionary *secretPhoto = @{
		@"id" : @9202,
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000071,
		@"content" : @{@"@type" : @"messagePhoto", @"is_secret" : @YES},
	};
	TGTestExpectTrue(&outcome,
			[TGMessagePreview(secretPhoto, TGFlattenMessageTestContext())
					isEqualToString:@"Disappearing Photo"],
			"a photo that disappears says so, the way the notification for it already did");

	NSDictionary *viewOnceVideo = @{
		@"id" : @9203,
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000072,
		@"content" : @{@"@type" : @"messageVideo",
			@"self_destruct_type" : @{@"@type" : @"messageSelfDestructTypeImmediately"}},
	};
	TGTestExpectTrue(&outcome,
			[TGMessagePreview(viewOnceVideo, TGFlattenMessageTestContext())
					isEqualToString:@"Disappearing Video"],
			"a view-once video does too, whether the server marks it secret or self-destructing");

	NSDictionary *captionedSecretPhoto = @{
		@"id" : @9204,
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000073,
		@"content" : @{@"@type" : @"messagePhoto", @"is_secret" : @YES,
			@"caption" : @{@"text" : @"look at this"}},
	};
	TGTestExpectTrue(&outcome,
			[TGMessagePreview(captionedSecretPhoto, TGFlattenMessageTestContext())
					isEqualToString:@"Disappearing Photo"],
			"and its caption stays inside the chat rather than being repeated in the list, "
			"where a passer-by would read what the sender meant to show once");

	NSDictionary *captionedPhoto = @{
		@"id" : @9205,
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000074,
		@"content" : @{@"@type" : @"messagePhoto", @"caption" : @{@"text" : @"look at this"}},
	};
	TGTestExpectTrue(&outcome,
			[TGMessagePreview(captionedPhoto, TGFlattenMessageTestContext())
					isEqualToString:@"look at this"],
			"an ordinary photo still previews by its caption");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestADisappearingCaptionNeverLeavesTheChat(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *viewOncePhoto = @{
		@"id" : @9301,
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000080,
		@"content" : @{@"@type" : @"messagePhoto",
			@"caption" : @{@"text" : @"the words meant to be seen once"},
			@"self_destruct_type" : @{@"@type" : @"messageSelfDestructTypeImmediately"}},
	};
	NSDictionary *flat = TGFlattenMessage(viewOncePhoto, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@"Disappearing Photo"],
			"the row's own text names the kind, where the caption used to stand in for it and "
			"was then repeated by the reply bar, the pinned banner and every search result");
	TGTestExpectTrue(&outcome, [flat[@"captionText"] isEqualToString:@""],
			"and the caption is not carried alongside it either");

	NSDictionary *ordinaryPhoto = @{
		@"id" : @9302,
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000081,
		@"content" : @{@"@type" : @"messagePhoto",
			@"caption" : @{@"text" : @"an ordinary caption"}},
	};
	NSDictionary *ordinary = TGFlattenMessage(ordinaryPhoto, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome, [ordinary[@"text"] isEqualToString:@"an ordinary caption"],
			"an ordinary photo still carries its caption as its text");
	TGTestExpectTrue(&outcome, [ordinary[@"captionText"] isEqualToString:@"an ordinary caption"],
			"and alongside it");

	NSDictionary *replyToSecret = @{
		@"id" : @9303,
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000082,
		@"content" : @{@"@type" : @"messageText",
			@"text" : @{@"text" : @"answering", @"entities" : @[]}},
		@"reply_to" : @{@"@type" : @"messageReplyToMessage",
			@"message_id" : @9301,
			@"chat_id" : @2001,
			@"content" : @{@"@type" : @"messagePhoto", @"is_secret" : @YES,
				@"caption" : @{@"text" : @"the words meant to be seen once"}}},
	};
	NSDictionary *reply = TGFlattenMessage(replyToSecret, TGFlattenMessageTestContext());

	TGTestExpectTrue(&outcome,
			[reply[@"replyKindLabel"] isEqualToString:@"Disappearing Photo"],
			"a reply to a disappearing photo names it as one in the quote bar");
	TGTestExpectTrue(&outcome,
			[reply[@"replyText"] rangeOfString:@"meant to be seen once"].location == NSNotFound,
			"and does not quote the caption the sender meant to be seen once");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestAReplyNamesEveryKindItCanQuote(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *(^replyTo)(NSDictionary *) = ^NSDictionary *(NSDictionary *repliedContent) {
		return @{
			@"id" : @9401,
			@"chat_id" : @2001,
			@"is_outgoing" : @NO,
			@"date" : @1700000090,
			@"content" : @{@"@type" : @"messageText",
				@"text" : @{@"text" : @"answering", @"entities" : @[]}},
			@"reply_to" : @{@"@type" : @"messageReplyToMessage",
				@"message_id" : @9400,
				@"chat_id" : @2001,
				@"content" : repliedContent},
		};
	};

	NSDictionary *venue = TGFlattenMessage(replyTo(@{@"@type" : @"messageVenue"}),
			TGFlattenMessageTestContext());
	TGTestExpectTrue(&outcome, [venue[@"replyKindLabel"] isEqualToString:@"Location"],
			"a reply to a venue names it, where the quote line used to sit on an ellipsis that "
			"never resolved because the original had no text of its own");

	NSDictionary *checklist = TGFlattenMessage(replyTo(@{@"@type" : @"messageChecklist"}),
			TGFlattenMessageTestContext());
	TGTestExpectTrue(&outcome, [checklist[@"replyKindLabel"] isEqualToString:@"Checklist"],
			"a reply to a checklist names it");

	NSDictionary *call = TGFlattenMessage(replyTo(@{@"@type" : @"messageCall",
		@"is_video" : @NO,
		@"discard_reason" : @{@"@type" : @"callDiscardReasonHungUp"}}),
			TGFlattenMessageTestContext());
	TGTestExpectTrue(&outcome, [call[@"replyKindLabel"] isEqualToString:@"Incoming Call"],
			"a reply to a call names the call, in the same words the bubble uses");

	NSDictionary *missedVideoCall = TGFlattenMessage(replyTo(@{@"@type" : @"messageCall",
		@"is_video" : @YES,
		@"discard_reason" : @{@"@type" : @"callDiscardReasonMissed"}}),
			TGFlattenMessageTestContext());
	TGTestExpectTrue(&outcome,
			[missedVideoCall[@"replyKindLabel"] isEqualToString:@"Missed Video Call"],
			"and a missed video call the same way");

	NSDictionary *groupCall = TGFlattenMessage(replyTo(@{@"@type" : @"messageGroupCall",
		@"was_missed" : @NO}), TGFlattenMessageTestContext());
	TGTestExpectTrue(&outcome,
			[groupCall[@"replyKindLabel"] isEqualToString:@"Incoming Group Call"],
			"a group call too");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestPaidAndUnsupportedKindsAreNamedEverywhere(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *paid = @{
		@"id" : @9501,
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000100,
		@"content" : @{@"@type" : @"messagePaidMedia", @"star_count" : @50},
	};
	TGTestExpectTrue(&outcome,
			[TGMessagePreview(paid, TGFlattenMessageTestContext())
					isEqualToString:@"Paid media"],
			"a paid post names itself in the chat list rather than falling through to the "
			"unsupported line");

	NSDictionary *unsupported = @{
		@"id" : @9502,
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000101,
		@"content" : @{@"@type" : @"messageUnsupported"},
	};
	TGTestExpectTrue(&outcome,
			[TGMessagePreview(unsupported, TGFlattenMessageTestContext())
					rangeOfString:@"not supported"].location != NSNotFound,
			"a kind this build cannot draw says so in the chat list");

	NSDictionary *replyToPaid = @{
		@"id" : @9503,
		@"chat_id" : @2001,
		@"is_outgoing" : @NO,
		@"date" : @1700000102,
		@"content" : @{@"@type" : @"messageText",
			@"text" : @{@"text" : @"answering", @"entities" : @[]}},
		@"reply_to" : @{@"@type" : @"messageReplyToMessage",
			@"message_id" : @9501,
			@"chat_id" : @2001,
			@"content" : @{@"@type" : @"messagePaidMedia", @"star_count" : @50}},
	};
	TGTestExpectTrue(&outcome,
			[TGFlattenMessage(replyToPaid, TGFlattenMessageTestContext())[@"replyKindLabel"]
					isEqualToString:@"Paid media"],
			"and the quote bar names it too, where it used to hold an ellipsis for a message "
			"that had already arrived");

	return outcome;
}

TGTestOutcome TGFlattenMessageTestTheSharedKindTableNamesWhatEachSurfaceNeeds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGMessageContentKindLabel(@{@"@type" : @"messageChecklist"})
					isEqualToString:@"Checklist"],
			"the table every surface now falls through to names a checklist");
	TGTestExpectTrue(&outcome,
			[TGMessageContentKindLabel(@{@"@type" : @"messageExpiredVideoNote"})
					isEqualToString:@"Expired video message"],
			"and an expired round note");
	TGTestExpectTrue(&outcome,
			[TGMessageContentKindLabel(@{@"@type" : @"messagePhoto", @"is_secret" : @YES})
					isEqualToString:@"Disappearing Photo"],
			"and names a disappearing photo before anything reaches for its caption");
	TGTestExpectTrue(&outcome,
			TGMessageContentKindLabel(@{@"@type" : @"messageSomethingTelegramAddedLater"}) == nil,
			"a kind it has never heard of returns nothing, which is each caller's cue to use "
			"its own wording");
	TGTestExpectTrue(&outcome, TGMessageContentKindLabel(nil) == nil,
			"and so does no content at all");

	return outcome;
}

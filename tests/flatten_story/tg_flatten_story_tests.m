#import "tg_flatten_story_tests.h"
#import "../../src/Wire/Flatten/TGFlattenStory.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenStoryTestAreaFlattensLocation(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"storyArea",
		@"position" : @{
			@"@type" : @"storyAreaPosition",
			@"x_percentage" : @10.0,
			@"y_percentage" : @20.0,
			@"width_percentage" : @30.0,
			@"height_percentage" : @40.0,
			@"rotation_angle" : @5.0,
			@"corner_radius_percentage" : @2.0,
		},
		@"type" : @{
			@"@type" : @"storyAreaTypeLocation",
			@"location" : @{@"@type" : @"location", @"latitude" : @37.5, @"longitude" : @-122.4},
			@"address" : @{@"@type" : @"locationAddress", @"city" : @"Springfield"},
		},
	};

	NSDictionary *flat = TGStoryAreaFlattened(raw);

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"location"],
			"a storyAreaTypeLocation must flatten with kind \"location\"");
	TGTestExpectEqualDouble(&outcome, [flat[@"latitude"] doubleValue], 37.5, 0.0001,
			"a location area's latitude must round-trip");
	TGTestExpectEqualDouble(&outcome, [flat[@"longitude"] doubleValue], -122.4, 0.0001,
			"a location area's longitude must round-trip");
	TGTestExpectTrue(&outcome, [flat[@"title"] isEqualToString:@"Springfield"],
			"a location area's title must come from address.city");
	TGTestExpectEqualDouble(&outcome, [flat[@"x"] doubleValue], 10.0, 0.0001,
			"a location area's x position must round-trip");
	TGTestExpectEqualDouble(&outcome, [flat[@"width"] doubleValue], 30.0, 0.0001,
			"a location area's width must round-trip");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestAreaFlattensVenue(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"storyArea",
		@"position" : @{@"@type" : @"storyAreaPosition"},
		@"type" : @{
			@"@type" : @"storyAreaTypeVenue",
			@"venue" : @{
				@"@type" : @"venue",
				@"title" : @"Coffee Shop",
				@"provider" : @"foursquare",
				@"id" : @"venue123",
				@"location" : @{@"@type" : @"location", @"latitude" : @1.0, @"longitude" : @2.0},
			},
		},
	};

	NSDictionary *flat = TGStoryAreaFlattened(raw);

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"venue"],
			"a storyAreaTypeVenue must flatten with kind \"venue\"");
	TGTestExpectTrue(&outcome, [flat[@"title"] isEqualToString:@"Coffee Shop"],
			"a venue area's title must come from venue.title");
	TGTestExpectTrue(&outcome, [flat[@"venueProvider"] isEqualToString:@"foursquare"],
			"a venue area's provider must round-trip");
	TGTestExpectTrue(&outcome, [flat[@"venueId"] isEqualToString:@"venue123"],
			"a venue area's id must round-trip");
	TGTestExpectEqualDouble(&outcome, [flat[@"latitude"] doubleValue], 1.0, 0.0001,
			"a venue area's latitude must come from its nested location");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestAreaFlattensReaction(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"storyArea",
		@"position" : @{@"@type" : @"storyAreaPosition"},
		@"type" : @{
			@"@type" : @"storyAreaTypeSuggestedReaction",
			@"reaction_type" : @{@"@type" : @"reactionTypeEmoji", @"emoji" : @"\U0001F525"},
		},
	};

	NSDictionary *flat = TGStoryAreaFlattened(raw);

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"reaction"],
			"a storyAreaTypeSuggestedReaction must flatten with kind \"reaction\"");
	TGTestExpectTrue(&outcome, [flat[@"emoji"] isEqualToString:@"\U0001F525"],
			"a reaction area's emoji must round-trip from reaction_type.emoji");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestAreaFlattensMessage(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"storyArea",
		@"position" : @{@"@type" : @"storyAreaPosition"},
		@"type" : @{
			@"@type" : @"storyAreaTypeMessage",
			@"chat_id" : @9001,
			@"message_id" : @123456,
		},
	};

	NSDictionary *flat = TGStoryAreaFlattened(raw);

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"message"],
			"a storyAreaTypeMessage must flatten with kind \"message\"");
	TGTestExpectEqualLongLong(&outcome, [flat[@"chatId"] longLongValue], 9001,
			"a message area's chat id must round-trip");
	TGTestExpectEqualLongLong(&outcome, [flat[@"messageId"] longLongValue], 123456,
			"a message area's message id must round-trip");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestAreaFlattensLink(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"storyArea",
		@"position" : @{@"@type" : @"storyAreaPosition"},
		@"type" : @{@"@type" : @"storyAreaTypeLink", @"url" : @"https://example.com"},
	};

	NSDictionary *flat = TGStoryAreaFlattened(raw);

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"link"],
			"a storyAreaTypeLink must flatten with kind \"link\"");
	TGTestExpectTrue(&outcome, [flat[@"url"] isEqualToString:@"https://example.com"],
			"a link area's url must round-trip");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestAreaFlattensWeather(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"storyArea",
		@"position" : @{@"@type" : @"storyAreaPosition"},
		@"type" : @{@"@type" : @"storyAreaTypeWeather", @"emoji" : @"\U00002600", @"temperature" : @21.6},
	};

	NSDictionary *flat = TGStoryAreaFlattened(raw);

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"weather"],
			"a storyAreaTypeWeather must flatten with kind \"weather\"");
	TGTestExpectTrue(&outcome, [flat[@"emoji"] isEqualToString:@"\U00002600"],
			"a weather area's emoji must round-trip");
	TGTestExpectTrue(&outcome, [flat[@"title"] isEqualToString:@"22°"],
			"a weather area's title must be its temperature rounded to a whole degree");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestAreaFlattensUpgradedGift(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"storyArea",
		@"position" : @{@"@type" : @"storyAreaPosition"},
		@"type" : @{@"@type" : @"storyAreaTypeUpgradedGift", @"gift_name" : @"Golden Star"},
	};

	NSDictionary *flat = TGStoryAreaFlattened(raw);

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"gift"],
			"a storyAreaTypeUpgradedGift must flatten with kind \"gift\"");
	TGTestExpectTrue(&outcome, [flat[@"title"] isEqualToString:@"Golden Star"],
			"an upgraded gift area's title must come from gift_name");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestAreaUnknownTypeFallsThroughSafely(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"storyArea",
		@"position" : @{@"@type" : @"storyAreaPosition"},
		@"type" : @{@"@type" : @"storyAreaTypeSomethingFuture"},
	};

	NSDictionary *flat = TGStoryAreaFlattened(raw);

	TGTestExpectTrue(&outcome, flat != nil,
			"an unrecognised area type must still flatten to a dictionary, not nil");
	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"unsupported"],
			"an unrecognised area type must flatten with kind \"unsupported\"");
	TGTestExpectTrue(&outcome, [flat[@"url"] isEqualToString:@""],
			"an unsupported area must default its url to an empty string, not crash");
	TGTestExpectEqualLongLong(&outcome, [flat[@"latitude"] longLongValue], 0,
			"an unsupported area must default its latitude to zero");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestAreaNilRawReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGStoryAreaFlattened(nil) == nil,
			"a nil raw area must flatten to nil, not crash");
	TGTestExpectTrue(&outcome, TGStoryAreaFlattened((NSDictionary *)@"not a dict") == nil,
			"a malformed non-dictionary raw area must flatten to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestFlattensPhotoStory(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"story",
		@"id" : @777,
		@"poster_chat_id" : @2001,
		@"poster_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"date" : @1700000000,
		@"caption" : @{@"@type" : @"formattedText", @"text" : @"hi there"},
		@"content" : @{
			@"@type" : @"storyContentPhoto",
			@"photo" : @{
				@"@type" : @"photo",
				@"sizes" : @[
					@{@"@type" : @"photoSize", @"photo" : @{@"@type" : @"file", @"id" : @55}},
					@{@"@type" : @"photoSize", @"photo" : @{@"@type" : @"file", @"id" : @66}},
				],
			},
		},
		@"privacy_settings" : @{@"@type" : @"storyPrivacySettingsEveryone", @"except_user_ids" : @[]},
	};

	NSDictionary *flat = TGStoryFlattened(raw);

	TGTestExpectTrue(&outcome, flat != nil,
			"a well-formed photo story must flatten to a dictionary, not nil");
	TGTestExpectEqualLongLong(&outcome, [flat[@"id"] longLongValue], 777,
			"a story's id must round-trip");
	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"photo"],
			"a storyContentPhoto must flatten with kind \"photo\"");
	TGTestExpectEqualLongLong(&outcome, [flat[@"photoId"] longLongValue], 66,
			"a photo story's photoId must come from the last size in the sizes array");
	TGTestExpectEqualLongLong(&outcome, [flat[@"senderId"] longLongValue], 1001,
			"a story posted by a user sender must expose that user id as senderId");
	TGTestExpectTrue(&outcome, [flat[@"caption"] isEqualToString:@"hi there"],
			"a story's caption text must round-trip");
	TGTestExpectTrue(&outcome, [flat[@"privacy"] isEqualToString:@"everyone"],
			"a storyPrivacySettingsEveryone story must flatten with privacy \"everyone\"");
	TGTestExpectTrue(&outcome, flat[@"videoId"] == nil,
			"a photo story must not carry a videoId key at all");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestFlattensVideoStory(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"story",
		@"id" : @778,
		@"poster_chat_id" : @2001,
		@"poster_id" : @{@"@type" : @"messageSenderChat", @"chat_id" : @3001},
		@"date" : @1700000001,
		@"content" : @{
			@"@type" : @"storyContentVideo",
			@"video" : @{
				@"@type" : @"storyVideo",
				@"video" : @{@"@type" : @"file", @"id" : @88},
				@"duration" : @9.5,
				@"width" : @1080,
				@"height" : @1920,
				@"thumbnail" : @{@"@type" : @"thumbnail", @"file" : @{@"@type" : @"file", @"id" : @89}},
			},
		},
	};

	NSDictionary *flat = TGStoryFlattened(raw);

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"video"],
			"a storyContentVideo must flatten with kind \"video\"");
	TGTestExpectEqualLongLong(&outcome, [flat[@"videoId"] longLongValue], 88,
			"a video story's videoId must come from video.video.id");
	TGTestExpectEqualLongLong(&outcome, [flat[@"photoId"] longLongValue], 89,
			"a video story's thumbnail file id must become its photoId");
	TGTestExpectEqualDouble(&outcome, [flat[@"duration"] doubleValue], 9.5, 0.0001,
			"a video story's duration must round-trip");
	TGTestExpectEqualInteger(&outcome, [flat[@"width"] integerValue], 1080,
			"a video story's width must round-trip");
	TGTestExpectEqualLongLong(&outcome, [flat[@"senderId"] longLongValue], 3001,
			"a story posted by a chat sender must expose that chat id as senderId");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestFlattensLiveStory(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"story",
		@"id" : @779,
		@"poster_chat_id" : @2001,
		@"content" : @{@"@type" : @"storyContentLive"},
	};

	NSDictionary *flat = TGStoryFlattened(raw);

	TGTestExpectTrue(&outcome, [flat[@"kind"] isEqualToString:@"live"],
			"a storyContentLive must flatten with kind \"live\"");
	TGTestExpectTrue(&outcome, flat[@"photoId"] == nil,
			"a live story must not carry a photoId key");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestFlattensRepostedStory(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"story",
		@"id" : @780,
		@"poster_chat_id" : @2001,
		@"content" : @{@"@type" : @"storyContentPhoto", @"photo" : @{@"@type" : @"photo", @"sizes" : @[]}},
		@"repost_info" : @{
			@"@type" : @"storyRepostInfo",
			@"origin" : @{@"@type" : @"storyOriginHiddenUser", @"poster_name" : @"Anonymous Fox"},
		},
	};

	NSDictionary *flat = TGStoryFlattened(raw);

	TGTestExpectTrue(&outcome, [flat[@"repostFrom"] isEqualToString:@"Anonymous Fox"],
			"a repost from a hidden user must expose that poster name as repostFrom");

	NSDictionary *notReposted = @{
		@"@type" : @"story",
		@"id" : @781,
		@"poster_chat_id" : @2001,
		@"content" : @{@"@type" : @"storyContentPhoto", @"photo" : @{@"@type" : @"photo", @"sizes" : @[]}},
	};
	NSDictionary *plainFlat = TGStoryFlattened(notReposted);
	TGTestExpectTrue(&outcome, [plainFlat[@"repostFrom"] isEqualToString:@""],
			"a story with no repost_info must default repostFrom to an empty string");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestFlattensStoryWithAreas(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"story",
		@"id" : @782,
		@"poster_chat_id" : @2001,
		@"content" : @{@"@type" : @"storyContentPhoto", @"photo" : @{@"@type" : @"photo", @"sizes" : @[]}},
		@"areas" : @[
			@{
				@"@type" : @"storyArea",
				@"position" : @{@"@type" : @"storyAreaPosition"},
				@"type" : @{@"@type" : @"storyAreaTypeLink", @"url" : @"https://a.example"},
			},
			@"not a dictionary",
			@{
				@"@type" : @"storyArea",
				@"position" : @{@"@type" : @"storyAreaPosition"},
				@"type" : @{@"@type" : @"storyAreaTypeLink", @"url" : @"https://b.example"},
			},
		],
	};

	NSDictionary *flat = TGStoryFlattened(raw);
	NSArray *areas = flat[@"areas"];

	TGTestExpectEqualInteger(&outcome, areas.count, 2,
			"a malformed area entry inside the areas array must be dropped, not crash the whole story");
	TGTestExpectTrue(&outcome, [areas[0][@"url"] isEqualToString:@"https://a.example"],
			"the first valid area must survive in order");
	TGTestExpectTrue(&outcome, [areas[1][@"url"] isEqualToString:@"https://b.example"],
			"the second valid area must survive in order after the malformed one is skipped");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestMissingIdReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGStoryFlattened(nil) == nil,
			"a nil raw story must flatten to nil, not crash");
	TGTestExpectTrue(&outcome, TGStoryFlattened(@{@"poster_chat_id" : @2001}) == nil,
			"a story dictionary with no id must flatten to nil");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestArrayDropsInvalidEntries(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *list = @[
		@{@"@type" : @"story", @"id" : @900, @"content" : @{@"@type" : @"storyContentLive"}},
		@{@"poster_chat_id" : @2001},
		@"garbage",
		@{@"@type" : @"story", @"id" : @901, @"content" : @{@"@type" : @"storyContentLive"}},
	];

	NSArray *flat = TGStoriesFlattened(list);

	TGTestExpectEqualInteger(&outcome, flat.count, 2,
			"entries missing an id or of the wrong type must be dropped from the flattened array");
	TGTestExpectEqualLongLong(&outcome, [flat[0][@"id"] longLongValue], 900,
			"surviving entries must keep their original relative order");
	TGTestExpectEqualLongLong(&outcome, [flat[1][@"id"] longLongValue], 901,
			"the second surviving entry must follow the first");

	NSArray *empty = TGStoriesFlattened(nil);
	TGTestExpectEqualInteger(&outcome, empty.count, 0,
			"a nil list must flatten to an empty array, not crash");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestAlbumFlattensValid(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *flat = TGStoryAlbumFlattened(@{@"@type" : @"storyAlbum", @"id" : @55, @"name" : @"Trips"});

	TGTestExpectEqualLongLong(&outcome, [flat[@"id"] longLongValue], 55,
			"a story album's id must round-trip");
	TGTestExpectTrue(&outcome, [flat[@"name"] isEqualToString:@"Trips"],
			"a story album's name must round-trip");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestAlbumMissingIdReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGStoryAlbumFlattened(@{@"name" : @"Untitled"}) == nil,
			"a story album with no id must flatten to nil, not fabricate one");
	TGTestExpectTrue(&outcome, TGStoryAlbumFlattened(nil) == nil,
			"a nil raw album must flatten to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestErrorTextFloodWaitBoundaries(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"FLOOD_WAIT_59"})
					isEqualToString:@"Too many attempts. Try again in 59 seconds."],
			"59 seconds must stay in the seconds bucket");
	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"FLOOD_WAIT_60"})
					isEqualToString:@"Too many attempts. Try again in 60 seconds."],
			"exactly 60 seconds must still report in seconds, not round up to a minute");
	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"FLOOD_WAIT_61"})
					isEqualToString:@"Too many attempts. Try again in 1 minutes."],
			"61 seconds must cross into the minutes bucket");
	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"FLOOD_WAIT_3599"})
					isEqualToString:@"Too many attempts. Try again in 59 minutes."],
			"3599 seconds must still report in minutes, not hours");
	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"FLOOD_WAIT_3600"})
					isEqualToString:@"Too many attempts. Try again in 60 minutes."],
			"exactly 3600 seconds must still report in minutes, not round up to an hour");
	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"FLOOD_WAIT_3601"})
					isEqualToString:@"Too many attempts. Try again in 1 hours."],
			"3601 seconds must cross into the hours bucket");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestErrorTextKnownCodes(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"STORY_SEND_FLOOD_WEEKLY_5"})
					isEqualToString:@"The weekly story limit has been reached."],
			"a STORY_SEND_FLOOD_WEEKLY_ prefixed code must map to the weekly limit text");
	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"STORY_SEND_FLOOD_MONTHLY_5"})
					isEqualToString:@"The monthly story limit has been reached."],
			"a STORY_SEND_FLOOD_MONTHLY_ prefixed code must map to the monthly limit text");
	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"STORIES_TOO_MUCH"})
					isEqualToString:@"Too many active stories. Delete one first."],
			"STORIES_TOO_MUCH must map to the active-story-limit text");
	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"PREMIUM_ACCOUNT_REQUIRED"})
					isEqualToString:@"This needs Telegram Premium."],
			"PREMIUM_ACCOUNT_REQUIRED must map to the Premium-required text");
	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"STORY_PERIOD_INVALID"})
					isEqualToString:@"That expiry needs Telegram Premium. Post for 24 hours instead."],
			"STORY_PERIOD_INVALID must map to the expiry-needs-Premium text");
	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"BOOSTS_REQUIRED"})
					isEqualToString:@"This channel needs more boosts before it can post stories."],
			"BOOSTS_REQUIRED must map to the boosts-needed text");
	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"CHAT_ADMIN_REQUIRED"})
					isEqualToString:@"You are not allowed to post stories here."],
			"CHAT_ADMIN_REQUIRED must map to the not-allowed text");
	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"CHAT_WRITE_FORBIDDEN"})
					isEqualToString:@"You are not allowed to post stories here."],
			"CHAT_WRITE_FORBIDDEN must map to the same not-allowed text as CHAT_ADMIN_REQUIRED");
	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"PHOTO_INVALID_DIMENSIONS"})
					isEqualToString:@"Telegram rejected that picture."],
			"PHOTO_INVALID_DIMENSIONS must map to the picture-rejected text");
	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"VIDEO_FILE_INVALID"})
					isEqualToString:@"Telegram rejected that video. Stories need a short MP4."],
			"VIDEO_FILE_INVALID must map to the video-rejected text");
	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"VIDEO_CONTENT_TYPE_INVALID"})
					isEqualToString:@"Telegram rejected that video. Stories need a short MP4."],
			"any VIDEO_ prefixed code must map to the same video-rejected text");
	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"Request timeout"})
					isEqualToString:@"The connection dropped before the story went out."],
			"a bare \"Request timeout\" message must map to the connection-dropped text");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestErrorTextUnknownMessagePassesThrough(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{@"message" : @"SOME_FUTURE_ERROR_CODE"})
					isEqualToString:@"SOME_FUTURE_ERROR_CODE"],
			"an unrecognised error message must pass through verbatim rather than being swallowed");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestErrorTextMissingMessageUsesDefault(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(@{}) isEqualToString:@"The story could not be posted."],
			"an error dictionary with no message must fall back to the generic posting-failed text");
	TGTestExpectTrue(&outcome,
			[TGStoryErrorText(nil) isEqualToString:@"The story could not be posted."],
			"a nil error must fall back to the generic posting-failed text, not crash");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestLimitReasonKnownVariants(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStoryLimitReason(@"canPostStoryResultPremiumNeeded")
					isEqualToString:@"Posting more stories requires Telegram Premium."],
			"canPostStoryResultPremiumNeeded must map to the Premium-needed text");
	TGTestExpectTrue(&outcome,
			[TGStoryLimitReason(@"canPostStoryResultBoostNeeded")
					isEqualToString:@"This channel needs more boosts before it can post stories."],
			"canPostStoryResultBoostNeeded must map to the boosts-needed text");
	TGTestExpectTrue(&outcome,
			[TGStoryLimitReason(@"canPostStoryResultActiveStoryLimitExceeded")
					isEqualToString:@"Too many active stories. Delete one first."],
			"canPostStoryResultActiveStoryLimitExceeded must map to the active-limit text");
	TGTestExpectTrue(&outcome,
			[TGStoryLimitReason(@"canPostStoryResultWeeklyLimitExceeded")
					isEqualToString:@"The weekly story limit has been reached."],
			"canPostStoryResultWeeklyLimitExceeded must map to the weekly-limit text");
	TGTestExpectTrue(&outcome,
			[TGStoryLimitReason(@"canPostStoryResultMonthlyLimitExceeded")
					isEqualToString:@"The monthly story limit has been reached."],
			"canPostStoryResultMonthlyLimitExceeded must map to the monthly-limit text");
	TGTestExpectTrue(&outcome,
			[TGStoryLimitReason(@"canPostStoryResultLiveStoryIsActive")
					isEqualToString:@"A live story is still running."],
			"canPostStoryResultLiveStoryIsActive must map to the live-story-running text");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestLimitReasonUnknownFallsBackToGenericText(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStoryLimitReason(@"canPostStoryResultSomeFutureVariant")
					isEqualToString:@"Stories cannot be posted right now."],
			"an unrecognised limit reason must fall back to the generic cannot-post text");
	TGTestExpectTrue(&outcome,
			[TGStoryLimitReason(nil) isEqualToString:@"Stories cannot be posted right now."],
			"a nil limit reason type must fall back to the generic cannot-post text, not crash");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestPrivacyRoundTripsEveryVariant(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *closeFriends = TGStoryPrivacyRules(@"closeFriends", nil);
	TGTestExpectTrue(&outcome,
			[closeFriends[@"@type"] isEqualToString:@"storyPrivacySettingsCloseFriends"],
			"\"closeFriends\" must build a storyPrivacySettingsCloseFriends dictionary");
	TGTestExpectTrue(&outcome,
			[TGStoryPrivacyName(closeFriends) isEqualToString:@"closeFriends"],
			"a storyPrivacySettingsCloseFriends dictionary must name back to \"closeFriends\"");

	NSDictionary *selected = TGStoryPrivacyRules(@"selected", @[@1001, @1002]);
	TGTestExpectTrue(&outcome,
			[selected[@"@type"] isEqualToString:@"storyPrivacySettingsSelectedUsers"],
			"\"selected\" must build a storyPrivacySettingsSelectedUsers dictionary");
	TGTestExpectEqualInteger(&outcome, [selected[@"user_ids"] count], 2,
			"\"selected\" privacy must carry the given user ids through as user_ids");
	TGTestExpectTrue(&outcome,
			[TGStoryPrivacyName(selected) isEqualToString:@"selected"],
			"a storyPrivacySettingsSelectedUsers dictionary must name back to \"selected\"");

	NSDictionary *contacts = TGStoryPrivacyRules(@"contacts", @[@1003]);
	TGTestExpectTrue(&outcome,
			[contacts[@"@type"] isEqualToString:@"storyPrivacySettingsContacts"],
			"\"contacts\" must build a storyPrivacySettingsContacts dictionary");
	TGTestExpectEqualInteger(&outcome, [contacts[@"except_user_ids"] count], 1,
			"\"contacts\" privacy must carry the given user ids through as except_user_ids");
	TGTestExpectTrue(&outcome,
			[TGStoryPrivacyName(contacts) isEqualToString:@"contacts"],
			"a storyPrivacySettingsContacts dictionary must name back to \"contacts\"");

	NSDictionary *everyone = TGStoryPrivacyRules(@"everyone", nil);
	TGTestExpectTrue(&outcome,
			[everyone[@"@type"] isEqualToString:@"storyPrivacySettingsEveryone"],
			"\"everyone\" must build a storyPrivacySettingsEveryone dictionary");
	TGTestExpectTrue(&outcome,
			[TGStoryPrivacyName(everyone) isEqualToString:@"everyone"],
			"a storyPrivacySettingsEveryone dictionary must name back to \"everyone\"");

	NSDictionary *unknownFallback = TGStoryPrivacyRules(@"something-unrecognised", nil);
	TGTestExpectTrue(&outcome,
			[unknownFallback[@"@type"] isEqualToString:@"storyPrivacySettingsEveryone"],
			"an unrecognised app-level privacy string must fall back to storyPrivacySettingsEveryone");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestPrivacyNameUnknownTypeReturnsEmpty(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStoryPrivacyName(@{@"@type" : @"storyPrivacySettingsSomethingFuture"}) isEqualToString:@""],
			"an unrecognised TDLib privacy variant must name back to an empty string, not crash");
	TGTestExpectTrue(&outcome,
			[TGStoryPrivacyName(nil) isEqualToString:@""],
			"a nil privacy settings dictionary must name back to an empty string, not crash");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestFlattenExposesPrivacyUserIdLists(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *selectedRaw = @{
		@"@type" : @"story",
		@"id" : @901,
		@"poster_chat_id" : @2001,
		@"poster_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"content" : @{@"@type" : @"storyContentLive"},
		@"privacy_settings" : @{
			@"@type" : @"storyPrivacySettingsSelectedUsers",
			@"user_ids" : @[@11, @12],
		},
	};
	NSDictionary *selectedFlat = TGStoryFlattened(selectedRaw);
	TGTestExpectEqualInteger(&outcome, [selectedFlat[@"privacyUserIds"] count], 2,
			"a storyPrivacySettingsSelectedUsers story must expose its user_ids as privacyUserIds");
	TGTestExpectEqualInteger(&outcome, [selectedFlat[@"privacyExceptUserIds"] count], 0,
			"a storyPrivacySettingsSelectedUsers story must expose an empty privacyExceptUserIds, not crash");

	NSDictionary *contactsRaw = @{
		@"@type" : @"story",
		@"id" : @902,
		@"poster_chat_id" : @2001,
		@"poster_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"content" : @{@"@type" : @"storyContentLive"},
		@"privacy_settings" : @{
			@"@type" : @"storyPrivacySettingsContacts",
			@"except_user_ids" : @[@21],
		},
	};
	NSDictionary *contactsFlat = TGStoryFlattened(contactsRaw);
	TGTestExpectEqualInteger(&outcome, [contactsFlat[@"privacyExceptUserIds"] count], 1,
			"a storyPrivacySettingsContacts story must expose its except_user_ids as privacyExceptUserIds, so the exclusion list can survive a re-opened privacy editor");
	TGTestExpectEqualInteger(&outcome, [contactsFlat[@"privacyUserIds"] count], 0,
			"a storyPrivacySettingsContacts story must expose an empty privacyUserIds, not crash");

	NSDictionary *closeFriendsRaw = @{
		@"@type" : @"story",
		@"id" : @903,
		@"poster_chat_id" : @2001,
		@"poster_id" : @{@"@type" : @"messageSenderUser", @"user_id" : @1001},
		@"content" : @{@"@type" : @"storyContentLive"},
		@"privacy_settings" : @{@"@type" : @"storyPrivacySettingsCloseFriends"},
	};
	NSDictionary *closeFriendsFlat = TGStoryFlattened(closeFriendsRaw);
	TGTestExpectEqualInteger(&outcome, [closeFriendsFlat[@"privacyUserIds"] count], 0,
			"a storyPrivacySettingsCloseFriends story must expose an empty privacyUserIds, not crash");
	TGTestExpectEqualInteger(&outcome, [closeFriendsFlat[@"privacyExceptUserIds"] count], 0,
			"a storyPrivacySettingsCloseFriends story must expose an empty privacyExceptUserIds, not crash");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestReactionEmojiExtractsAndFallsBack(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGStoryReactionEmoji(@{@"@type" : @"reactionTypeEmoji", @"emoji" : @"\U0001F44D"})
					isEqualToString:@"\U0001F44D"],
			"a reactionTypeEmoji dictionary's emoji must round-trip");
	TGTestExpectTrue(&outcome,
			[TGStoryReactionEmoji(nil) isEqualToString:@""],
			"a nil reaction type must return an empty string, not crash");
	TGTestExpectTrue(&outcome,
			[TGStoryReactionEmoji(@{}) isEqualToString:@""],
			"a reaction type with no emoji key must return an empty string");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestLargestPhotoIdPicksLastSize(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *photo = @{
		@"@type" : @"photo",
		@"sizes" : @[
			@{@"@type" : @"photoSize", @"photo" : @{@"@type" : @"file", @"id" : @101}},
			@{@"@type" : @"photoSize", @"photo" : @{@"@type" : @"file", @"id" : @102}},
			@{@"@type" : @"photoSize", @"photo" : @{@"@type" : @"file", @"id" : @103}},
		],
	};

	TGTestExpectEqualLongLong(&outcome, [TGStoryLargestPhotoId(photo) longLongValue], 103,
			"the largest photo id must come from the last entry in the sizes array");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestLargestPhotoIdEmptySizesReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGStoryLargestPhotoId(@{@"sizes" : @[]}) == nil,
			"a photo with an empty sizes array must return nil, not crash");
	TGTestExpectTrue(&outcome, TGStoryLargestPhotoId(nil) == nil,
			"a nil photo must return nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestNetworkTypeMapsAllVariants(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGStoryNetworkType(@"wifi") isEqualToString:@"networkTypeWiFi"],
			"\"wifi\" must map to networkTypeWiFi");
	TGTestExpectTrue(&outcome, [TGStoryNetworkType(@"WiFi") isEqualToString:@"networkTypeWiFi"],
			"network type matching must be case-insensitive");
	TGTestExpectTrue(&outcome, [TGStoryNetworkType(@"roaming") isEqualToString:@"networkTypeMobileRoaming"],
			"\"roaming\" must map to networkTypeMobileRoaming");
	TGTestExpectTrue(&outcome,
			[TGStoryNetworkType(@"mobileroaming") isEqualToString:@"networkTypeMobileRoaming"],
			"\"mobileroaming\" must also map to networkTypeMobileRoaming");
	TGTestExpectTrue(&outcome, [TGStoryNetworkType(@"other") isEqualToString:@"networkTypeOther"],
			"\"other\" must map to networkTypeOther");
	TGTestExpectTrue(&outcome, [TGStoryNetworkType(@"none") isEqualToString:@"networkTypeNone"],
			"\"none\" must map to networkTypeNone");
	TGTestExpectTrue(&outcome, [TGStoryNetworkType(@"cellular") isEqualToString:@"networkTypeMobile"],
			"an unrecognised network type must fall back to networkTypeMobile");
	TGTestExpectTrue(&outcome, [TGStoryNetworkType(nil) isEqualToString:@"networkTypeMobile"],
			"a nil network type must fall back to networkTypeMobile, not crash");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestSenderIdHandlesUserAndChat(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualLongLong(&outcome,
			TGStorySenderId(@{@"@type" : @"messageSenderUser", @"user_id" : @1001}), 1001,
			"a messageSenderUser dictionary must expose its user_id as the sender id");
	TGTestExpectEqualLongLong(&outcome,
			TGStorySenderId(@{@"@type" : @"messageSenderChat", @"chat_id" : @3001}), 3001,
			"a messageSenderChat dictionary must expose its chat_id as the sender id");
	TGTestExpectEqualLongLong(&outcome, TGStorySenderId(nil), 0,
			"a nil sender must resolve to zero, not crash");
	TGTestExpectEqualLongLong(&outcome, TGStorySenderId(@{}), 0,
			"a sender dictionary with neither a recognised type nor an id must resolve to zero");

	return outcome;
}

TGTestOutcome TGFlattenStoryTestFlattenCarriesTheAlbumPermission(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *allowed = TGStoryFlattened(@{
		@"id" : @7,
		@"can_be_added_to_album" : @YES,
		@"can_be_deleted" : @YES
	});
	TGTestExpectTrue(&outcome, [allowed[@"canAddToAlbum"] boolValue],
			"a story the server says may be added to an album says so after flattening");

	NSDictionary *refused = TGStoryFlattened(@{@"id" : @7, @"can_be_added_to_album" : @NO});
	TGTestExpectTrue(&outcome, ![refused[@"canAddToAlbum"] boolValue],
			"a story that may not be added to an album must not offer the action");

	NSDictionary *silent = TGStoryFlattened(@{@"id" : @7});
	TGTestExpectTrue(&outcome, silent[@"canAddToAlbum"] != nil &&
					![silent[@"canAddToAlbum"] boolValue],
			"the key is always present so the menu never reads a missing permission as allowed");

	return outcome;
}

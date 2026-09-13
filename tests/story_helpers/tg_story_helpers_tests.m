#import "tg_story_helpers_tests.h"
#import "../../src/Companions/TGStoryHelpers.h"

TGTestOutcome TGStoryHelpersTestReadersTolerateEveryWireShape(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *story = @{
		@"name" : @"Ada",
		@"id" : @17,
		@"chatId" : @(-1001234567890LL),
		@"archived" : @YES,
		@"numericName" : @41,
		@"stringId" : @"17"
	};

	TGTestExpectTrue(&outcome, [TGStoryString(story, @"name") isEqualToString:@"Ada"],
			"a string reads back as itself");
	TGTestExpectTrue(&outcome, [TGStoryString(story, @"numericName") isEqualToString:@""],
			"a number where a string was expected reads as empty, never as a stringified number");
	TGTestExpectTrue(&outcome, [TGStoryString(story, @"missing") isEqualToString:@""],
			"an absent key reads as empty rather than nil");
	TGTestExpectTrue(&outcome, [TGStoryString(nil, @"name") isEqualToString:@""],
			"a nil story must not crash a reader");

	TGTestExpectTrue(&outcome, TGStoryNumber(story, @"id") == 17, "a number reads back as itself");
	TGTestExpectTrue(&outcome, TGStoryNumber(story, @"stringId") == 17,
			"an int64 arriving as a string still reads as a number");
	TGTestExpectTrue(&outcome, TGStoryNumber(story, @"missing") == 0, "an absent number reads as zero");

	TGTestExpectTrue(&outcome, TGStoryChatId(story, @"chatId") == -1001234567890LL,
			"a chat id keeps every one of its digits");
	TGTestExpectTrue(&outcome, TGStoryChatId(story, @"missing") == 0, "an absent chat id reads as zero");

	TGTestExpectTrue(&outcome, TGStoryFlag(story, @"archived"), "a set flag reads as set");
	TGTestExpectTrue(&outcome, !TGStoryFlag(story, @"missing"), "an absent flag reads as clear");

	return outcome;
}

TGTestOutcome TGStoryHelpersTestAgeTextIsEmptyWithoutADate(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGStoryAgeText(0) isEqualToString:@""],
			"a story with no date shows no age rather than the epoch");
	TGTestExpectTrue(&outcome, [TGStoryAgeText(-1) isEqualToString:@""],
			"a negative date is no date");
	TGTestExpectTrue(&outcome, TGStoryAgeText((int)time(NULL)).length > 0,
			"a story posted now has an age to show");

	return outcome;
}

TGTestOutcome TGStoryHelpersTestPosterEntryCarriesEveryStoryId(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *entry = TGStoryPosterEntry(77, @"Ada", @{
		@"stories" : @[ @{@"id" : @3}, @{@"id" : @5}, @{@"id" : @8} ],
		@"order" : @9
	});
	TGTestExpectTrue(&outcome, entry != nil, "a poster with stories has an entry");
	TGTestExpectTrue(&outcome, [entry[@"chatId"] longLongValue] == 77, "the entry keeps the chat id");
	TGTestExpectTrue(&outcome, [entry[@"title"] isEqualToString:@"Ada"], "the entry keeps the title");
	TGTestExpectTrue(&outcome, [entry[@"order"] integerValue] == 9, "the entry keeps the server's order");
	TGTestExpectTrue(&outcome,
			[entry[@"ids"] isEqualToArray:(@[ @3, @5, @8 ])],
			"every story id is carried, in the order the server sent them");

	NSDictionary *mixed = TGStoryPosterEntry(77, @"Ada", @{
		@"stories" : @[ @{@"id" : @3}, @"not a story", @{@"id" : @5} ]
	});
	TGTestExpectTrue(&outcome, [mixed[@"ids"] isEqualToArray:(@[ @3, @5 ])],
			"an element of the wrong type is skipped rather than crashing the tray");

	return outcome;
}

TGTestOutcome TGStoryHelpersTestPosterEntryRefusesArchivedAndEmptyPosters(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			TGStoryPosterEntry(77, @"Ada", @{@"stories" : @[ @{@"id" : @3} ], @"archived" : @YES}) == nil,
			"an archived poster never reaches the tray");
	TGTestExpectTrue(&outcome, TGStoryPosterEntry(77, @"Ada", @{@"stories" : @[]}) == nil,
			"a poster with no stories has no entry");
	TGTestExpectTrue(&outcome, TGStoryPosterEntry(77, @"Ada", @{}) == nil,
			"a poster with no stories key at all has no entry");
	TGTestExpectTrue(&outcome, TGStoryPosterEntry(77, @"Ada", nil) == nil,
			"a nil active-stories reply has no entry");
	TGTestExpectTrue(&outcome, TGStoryPosterEntry(77, @"Ada", @{@"stories" : @"none"}) == nil,
			"a stories field that is not an array has no entry");
	TGTestExpectTrue(&outcome, TGStoryPosterEntry(77, @"Ada", @{@"stories" : @[ @"not a story" ]}) == nil,
			"a poster whose only story is unreadable has no entry rather than an empty one");

	return outcome;
}

TGTestOutcome TGStoryHelpersTestPosterEntryDefaultsTheOrder(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *unordered = TGStoryPosterEntry(77, @"Ada", @{@"stories" : @[ @{@"id" : @3} ]});
	TGTestExpectTrue(&outcome, [unordered[@"order"] integerValue] == 0,
			"a poster the server sent no order for sorts as zero, not as nil in the dictionary");
	TGTestExpectTrue(&outcome, unordered[@"order"] != nil,
			"the order key is always present so the tray's sort never reads a missing value");

	return outcome;
}

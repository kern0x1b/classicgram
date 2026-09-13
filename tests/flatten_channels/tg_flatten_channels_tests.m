#import "tg_flatten_channels_tests.h"
#import "../../src/Wire/Flatten/TGFlattenChannels.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenChannelsTestGraphFlattensStatisticalGraphData(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"statisticalGraphData",
		@"json_data" : @"{\"columns\":[]}",
		@"zoom_token" : @"tok123",
	};

	NSDictionary *flat = TGChGraph(@"member_count_graph", @"Growth", raw);

	TGTestExpectTrue(&outcome, flat != nil,
			"a statisticalGraphData payload must flatten to a non-nil dictionary");
	TGTestExpectTrue(&outcome, [flat[@"key"] isEqualToString:@"member_count_graph"],
			"the flattened graph's key must be the caller-supplied key, not derived from the payload");
	TGTestExpectTrue(&outcome, [flat[@"title"] isEqualToString:@"Growth"],
			"the flattened graph's title must be the caller-supplied title");
	TGTestExpectTrue(&outcome, [flat[@"json"] isEqualToString:@"{\"columns\":[]}"],
			"a statisticalGraphData's json must round-trip from json_data");
	TGTestExpectTrue(&outcome, [flat[@"zoom_token"] isEqualToString:@"tok123"],
			"a statisticalGraphData's zoom_token must round-trip verbatim");
	TGTestExpectTrue(&outcome, flat[@"token"] == nil,
			"a statisticalGraphData branch must not produce the async branch's token key");

	return outcome;
}

TGTestOutcome TGFlattenChannelsTestGraphFlattensStatisticalGraphAsync(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"statisticalGraphAsync",
		@"token" : @"async-token-1",
	};

	NSDictionary *flat = TGChGraph(@"join_graph", @"Followers", raw);

	TGTestExpectTrue(&outcome, flat != nil,
			"a statisticalGraphAsync payload must flatten to a non-nil dictionary");
	TGTestExpectTrue(&outcome, [flat[@"key"] isEqualToString:@"join_graph"],
			"the async graph's key must be the caller-supplied key");
	TGTestExpectTrue(&outcome, [flat[@"title"] isEqualToString:@"Followers"],
			"the async graph's title must be the caller-supplied title");
	TGTestExpectTrue(&outcome, [flat[@"token"] isEqualToString:@"async-token-1"],
			"a statisticalGraphAsync's token must round-trip verbatim");
	TGTestExpectTrue(&outcome, flat[@"json"] == nil,
			"a statisticalGraphAsync branch must not produce the data branch's json key");

	return outcome;
}

TGTestOutcome TGFlattenChannelsTestGraphReturnsNilForUnknownTypeOrNonDictionary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *unknown = @{@"@type" : @"statisticalGraphSomethingElse"};

	TGTestExpectTrue(&outcome, TGChGraph(@"k", @"t", unknown) == nil,
			"an unrecognised graph @type must flatten to nil, not a partially-filled dictionary");
	TGTestExpectTrue(&outcome, TGChGraph(@"k", @"t", nil) == nil,
			"a nil raw graph must flatten to nil, not crash");
	TGTestExpectTrue(&outcome, TGChGraph(@"k", @"t", @"not a dictionary") == nil,
			"a non-dictionary raw graph must flatten to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenChannelsTestGraphFlattensStatisticalGraphError(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"@type" : @"statisticalGraphError",
		@"error_message" : @"start date is too far in the past",
	};

	NSDictionary *flat = TGChGraph(@"join_graph", @"Followers", raw);

	TGTestExpectTrue(&outcome, flat != nil,
			"a statisticalGraphError payload must flatten to a non-nil dictionary, not be treated as absent");
	TGTestExpectTrue(&outcome, [flat[@"key"] isEqualToString:@"join_graph"],
			"the error graph's key must be the caller-supplied key");
	TGTestExpectTrue(&outcome, [flat[@"title"] isEqualToString:@"Followers"],
			"the error graph's title must be the caller-supplied title");
	TGTestExpectTrue(&outcome, [flat[@"error"] isEqualToString:@"start date is too far in the past"],
			"a statisticalGraphError's error must round-trip from error_message");
	TGTestExpectTrue(&outcome, flat[@"json"] == nil,
			"a statisticalGraphError branch must not produce the data branch's json key");
	TGTestExpectTrue(&outcome, flat[@"token"] == nil,
			"a statisticalGraphError branch must not produce the async branch's token key");

	return outcome;
}

TGTestOutcome TGFlattenChannelsTestValueFlattensRealisticPayload(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *raw = @{
		@"value" : @1500,
		@"previous_value" : @1200,
		@"growth_rate_percentage" : @25,
	};

	NSDictionary *flat = TGChValue(@"member_count", @"Followers", raw);

	TGTestExpectTrue(&outcome, [flat[@"key"] isEqualToString:@"member_count"],
			"the flattened value's key must be the caller-supplied key");
	TGTestExpectTrue(&outcome, [flat[@"title"] isEqualToString:@"Followers"],
			"the flattened value's title must be the caller-supplied title");
	TGTestExpectEqualInteger(&outcome, [flat[@"value"] integerValue], 1500,
			"the flattened value's value must round-trip from value");
	TGTestExpectEqualInteger(&outcome, [flat[@"previous"] integerValue], 1200,
			"the flattened value's previous must round-trip from previous_value");
	TGTestExpectEqualInteger(&outcome, [flat[@"growth"] integerValue], 25,
			"the flattened value's growth must round-trip from growth_rate_percentage");

	return outcome;
}

TGTestOutcome TGFlattenChannelsTestValueReturnsNilForNonDictionaryInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGChValue(@"k", @"t", nil) == nil,
			"a nil raw value must flatten to nil, not crash");
	TGTestExpectTrue(&outcome, TGChValue(@"k", @"t", @42) == nil,
			"a non-dictionary raw value must flatten to nil, not crash");

	return outcome;
}

TGTestOutcome TGFlattenChannelsTestAddGraphsCollectsMultipleEntriesAndSkipsMissing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *stats = @{
		@"member_count_graph" : @{@"@type" : @"statisticalGraphData", @"json_data" : @"{}", @"zoom_token" : @""},
		@"join_graph" : @{@"@type" : @"statisticalGraphAsync", @"token" : @"tok"},
	};
	NSArray *pairs = @[
		@"member_count_graph", @"Growth",
		@"join_graph", @"Followers",
		@"mute_graph", @"Notifications",
	];

	NSMutableArray *out = [NSMutableArray array];
	TGChAddGraphs(out, stats, pairs);

	TGTestExpectEqualInteger(&outcome, out.count, 2,
			"only the pairs whose key is present in stats must produce an entry, missing keys must be skipped silently");
	TGTestExpectTrue(&outcome, [out[0][@"key"] isEqualToString:@"member_count_graph"],
			"the first collected graph must preserve the pairs order");
	TGTestExpectTrue(&outcome, [out[1][@"key"] isEqualToString:@"join_graph"],
			"the second collected graph must preserve the pairs order");

	return outcome;
}

TGTestOutcome TGFlattenChannelsTestAddGraphsHandlesEmptyPairs(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSMutableArray *out = [NSMutableArray array];
	TGChAddGraphs(out, @{}, @[]);

	TGTestExpectEqualInteger(&outcome, out.count, 0,
			"an empty pairs array must leave the output array empty, not crash");

	return outcome;
}

TGTestOutcome TGFlattenChannelsTestAddValuesCollectsMultipleEntriesAndSkipsMissing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *stats = @{
		@"member_count" : @{@"value" : @100, @"previous_value" : @90, @"growth_rate_percentage" : @11},
		@"message_count" : @{@"value" : @500, @"previous_value" : @400, @"growth_rate_percentage" : @25},
	};
	NSArray *pairs = @[
		@"member_count", @"Members",
		@"message_count", @"Messages",
		@"viewer_count", @"Viewing Members",
	];

	NSMutableArray *out = [NSMutableArray array];
	TGChAddValues(out, stats, pairs);

	TGTestExpectEqualInteger(&outcome, out.count, 2,
			"only the pairs whose key is present in stats must produce an entry, missing keys must be skipped silently");
	TGTestExpectTrue(&outcome, [out[0][@"key"] isEqualToString:@"member_count"],
			"the first collected value must preserve the pairs order");
	TGTestExpectTrue(&outcome, [out[1][@"key"] isEqualToString:@"message_count"],
			"the second collected value must preserve the pairs order");

	return outcome;
}

TGTestOutcome TGFlattenChannelsTestAddValuesHandlesEmptyPairs(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSMutableArray *out = [NSMutableArray array];
	TGChAddValues(out, @{}, @[]);

	TGTestExpectEqualInteger(&outcome, out.count, 0,
			"an empty pairs array must leave the output array empty, not crash");

	return outcome;
}

TGTestOutcome TGFlattenChannelsTestBoostSlotNeverUsedIsFreeAndAvailable(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *slot = TGChBoostSlot(0, 0, 1000);

	TGTestExpectTrue(&outcome, [slot[@"is_free"] boolValue],
			"a slot with no currently boosted chat must be free");
	TGTestExpectTrue(&outcome, [slot[@"is_available"] boolValue],
			"a free slot must always be available");
	TGTestExpectTrue(&outcome, ![slot[@"is_reassignable"] boolValue],
			"a free slot must never be reported as reassignable, since there is nothing to reassign away from");

	return outcome;
}

TGTestOutcome TGFlattenChannelsTestBoostSlotBoostingAnotherChatInCooldownIsCommitted(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *slot = TGChBoostSlot(555, 2000, 1000);

	TGTestExpectTrue(&outcome, ![slot[@"is_free"] boolValue],
			"a slot currently boosting another chat must not be reported free");
	TGTestExpectTrue(&outcome, ![slot[@"is_available"] boolValue],
			"a slot whose cooldown has not yet lapsed must not be available");
	TGTestExpectTrue(&outcome, ![slot[@"is_reassignable"] boolValue],
			"a slot still in cooldown must not be offered as reassignable");

	return outcome;
}

TGTestOutcome TGFlattenChannelsTestBoostSlotBoostingAnotherChatAfterCooldownIsReassignableNotFree(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *slot = TGChBoostSlot(555, 500, 1000);

	TGTestExpectTrue(&outcome, ![slot[@"is_free"] boolValue],
			"a slot boosting another chat must never be reported free, even once its cooldown has lapsed, "
			"since applying it would silently move the boost off that chat");
	TGTestExpectTrue(&outcome, [slot[@"is_available"] boolValue],
			"a slot past its cooldown must be reported available");
	TGTestExpectTrue(&outcome, [slot[@"is_reassignable"] boolValue],
			"a slot boosting another chat past its cooldown is the reassignable case");

	return outcome;
}

TGTestOutcome TGFlattenChannelsTestBoostSlotCooldownBoundaryEqualsNowIsAvailable(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *slot = TGChBoostSlot(555, 1000, 1000);

	TGTestExpectTrue(&outcome, [slot[@"is_available"] boolValue],
			"a cooldown that has just lapsed (equal to now) must count as available");
	TGTestExpectTrue(&outcome, [slot[@"is_reassignable"] boolValue],
			"a cooldown boundary of exactly now must still be reassignable for a chat-bound slot");

	return outcome;
}

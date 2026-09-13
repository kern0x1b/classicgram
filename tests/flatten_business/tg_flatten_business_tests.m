#import "tg_flatten_business_tests.h"
#import "../../src/Wire/Flatten/TGFlattenBusiness.h"
#import <Foundation/Foundation.h>

TGTestOutcome TGFlattenBusinessTestOpeningHoursClampsMinuteZero(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *hours = @{
		@"time_zone_id" : @"UTC",
		@"opening_hours" : @[ @{@"start_minute" : @0, @"end_minute" : @540} ],
	};

	NSDictionary *flat = TGBizOpeningHoursFrom(hours);
	NSArray *days = flat[@"days"];
	NSDictionary *day0 = days[0];

	TGTestExpectTrue(&outcome, [flat[@"timeZoneId"] isEqualToString:@"UTC"],
			"the composed hours dict's timeZoneId must round-trip from time_zone_id");
	TGTestExpectTrue(&outcome, [day0[@"open"] boolValue],
			"an interval starting exactly at minute 0 must mark its day open");
	TGTestExpectEqualInteger(&outcome, [day0[@"startMinute"] integerValue], 0,
			"an interval starting exactly at minute 0 must keep startMinute at 0, not underflow");
	TGTestExpectEqualInteger(&outcome, [day0[@"endMinute"] integerValue], 540,
			"an interval starting exactly at minute 0 must round-trip its endMinute unclamped when it fits the day");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestOpeningHoursClampsDayBoundary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSInteger day = 2;
	NSInteger start = day * 24 * 60 + 600;
	NSInteger end = (day + 1) * 24 * 60;
	NSDictionary *hours = @{
		@"opening_hours" : @[ @{@"start_minute" : @(start), @"end_minute" : @(end)} ],
	};

	NSDictionary *flat = TGBizOpeningHoursFrom(hours);
	NSArray *days = flat[@"days"];
	NSDictionary *dayEntry = days[(NSUInteger)day];

	TGTestExpectTrue(&outcome, [dayEntry[@"open"] boolValue],
			"an interval ending exactly at the day's own 24:00 boundary must still mark the day open");
	TGTestExpectEqualInteger(&outcome, [dayEntry[@"startMinute"] integerValue], 600,
			"the day-relative startMinute must subtract the day's own offset, not the wrong day's");
	TGTestExpectEqualInteger(&outcome, [dayEntry[@"endMinute"] integerValue], 24 * 60,
			"an interval ending exactly at 24:00 must land on the boundary value itself, not be clamped below it");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestOpeningHoursHandlesMinuteWrappingIntoNextDay(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSInteger day = 1;
	NSInteger start = day * 24 * 60 + 600;
	NSInteger end = day * 24 * 60 + 1500;
	NSDictionary *hours = @{
		@"opening_hours" : @[ @{@"start_minute" : @(start), @"end_minute" : @(end)} ],
	};

	NSDictionary *flat = TGBizOpeningHoursFrom(hours);
	NSArray *days = flat[@"days"];
	NSDictionary *dayEntry = days[(NSUInteger)day];
	NSDictionary *nextDayEntry = days[(NSUInteger)day + 1];

	TGTestExpectEqualInteger(&outcome, [dayEntry[@"endMinute"] integerValue], 24 * 60,
			"an end_minute that spills past its own day's 24:00 must stop that day's fragment at its own midnight");
	TGTestExpectTrue(&outcome, [nextDayEntry[@"open"] boolValue],
			"a spillover end_minute must carry the remainder onto the next day instead of dropping it");
	TGTestExpectEqualInteger(&outcome, [nextDayEntry[@"startMinute"] integerValue], 0,
			"the carried-over remainder must start at minute 0 of the next day");
	TGTestExpectEqualInteger(&outcome, [nextDayEntry[@"endMinute"] integerValue], 60,
			"the carried-over remainder must keep every minute past midnight, not just some of them");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestOpeningHoursOvernightIntervalRoundTripsWithoutTruncation(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSInteger day = 4;
	NSInteger start = day * 24 * 60 + 22 * 60;
	NSInteger end = (day + 1) * 24 * 60 + 2 * 60;
	NSDictionary *hours = @{
		@"opening_hours" : @[ @{@"start_minute" : @(start), @"end_minute" : @(end)} ],
	};

	NSDictionary *flat = TGBizOpeningHoursFrom(hours);
	NSArray *days = flat[@"days"];
	NSDictionary *friday = days[(NSUInteger)day];
	NSDictionary *saturday = days[(NSUInteger)day + 1];

	TGTestExpectTrue(&outcome, [friday[@"open"] boolValue],
			"the day an overnight interval starts on must be marked open");
	TGTestExpectEqualInteger(&outcome, [friday[@"startMinute"] integerValue], 22 * 60,
			"the starting day must keep its own startMinute unclamped");
	TGTestExpectEqualInteger(&outcome, [friday[@"endMinute"] integerValue], 24 * 60,
			"the starting day's endMinute must stop at its own midnight, not overrun it");
	TGTestExpectTrue(&outcome, [saturday[@"open"] boolValue],
			"the interval's tail past midnight must open the next day rather than being dropped");
	TGTestExpectEqualInteger(&outcome, [saturday[@"startMinute"] integerValue], 0,
			"the carried-over tail must start at minute 0 of the next day");
	TGTestExpectEqualInteger(&outcome, [saturday[@"endMinute"] integerValue], 2 * 60,
			"the carried-over tail must keep the full remainder of the original end_minute, not lose it");

	NSInteger reconstructedStart = day * 24 * 60 + [friday[@"startMinute"] integerValue];
	NSInteger reconstructedEnd = (day + 1) * 24 * 60 + [saturday[@"endMinute"] integerValue];
	TGTestExpectEqualInteger(&outcome, reconstructedStart, start,
			"reconstructing the two fragments' minutes must recover the original start_minute exactly");
	TGTestExpectEqualInteger(&outcome, reconstructedEnd, end,
			"reconstructing the two fragments' minutes must recover the original end_minute exactly, with no minutes truncated");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestOpeningHoursOvernightWrapsFromSundayToMonday(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSInteger start = 6 * 24 * 60 + 22 * 60;
	NSInteger end = 7 * 24 * 60 + 2 * 60;
	NSDictionary *hours = @{
		@"opening_hours" : @[ @{@"start_minute" : @(start), @"end_minute" : @(end)} ],
	};

	NSDictionary *flat = TGBizOpeningHoursFrom(hours);
	NSArray *days = flat[@"days"];
	NSDictionary *sunday = days[6];
	NSDictionary *monday = days[0];

	TGTestExpectTrue(&outcome, [sunday[@"open"] boolValue],
			"Sunday must stay open for the portion of the overnight interval before midnight");
	TGTestExpectEqualInteger(&outcome, [sunday[@"endMinute"] integerValue], 24 * 60,
			"Sunday's endMinute must stop at its own midnight");
	TGTestExpectTrue(&outcome, [monday[@"open"] boolValue],
			"an interval spilling past Sunday's midnight must wrap onto Monday, the recurring week's next day, not be dropped");
	TGTestExpectEqualInteger(&outcome, [monday[@"startMinute"] integerValue], 0,
			"the wrapped tail must start at minute 0 of Monday");
	TGTestExpectEqualInteger(&outcome, [monday[@"endMinute"] integerValue], 2 * 60,
			"the wrapped tail must keep its full duration, not lose minutes past the week boundary");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestOpeningHoursReturnsNilForNilInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGBizOpeningHoursFrom(nil) == nil,
			"nil opening hours must flatten to nil, not crash or fabricate a dictionary");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestOpeningHoursDefaultsUnlistedDaysClosed(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *hours = @{
		@"opening_hours" : @[ @"not a dictionary", @{@"start_minute" : @(7 * 24 * 60), @"end_minute" : @(7 * 24 * 60 + 60)} ],
	};

	NSDictionary *flat = TGBizOpeningHoursFrom(hours);
	NSArray *days = flat[@"days"];

	TGTestExpectEqualInteger(&outcome, (NSInteger)days.count, 7,
			"the flattened hours must always carry all 7 days, even with no valid intervals supplied");
	for (NSInteger day = 0; day < 7; day++) {
		NSDictionary *dayEntry = days[(NSUInteger)day];
		TGTestExpectTrue(&outcome, ![dayEntry[@"open"] boolValue],
				"a day with no matching interval must default to closed");
		TGTestExpectEqualInteger(&outcome, [dayEntry[@"startMinute"] integerValue], 9 * 60,
				"a day with no matching interval must default its startMinute to 9am");
		TGTestExpectEqualInteger(&outcome, [dayEntry[@"endMinute"] integerValue], 18 * 60,
				"a day with no matching interval must default its endMinute to 6pm");
	}

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestOpeningHoursAccumulatesSplitIntervalsInsteadOfOverwriting(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSInteger day = 3;
	NSDictionary *morning = @{
		@"start_minute" : @(day * 24 * 60 + 9 * 60),
		@"end_minute" : @(day * 24 * 60 + 12 * 60),
	};
	NSDictionary *afternoon = @{
		@"start_minute" : @(day * 24 * 60 + 13 * 60),
		@"end_minute" : @(day * 24 * 60 + 18 * 60),
	};
	NSDictionary *hours = @{@"opening_hours" : @[ morning, afternoon ]};

	NSDictionary *flat = TGBizOpeningHoursFrom(hours);
	NSArray *days = flat[@"days"];
	NSDictionary *dayEntry = days[(NSUInteger)day];
	NSArray *intervals = dayEntry[@"intervals"];

	TGTestExpectEqualInteger(&outcome, (NSInteger)intervals.count, 2,
			"a second interval landing on a day that already has one must be appended, not overwrite the first");
	TGTestExpectEqualInteger(&outcome, [intervals[0][@"startMinute"] integerValue], 9 * 60,
			"the first accumulated interval must keep its own start minute");
	TGTestExpectEqualInteger(&outcome, [intervals[0][@"endMinute"] integerValue], 12 * 60,
			"the first accumulated interval must keep its own end minute");
	TGTestExpectEqualInteger(&outcome, [intervals[1][@"startMinute"] integerValue], 13 * 60,
			"the second accumulated interval must be preserved with its own start minute, not lost");
	TGTestExpectEqualInteger(&outcome, [intervals[1][@"endMinute"] integerValue], 18 * 60,
			"the second accumulated interval must be preserved with its own end minute, not lost");
	TGTestExpectEqualInteger(&outcome, [dayEntry[@"startMinute"] integerValue], 9 * 60,
			"the day's scalar startMinute must still reflect the first interval, for callers that only understand one slot");
	TGTestExpectEqualInteger(&outcome, [dayEntry[@"endMinute"] integerValue], 12 * 60,
			"the day's scalar endMinute must still reflect the first interval, not the last one written");
	TGTestExpectTrue(&outcome, [flat[@"hasComplexSchedule"] boolValue],
			"a day carrying two intervals must mark the whole schedule as complex");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestOpeningHoursDetectsOvernightCollisionAsComplex(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *mondayNight = @{
		@"start_minute" : @(0 * 24 * 60 + 22 * 60),
		@"end_minute" : @(0 * 24 * 60 + 24 * 60),
	};
	NSDictionary *tuesdayCarryover = @{
		@"start_minute" : @(1 * 24 * 60 + 0),
		@"end_minute" : @(1 * 24 * 60 + 2 * 60),
	};
	NSDictionary *tuesdayOwnHours = @{
		@"start_minute" : @(1 * 24 * 60 + 9 * 60),
		@"end_minute" : @(1 * 24 * 60 + 18 * 60),
	};
	NSDictionary *hours = @{@"opening_hours" : @[ mondayNight, tuesdayCarryover, tuesdayOwnHours ]};

	NSDictionary *flat = TGBizOpeningHoursFrom(hours);
	NSArray *days = flat[@"days"];
	NSDictionary *monday = days[0];
	NSDictionary *tuesday = days[1];

	TGTestExpectEqualInteger(&outcome, (NSInteger)[monday[@"intervals"] count], 1,
			"Monday's own late-night interval must round-trip alone, since nothing else lands on Monday");
	TGTestExpectEqualInteger(&outcome, (NSInteger)[tuesday[@"intervals"] count], 2,
			"Tuesday must carry BOTH the overnight carryover fragment and its own normal-hours interval, not just one");
	TGTestExpectEqualInteger(&outcome, [tuesday[@"intervals"][0][@"startMinute"] integerValue], 0,
			"the overnight carryover fragment must be preserved starting at minute 0 of Tuesday");
	TGTestExpectEqualInteger(&outcome, [tuesday[@"intervals"][1][@"startMinute"] integerValue], 9 * 60,
			"Tuesday's own normal-hours interval must survive alongside the carryover, not be silently overwritten");
	TGTestExpectTrue(&outcome, [flat[@"hasComplexSchedule"] boolValue],
			"an overnight interval colliding with the next day's own hours must be flagged as a complex schedule");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestOpeningHoursSingleCarryoverIsNotFlaggedComplex(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *sundayNight = @{
		@"start_minute" : @(6 * 24 * 60 + 23 * 60),
		@"end_minute" : @(6 * 24 * 60 + 24 * 60),
	};
	NSDictionary *mondayCarryover = @{
		@"start_minute" : @(0 * 24 * 60 + 0),
		@"end_minute" : @(0 * 24 * 60 + 90),
	};
	NSDictionary *hours = @{@"opening_hours" : @[ sundayNight, mondayCarryover ]};

	NSDictionary *flat = TGBizOpeningHoursFrom(hours);
	NSArray *days = flat[@"days"];
	NSDictionary *monday = days[0];

	TGTestExpectEqualInteger(&outcome, (NSInteger)[monday[@"intervals"] count], 1,
			"a carryover fragment landing on an otherwise-closed day must not collide with anything");
	TGTestExpectTrue(&outcome, ![flat[@"hasComplexSchedule"] boolValue],
			"a genuinely simple schedule, where every day has at most one interval, must not be flagged complex");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestOpeningHoursSimpleWeeklyScheduleIsNotComplex(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSMutableArray *intervals = [NSMutableArray array];
	for (NSInteger day = 0; day < 7; day++)
		[intervals addObject:@{
			@"start_minute" : @(day * 24 * 60 + 9 * 60),
			@"end_minute" : @(day * 24 * 60 + 18 * 60),
		}];
	NSDictionary *hours = @{@"opening_hours" : intervals};

	NSDictionary *flat = TGBizOpeningHoursFrom(hours);

	TGTestExpectTrue(&outcome, ![flat[@"hasComplexSchedule"] boolValue],
			"one interval per day for all seven days must not be flagged as a complex schedule");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestAwayScheduleAlways(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *away = @{
		@"shortcut_id" : @5,
		@"recipients" : @{@"select_existing_chats" : @YES},
		@"schedule" : @{@"@type" : @"businessAwayMessageScheduleAlways"},
		@"offline_only" : @NO,
	};

	NSDictionary *flat = TGBizAwayFrom(away);

	TGTestExpectTrue(&outcome, [flat[@"schedule"] isEqualToString:@"always"],
			"businessAwayMessageScheduleAlways must flatten to the \"always\" schedule tag");
	TGTestExpectEqualInteger(&outcome, [flat[@"startDate"] integerValue], 0,
			"the always schedule must not carry over a start date");
	TGTestExpectEqualInteger(&outcome, [flat[@"endDate"] integerValue], 0,
			"the always schedule must not carry over an end date");
	TGTestExpectEqualInteger(&outcome, [flat[@"shortcutId"] integerValue], 5,
			"the away message's shortcutId must round-trip from shortcut_id");
	TGTestExpectTrue(&outcome, [flat[@"recipients"][@"existingChats"] boolValue],
			"the away message's recipients must be flattened through TGBizRecipientsFrom");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestAwayScheduleOutsideOfOpeningHours(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *away = @{
		@"recipients" : @{},
		@"schedule" : @{@"@type" : @"businessAwayMessageScheduleOutsideOfOpeningHours"},
	};

	NSDictionary *flat = TGBizAwayFrom(away);

	TGTestExpectTrue(&outcome, [flat[@"schedule"] isEqualToString:@"outsideHours"],
			"businessAwayMessageScheduleOutsideOfOpeningHours must flatten to the \"outsideHours\" schedule tag");
	TGTestExpectEqualInteger(&outcome, [flat[@"startDate"] integerValue], 0,
			"the outsideHours schedule must not carry over a start date");
	TGTestExpectEqualInteger(&outcome, [flat[@"endDate"] integerValue], 0,
			"the outsideHours schedule must not carry over an end date");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestAwayScheduleCustomDates(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *away = @{
		@"recipients" : @{},
		@"schedule" : @{
			@"@type" : @"businessAwayMessageScheduleCustom",
			@"start_date" : @1000,
			@"end_date" : @2000,
		},
	};

	NSDictionary *flat = TGBizAwayFrom(away);

	TGTestExpectTrue(&outcome, [flat[@"schedule"] isEqualToString:@"custom"],
			"businessAwayMessageScheduleCustom must flatten to the \"custom\" schedule tag");
	TGTestExpectEqualLongLong(&outcome, [flat[@"startDate"] longLongValue], 1000,
			"the custom schedule's startDate must round-trip from start_date");
	TGTestExpectEqualLongLong(&outcome, [flat[@"endDate"] longLongValue], 2000,
			"the custom schedule's endDate must round-trip from end_date");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestAwayReturnsNilForNilInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGBizAwayFrom(nil) == nil,
			"nil away message settings must flatten to nil, not crash or fabricate a dictionary");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestRightsRoundTripsFullSet(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *tdRights = @{
		@"can_reply" : @YES,
		@"can_read_messages" : @YES,
		@"can_delete_sent_messages" : @YES,
		@"can_delete_all_messages" : @YES,
		@"can_edit_name" : @YES,
		@"can_edit_bio" : @YES,
		@"can_edit_profile_photo" : @YES,
		@"can_edit_username" : @YES,
		@"can_view_gifts_and_stars" : @YES,
		@"can_sell_gifts" : @YES,
		@"can_change_gift_settings" : @YES,
		@"can_transfer_and_upgrade_gifts" : @YES,
		@"can_transfer_stars" : @YES,
		@"can_manage_stories" : @YES,
	};

	NSDictionary *flat = TGBizRightsFrom(tdRights);

	TGTestExpectTrue(&outcome, [flat[@"canReply"] boolValue] && [flat[@"canReadMessages"] boolValue] &&
			[flat[@"canDeleteSentMessages"] boolValue] && [flat[@"canDeleteAllMessages"] boolValue] &&
			[flat[@"canEditName"] boolValue] && [flat[@"canEditBio"] boolValue] &&
			[flat[@"canEditProfilePhoto"] boolValue] && [flat[@"canEditUsername"] boolValue] &&
			[flat[@"canViewGiftsAndStars"] boolValue] && [flat[@"canSellGifts"] boolValue] &&
			[flat[@"canChangeGiftSettings"] boolValue] && [flat[@"canTransferAndUpgradeGifts"] boolValue] &&
			[flat[@"canTransferStars"] boolValue] && [flat[@"canManageStories"] boolValue],
			"a full set of TDLib rights must flatten with every camelCase key true");

	NSDictionary *input = TGBizRightsInput(flat);

	TGTestExpectTrue(&outcome, [input[@"@type"] isEqualToString:@"businessBotRights"],
			"the rebuilt rights input must carry the businessBotRights type tag");
	TGTestExpectTrue(&outcome, [input[@"can_reply"] boolValue] && [input[@"can_read_messages"] boolValue] &&
			[input[@"can_delete_sent_messages"] boolValue] && [input[@"can_delete_all_messages"] boolValue] &&
			[input[@"can_edit_name"] boolValue] && [input[@"can_edit_bio"] boolValue] &&
			[input[@"can_edit_profile_photo"] boolValue] && [input[@"can_edit_username"] boolValue] &&
			[input[@"can_view_gifts_and_stars"] boolValue] && [input[@"can_sell_gifts"] boolValue] &&
			[input[@"can_change_gift_settings"] boolValue] && [input[@"can_transfer_and_upgrade_gifts"] boolValue] &&
			[input[@"can_transfer_stars"] boolValue] && [input[@"can_manage_stories"] boolValue],
			"round-tripping a full rights set back through TGBizRightsInput must restore every snake_case key true");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestRightsRoundTripsPartialSet(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *tdRights = @{@"can_reply" : @YES};

	NSDictionary *flat = TGBizRightsFrom(tdRights);

	TGTestExpectTrue(&outcome, [flat[@"canReply"] boolValue],
			"a partial rights set must still flatten the one key that is present");
	TGTestExpectTrue(&outcome, ![flat[@"canReadMessages"] boolValue] && ![flat[@"canManageStories"] boolValue],
			"a partial rights set must default every missing key to false, not crash on the missing value");

	NSDictionary *input = TGBizRightsInput(flat);

	TGTestExpectTrue(&outcome, [input[@"can_reply"] boolValue],
			"round-tripping a partial rights set must preserve the one true key");
	TGTestExpectTrue(&outcome, ![input[@"can_read_messages"] boolValue] && ![input[@"can_manage_stories"] boolValue],
			"round-tripping a partial rights set must emit every other key as an explicit false, not omit it");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestRecipientsRoundTripsBothDirections(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *tdRecipients = @{
		@"select_existing_chats" : @YES,
		@"select_new_chats" : @NO,
		@"select_contacts" : @YES,
		@"select_non_contacts" : @NO,
		@"chat_ids" : @[ @111, @222 ],
		@"excluded_chat_ids" : @[],
		@"exclude_selected" : @NO,
	};

	NSDictionary *flat = TGBizRecipientsFrom(tdRecipients);

	TGTestExpectTrue(&outcome, [flat[@"existingChats"] boolValue],
			"select_existing_chats must flatten to existingChats");
	TGTestExpectTrue(&outcome, ![flat[@"newChats"] boolValue],
			"select_new_chats must flatten to newChats");
	TGTestExpectTrue(&outcome, [flat[@"contacts"] boolValue],
			"select_contacts must flatten to contacts");
	TGTestExpectTrue(&outcome, ![flat[@"nonContacts"] boolValue],
			"select_non_contacts must flatten to nonContacts");
	TGTestExpectTrue(&outcome, [flat[@"chatIds"] isEqual:(@[ @111, @222 ])],
			"chat_ids must flatten to chatIds");
	TGTestExpectTrue(&outcome, ![flat[@"excludeSelected"] boolValue],
			"exclude_selected false must flatten to excludeSelected false");

	NSDictionary *input = TGBizRecipientsInput(flat);

	TGTestExpectTrue(&outcome, [input[@"@type"] isEqualToString:@"businessRecipients"],
			"the rebuilt recipients input must carry the businessRecipients type tag");
	TGTestExpectTrue(&outcome, [input[@"chat_ids"] isEqual:(@[ @111, @222 ])] && [input[@"excluded_chat_ids"] isEqual:@[]],
			"the rebuilt recipients input must carry the same chat_ids and excluded_chat_ids arrays it was given");
	TGTestExpectTrue(&outcome, [input[@"select_existing_chats"] boolValue] &&
			![input[@"select_new_chats"] boolValue] && [input[@"select_contacts"] boolValue] &&
			![input[@"select_non_contacts"] boolValue],
			"round-tripping recipients back through TGBizRecipientsInput must restore every select_ flag");
	TGTestExpectTrue(&outcome, ![input[@"exclude_selected"] boolValue],
			"the common only-these-chats case must round-trip exclude_selected as false, unchanged");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestRecipientsPreservesExcludeSelectedTrueOnRoundTrip(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *tdRecipients = @{
		@"select_existing_chats" : @YES,
		@"select_new_chats" : @YES,
		@"select_contacts" : @YES,
		@"select_non_contacts" : @YES,
		@"chat_ids" : @[ @111, @222 ],
		@"excluded_chat_ids" : @[],
		@"exclude_selected" : @YES,
	};

	NSDictionary *flat = TGBizRecipientsFrom(tdRecipients);

	TGTestExpectTrue(&outcome, [flat[@"excludeSelected"] boolValue],
			"a server-side exclude_selected:true (\"everyone except the selected chats\") must not be silently dropped on read");
	TGTestExpectTrue(&outcome, [flat[@"chatIds"] isEqual:(@[ @111, @222 ])],
			"the excluded chat ids themselves, carried in chat_ids when exclude_selected is true, must still round-trip");

	NSDictionary *input = TGBizRecipientsInput(flat);

	TGTestExpectTrue(&outcome, [input[@"exclude_selected"] boolValue],
			"saving back an untouched exclude_selected:true configuration must not flip it to false and widen who receives the message");
	TGTestExpectTrue(&outcome, [input[@"chat_ids"] isEqual:(@[ @111, @222 ])],
			"the two deliberately-excluded chat ids must still be the ones sent back, not dropped or moved");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestFlattenLinkComposesRealisticPayload(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *link = @{
		@"link" : @"https://t.me/m/abc123",
		@"title" : @"My Link",
		@"text" : @{@"@type" : @"formattedText", @"text" : @"Hello there", @"entities" : @[]},
		@"view_count" : @42,
	};

	NSDictionary *flat = TGBizFlattenLink(link);

	TGTestExpectTrue(&outcome, [flat[@"link"] isEqualToString:@"https://t.me/m/abc123"],
			"a well-formed business chat link must round-trip its link string");
	TGTestExpectTrue(&outcome, [flat[@"title"] isEqualToString:@"My Link"],
			"a well-formed business chat link must round-trip its title");
	TGTestExpectTrue(&outcome, [flat[@"text"] isEqualToString:@"Hello there"],
			"a well-formed business chat link must pull its text out of the nested formattedText");
	TGTestExpectEqualInteger(&outcome, [flat[@"viewCount"] integerValue], 42,
			"a well-formed business chat link must round-trip its view_count");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestFlattenLinkReturnsNilForMalformedInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGBizFlattenLink(nil) == nil,
			"a nil business chat link must flatten to nil, not crash");
	TGTestExpectTrue(&outcome, TGBizFlattenLink((NSDictionary *)@"not a dictionary") == nil,
			"a non-dictionary business chat link must flatten to nil, not crash");

	NSDictionary *empty = TGBizFlattenLink(@{});
	TGTestExpectTrue(&outcome, empty != nil,
			"an empty but structurally valid business chat link dictionary must still flatten, not be treated as malformed");
	TGTestExpectTrue(&outcome, [empty[@"link"] isEqualToString:@""] && [empty[@"title"] isEqualToString:@""] &&
			[empty[@"text"] isEqualToString:@""],
			"an empty business chat link must default its string fields, not crash on missing keys");
	TGTestExpectEqualInteger(&outcome, [empty[@"viewCount"] integerValue], 0,
			"an empty business chat link must default its view count to 0");

	return outcome;
}

TGTestOutcome TGFlattenBusinessTestFlattenLinkPreservesTextEntities(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *entities = @[ @{@"@type" : @"textEntity", @"offset" : @0, @"length" : @5,
		@"type" : @{@"@type" : @"textEntityTypeBold"}} ];
	NSDictionary *link = @{
		@"link" : @"https://t.me/m/abc123",
		@"title" : @"My Link",
		@"text" : @{@"@type" : @"formattedText", @"text" : @"Hello there", @"entities" : entities},
		@"view_count" : @42,
	};

	NSDictionary *flat = TGBizFlattenLink(link);

	TGTestExpectTrue(&outcome, [flat[@"entities"] isEqual:entities],
			"a business chat link's formatting entities must survive flattening so the edit screen can re-save them unchanged");

	NSDictionary *withoutEntities = TGBizFlattenLink(@{
		@"link" : @"https://t.me/m/abc123",
		@"title" : @"My Link",
		@"text" : @{@"@type" : @"formattedText", @"text" : @"Hello there"},
		@"view_count" : @42,
	});
	TGTestExpectTrue(&outcome, [withoutEntities[@"entities"] isEqual:@[]],
			"a business chat link with no entities key must flatten to an empty array, not nil or a crash");

	return outcome;
}

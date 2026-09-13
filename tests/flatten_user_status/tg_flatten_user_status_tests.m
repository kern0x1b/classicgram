#import "tg_flatten_user_status_tests.h"
#import "../../src/Utilities/TGDateUtils.h"
#import "../../src/Wire/Flatten/TGFlattenUserStatus.h"
#import <Foundation/Foundation.h>
#import <time.h>

static NSInteger TGFlattenUserStatusCalendarDayDelta(time_t candidate, time_t now) {
	NSCalendar *cal = [NSCalendar currentCalendar];
	NSUInteger units = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;
	NSDate *candidateDate = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)candidate];
	NSDate *nowDate = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)now];
	NSDate *dayOfCandidate = [cal dateFromComponents:[cal components:units fromDate:candidateDate]];
	NSDate *dayOfNow = [cal dateFromComponents:[cal components:units fromDate:nowDate]];
	return [cal components:NSDayCalendarUnit
					fromDate:dayOfCandidate
					  toDate:dayOfNow
					 options:0]
		.day;
}

static NSString *TGFlattenUserStatusExpectedTime(time_t timestamp) {
	static NSDateFormatter *fmt = nil;
	if (!fmt) {
		fmt = [[NSDateFormatter alloc] init];
		[fmt setDateFormat:@"HH:mm"];
	}
	return [fmt stringFromDate:[NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)timestamp]];
}

static NSString *TGFlattenUserStatusExpectedWeekday(time_t timestamp) {
	static NSDateFormatter *fmt = nil;
	if (!fmt) {
		fmt = [[NSDateFormatter alloc] init];
		[fmt setDateFormat:@"EEEE"];
	}
	return [fmt stringFromDate:[NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)timestamp]];
}

static NSString *TGFlattenUserStatusExpectedDate(time_t timestamp) {
	return [TGDateUtils stringForShortDate:(int)timestamp];
}

TGTestOutcome TGFlattenUserStatusTestEmojiIconCarriesScalarFields(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *sticker = @{@"emoji" : @"\U0001F525"};
	NSDictionary *icon = TGUSFlatEmojiStatusIcon(sticker, 12345, 999, YES, @"Cool Gift");

	TGTestExpectEqualLongLong(&outcome, [icon[@"customEmojiId"] longLongValue], 12345,
			"the flattened icon must carry the given customEmojiId verbatim");
	TGTestExpectEqualLongLong(&outcome, [icon[@"expires"] longLongValue], 999,
			"the flattened icon must carry the given expiration verbatim");
	TGTestExpectTrue(&outcome, [icon[@"isGift"] boolValue] == YES,
			"the flattened icon must carry the given isGift flag verbatim");
	TGTestExpectTrue(&outcome, [icon[@"giftTitle"] isEqualToString:@"Cool Gift"],
			"the flattened icon must carry the given giftTitle verbatim");
	TGTestExpectTrue(&outcome, [icon[@"emoji"] isEqualToString:@"\U0001F525"],
			"the flattened icon's emoji must come from the sticker's emoji field");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestEmojiIconNilGiftTitleFallsBackToEmptyString(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *icon = TGUSFlatEmojiStatusIcon(nil, 1, 0, NO, nil);

	TGTestExpectTrue(&outcome, [icon[@"giftTitle"] isEqualToString:@""],
			"a nil giftTitle must flatten to an empty string, not nil or a crash");
	TGTestExpectTrue(&outcome, [icon[@"emoji"] isEqualToString:@""],
			"a nil sticker must flatten to an empty emoji string, not crash");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestEmojiIconNilStickerOmitsFileIds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *icon = TGUSFlatEmojiStatusIcon(nil, 1, 0, NO, @"");

	TGTestExpectTrue(&outcome, icon[@"thumbFileId"] == nil,
			"a nil sticker must produce no thumbFileId key at all");
	TGTestExpectTrue(&outcome, icon[@"stickerFileId"] == nil,
			"a nil sticker must produce no stickerFileId key at all");
	TGTestExpectTrue(&outcome, [icon[@"isAnimated"] boolValue] == NO,
			"a nil sticker must flatten to isAnimated == NO");
	TGTestExpectTrue(&outcome, [icon[@"isTgs"] boolValue] == NO,
			"a nil sticker must flatten to isTgs == NO");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestEmojiIconFileIdsPassThroughWhenNumeric(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *sticker = @{
		@"thumbnail" : @{@"file" : @{@"id" : @777}},
		@"sticker" : @{@"id" : @888},
	};
	NSDictionary *icon = TGUSFlatEmojiStatusIcon(sticker, 1, 0, NO, @"");

	TGTestExpectEqualLongLong(&outcome, [icon[@"thumbFileId"] longLongValue], 777,
			"a numeric thumbnail file id must round-trip into thumbFileId");
	TGTestExpectEqualLongLong(&outcome, [icon[@"stickerFileId"] longLongValue], 888,
			"a numeric sticker file id must round-trip into stickerFileId");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestEmojiIconIgnoresNonNumericFileIds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *sticker = @{
		@"thumbnail" : @{@"file" : @{@"id" : @"not-a-number"}},
		@"sticker" : @{@"id" : @"also-not-a-number"},
	};
	NSDictionary *icon = TGUSFlatEmojiStatusIcon(sticker, 1, 0, NO, @"");

	TGTestExpectTrue(&outcome, icon[@"thumbFileId"] == nil,
			"a non-numeric thumbnail file id must be dropped, not passed through as garbage");
	TGTestExpectTrue(&outcome, icon[@"stickerFileId"] == nil,
			"a non-numeric sticker file id must be dropped, not passed through as garbage");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestEmojiIconTgsFormatIsAnimatedAndTgs(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *sticker = @{@"format" : @{@"@type" : @"stickerFormatTgs"}};
	NSDictionary *icon = TGUSFlatEmojiStatusIcon(sticker, 1, 0, NO, @"");

	TGTestExpectTrue(&outcome, [icon[@"isAnimated"] boolValue] == YES,
			"stickerFormatTgs must flatten to isAnimated == YES");
	TGTestExpectTrue(&outcome, [icon[@"isTgs"] boolValue] == YES,
			"stickerFormatTgs must flatten to isTgs == YES");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestEmojiIconWebmFormatIsNeitherAnimatedNorTgs(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *sticker = @{@"format" : @{@"@type" : @"stickerFormatWebm"}};
	NSDictionary *icon = TGUSFlatEmojiStatusIcon(sticker, 1, 0, NO, @"");

	TGTestExpectTrue(&outcome, [icon[@"isAnimated"] boolValue] == NO,
			"stickerFormatWebm must flatten to isAnimated == NO, this app has no WebM player");
	TGTestExpectTrue(&outcome, [icon[@"isTgs"] boolValue] == NO,
			"stickerFormatWebm must flatten to isTgs == NO, only stickerFormatTgs sets isTgs");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestEmojiIconStaticFormatIsNeitherAnimatedNorTgs(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *sticker = @{@"format" : @{@"@type" : @"stickerFormatWebp"}};
	NSDictionary *icon = TGUSFlatEmojiStatusIcon(sticker, 1, 0, NO, @"");

	TGTestExpectTrue(&outcome, [icon[@"isAnimated"] boolValue] == NO,
			"stickerFormatWebp must flatten to isAnimated == NO");
	TGTestExpectTrue(&outcome, [icon[@"isTgs"] boolValue] == NO,
			"stickerFormatWebp must flatten to isTgs == NO");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestLastSeenNonPositiveIsLongTimeAgo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGUSLastSeenText(0) isEqualToString:@"last seen a long time ago"],
			"a zero wasOnline timestamp must flatten to the long-time-ago fallback");
	TGTestExpectTrue(&outcome, [TGUSLastSeenText(-5) isEqualToString:@"last seen a long time ago"],
			"a negative wasOnline timestamp must flatten to the long-time-ago fallback, not crash");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestLastSeenNowContainsTodayLabelAndTime(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	time_t now = time(NULL);
	NSString *result = TGUSLastSeenText((long long)now);
	NSString *expectedTime = TGFlattenUserStatusExpectedTime(now);

	TGTestExpectTrue(&outcome, [result rangeOfString:@"last seen today at "].location != NSNotFound,
			"a timestamp from right now must be reported with the today label");
	TGTestExpectTrue(&outcome, [result rangeOfString:expectedTime].location != NSNotFound,
			"a timestamp from right now must render its own HH:mm time in the output");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestLastSeenYesterdayContainsYesterdayLabel(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	time_t now = time(NULL);
	time_t yesterday = now - 86400;
	NSInteger delta = TGFlattenUserStatusCalendarDayDelta(yesterday, now);

	if (delta == 1) {
		NSString *result = TGUSLastSeenText((long long)yesterday);
		TGTestExpectTrue(&outcome, [result rangeOfString:@"last seen yesterday at "].location != NSNotFound,
				"a timestamp exactly one calendar day before now must be reported with the yesterday label");
	} else {
		TGTestExpectTrue(&outcome, true,
				"skipped yesterday-label check because the calendar-day delta was not exactly 1");
	}

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestLastSeenWithinWeekUsesWeekdayName(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	time_t now = time(NULL);
	time_t threeDaysAgo = now - 3 * 86400;
	NSInteger delta = TGFlattenUserStatusCalendarDayDelta(threeDaysAgo, now);

	if (delta >= 2 && delta < 7) {
		NSString *result = TGUSLastSeenText((long long)threeDaysAgo);
		NSString *expectedWeekday = TGFlattenUserStatusExpectedWeekday(threeDaysAgo);
		TGTestExpectTrue(&outcome, [result rangeOfString:expectedWeekday].location != NSNotFound,
				"a timestamp within the last week must be reported with its weekday name");
		TGTestExpectTrue(&outcome, [result rangeOfString:@"last seen on "].location != NSNotFound,
				"a timestamp within the last week must use the \"last seen on <weekday>\" phrasing");
	} else {
		TGTestExpectTrue(&outcome, true,
				"skipped within-week check because the calendar-day delta fell outside [2, 7)");
	}

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestLastSeenOlderThanWeekUsesDateFormat(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	time_t now = time(NULL);
	time_t longAgo = now - 30 * 86400;
	NSInteger delta = TGFlattenUserStatusCalendarDayDelta(longAgo, now);

	if (delta >= 7) {
		NSString *result = TGUSLastSeenText((long long)longAgo);
		NSString *expectedDate = TGFlattenUserStatusExpectedDate(longAgo);
		TGTestExpectTrue(&outcome, [result rangeOfString:expectedDate].location != NSNotFound,
				"a timestamp more than a week old is reported with the same short date the rest of the app writes, in the order the device's locale uses");
		TGTestExpectTrue(&outcome, [result rangeOfString:@"today"].location == NSNotFound,
				"a timestamp more than a week old must not contain the today label");
		TGTestExpectTrue(&outcome, [result rangeOfString:@"yesterday"].location == NSNotFound,
				"a timestamp more than a week old must not contain the yesterday label");
	} else {
		TGTestExpectTrue(&outcome, true,
				"skipped older-than-week check because the calendar-day delta was still under 7");
	}

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestMergeOrdersThemedBeforeRecentBeforeDefault(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray<NSNumber *> *themed = @[ @1, @2 ];
	NSArray<NSNumber *> *recent = @[ @3, @4 ];
	NSArray<NSNumber *> *defaultIds = @[ @5, @6 ];
	NSArray<NSNumber *> *merged = TGUSMergePickableEmojiStatusIds(themed, recent, defaultIds, 40);

	NSArray<NSNumber *> *expected = @[ @1, @2, @3, @4, @5, @6 ];
	TGTestExpectTrue(&outcome, [merged isEqualToArray:expected],
			"themed ids must come first, then recent, then default, each tier's own order preserved");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestMergeDedupesAcrossTiers(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray<NSNumber *> *themed = @[ @1, @2 ];
	NSArray<NSNumber *> *recent = @[ @2, @3 ];
	NSArray<NSNumber *> *defaultIds = @[ @3, @1, @4 ];
	NSArray<NSNumber *> *merged = TGUSMergePickableEmojiStatusIds(themed, recent, defaultIds, 40);

	NSArray<NSNumber *> *expected = @[ @1, @2, @3, @4 ];
	TGTestExpectTrue(&outcome, [merged isEqualToArray:expected],
			"an id repeated in a later tier must not appear twice, and keeps its first tier's position");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestMergeDropsZeroIds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray<NSNumber *> *themed = @[ @0, @1 ];
	NSArray<NSNumber *> *recent = @[ @0 ];
	NSArray<NSNumber *> *defaultIds = @[ @0, @2 ];
	NSArray<NSNumber *> *merged = TGUSMergePickableEmojiStatusIds(themed, recent, defaultIds, 40);

	NSArray<NSNumber *> *expected = @[ @1, @2 ];
	TGTestExpectTrue(&outcome, [merged isEqualToArray:expected],
			"a zero custom_emoji_id must never be treated as a real emoji status id");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestMergeCapsAtLimit(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSMutableArray<NSNumber *> *themed = [NSMutableArray array];
	for (long long i = 1; i <= 3; i++)
		[themed addObject:@(i)];
	NSMutableArray<NSNumber *> *defaultIds = [NSMutableArray array];
	for (long long i = 100; i < 150; i++)
		[defaultIds addObject:@(i)];

	NSArray<NSNumber *> *merged = TGUSMergePickableEmojiStatusIds(themed, @[], defaultIds, 40);

	TGTestExpectEqualInteger(&outcome, merged.count, 40,
			"the merged list must stay capped at 40 even when the themed tier is folded in");
	TGTestExpectTrue(&outcome, [merged[0] isEqualToNumber:@1],
			"the cap must trim from the tail, keeping the themed tier's ids at the front");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestMergeTreatsNilArraysAsEmpty(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray<NSNumber *> *merged = TGUSMergePickableEmojiStatusIds(nil, nil, @[ @1 ], 40);

	NSArray<NSNumber *> *expected = @[ @1 ];
	TGTestExpectTrue(&outcome, [merged isEqualToArray:expected],
			"a nil tier must be treated as empty rather than crashing the merge");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestStatusInfoForEmptyTypeHasNoFabricatedText(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *info = TGUSStatusInfoForType(@"userStatusEmpty", 0, NO);

	TGTestExpectTrue(&outcome, [info[@"text"] isEqualToString:@""],
			"userStatusEmpty means the server supplied no status at all, so it must not be shown as a fabricated 'last seen a long time ago' timestamp");
	TGTestExpectTrue(&outcome, [info[@"isOnline"] boolValue] == NO,
			"a status carrying no information at all cannot be reported as online");
	TGTestExpectTrue(&outcome, [info[@"wasOnline"] longLongValue] == 0,
			"a status carrying no information at all cannot carry a last-online timestamp");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestStatusInfoForUnknownTypeHasNoFabricatedText(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *info = TGUSStatusInfoForType(@"", 0, NO);
	TGTestExpectTrue(&outcome, [info[@"text"] isEqualToString:@""],
			"a missing/nil status (empty type string) must not be shown as a fabricated 'last seen a long time ago' timestamp");

	NSDictionary *futureInfo = TGUSStatusInfoForType(@"userStatusSomethingFutureTDLibAdds", 0, NO);
	TGTestExpectTrue(&outcome, [futureInfo[@"text"] isEqualToString:@""],
			"a status type this client does not yet recognize must not fabricate a plausible-looking timestamp either");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestStatusInfoForOnlineIsUnaffected(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *info = TGUSStatusInfoForType(@"userStatusOnline", 0, NO);
	TGTestExpectTrue(&outcome, [info[@"text"] isEqualToString:@"online"],
			"userStatusOnline must keep reporting its real online text, unaffected by the userStatusEmpty fix");
	TGTestExpectTrue(&outcome, [info[@"isOnline"] boolValue] == YES,
			"userStatusOnline must still report isOnline");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestStatusInfoForOfflineCarriesWasOnline(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	long long wasOnline = 1000000;
	NSDictionary *info = TGUSStatusInfoForType(@"userStatusOffline", wasOnline, NO);
	TGTestExpectTrue(&outcome, [info[@"wasOnline"] longLongValue] == wasOnline,
			"userStatusOffline must keep carrying its real was_online timestamp, unaffected by the userStatusEmpty fix");
	TGTestExpectTrue(&outcome, [(NSString *)info[@"text"] length] > 0,
			"userStatusOffline with a real timestamp must still produce a non-empty last-seen text");

	return outcome;
}

TGTestOutcome TGFlattenUserStatusTestStatusInfoForRecentlyCarriesHiddenFlag(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *shown = TGUSStatusInfoForType(@"userStatusRecently", 0, NO);
	NSDictionary *hidden = TGUSStatusInfoForType(@"userStatusRecently", 0, YES);
	TGTestExpectTrue(&outcome, [shown[@"hiddenByMyPrivacy"] boolValue] == NO,
			"userStatusRecently must still propagate by_my_privacy_settings through hiddenByMyPrivacy when false");
	TGTestExpectTrue(&outcome, [hidden[@"hiddenByMyPrivacy"] boolValue] == YES,
			"userStatusRecently must still propagate by_my_privacy_settings through hiddenByMyPrivacy when true");

	return outcome;
}

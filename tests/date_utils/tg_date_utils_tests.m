#import "tg_date_utils_tests.h"
#import "../../src/Utilities/TGDateUtils.h"
#import <Foundation/Foundation.h>
#import <time.h>
#import <limits.h>

static NSString *value_expectedMonthNamesShort[] = {
	@"Jan", @"Feb", @"Mar", @"Apr", @"May", @"Jun",
	@"Jul", @"Aug", @"Sep", @"Oct", @"Nov", @"Dec"
};
static NSString *value_expectedWeekdayNamesShort[] = {
	@"Mon", @"Tue", @"Wed", @"Thu", @"Fri", @"Sat", @"Sun"
};

static NSString *TGDateUtilsExpectedWeekdayName(struct tm timeinfo) {
	int index = (timeinfo.tm_wday == 0) ? 6 : timeinfo.tm_wday - 1;
	return value_expectedWeekdayNamesShort[index];
}

static NSString *TGDateUtilsExpectedMonthName(struct tm timeinfo) {
	return value_expectedMonthNamesShort[timeinfo.tm_mon];
}

static bool TGDateUtilsSameLocalDay(time_t a, time_t b) {
	struct tm aInfo;
	struct tm bInfo;
	localtime_r(&a, &aInfo);
	localtime_r(&b, &bInfo);
	return aInfo.tm_year == bInfo.tm_year && aInfo.tm_yday == bInfo.tm_yday;
}

static bool TGDateUtilsIsDaysBeforeSameYear(time_t base, time_t candidate, int days) {
	struct tm baseInfo;
	struct tm candidateInfo;
	localtime_r(&base, &baseInfo);
	localtime_r(&candidate, &candidateInfo);
	if (baseInfo.tm_year != candidateInfo.tm_year)
		return false;
	return baseInfo.tm_yday - candidateInfo.tm_yday == days;
}

static bool TGDateUtilsIsDayAfterSameYear(time_t base, time_t candidate) {
	struct tm baseInfo;
	struct tm candidateInfo;
	localtime_r(&base, &baseInfo);
	localtime_r(&candidate, &candidateInfo);
	if (baseInfo.tm_year != candidateInfo.tm_year)
		return false;
	return candidateInfo.tm_yday == baseInfo.tm_yday + 1;
}

TGTestOutcome TGDateUtilsTestShortTimeIsDeterministicForSameInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	int fixedTime = 1700000000;
	NSString *first = [TGDateUtils stringForShortTime:fixedTime];
	NSString *second = [TGDateUtils stringForShortTime:fixedTime];

	TGTestExpectTrue(&outcome, first != nil && first.length > 0,
			"stringForShortTime must return a non-empty string for an ordinary timestamp");
	TGTestExpectTrue(&outcome, [first isEqualToString:second],
			"stringForShortTime must be a pure function of its input, same input yields same output");

	return outcome;
}

TGTestOutcome TGDateUtilsTestShortTimeReflectsMinuteChange(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	int baseTime = 1700000000;
	int laterTime = baseTime + 1800;

	time_t baseT = baseTime;
	time_t laterT = laterTime;
	struct tm baseInfo;
	struct tm laterInfo;
	localtime_r(&baseT, &baseInfo);
	localtime_r(&laterT, &laterInfo);

	NSString *baseResult = [TGDateUtils stringForShortTime:baseTime];
	NSString *laterResult = [TGDateUtils stringForShortTime:laterTime];

	NSString *baseMinute = [NSString stringWithFormat:@"%02d", baseInfo.tm_min];
	NSString *laterMinute = [NSString stringWithFormat:@"%02d", laterInfo.tm_min];

	TGTestExpectTrue(&outcome, [baseResult rangeOfString:baseMinute].location != NSNotFound,
			"stringForShortTime must render the zero-padded minute somewhere in its output");
	TGTestExpectTrue(&outcome, [laterResult rangeOfString:laterMinute].location != NSNotFound,
			"a 30-minutes-later timestamp must render its own zero-padded minute in the output");
	TGTestExpectTrue(&outcome, ![baseResult isEqualToString:laterResult],
			"a timestamp 30 minutes apart must never render identically to the original");

	return outcome;
}

TGTestOutcome TGDateUtilsTestDialogTimeReflectsMonthAndDay(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	int fixedTime = 1700000000;
	time_t t = fixedTime;
	struct tm timeinfo;
	localtime_r(&t, &timeinfo);

	NSString *expected = [[NSString alloc] initWithFormat:@"%@ %d",
			TGDateUtilsExpectedMonthName(timeinfo), timeinfo.tm_mday];
	NSString *result = [TGDateUtils stringForDialogTime:fixedTime];

	TGTestExpectTrue(&outcome, [result isEqualToString:expected],
			"stringForDialogTime must render as \"<short month> <day>\" for the given date");

	return outcome;
}

TGTestOutcome TGDateUtilsTestDayOfMonthMatchesCalendarDayAndOutParam(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	int fixedTime = 1700000000;
	time_t t = fixedTime;
	struct tm timeinfo;
	localtime_r(&t, &timeinfo);

	int dayOfMonth = -1;
	NSString *result = [TGDateUtils stringForDayOfMonth:fixedTime dayOfMonth:&dayOfMonth];
	NSString *expected = [[NSString alloc] initWithFormat:@"%d %@",
			timeinfo.tm_mday, TGDateUtilsExpectedMonthName(timeinfo)];

	TGTestExpectTrue(&outcome, [result isEqualToString:expected],
			"stringForDayOfMonth must render as \"<day> <short month>\" for the given date");
	TGTestExpectEqualInteger(&outcome, dayOfMonth, timeinfo.tm_mday,
			"the dayOfMonth out-parameter must be filled with the calendar day of the given date");

	NSString *resultWithoutOutParam = [TGDateUtils stringForDayOfMonth:fixedTime dayOfMonth:NULL];
	TGTestExpectTrue(&outcome, [resultWithoutOutParam isEqualToString:expected],
			"passing NULL for the out-parameter must not change the returned string or crash");

	return outcome;
}

TGTestOutcome TGDateUtilsTestDayOfWeekMatchesWeekdayName(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	int fixedTime = 1700000000;
	time_t t = fixedTime;
	struct tm timeinfo;
	localtime_r(&t, &timeinfo);

	NSString *expected = TGDateUtilsExpectedWeekdayName(timeinfo);
	NSString *result = [TGDateUtils stringForDayOfWeek:fixedTime];

	TGTestExpectTrue(&outcome, [result isEqualToString:expected],
			"stringForDayOfWeek must return the short weekday name matching the date's tm_wday");

	int nextDayTime = fixedTime + 86400;
	NSString *nextResult = [TGDateUtils stringForDayOfWeek:nextDayTime];
	TGTestExpectTrue(&outcome, ![nextResult isEqualToString:result],
			"consecutive calendar days must never report the same weekday name");

	return outcome;
}

TGTestOutcome TGDateUtilsTestMessageListDateSameDayMatchesShortTime(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	time_t now = time(NULL);
	int date = (int)now;

	NSString *listResult = [TGDateUtils stringForMessageListDate:date];
	NSString *shortTimeResult = [TGDateUtils stringForShortTime:date];

	TGTestExpectTrue(&outcome, listResult != nil && listResult.length > 0,
			"stringForMessageListDate must return a non-empty string for the current moment");
	TGTestExpectTrue(&outcome, [listResult isEqualToString:shortTimeResult],
			"a same-day message list date must render identically to stringForShortTime");

	return outcome;
}

TGTestOutcome TGDateUtilsTestMessageListDateWeekBoundaryBehavior(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	time_t now = time(NULL);
	time_t sixDaysAgo = now - 6 * 86400;
	time_t sevenDaysAgo = now - 7 * 86400;

	if (TGDateUtilsIsDaysBeforeSameYear(now, sixDaysAgo, 6)) {
		NSString *sixDaysResult = [TGDateUtils stringForMessageListDate:(int)sixDaysAgo];
		NSString *weekdayResult = [TGDateUtils stringForDayOfWeek:(int)sixDaysAgo];
		TGTestExpectTrue(&outcome, [sixDaysResult isEqualToString:weekdayResult],
				"a message from 6 days ago must render as its short weekday name");
	} else {
		TGTestExpectTrue(&outcome, true,
				"skipped 6-day boundary check across a year rollover");
	}

	if (TGDateUtilsIsDaysBeforeSameYear(now, sevenDaysAgo, 7)) {
		NSString *sevenDaysResult = [TGDateUtils stringForMessageListDate:(int)sevenDaysAgo];
		NSString *weekdayResult = [TGDateUtils stringForDayOfWeek:(int)sevenDaysAgo];
		TGTestExpectTrue(&outcome, ![sevenDaysResult isEqualToString:weekdayResult],
				"a message from exactly 7 days ago must fall outside the weekday-name window");
	} else {
		TGTestExpectTrue(&outcome, true,
				"skipped 7-day boundary check across a year rollover");
	}

	return outcome;
}

TGTestOutcome TGDateUtilsTestLastSeenTodayContainsTodayLabel(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	time_t now = time(NULL);
	NSString *result = [TGDateUtils stringForLastSeen:(int)now];

	TGTestExpectTrue(&outcome, [result rangeOfString:@"today"].location != NSNotFound,
			"a last-seen timestamp from right now must contain the \"today\" label");
	TGTestExpectTrue(&outcome, [result rangeOfString:@"yesterday"].location == NSNotFound,
			"a last-seen timestamp from right now must not contain the \"yesterday\" label");

	return outcome;
}

TGTestOutcome TGDateUtilsTestLastSeenYesterdayContainsYesterdayLabel(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	time_t now = time(NULL);
	time_t yesterday = now - 86400;

	if (TGDateUtilsIsDaysBeforeSameYear(now, yesterday, 1)) {
		NSString *result = [TGDateUtils stringForLastSeen:(int)yesterday];
		TGTestExpectTrue(&outcome, [result rangeOfString:@"yesterday"].location != NSNotFound,
				"a last-seen timestamp from exactly one day ago must contain the \"yesterday\" label");
		TGTestExpectTrue(&outcome, [result rangeOfString:@"today"].location == NSNotFound,
				"a last-seen timestamp from exactly one day ago must not contain the \"today\" label");
	} else {
		TGTestExpectTrue(&outcome, true,
				"skipped yesterday-label check across a year rollover");
	}

	return outcome;
}

TGTestOutcome TGDateUtilsTestLastSeenOlderThanYesterdayOmitsRelativeLabels(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	time_t now = time(NULL);
	time_t threeDaysAgo = now - 3 * 86400;

	NSString *result = [TGDateUtils stringForLastSeen:(int)threeDaysAgo];

	TGTestExpectTrue(&outcome, result != nil && result.length > 0,
			"stringForLastSeen must return a non-empty string for a date several days old");
	TGTestExpectTrue(&outcome, [result rangeOfString:@"today"].location == NSNotFound,
			"a last-seen timestamp three days old must not contain the \"today\" label");
	TGTestExpectTrue(&outcome, [result rangeOfString:@"yesterday"].location == NSNotFound,
			"a last-seen timestamp three days old must not contain the \"yesterday\" label");

	return outcome;
}

TGTestOutcome TGDateUtilsTestLastSeenShortMatchesLastSeen(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	time_t now = time(NULL);
	int date = (int)now;

	NSString *lastSeen = [TGDateUtils stringForLastSeen:date];
	NSString *lastSeenShort = [TGDateUtils stringForLastSeenShort:date];

	TGTestExpectTrue(&outcome, [lastSeenShort isEqualToString:lastSeen],
			"stringForLastSeenShort must forward to stringForLastSeen for the same input");

	return outcome;
}

static time_t TGDateTestMidday(void) {
	struct tm midday;
	memset(&midday, 0, sizeof(midday));
	midday.tm_year = 126;
	midday.tm_mon = 5;
	midday.tm_mday = 15;
	midday.tm_hour = 12;
	midday.tm_isdst = -1;
	return mktime(&midday);
}

TGTestOutcome TGDateUtilsTestRelativeLastSeenJustNowForRecentTimestamp(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	time_t now = TGDateTestMidday();
	int date = (int)(now - 5);

	NSString *result = [TGDateUtils stringForRelativeLastSeen:date now:now];

	TGTestExpectTrue(&outcome, [result isEqualToString:@"just now"],
			"a timestamp 5 seconds old must render as exactly \"just now\"");

	return outcome;
}

TGTestOutcome TGDateUtilsTestRelativeLastSeenMinuteSingularPluralBoundary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	time_t now = TGDateTestMidday();
	int oneMinuteAgo = (int)(now - 70);
	int twoMinutesAgo = (int)(now - 130);

	NSString *singular = [TGDateUtils stringForRelativeLastSeen:oneMinuteAgo now:now];
	NSString *plural = [TGDateUtils stringForRelativeLastSeen:twoMinutesAgo now:now];

	TGTestExpectTrue(&outcome, [singular isEqualToString:@"1 minute ago"],
			"a timestamp about 70 seconds old must render as the singular \"1 minute ago\"");
	TGTestExpectTrue(&outcome, [plural isEqualToString:@"2 minutes ago"],
			"a timestamp about 130 seconds old must render as the plural \"2 minutes ago\"");

	return outcome;
}

TGTestOutcome TGDateUtilsTestRelativeLastSeenHourBoundaryAtSixtyMinutes(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	time_t now = TGDateTestMidday();
	time_t justUnderAnHourAgo = now - 3599;
	time_t exactlyAnHourAgo = now - 3600;

	NSString *underHourResult = [TGDateUtils stringForRelativeLastSeen:(int)justUnderAnHourAgo now:now];
	NSString *atHourResult = [TGDateUtils stringForRelativeLastSeen:(int)exactlyAnHourAgo now:now];

	TGTestExpectTrue(&outcome, [underHourResult isEqualToString:@"59 minutes ago"],
			"a timestamp 3599 seconds old must still be reported in minutes, just under the hour");
	TGTestExpectTrue(&outcome, [atHourResult isEqualToString:@"1 hour ago"],
			"a timestamp exactly 3600 seconds old must cross over into the singular hour unit");

	return outcome;
}

TGTestOutcome TGDateUtilsTestUntilTodayAndTomorrowLabels(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	time_t now = time(NULL);
	NSString *todayResult = [TGDateUtils stringForUntil:(int)now];

	TGTestExpectTrue(&outcome, [todayResult rangeOfString:@"today"].location != NSNotFound,
			"stringForUntil for the current moment must contain the \"today\" label");

	time_t tomorrow = now + 86400;
	if (TGDateUtilsIsDayAfterSameYear(now, tomorrow)) {
		NSString *tomorrowResult = [TGDateUtils stringForUntil:(int)tomorrow];
		TGTestExpectTrue(&outcome, [tomorrowResult rangeOfString:@"tomorrow"].location != NSNotFound,
				"stringForUntil for exactly one day ahead must contain the \"tomorrow\" label");
	} else {
		TGTestExpectTrue(&outcome, true,
				"skipped tomorrow-label check across a year rollover");
	}

	return outcome;
}

TGTestOutcome TGDateUtilsTestUntilTwoDaysAheadOmitsTodayAndTomorrowLabels(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	time_t now = time(NULL);
	time_t twoDaysAhead = now + 2 * 86400;

	if (TGDateUtilsIsDaysBeforeSameYear(now, twoDaysAhead, -2)) {
		NSString *result = [TGDateUtils stringForUntil:(int)twoDaysAhead];
		TGTestExpectTrue(&outcome, [result rangeOfString:@"today"].location == NSNotFound,
				"stringForUntil two days ahead must not contain the \"today\" label");
		TGTestExpectTrue(&outcome, [result rangeOfString:@"tomorrow"].location == NSNotFound,
				"stringForUntil two days ahead must not contain the \"tomorrow\" label");
	} else {
		TGTestExpectTrue(&outcome, true,
				"skipped two-days-ahead check across a year rollover");
	}

	return outcome;
}

TGTestOutcome TGDateUtilsTestDefensiveInputsDoNotCrashAcrossFunctions(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	int candidates[] = {0, -1, -1000000, 2000000000, INT_MAX, INT_MIN};
	int dayOfMonth = 0;

	for (unsigned long i = 0; i < sizeof(candidates) / sizeof(candidates[0]); i++) {
		int value = candidates[i];

		TGTestExpectTrue(&outcome, [TGDateUtils stringForShortTime:value].length > 0,
				"stringForShortTime must return a non-empty string for an extreme timestamp");
		TGTestExpectTrue(&outcome, [TGDateUtils stringForDialogTime:value].length > 0,
				"stringForDialogTime must return a non-empty string for an extreme timestamp");
		TGTestExpectTrue(&outcome, [TGDateUtils stringForDayOfMonth:value dayOfMonth:&dayOfMonth].length > 0,
				"stringForDayOfMonth must return a non-empty string for an extreme timestamp");
		TGTestExpectTrue(&outcome, [TGDateUtils stringForDayOfWeek:value].length > 0,
				"stringForDayOfWeek must return a non-empty string for an extreme timestamp");
		TGTestExpectTrue(&outcome, [TGDateUtils stringForMessageListDate:value].length > 0,
				"stringForMessageListDate must return a non-empty string for an extreme timestamp");
		TGTestExpectTrue(&outcome, [TGDateUtils stringForLastSeen:value].length > 0,
				"stringForLastSeen must return a non-empty string for an extreme timestamp");
		TGTestExpectTrue(&outcome, [TGDateUtils stringForRelativeLastSeen:value].length > 0,
				"stringForRelativeLastSeen must return a non-empty string for an extreme timestamp");
		TGTestExpectTrue(&outcome, [TGDateUtils stringForUntil:value].length > 0,
				"stringForUntil must return a non-empty string for an extreme timestamp");
	}

	return outcome;
}

TGTestOutcome TGDateUtilsTestDayDividerReadsAsADate(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	struct tm parts;
	memset(&parts, 0, sizeof(parts));
	parts.tm_year = 124;
	parts.tm_mon = 8;
	parts.tm_mday = 12;
	parts.tm_hour = 12;
	time_t september = mktime(&parts);

	NSString *sameYear = [TGDateUtils stringForDayDivider:(int)september now:september + 86400 * 10];
	TGTestExpectTrue(&outcome, [sameYear rangeOfString:@"September"].location != NSNotFound,
			"a divider in the current year names the month in the app's own words");
	TGTestExpectTrue(&outcome, [sameYear rangeOfString:@"12"].location != NSNotFound,
			"and the day of the month");
	TGTestExpectTrue(&outcome, [sameYear rangeOfString:@"2024"].location == NSNotFound,
			"the current year is not repeated on every divider");

	NSString *sameDay = [TGDateUtils stringForDayDivider:(int)september now:september + 3600];
	TGTestExpectTrue(&outcome, [sameDay isEqualToString:@"Today"],
			"today is named, not dated");

	NSString *olderYear = [TGDateUtils stringForDayDivider:(int)september
														now:september + 86400 * 400];
	TGTestExpectTrue(&outcome, [olderYear rangeOfString:@"2024"].location != NSNotFound,
			"a divider from an earlier year carries the year");

	TGTestExpectTrue(&outcome, [TGDateUtils stringForDayDivider:0].length > 0,
			"an impossible timestamp still produces a divider rather than an empty one");

	return outcome;
}

TGTestOutcome TGDateUtilsTestWeekdayAndShortDateAreTheAppsOwnWords(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	struct tm parts;
	memset(&parts, 0, sizeof(parts));
	parts.tm_year = 124;
	parts.tm_mon = 8;
	parts.tm_mday = 12;
	parts.tm_hour = 12;
	time_t thursday = mktime(&parts);

	TGTestExpectTrue(&outcome,
			[[TGDateUtils stringForWeekday:(int)thursday] isEqualToString:@"Thursday"],
			"a weekday is spelled out from the app's own table, not a system formatter");
	TGTestExpectTrue(&outcome, [TGDateUtils stringForShortDate:(int)thursday].length > 0,
			"a short date is written in the order the device's own locale uses");
	NSString *both = [TGDateUtils stringForDateAndTime:(int)thursday];
	TGTestExpectTrue(&outcome,
			[both hasPrefix:[TGDateUtils stringForShortDate:(int)thursday]],
			"a date and time starts with that same short date");
	TGTestExpectTrue(&outcome,
			[both hasSuffix:[TGDateUtils stringForShortTime:(int)thursday]],
			"and ends with the clock, in whichever of 12 or 24 hours the device uses");

	return outcome;
}

TGTestOutcome TGDateUtilsTestMonthAndFullDateAreTheAppsOwnWords(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	struct tm parts;
	memset(&parts, 0, sizeof(parts));
	parts.tm_year = 124;
	parts.tm_mon = 8;
	parts.tm_mday = 12;
	parts.tm_hour = 12;
	time_t september = mktime(&parts);

	NSString *monthAndYear = [TGDateUtils stringForMonthAndYear:(int)september];
	TGTestExpectTrue(&outcome, [monthAndYear isEqualToString:@"September 2024"],
			"a media section header names the month in the app's own words and carries the year");

	NSString *full = [TGDateUtils stringForFullDate:(int)september];
	TGTestExpectTrue(&outcome, [full rangeOfString:@"September"].location != NSNotFound,
			"a full date spells the month rather than abbreviating it");
	TGTestExpectTrue(&outcome, [full rangeOfString:@"2024"].location != NSNotFound,
			"and always carries the year, since a calendar row can be any year");
	TGTestExpectTrue(&outcome, [full rangeOfString:@"12"].location != NSNotFound,
			"and the day");

	TGTestExpectTrue(&outcome,
			[[TGDateUtils shortWeekdayNameForTmWday:1] isEqualToString:@"Mon"],
			"the weekday strip reads Monday from the same table the rest of the app uses");
	TGTestExpectTrue(&outcome,
			[[TGDateUtils shortWeekdayNameForTmWday:0] isEqualToString:@"Sun"],
			"and Sunday, which is index zero the way tm_wday counts");

	return outcome;
}

TGTestOutcome TGDateUtilsTestFullDateAndTimeCarriesBothHalves(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	struct tm parts;
	memset(&parts, 0, sizeof(parts));
	parts.tm_year = 124;
	parts.tm_mon = 8;
	parts.tm_mday = 12;
	parts.tm_hour = 14;
	parts.tm_min = 32;
	time_t stamp = mktime(&parts);

	NSString *both = [TGDateUtils stringForFullDateAndTime:(int)stamp];
	TGTestExpectTrue(&outcome,
			[both hasPrefix:[TGDateUtils stringForFullDate:(int)stamp]],
			"a full date and time starts with the spelled-out date");
	TGTestExpectTrue(&outcome,
			[both hasSuffix:[TGDateUtils stringForShortTime:(int)stamp]],
			"and ends with the same clock the rest of the app uses");

	NSString *dayAndMonth = [TGDateUtils stringForDayAndMonth:(int)stamp];
	TGTestExpectTrue(&outcome,
			[dayAndMonth rangeOfString:@"September"].location != NSNotFound,
			"a birthday with no year still names its month");
	TGTestExpectTrue(&outcome, [dayAndMonth rangeOfString:@"2024"].location == NSNotFound,
			"and does not invent one");
	TGTestExpectTrue(&outcome, [dayAndMonth rangeOfString:@"12"].location != NSNotFound,
			"and carries the day");

	return outcome;
}

TGTestOutcome TGDateUtilsTestClockSplitsIntoNumberAndMarker(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	struct tm parts;
	memset(&parts, 0, sizeof(parts));
	parts.tm_year = 124;
	parts.tm_mon = 8;
	parts.tm_mday = 12;
	parts.tm_hour = 14;
	parts.tm_min = 32;
	time_t afternoon = mktime(&parts);

	NSString *number = [TGDateUtils stringForShortTimeWithoutMarker:(int)afternoon];
	NSString *marker = [TGDateUtils stringForClockMarker:(int)afternoon];
	NSString *whole = [TGDateUtils stringForShortTime:(int)afternoon];

	TGTestExpectTrue(&outcome, [whole hasPrefix:number],
			"the chat list splits the clock so it can embolden the number, and the two halves "
			"must add up to the clock the rest of the app writes");
	TGTestExpectTrue(&outcome, marker.length == 0 || [whole hasSuffix:marker],
			"a 24-hour device has no marker at all, and a 12-hour one ends with it");
	TGTestExpectTrue(&outcome, [number rangeOfString:@":"].location != NSNotFound,
			"the number half is still a clock");

	parts.tm_hour = 0;
	parts.tm_min = 5;
	time_t midnight = mktime(&parts);
	NSString *midnightNumber = [TGDateUtils stringForShortTimeWithoutMarker:(int)midnight];
	TGTestExpectTrue(&outcome,
			[midnightNumber isEqualToString:@"00:05"] ||
				[midnightNumber isEqualToString:@"12:05"],
			"midnight is 00:05 on a 24-hour clock and 12:05 on a 12-hour one, never 0:05");

	return outcome;
}

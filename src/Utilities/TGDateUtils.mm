#include "TGDateUtils.h"
#include "TGDateDayDifference.h"
#include "TGLocalization.h"
#include <time.h>

static bool value_dateHas12hFormat = false;
static __strong NSString *value_amSymbol = @"AM";
static __strong NSString *value_pmSymbol = @"PM";

static NSString *monthNameGenShortKeys[] = {
	@"Month.ShortJanuary", @"Month.ShortFebruary", @"Month.ShortMarch", @"Month.ShortApril",
	@"Month.ShortMay", @"Month.ShortJune", @"Month.ShortJuly", @"Month.ShortAugust",
	@"Month.ShortSeptember", @"Month.ShortOctober", @"Month.ShortNovember", @"Month.ShortDecember"
};
static NSString *monthNameGenShortFallbacks[] = {
	@"Jan", @"Feb", @"Mar", @"Apr", @"May", @"Jun",
	@"Jul", @"Aug", @"Sep", @"Oct", @"Nov", @"Dec"
};
static NSString *monthNameKeys[] = {
	@"Month.January", @"Month.February", @"Month.March", @"Month.April",
	@"Month.May", @"Month.June", @"Month.July", @"Month.August",
	@"Month.September", @"Month.October", @"Month.November", @"Month.December"
};
static NSString *monthNameFallbacks[] = {
	@"January", @"February", @"March", @"April", @"May", @"June",
	@"July", @"August", @"September", @"October", @"November", @"December"
};
static NSString *weekdayNameKeys[] = {
	@"Weekday.Monday", @"Weekday.Tuesday", @"Weekday.Wednesday", @"Weekday.Thursday",
	@"Weekday.Friday", @"Weekday.Saturday", @"Weekday.Sunday"
};
static NSString *weekdayNameFallbacks[] = {
	@"Monday", @"Tuesday", @"Wednesday", @"Thursday", @"Friday", @"Saturday", @"Sunday"
};
static NSString *weekdayNameShortKeys[] = {
	@"Weekday.ShortMonday", @"Weekday.ShortTuesday", @"Weekday.ShortWednesday",
	@"Weekday.ShortThursday", @"Weekday.ShortFriday", @"Weekday.ShortSaturday",
	@"Weekday.ShortSunday"
};
static NSString *weekdayNameShortFallbacks[] = {
	@"Mon", @"Tue", @"Wed", @"Thu", @"Fri", @"Sat", @"Sun"
};

static char value_date_separator = '.';
static bool value_monthFirst = false;

static bool TGDateUtilsInitialized = false;
static void initializeTGDateUtils() {
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setLocale:[NSLocale currentLocale]];
	[dateFormatter setDateStyle:NSDateFormatterNoStyle];
	[dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
	[dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
	NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
	NSRange amRange = [dateString rangeOfString:[dateFormatter AMSymbol]];
	NSRange pmRange = [dateString rangeOfString:[dateFormatter PMSymbol]];
	value_dateHas12hFormat = !(amRange.location == NSNotFound && pmRange.location == NSNotFound);
	if ([dateFormatter AMSymbol].length)
		value_amSymbol = [dateFormatter AMSymbol];
	if ([dateFormatter PMSymbol].length)
		value_pmSymbol = [dateFormatter PMSymbol];

	dateString = [NSDateFormatter dateFormatFromTemplate:@"MdY" options:0 locale:[NSLocale currentLocale]];
	if ([dateString rangeOfString:@"."].location != NSNotFound)
		value_date_separator = '.';
	else if ([dateString rangeOfString:@"/"].location != NSNotFound)
		value_date_separator = '/';
	else if ([dateString rangeOfString:@"-"].location != NSNotFound)
		value_date_separator = '-';

	if ([dateString rangeOfString:[NSString stringWithFormat:@"M%cd", value_date_separator]].location != NSNotFound)
		value_monthFirst = true;

	TGDateUtilsInitialized = true;
}

static inline bool dateHas12hFormat() {
	if (!TGDateUtilsInitialized)
		initializeTGDateUtils();
	return value_dateHas12hFormat;
}

bool TGUse12hDateFormat() {
	return dateHas12hFormat();
}

static inline NSString *weekdayNameShort(int number) {
	if (!TGDateUtilsInitialized)
		initializeTGDateUtils();
	if (number < 0) number = 0;
	if (number > 6) number = 6;
	number = (number == 0) ? 6 : number - 1;
	return TGL(weekdayNameShortKeys[number], weekdayNameShortFallbacks[number]);
}

static inline NSString *weekdayNameFull(int number) {
	number -= 1;
	if (number < 0)
		number = 6;
	if (number > 6)
		number = 6;
	return TGL(weekdayNameKeys[number], weekdayNameFallbacks[number]);
}

static inline NSString *monthNameFull(int number) {
	if (number < 0)
		number = 0;
	if (number > 11)
		number = 11;
	return TGL(monthNameKeys[number], monthNameFallbacks[number]);
}

static inline NSString *monthNameGenShort(int number) {
	if (!TGDateUtilsInitialized)
		initializeTGDateUtils();
	if (number < 0) number = 0;
	if (number > 11) number = 11;
	return TGL(monthNameGenShortKeys[number], monthNameGenShortFallbacks[number]);
}

static NSString *clockText(struct tm timeinfo) {
	if (dateHas12hFormat()) {
		if (timeinfo.tm_hour < 12)
			return [[NSString alloc] initWithFormat:@"%d:%02d %@",
				timeinfo.tm_hour == 0 ? 12 : timeinfo.tm_hour, timeinfo.tm_min, value_amSymbol];
		return [[NSString alloc] initWithFormat:@"%d:%02d %@",
			(timeinfo.tm_hour - 12 == 0) ? 12 : (timeinfo.tm_hour - 12), timeinfo.tm_min, value_pmSymbol];
	}
	return [[NSString alloc] initWithFormat:@"%02d:%02d", timeinfo.tm_hour, timeinfo.tm_min];
}

static NSString *shortAbsoluteDate(struct tm timeinfo) {
	if (value_monthFirst)
		return [[NSString alloc] initWithFormat:@"%d%c%d%c%02d", timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_mday, value_date_separator, timeinfo.tm_year - 100];
	return [[NSString alloc] initWithFormat:@"%d%c%02d%c%02d", timeinfo.tm_mday, value_date_separator, timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_year - 100];
}

@implementation TGDateUtils

+ (NSString *)stringForShortTime:(int)time {
	time_t t = time;
	struct tm timeinfo;
	localtime_r(&t, &timeinfo);

	return clockText(timeinfo);
}

+ (NSString *)stringForDialogTime:(int)time {
	time_t t = time;
	struct tm timeinfo;
	localtime_r(&t, &timeinfo);

	return [[NSString alloc] initWithFormat:@"%@ %d", monthNameGenShort(timeinfo.tm_mon), timeinfo.tm_mday];
}

+ (NSString *)stringForDayOfMonth:(int)date dayOfMonth:(int *)dayOfMonth {
	time_t t = date;
	struct tm timeinfo;
	localtime_r(&t, &timeinfo);
	if (dayOfMonth != NULL)
		*dayOfMonth = timeinfo.tm_mday;
	return [[NSString alloc] initWithFormat:@"%d %@", timeinfo.tm_mday, monthNameGenShort(timeinfo.tm_mon)];
}

+ (NSString *)stringForDayOfWeek:(int)date {
	time_t t = date;
	struct tm timeinfo;
	localtime_r(&t, &timeinfo);
	return weekdayNameShort(timeinfo.tm_wday);
}

+ (NSString *)stringForMessageListDate:(int)date {
	time_t t = date;
	struct tm timeinfo;
	localtime_r(&t, &timeinfo);
	time_t t_now = time(0);
	struct tm timeinfo_now;
	localtime_r(&t_now, &timeinfo_now);

	int dayDiff = TGDateDayDifference(timeinfo, timeinfo_now);
	if (dayDiff == 0)
		return [self stringForShortTime:date];
	if (dayDiff >= -6 && dayDiff <= -1)
		return weekdayNameShort(timeinfo.tm_wday);
	return shortAbsoluteDate(timeinfo);
}

+ (NSString *)stringForLastSeen:(int)date {
	time_t t = date;
	struct tm timeinfo;
	localtime_r(&t, &timeinfo);
	time_t t_now = time(0);
	struct tm timeinfo_now;
	localtime_r(&t_now, &timeinfo_now);

	int dayDiff = TGDateDayDifference(timeinfo, timeinfo_now);
	if (dayDiff == 0 || dayDiff == -1) {
		NSString *format = dayDiff == 0
			? TGL(@"Time.TodayAt", @"today at %@")
			: TGL(@"Time.YesterdayAt", @"yesterday at %@");
		return [[NSString alloc] initWithFormat:format, clockText(timeinfo)];
	}
	return shortAbsoluteDate(timeinfo);
}

+ (NSString *)stringForLastSeenShort:(int)date {
	return [self stringForLastSeen:date];
}

+ (NSString *)stringForRelativeLastSeen:(int)date {
	return [self stringForRelativeLastSeen:date now:time(0)];
}

+ (NSString *)stringForRelativeLastSeen:(int)date now:(time_t)now {
	time_t t = date;
	struct tm timeinfo;
	localtime_r(&t, &timeinfo);
	time_t t_now = now;
	struct tm timeinfo_now;
	localtime_r(&t_now, &timeinfo_now);

	int dayDiff = TGDateDayDifference(timeinfo, timeinfo_now);
	int minutesDiff = (int)((t_now - date) / 60);
	int hoursDiff = (int)((t_now - date) / (60 * 60));

	if (dayDiff == 0 && hoursDiff <= 23) {
		if (minutesDiff < 1)
			return TGL(@"Time.JustNow", @"just now");
		if (minutesDiff < 60)
			return TGLPlural(@"Time.MinutesAgo", minutesDiff, @"%@ minute ago", @"%@ minutes ago");
		return TGLPlural(@"Time.HoursAgo", hoursDiff, @"%@ hour ago", @"%@ hours ago");
	}
	if (dayDiff == 0 || dayDiff == -1)
		return [self stringForLastSeen:date];
	return shortAbsoluteDate(timeinfo);
}

+ (NSString *)stringForShortDate:(int)date {
	time_t t = date;
	struct tm timeinfo;
	localtime_r(&t, &timeinfo);
	return shortAbsoluteDate(timeinfo);
}

+ (NSString *)stringForWeekday:(int)date {
	time_t t = date;
	struct tm timeinfo;
	localtime_r(&t, &timeinfo);
	return weekdayNameFull(timeinfo.tm_wday);
}

+ (NSString *)stringForDateAndTime:(int)date {
	time_t t = date;
	struct tm timeinfo;
	localtime_r(&t, &timeinfo);
	return [[NSString alloc] initWithFormat:@"%@ %@", shortAbsoluteDate(timeinfo),
		clockText(timeinfo)];
}

+ (NSString *)stringForMonthAndYear:(int)date {
	time_t t = date;
	struct tm parts;
	localtime_r(&t, &parts);
	return [[NSString alloc] initWithFormat:@"%@ %d", monthNameFull(parts.tm_mon),
		parts.tm_year + 1900];
}

+ (NSString *)stringForFullDate:(int)date {
	time_t t = date;
	struct tm parts;
	localtime_r(&t, &parts);
	if (!TGDateUtilsInitialized)
		initializeTGDateUtils();
	NSString *month = monthNameFull(parts.tm_mon);
	if (value_monthFirst)
		return [[NSString alloc] initWithFormat:@"%@ %d, %d", month, parts.tm_mday,
			parts.tm_year + 1900];
	return [[NSString alloc] initWithFormat:@"%d %@ %d", parts.tm_mday, month,
		parts.tm_year + 1900];
}

+ (NSString *)stringForFullDateAndTime:(int)date {
	time_t t = date;
	struct tm parts;
	localtime_r(&t, &parts);
	return [[NSString alloc] initWithFormat:@"%@ %@", [self stringForFullDate:date],
		clockText(parts)];
}

+ (NSString *)stringForDayAndMonth:(int)date {
	time_t t = date;
	struct tm parts;
	localtime_r(&t, &parts);
	if (!TGDateUtilsInitialized)
		initializeTGDateUtils();
	NSString *month = monthNameFull(parts.tm_mon);
	if (value_monthFirst)
		return [[NSString alloc] initWithFormat:@"%@ %d", month, parts.tm_mday];
	return [[NSString alloc] initWithFormat:@"%d %@", parts.tm_mday, month];
}

+ (NSString *)stringForShortTimeWithoutMarker:(int)date {
	time_t t = date;
	struct tm parts;
	localtime_r(&t, &parts);
	if (!dateHas12hFormat())
		return [[NSString alloc] initWithFormat:@"%02d:%02d", parts.tm_hour, parts.tm_min];
	int hour = parts.tm_hour % 12;
	return [[NSString alloc] initWithFormat:@"%d:%02d", hour == 0 ? 12 : hour, parts.tm_min];
}

+ (NSString *)stringForClockMarker:(int)date {
	if (!dateHas12hFormat())
		return @"";
	time_t t = date;
	struct tm parts;
	localtime_r(&t, &parts);
	return parts.tm_hour < 12 ? value_amSymbol : value_pmSymbol;
}

+ (NSString *)clockMarkerAm {
	if (!TGDateUtilsInitialized)
		initializeTGDateUtils();
	return value_amSymbol;
}

+ (NSString *)clockMarkerPm {
	if (!TGDateUtilsInitialized)
		initializeTGDateUtils();
	return value_pmSymbol;
}

+ (NSString *)shortWeekdayNameForTmWday:(int)wday {
	return weekdayNameShort(wday);
}

+ (NSString *)stringForDayDivider:(int)date now:(time_t)now {
	time_t t = date;
	struct tm parts;
	localtime_r(&t, &parts);
	struct tm nowParts;
	localtime_r(&now, &nowParts);

	if (parts.tm_year == nowParts.tm_year && parts.tm_yday == nowParts.tm_yday)
		return TGL(@"Weekday.Today", @"Today");

	if (!TGDateUtilsInitialized)
		initializeTGDateUtils();
	NSString *month = monthNameFull(parts.tm_mon);
	NSString *dayAndMonth = value_monthFirst
		? [[NSString alloc] initWithFormat:@"%@ %d", month, parts.tm_mday]
		: [[NSString alloc] initWithFormat:@"%d %@", parts.tm_mday, month];
	if (parts.tm_year == nowParts.tm_year)
		return dayAndMonth;
	return [[NSString alloc] initWithFormat:@"%@ %d", dayAndMonth, parts.tm_year + 1900];
}

+ (NSString *)stringForDayDivider:(int)date {
	return [self stringForDayDivider:date now:time(0)];
}

+ (NSString *)stringForUntil:(int)date {
	time_t t = date;
	struct tm timeinfo;
	localtime_r(&t, &timeinfo);
	time_t t_now = time(0);
	struct tm timeinfo_now;
	localtime_r(&t_now, &timeinfo_now);

	int dayDiff = TGDateDayDifference(timeinfo, timeinfo_now);
	if (dayDiff == 0 || dayDiff == 1) {
		NSString *format = dayDiff == 0
			? TGL(@"Time.TodayAt", @"today at %@")
			: TGL(@"Time.TomorrowAt", @"tomorrow at %@");
		return [[NSString alloc] initWithFormat:format, clockText(timeinfo)];
	}
	return shortAbsoluteDate(timeinfo);
}

@end

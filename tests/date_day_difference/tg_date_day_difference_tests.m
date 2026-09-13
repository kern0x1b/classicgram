#import "tg_date_day_difference_tests.h"
#import "../../src/Utilities/TGDateDayDifference.h"

static struct tm TGDateDayDifferenceTestDay(int year, int month, int day, int hour, int minute) {
	struct tm parts;
	memset(&parts, 0, sizeof(parts));
	parts.tm_year = year - 1900;
	parts.tm_mon = month - 1;
	parts.tm_mday = day;
	parts.tm_hour = hour;
	parts.tm_min = minute;
	return parts;
}

TGTestOutcome TGDateDayDifferenceTestSameDayIsZero(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	struct tm morning = TGDateDayDifferenceTestDay(2026, 9, 9, 0, 1);
	struct tm night = TGDateDayDifferenceTestDay(2026, 9, 9, 23, 59);

	TGTestExpectEqualInteger(&outcome, TGDateDayDifference(morning, night), 0,
			"one minute past midnight and one minute before it are the same calendar day");
	TGTestExpectEqualInteger(&outcome, TGDateDayDifference(night, morning), 0,
			"the comparison is symmetric within a day");

	return outcome;
}

TGTestOutcome TGDateDayDifferenceTestNeighbouringDays(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	struct tm today = TGDateDayDifferenceTestDay(2026, 9, 9, 12, 0);
	struct tm yesterday = TGDateDayDifferenceTestDay(2026, 9, 8, 12, 0);
	struct tm tomorrow = TGDateDayDifferenceTestDay(2026, 9, 10, 12, 0);

	TGTestExpectEqualInteger(&outcome, TGDateDayDifference(yesterday, today), -1,
			"a past day is negative, which is what the last-seen wording keys off");
	TGTestExpectEqualInteger(&outcome, TGDateDayDifference(tomorrow, today), 1,
			"a future day is positive, which is what the mute-until wording keys off");

	return outcome;
}

TGTestOutcome TGDateDayDifferenceTestCrossesTheYearBoundary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	struct tm newYearsEveNight = TGDateDayDifferenceTestDay(2025, 12, 31, 23, 0);
	struct tm newYearsDay = TGDateDayDifferenceTestDay(2026, 1, 1, 0, 30);

	TGTestExpectEqualInteger(&outcome, TGDateDayDifference(newYearsEveNight, newYearsDay), -1,
			"a message sent at 23:00 on 31 December and read at 00:30 on 1 January is one day old: comparing "
			"tm_yday alone made it a whole year away, which is why the last-seen wording lost \"yesterday\" "
			"for a few days every January");
	TGTestExpectEqualInteger(&outcome, TGDateDayDifference(newYearsDay, newYearsEveNight), 1,
			"and one day ahead in the other direction, so the mute-until wording keeps \"tomorrow\"");

	struct tm sixDaysBefore = TGDateDayDifferenceTestDay(2025, 12, 27, 9, 0);
	TGTestExpectEqualInteger(&outcome, TGDateDayDifference(sixDaysBefore, newYearsDay), -5,
			"the chat list's six-day weekday window also has to survive the rollover");

	return outcome;
}

TGTestOutcome TGDateDayDifferenceTestCrossesALeapDay(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	struct tm leapDay = TGDateDayDifferenceTestDay(2024, 2, 29, 12, 0);
	struct tm dayAfterLeapDay = TGDateDayDifferenceTestDay(2024, 3, 1, 12, 0);
	struct tm dayBeforeLeapDay = TGDateDayDifferenceTestDay(2024, 2, 28, 12, 0);

	TGTestExpectEqualInteger(&outcome, TGDateDayDifference(leapDay, dayAfterLeapDay), -1,
			"29 February is the day before 1 March in a leap year");
	TGTestExpectEqualInteger(&outcome, TGDateDayDifference(dayBeforeLeapDay, dayAfterLeapDay), -2,
			"and two days separate 28 February from 1 March that year");

	struct tm nonLeapFeb28 = TGDateDayDifferenceTestDay(2025, 2, 28, 12, 0);
	struct tm nonLeapMar1 = TGDateDayDifferenceTestDay(2025, 3, 1, 12, 0);
	TGTestExpectEqualInteger(&outcome, TGDateDayDifference(nonLeapFeb28, nonLeapMar1), -1,
			"in a non-leap year 28 February is the day before 1 March");

	return outcome;
}

TGTestOutcome TGDateDayDifferenceTestSpansWholeYears(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	struct tm now = TGDateDayDifferenceTestDay(2026, 9, 9, 12, 0);
	struct tm oneYearEarlier = TGDateDayDifferenceTestDay(2025, 9, 9, 12, 0);
	struct tm fourYearsEarlier = TGDateDayDifferenceTestDay(2022, 9, 9, 12, 0);

	TGTestExpectEqualInteger(&outcome, TGDateDayDifference(oneYearEarlier, now), -365,
			"a year that contains no 29 February is 365 days");
	TGTestExpectEqualInteger(&outcome, TGDateDayDifference(fourYearsEarlier, now), -1461,
			"four years spanning one leap day are 1461 days, so the arithmetic must count real days rather "
			"than assume 365 apiece");

	return outcome;
}

TGTestOutcome TGDateDayDifferenceTestIgnoresTheTimeOfDay(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	struct tm lateYesterday = TGDateDayDifferenceTestDay(2026, 9, 8, 23, 59);
	struct tm earlyToday = TGDateDayDifferenceTestDay(2026, 9, 9, 0, 0);

	TGTestExpectEqualInteger(&outcome, TGDateDayDifference(lateYesterday, earlyToday), -1,
			"one minute apart across midnight is still a full calendar day apart, which is what the wording "
			"describes: an elapsed-hours comparison would call it the same day");

	return outcome;
}

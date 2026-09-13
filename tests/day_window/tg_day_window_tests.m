#import "tg_day_window_tests.h"

#import "../../src/Utilities/TGDayWindow.h"

#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <time.h>

static NSTimeInterval TGTestLocalDayStart(int year, int month, int day) {
	struct tm parts;
	memset(&parts, 0, sizeof(parts));
	parts.tm_year = year - 1900;
	parts.tm_mon = month - 1;
	parts.tm_mday = day;
	parts.tm_isdst = -1;
	return (NSTimeInterval)mktime(&parts);
}

static void TGTestUseTimeZone(const char *name) {
	setenv("TZ", name, 1);
	tzset();
}

static void TGTestRestoreTimeZone(void) {
	unsetenv("TZ");
	tzset();
}

TGTestOutcome TGDayWindowTestAnOrdinaryDayHoldsItsOwnHours(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;
	TGTestUseTimeZone("Europe/Warsaw");

	NSTimeInterval dayStart = TGTestLocalDayStart(2026, 6, 15);

	TGTestExpectTrue(&outcome, TGTimestampFallsOnDayStartingAt(dayStart, dayStart),
			"the first second of the day is in it");
	TGTestExpectTrue(&outcome, TGTimestampFallsOnDayStartingAt(dayStart + 23 * 3600 + 3599, dayStart),
			"and the last second of the day is too");
	TGTestExpectTrue(&outcome, !TGTimestampFallsOnDayStartingAt(dayStart + 24 * 3600, dayStart),
			"and the next midnight is not");

	TGTestRestoreTimeZone();
	return outcome;
}

TGTestOutcome TGDayWindowTestTheLongDayHoldsTwentyFiveHours(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;
	TGTestUseTimeZone("Europe/Warsaw");

	NSTimeInterval dayStart = TGTestLocalDayStart(2026, 10, 25);

	TGTestExpectTrue(&outcome, TGTimestampFallsOnDayStartingAt(dayStart + 24 * 3600 + 1800, dayStart),
			"on the day the clocks go back the day is 25 hours long, and a message sent in "
			"its last hour belongs to it - a fixed 86400-second window would have dropped it");
	TGTestExpectTrue(&outcome, !TGTimestampFallsOnDayStartingAt(dayStart + 25 * 3600, dayStart),
			"and the hour after that belongs to the next day");

	TGTestRestoreTimeZone();
	return outcome;
}

TGTestOutcome TGDayWindowTestTheShortDayHoldsTwentyThree(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;
	TGTestUseTimeZone("Europe/Warsaw");

	NSTimeInterval dayStart = TGTestLocalDayStart(2026, 3, 29);

	TGTestExpectTrue(&outcome, TGTimestampFallsOnDayStartingAt(dayStart + 22 * 3600 + 3599, dayStart),
			"on the day the clocks go forward the day is 23 hours long and its last second "
			"is still its own");
	TGTestExpectTrue(&outcome, !TGTimestampFallsOnDayStartingAt(dayStart + 23 * 3600, dayStart),
			"a fixed 86400-second window would have counted the next day's first hour as "
			"part of this one, so jumping to a date could land on the day after it");

	TGTestRestoreTimeZone();
	return outcome;
}

TGTestOutcome TGDayWindowTestBeforeTheDayIsNeverInIt(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;
	TGTestUseTimeZone("Europe/Warsaw");

	NSTimeInterval dayStart = TGTestLocalDayStart(2026, 6, 15);

	TGTestExpectTrue(&outcome, !TGTimestampFallsOnDayStartingAt(dayStart - 1, dayStart),
			"the second before the day starts belongs to the day before");

	TGTestRestoreTimeZone();
	return outcome;
}

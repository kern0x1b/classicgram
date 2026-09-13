#import "TGDateDayDifference.h"

static int TGDateDaysFromCivil(int year, int month, int day) {
	year -= month <= 2;
	int era = (year >= 0 ? year : year - 399) / 400;
	unsigned yearOfEra = (unsigned)(year - era * 400);
	unsigned dayOfYear = (unsigned)((153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1);
	unsigned dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear;
	return era * 146097 + (int)dayOfEra - 719468;
}

int TGDateDayDifference(struct tm then, struct tm now) {
	int thenDay = TGDateDaysFromCivil(then.tm_year + 1900, then.tm_mon + 1, then.tm_mday);
	int nowDay = TGDateDaysFromCivil(now.tm_year + 1900, now.tm_mon + 1, now.tm_mday);
	return thenDay - nowDay;
}

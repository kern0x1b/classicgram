#import "TGBusinessOpenState.h"

static NSDictionary *TGBusinessDay(NSArray *days, NSInteger weekday) {
	if (![days isKindOfClass:NSArray.class] || weekday < 0 || weekday >= (NSInteger)days.count)
		return nil;
	id day = days[(NSUInteger)weekday];
	return [day isKindOfClass:NSDictionary.class] ? day : nil;
}

static NSString *TGBusinessClockText(NSInteger minuteOfDay) {
	return [NSString stringWithFormat:@"%02ld:%02ld",
			(long)(minuteOfDay / 60), (long)(minuteOfDay % 60)];
}

BOOL TGBusinessIsOpenAt(NSArray *days, NSInteger weekday, NSInteger minuteOfDay) {
	NSDictionary *day = TGBusinessDay(days, weekday);
	if (![day[@"open"] boolValue])
		return NO;
	NSInteger start = [day[@"startMinute"] integerValue];
	NSInteger end = [day[@"endMinute"] integerValue];
	if (end <= start)
		return NO;
	return minuteOfDay >= start && minuteOfDay < end;
}

NSString *TGBusinessDayIntervalText(NSArray *days, NSInteger weekday) {
	NSDictionary *day = TGBusinessDay(days, weekday);
	if (![day[@"open"] boolValue])
		return nil;
	NSInteger start = [day[@"startMinute"] integerValue];
	NSInteger end = [day[@"endMinute"] integerValue];
	if (end <= start)
		return nil;
	if (start == 0 && end >= 24 * 60)
		return @"";
	return [NSString stringWithFormat:@"%@ - %@",
			TGBusinessClockText(start), TGBusinessClockText(end % (24 * 60))];
}

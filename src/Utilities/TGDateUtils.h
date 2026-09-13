#import <Foundation/Foundation.h>

@interface TGDateUtils : NSObject

+ (NSString *)stringForShortTime:(int)time;
+ (NSString *)stringForDialogTime:(int)time;
+ (NSString *)stringForDayOfMonth:(int)date dayOfMonth:(int *)dayOfMonth;
+ (NSString *)stringForDayOfWeek:(int)date;
+ (NSString *)stringForMessageListDate:(int)date;
+ (NSString *)stringForLastSeen:(int)date;
+ (NSString *)stringForLastSeenShort:(int)date;
+ (NSString *)stringForRelativeLastSeen:(int)date;
+ (NSString *)stringForRelativeLastSeen:(int)date now:(time_t)now;
+ (NSString *)stringForUntil:(int)date;
+ (NSString *)stringForShortDate:(int)date;
+ (NSString *)stringForWeekday:(int)date;
+ (NSString *)stringForDateAndTime:(int)date;
+ (NSString *)stringForMonthAndYear:(int)date;
+ (NSString *)stringForFullDate:(int)date;
+ (NSString *)stringForFullDateAndTime:(int)date;
+ (NSString *)stringForDayAndMonth:(int)date;
+ (NSString *)shortWeekdayNameForTmWday:(int)wday;
+ (NSString *)stringForShortTimeWithoutMarker:(int)date;
+ (NSString *)stringForClockMarker:(int)date;
+ (NSString *)clockMarkerAm;
+ (NSString *)clockMarkerPm;
+ (NSString *)stringForDayDivider:(int)date;
+ (NSString *)stringForDayDivider:(int)date now:(time_t)now;

@end

#ifdef __cplusplus
extern "C" {
#endif

bool TGUse12hDateFormat(void);

#ifdef __cplusplus
}
#endif

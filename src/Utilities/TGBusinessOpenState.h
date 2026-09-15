#import <Foundation/Foundation.h>

BOOL TGBusinessIsOpenAt(NSArray *days, NSInteger weekday, NSInteger minuteOfDay);

NSString *TGBusinessDayIntervalText(NSArray *days, NSInteger weekday);

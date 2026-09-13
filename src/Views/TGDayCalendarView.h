#import <UIKit/UIKit.h>

@interface TGDayCalendarView : UIView

+ (void)showForChat:(int64_t)chatId
		 aroundDate:(NSTimeInterval)date
		loadedDates:(NSArray *)loadedMessageDates
	 reachesPresent:(BOOL)reachesPresent
		  onPickDay:(void (^)(NSTimeInterval seekDate, NSTimeInterval dayStart))pick;

+ (void)dismiss;

+ (void)resetForAccountSwitch;

@end

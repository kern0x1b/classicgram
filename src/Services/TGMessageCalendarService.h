#import <Foundation/Foundation.h>

@interface TGMessageCalendarService : NSObject

+ (void)messageCalendarForChat:(int64_t)chatId
						filter:(NSString *)filter
				 fromMessageId:(int64_t)fromMessageId
					completion:(void (^)(NSArray *days, NSInteger totalCount))completion;

@end

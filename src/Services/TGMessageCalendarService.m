#import "TGMessageCalendarService.h"
#import "TGClient+Search.h"

@implementation TGMessageCalendarService

+ (void)messageCalendarForChat:(int64_t)chatId
						filter:(NSString *)filter
				 fromMessageId:(int64_t)fromMessageId
					completion:(void (^)(NSArray *days, NSInteger totalCount))completion {
	[[TGClient shared] messageCalendarForChat:chatId
									   filter:filter
								fromMessageId:fromMessageId
								   completion:completion];
}

@end

#import <UIKit/UIKit.h>

@interface TGBotAddToChat : NSObject

+ (void)presentForLink:(NSString *)link
		fromController:(UIViewController *)owner
			completion:(void (^)(int64_t chatId, NSString *errorCode))completion;

@end

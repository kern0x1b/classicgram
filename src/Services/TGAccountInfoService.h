#import <Foundation/Foundation.h>

@interface TGAccountInfoService : NSObject

+ (void)accountInfoWithCompletion:(void (^)(NSDictionary *info))completion;

+ (BOOL)isPremiumAccount;

@end

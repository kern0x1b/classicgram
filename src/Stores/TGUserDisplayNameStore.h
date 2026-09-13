#import <Foundation/Foundation.h>

@interface TGUserDisplayNameStore : NSObject

+ (NSString *)nameForUserId:(int64_t)userId;

+ (void)ensureUserName:(int64_t)userId completion:(void (^)(void))completion;

@end

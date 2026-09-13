#import "TGUserDisplayNameStore.h"
#import "TGClient.h"
#import "TGClient+ChatState.h"

@implementation TGUserDisplayNameStore

+ (NSString *)nameForUserId:(int64_t)userId {
	return [[TGClient shared] nameForUserId:userId];
}

+ (void)ensureUserName:(int64_t)userId completion:(void (^)(void))completion {
	[[TGClient shared] ensureUserName:userId completion:completion];
}

@end

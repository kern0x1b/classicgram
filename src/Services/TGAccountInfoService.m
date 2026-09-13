#import "TGAccountInfoService.h"
#import "TGClient+Account.h"
#import "TGClient+Premium.h"

@implementation TGAccountInfoService

+ (void)accountInfoWithCompletion:(void (^)(NSDictionary *info))completion {
	[[TGClient shared] accountInfoWithCompletion:completion];
}

+ (BOOL)isPremiumAccount {
	return [[TGClient shared] isPremiumAccount];
}

@end

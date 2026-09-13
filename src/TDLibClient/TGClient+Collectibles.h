#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (Collectibles)

- (void)collectibleItemInfoForUsername:(NSString *)username
							completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)collectibleItemInfoForPhoneNumber:(NSString *)phoneNumber
							   completion:(void (^ _Nullable)(NSDictionary *info))completion;

@end

NS_ASSUME_NONNULL_END

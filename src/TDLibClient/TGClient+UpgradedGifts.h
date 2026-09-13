#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (UpgradedGifts)

- (void)upgradedGiftInfoForName:(NSString *)name
					 completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)upgradedGiftValueInfoForName:(NSString *)name
						  completion:(void (^ _Nullable)(NSDictionary *info))completion;

@end

NS_ASSUME_NONNULL_END

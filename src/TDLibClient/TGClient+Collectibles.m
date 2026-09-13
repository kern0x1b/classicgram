#import "TGClient+Private.h"
#import "TGClient+Collectibles.h"

static NSString *TGCIString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

@interface TGClient (CollectiblesPrivate)
- (void)collectibleItemInfoForType:(NSDictionary *)type
						completion:(void (^)(NSDictionary *))completion;
@end

@implementation TGClient (Collectibles)

- (void)collectibleItemInfoForType:(NSDictionary *)type
						completion:(void (^)(NSDictionary *))completion {
	if (!completion)
		return;
	[self request:@{@"@type" : @"getCollectibleItemInfo", @"type" : type}
		completion:^(NSDictionary *result) {
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			completion(@{
				@"purchaseDate" : result[@"purchase_date"] ?: @0,
				@"currency" : TGCIString(result[@"currency"]),
				@"amount" : result[@"amount"] ?: @0,
				@"cryptocurrency" : TGCIString(result[@"cryptocurrency"]),
				@"cryptocurrencyAmount" : result[@"cryptocurrency_amount"] ?: @0,
				@"url" : TGCIString(result[@"url"]),
			});
		}];
}

- (void)collectibleItemInfoForUsername:(NSString *)username
							completion:(void (^)(NSDictionary *))completion {
	if (!username.length) {
		if (completion)
			completion(nil);
		return;
	}
	[self collectibleItemInfoForType:@{@"@type" : @"collectibleItemTypeUsername",
		@"username" : username}
						  completion:completion];
}

- (void)collectibleItemInfoForPhoneNumber:(NSString *)phoneNumber
							   completion:(void (^)(NSDictionary *))completion {
	if (!phoneNumber.length) {
		if (completion)
			completion(nil);
		return;
	}
	[self collectibleItemInfoForType:@{@"@type" : @"collectibleItemTypePhoneNumber",
		@"phone_number" : phoneNumber}
						  completion:completion];
}

@end

#import "TGClient+Private.h"
#import "TGClient+UpgradedGifts.h"

static NSDictionary *TGUGDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSString *TGUGString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

@implementation TGClient (UpgradedGifts)

- (void)upgradedGiftInfoForName:(NSString *)name
					 completion:(void (^)(NSDictionary *))completion {
	if (!name.length) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{@"@type" : @"getUpgradedGift", @"name" : name}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			NSDictionary *resale = TGUGDict(result[@"resale_parameters"]);
			NSMutableDictionary *out = [NSMutableDictionary dictionary];
			out[@"title"] = TGUGString(result[@"title"]);
			out[@"name"] = TGUGString(result[@"name"]);
			out[@"number"] = result[@"number"] ?: @0;
			out[@"totalCount"] = result[@"total_upgraded_count"] ?: @0;
			out[@"isCrafted"] = @([result[@"is_crafted"] boolValue]);
			out[@"modelName"] = TGUGString(TGUGDict(result[@"model"])[@"name"]);
			out[@"symbolName"] = TGUGString(TGUGDict(result[@"symbol"])[@"name"]);
			out[@"backdropName"] = TGUGString(TGUGDict(result[@"backdrop"])[@"name"]);
			out[@"canSendPurchaseOffer"] = @([result[@"can_send_purchase_offer"] boolValue]);
			if (resale)
				out[@"resaleStarCount"] = resale[@"star_count"] ?: @0;
			out[@"valueCurrency"] = TGUGString(result[@"value_currency"]);
			out[@"valueAmount"] = result[@"value_amount"] ?: @0;
			out[@"valueUsdAmount"] = result[@"value_usd_amount"] ?: @0;
			completion(out);
		}];
}

- (void)upgradedGiftValueInfoForName:(NSString *)name
						  completion:(void (^)(NSDictionary *))completion {
	if (!name.length) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{@"@type" : @"getUpgradedGiftValueInfo", @"name" : name}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			completion(@{
				@"currency" : TGUGString(result[@"currency"]),
				@"value" : result[@"value"] ?: @0,
				@"isAverage" : @([result[@"is_value_average"] boolValue]),
				@"initialSaleDate" : result[@"initial_sale_date"] ?: @0,
				@"initialSaleStarCount" : result[@"initial_sale_star_count"] ?: @0,
				@"initialSalePrice" : result[@"initial_sale_price"] ?: @0,
				@"lastSaleDate" : result[@"last_sale_date"] ?: @0,
				@"lastSalePrice" : result[@"last_sale_price"] ?: @0,
				@"isLastSaleOnFragment" : @([result[@"is_last_sale_on_fragment"] boolValue]),
				@"minimumPrice" : result[@"minimum_price"] ?: @0,
				@"averageSalePrice" : result[@"average_sale_price"] ?: @0,
				@"telegramListedCount" : result[@"telegram_listed_gift_count"] ?: @0,
				@"fragmentListedCount" : result[@"fragment_listed_gift_count"] ?: @0,
				@"fragmentUrl" : TGUGString(result[@"fragment_url"]),
			});
		}];
}

@end

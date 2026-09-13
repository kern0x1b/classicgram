#import "TGFlattenPayments.h"
#import "TGLocalization.h"
#import <math.h>

static NSDictionary *TGFPDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSArray *TGFPArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : [NSArray array];
}

static NSString *TGFPString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSInteger TGPayCurrencyExponent(NSString *currencyCode) {
	static NSSet *zeroExponentCurrencies;
	static NSSet *threeExponentCurrencies;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		zeroExponentCurrencies = [NSSet setWithObjects:
			@"BIF", @"CLP", @"DJF", @"GNF", @"ISK", @"JPY", @"KMF", @"KRW",
			@"MGA", @"PYG", @"RWF", @"UGX", @"VND", @"VUV", @"XAF", @"XOF", @"XPF", nil];
		threeExponentCurrencies = [NSSet setWithObjects:
			@"BHD", @"IQD", @"JOD", @"KWD", @"LYD", @"OMR", @"TND", nil];
	});
	NSString *code = [currencyCode isKindOfClass:NSString.class] ? currencyCode.uppercaseString : @"";
	if ([zeroExponentCurrencies containsObject:code])
		return 0;
	if ([threeExponentCurrencies containsObject:code])
		return 3;
	return 2;
}

NSString *TGPayDecimalAmount(long long minorUnitsAmount, NSString *currencyCode) {
	NSInteger exponent = TGPayCurrencyExponent(currencyCode);
	if (exponent == 0)
		return [NSString stringWithFormat:@"%lld", minorUnitsAmount];
	return [NSString stringWithFormat:@"%.*f", (int)exponent,
		minorUnitsAmount / pow(10.0, exponent)];
}

long long TGPayStars(id starAmount) {
	NSDictionary *amount = TGFPDict(starAmount);
	if (amount)
		return [amount[@"star_count"] longLongValue];
	return [starAmount isKindOfClass:NSNumber.class] ? [starAmount longLongValue] : 0;
}

long long TGPayStarsNanos(id starAmount) {
	NSDictionary *amount = TGFPDict(starAmount);
	if (amount)
		return [amount[@"nanostar_count"] longLongValue];
	return 0;
}

NSNumber *TGPayPhotoFileId(id photo) {
	NSArray *sizes = TGFPArray(TGFPDict(photo)[@"sizes"]);
	NSDictionary *best = nil;
	for (id entry in sizes) {
		NSDictionary *size = TGFPDict(entry);
		if (!size)
			continue;
		if (!best || [size[@"width"] intValue] > [best[@"width"] intValue])
			best = size;
	}
	NSNumber *fileId = TGFPDict(best[@"photo"])[@"id"];
	return [fileId isKindOfClass:NSNumber.class] ? fileId : nil;
}

NSString *TGPayShortType(NSString *type, NSString *prefix) {
	if (![type isKindOfClass:NSString.class] || ![type hasPrefix:prefix])
		return TGFPString(type);
	return [type substringFromIndex:prefix.length];
}

NSString *TGPayHumanType(NSString *shortType) {
	static NSDictionary *titles;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSString *mediaPurchase = TGL(@"Stars.Transaction.MediaPurchase", @"Media Purchase");
		NSString *subscription = TGL(@"Stars.Transaction.Subscription", @"Subscription");
		NSString *giftPurchase = TGL(@"Stars.Transaction.GiftPurchase", @"Gift Purchase");
		NSString *giftSale = TGL(@"Stars.Transaction.GiftSale", @"Gift Sale");
		NSString *giftUpgrade = TGL(@"Stars.Transaction.GiftUpgrade", @"Gift Upgrade");
		NSString *starReaction = TGL(@"Stars.Transaction.Reaction.Title", @"Star reaction");
		NSString *paid = TGL(@"Stars.Transaction.Paid", @"Paid");
		NSString *unsupported = TGL(@"Stars.Transaction.Unsupported.Title", @"Unsupported");
		titles = @{
			@"PremiumBotDeposit" : TGL(@"Stars.Transaction.PremiumBotTopUp.Title", @"Stars Top-Up"),
			@"AppStoreDeposit" : TGL(@"Stars.Transaction.AppleTopUp.Title", @"Stars Top-Up"),
			@"GooglePlayDeposit" : TGL(@"Stars.Transaction.GoogleTopUp.Title", @"Stars Top-Up"),
			@"FragmentDeposit" : TGL(@"Stars.Transaction.FragmentTopUp.Title", @"Stars Top-Up"),
			@"UserDeposit" : TGL(@"Stars.Transaction.Gift.Title", @"Gift"),
			@"GiveawayDeposit" : TGL(@"Stars.Transaction.Giveaway.Giveaway", @"Giveaway"),
			@"FragmentWithdrawal" : TGL(@"Stars.Transaction.FragmentWithdrawal.Title", @"Stars Withdrawal"),
			@"TelegramAdsWithdrawal" : TGL(@"Stars.Transaction.TelegramAds.Title", @"Stars Withdrawal"),
			@"TelegramApiUsage" : unsupported,
			@"BotPaidMediaPurchase" : mediaPurchase,
			@"BotPaidMediaSale" : mediaPurchase,
			@"ChannelPaidMediaPurchase" : mediaPurchase,
			@"ChannelPaidMediaSale" : mediaPurchase,
			@"BotInvoicePurchase" : unsupported,
			@"BotInvoiceSale" : unsupported,
			@"BotSubscriptionPurchase" : subscription,
			@"BotSubscriptionSale" : subscription,
			@"ChannelSubscriptionPurchase" : subscription,
			@"ChannelSubscriptionSale" : subscription,
			@"GiftAuctionBid" : TGL(@"Stars.Transaction.GiftAuctionBid", @"Gift Auction Bid"),
			@"GiftPurchase" : giftPurchase,
			@"GiftPurchaseOffer" : giftPurchase,
			@"GiftTransfer" : TGL(@"Stars.Transaction.GiftTransfer", @"Gift Transfer"),
			@"GiftOriginalDetailsDrop" : TGL(@"Stars.Intro.Transaction.GiftDropOriginalDetails",
											 @"Gift Description Removal"),
			@"GiftSale" : giftSale,
			@"GiftUpgrade" : giftUpgrade,
			@"GiftUpgradePurchase" : giftUpgrade,
			@"UpgradedGiftPurchase" : giftPurchase,
			@"UpgradedGiftSale" : giftSale,
			@"ChannelPaidReactionSend" : starReaction,
			@"ChannelPaidReactionReceive" : starReaction,
			@"AffiliateProgramCommission" : TGL(@"StarsTransaction.Commission", @"Commission"),
			@"PaidMessageSend" : paid,
			@"PaidMessageReceive" : paid,
			@"PaidGroupCallMessageSend" : paid,
			@"PaidGroupCallMessageReceive" : paid,
			@"PaidGroupCallReactionSend" : TGL(@"Stars.Transaction.LiveStreamReaction",
											   @"Live Stream Reaction"),
			@"PaidGroupCallReactionReceive" : TGL(@"Stars.Transaction.LiveStreamReaction",
												  @"Live Stream Reaction"),
			@"SuggestedPostPaymentSend" : unsupported,
			@"SuggestedPostPaymentReceive" : unsupported,
			@"PremiumPurchase" : TGL(@"Notification.PremiumGift.Title", @"Telegram Premium"),
			@"BusinessBotTransferSend" : unsupported,
			@"BusinessBotTransferReceive" : unsupported,
			@"PublicPostSearch" : TGL(@"Stars.Transaction.SearchFee.Title", @"Extra Search Fee"),
			@"Unsupported" : unsupported,
		};
	});
	return titles[shortType] ?: TGL(@"Stars.Transaction.Unsupported.Title", @"Unsupported");
}

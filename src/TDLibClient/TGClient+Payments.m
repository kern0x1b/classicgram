#import "TGClient+ChatState.h"
#import "TGLocalization.h"
#import "TGClient+Payments.h"
#import "TGClient+Private.h"
#import "TGFlattenPayments.h"
#import "TGAccountManager.h"

static NSArray *TGPayArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : [NSArray array];
}

static NSDictionary *TGPayDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSString *TGPayString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSString *TGPayPlainText(id formattedText) {
	NSDictionary *text = TGPayDict(formattedText);
	return TGPayString(text[@"text"]);
}

static NSString *TGPayErrorText(NSDictionary *result, NSString *fallback) {
	NSString *message = TGResultIsError(result) ? TGPayString(result[@"message"]) : nil;
	return message.length ? message : fallback;
}

static NSNumber *TGPayStickerFileId(id sticker) {
	NSDictionary *file = TGPayDict(TGPayDict(sticker)[@"sticker"]);
	NSNumber *fileId = file[@"id"];
	return [fileId isKindOfClass:NSNumber.class] ? fileId : nil;
}

static long long TGPayCachedStarBalance = 0;

@implementation TGClient (Payments)

#pragma mark - senders

- (NSDictionary *)tg_senderForUser:(int64_t)userId {
	return @{@"@type" : @"messageSenderUser", @"user_id" : @(userId)};
}

- (NSDictionary *)tg_senderForChat:(int64_t)chatId {
	return @{@"@type" : @"messageSenderChat", @"chat_id" : @(chatId)};
}

- (NSDictionary *)tg_ownSender {
	return [self tg_senderForUser:[self.me[@"id"] longLongValue]];
}

- (void)tg_request:(NSDictionary *)request ok:(void (^)(BOOL ok))completion {
	[self request:request completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - star balance

- (long long)cachedStarBalance {
	return TGPayCachedStarBalance;
}

- (void)resetStarBalanceCacheForAccountSwitch {
	TGPayCachedStarBalance = 0;
}

- (void)starBalanceWithCompletion:(void (^)(long long))completion {
	[self request:@{
		@"@type" : @"getStarTransactions",
		@"owner_id" : [self tg_ownSender],
		@"offset" : @"",
		@"limit" : @1,
	} completion:^(NSDictionary *result) {
		long long stars = 0;
		if (!TGResultIsError(result)) {
			stars = TGPayStars(result[@"star_amount"]);
			TGPayCachedStarBalance = stars;
		}
		if (completion)
			completion(stars);
	}];
}

- (NSArray *)tg_starPaymentOptions:(id)options {
	NSMutableArray *out = [NSMutableArray array];
	for (id entry in TGPayArray(options)) {
		NSDictionary *option = TGPayDict(entry);
		if (!option)
			continue;
		[out addObject:@{
			@"stars" : option[@"star_count"] ?: @0,
			@"currency" : TGPayString(option[@"currency"]),
			@"amount" : option[@"amount"] ?: @0,
			@"storeProductId" : TGPayString(option[@"store_product_id"]),
			@"isAdditional" : @([option[@"is_additional"] boolValue]),
		}];
	}
	return out;
}

- (void)tg_starPaymentOptionsRequest:(NSDictionary *)request
						  completion:(void (^)(NSArray *))completion {
	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion([NSArray array]);
			return;
		}
		completion([self tg_starPaymentOptions:result[@"options"]]);
	}];
}

- (void)starPaymentOptionsWithCompletion:(void (^)(NSArray *))completion {
	[self tg_starPaymentOptionsRequest:@{@"@type" : @"getStarPaymentOptions"}
							completion:completion];
}

- (void)starGiftPaymentOptionsForUser:(int64_t)userId
						   completion:(void (^)(NSArray *))completion {
	[self tg_starPaymentOptionsRequest:@{
		@"@type" : @"getStarGiftPaymentOptions",
		@"user_id" : @(userId),
	}
							completion:completion];
}

#pragma mark - star subscriptions

- (NSDictionary *)tg_flattenStarSubscription:(NSDictionary *)subscription {
	NSDictionary *pricing = TGPayDict(subscription[@"pricing"]);
	NSDictionary *type = TGPayDict(subscription[@"type"]);
	NSString *typeName = TGPayString(type[@"@type"]);
	BOOL isBot = [typeName isEqualToString:@"starSubscriptionTypeBot"];

	return @{
		@"id" : TGPayString(subscription[@"id"]),
		@"chatId" : subscription[@"chat_id"] ?: @0,
		@"expirationDate" : subscription[@"expiration_date"] ?: @0,
		@"isCanceled" : @([subscription[@"is_canceled"] boolValue]),
		@"isExpiring" : @([subscription[@"is_expiring"] boolValue]),
		@"canReuse" : @([type[@"can_reuse"] boolValue]),
		@"period" : pricing[@"period"] ?: @0,
		@"stars" : pricing[@"star_count"] ?: @0,
		@"kind" : isBot ? @"bot" : @"channel",
		@"title" : TGPayString(type[@"title"]),
		@"inviteLink" : TGPayString(type[@"invite_link"]),
	};
}

- (void)starSubscriptionsOnlyExpiring:(BOOL)onlyExpiring
							   offset:(NSString *)offset
						   completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"getStarSubscriptions",
		@"only_expiring" : @(onlyExpiring),
		@"offset" : offset ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSMutableArray *subscriptions = [NSMutableArray array];
		for (id entry in TGPayArray(result[@"subscriptions"])) {
			NSDictionary *subscription = TGPayDict(entry);
			if (subscription)
				[subscriptions addObject:[self tg_flattenStarSubscription:subscription]];
		}
		long long balance = TGPayStars(result[@"star_amount"]);
		TGPayCachedStarBalance = balance;
		completion(@{
			@"balance" : @(balance),
			@"balanceNanos" : @(TGPayStarsNanos(result[@"star_amount"])),
			@"requiredStars" : result[@"required_star_count"] ?: @0,
			@"nextOffset" : TGPayString(result[@"next_offset"]),
			@"subscriptions" : subscriptions,
		});
	}];
}

- (void)setStarSubscription:(NSString *)subscriptionId
				   canceled:(BOOL)canceled
				 completion:(void (^)(BOOL))completion {
	[self tg_request:@{
		@"@type" : @"editStarSubscription",
		@"subscription_id" : subscriptionId ?: @"",
		@"is_canceled" : @(canceled),
	}
				  ok:completion];
}

- (void)reuseStarSubscription:(NSString *)subscriptionId
				   completion:(void (^)(BOOL))completion {
	[self tg_request:@{
		@"@type" : @"reuseStarSubscription",
		@"subscription_id" : subscriptionId ?: @"",
	}
				  ok:completion];
}

#pragma mark - star transactions

- (NSDictionary *)tg_flattenTransaction:(NSDictionary *)transaction {
	NSDictionary *type = TGPayDict(transaction[@"type"]);
	NSString *shortType = TGPayShortType(type[@"@type"], @"starTransactionType");
	NSDictionary *product = TGPayDict(type[@"product_info"]);
	NSDictionary *gift = TGPayDict(type[@"gift"]);

	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	[out setObject:TGPayString(transaction[@"id"]) forKey:@"id"];
	[out setObject:transaction[@"date"] ?: @0 forKey:@"date"];
	[out setObject:@(TGPayStars(transaction[@"star_amount"])) forKey:@"stars"];
	[out setObject:@(TGPayStarsNanos(transaction[@"star_amount"])) forKey:@"starsNanos"];
	[out setObject:@([transaction[@"is_refund"] boolValue]) forKey:@"isRefund"];
	[out setObject:shortType forKey:@"type"];

	NSDictionary *withdrawalState = TGPayDict(type[@"withdrawal_state"]);
	NSString *withdrawalStateType = TGPayString(withdrawalState[@"@type"]);
	if (withdrawalStateType.length) {
		if ([withdrawalStateType isEqualToString:@"revenueWithdrawalStateSucceeded"])
			[out setObject:@"succeeded" forKey:@"withdrawalState"];
		else if ([withdrawalStateType isEqualToString:@"revenueWithdrawalStateFailed"])
			[out setObject:@"failed" forKey:@"withdrawalState"];
		else
			[out setObject:@"pending" forKey:@"withdrawalState"];
	}

	NSNumber *userId = type[@"user_id"];
	NSNumber *chatId = type[@"chat_id"];
	NSDictionary *owner = TGPayDict(type[@"owner_id"]) ?: TGPayDict(type[@"sender_id"]);
	if (owner) {
		if (owner[@"user_id"])
			userId = owner[@"user_id"];
		if (owner[@"chat_id"])
			chatId = owner[@"chat_id"];
	}
	[out setObject:[userId isKindOfClass:NSNumber.class] ? userId : @0 forKey:@"userId"];
	[out setObject:[chatId isKindOfClass:NSNumber.class] ? chatId : @0 forKey:@"chatId"];

	NSString *title = nil;
	if (product)
		title = TGPayString(product[@"title"]);
	else if (gift)
		title = TGPayString(gift[@"title"]);
	if (!title.length && [chatId isKindOfClass:NSNumber.class] && [chatId longLongValue])
		title = TGPayString(self.chatsById[chatId][@"title"]);
	if (!title.length && [userId isKindOfClass:NSNumber.class] && [userId longLongValue])
		title = [self nameForUserId:[userId longLongValue]];
	if (!title.length)
		title = TGPayHumanType(shortType);
	[out setObject:title forKey:@"title"];
	[out setObject:product ? TGPayPlainText(product[@"description"]) : @""
			forKey:@"description"];

	NSNumber *photoId = product ? TGPayPhotoFileId(product[@"photo"]) : nil;
	if (!photoId)
		photoId = TGPayStickerFileId(type[@"sticker"] ?: gift[@"sticker"]);
	if (photoId)
		[out setObject:photoId forKey:@"photoFileId"];
	return out;
}

- (void)starTransactionsWithDirection:(NSString *)direction
							   offset:(NSString *)offset
								limit:(NSInteger)limit
						   completion:(void (^)(NSArray *, NSString *))completion {
	NSMutableDictionary *request = [NSMutableDictionary dictionaryWithDictionary:@{
		@"@type" : @"getStarTransactions",
		@"owner_id" : [self tg_ownSender],
		@"offset" : offset ?: @"",
		@"limit" : @(limit > 0 ? limit : 30),
	}];
	if ([direction isEqualToString:@"incoming"])
		[request setObject:@{@"@type" : @"transactionDirectionIncoming"} forKey:@"direction"];
	else if ([direction isEqualToString:@"outgoing"])
		[request setObject:@{@"@type" : @"transactionDirectionOutgoing"} forKey:@"direction"];

	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion([NSArray array], @"");
			return;
		}
		TGPayCachedStarBalance = TGPayStars(result[@"star_amount"]);
		NSMutableArray *out = [NSMutableArray array];
		for (id entry in TGPayArray(result[@"transactions"])) {
			NSDictionary *transaction = TGPayDict(entry);
			if (transaction)
				[out addObject:[self tg_flattenTransaction:transaction]];
		}
		completion(out, TGPayString(result[@"next_offset"]));
	}];
}

#pragma mark - payment forms

- (NSArray *)tg_priceParts:(id)parts {
	NSMutableArray *out = [NSMutableArray array];
	for (id entry in TGPayArray(parts)) {
		NSDictionary *part = TGPayDict(entry);
		if (!part)
			continue;
		[out addObject:@{
			@"label" : TGPayString(part[@"label"]),
			@"amount" : part[@"amount"] ?: @0,
		}];
	}
	return out;
}

- (NSDictionary *)tg_flattenOrderInfo:(NSDictionary *)info {
	NSDictionary *address = TGPayDict(info[@"shipping_address"]);
	return @{
		@"name" : TGPayString(info[@"name"]),
		@"phone" : TGPayString(info[@"phone_number"]),
		@"email" : TGPayString(info[@"email_address"]),
		@"countryCode" : TGPayString(address[@"country_code"]),
		@"state" : TGPayString(address[@"state"]),
		@"city" : TGPayString(address[@"city"]),
		@"street1" : TGPayString(address[@"street_line1"]),
		@"street2" : TGPayString(address[@"street_line2"]),
		@"postalCode" : TGPayString(address[@"postal_code"]),
	};
}

- (NSDictionary *)tg_flattenForm:(NSDictionary *)form inputInvoice:(NSDictionary *)inputInvoice {
	NSDictionary *type = TGPayDict(form[@"type"]);
	NSDictionary *product = TGPayDict(form[@"product_info"]);
	BOOL isStars = [type[@"@type"] isEqualToString:@"paymentFormTypeStars"];

	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	[out setObject:form[@"id"] ?: @0 forKey:@"formId"];
	[out setObject:@(isStars) forKey:@"isStars"];
	[out setObject:form[@"seller_bot_user_id"] ?: @0 forKey:@"sellerBotUserId"];
	[out setObject:TGPayString(product[@"title"]) forKey:@"title"];
	[out setObject:TGPayPlainText(product[@"description"]) forKey:@"description"];
	[out setObject:inputInvoice forKey:@"invoice"];
	NSNumber *photoId = TGPayPhotoFileId(product[@"photo"]);
	if (photoId)
		[out setObject:photoId forKey:@"photoFileId"];

	if (isStars) {
		[out setObject:type[@"star_count"] ?: @0 forKey:@"starCount"];
		return out;
	}

	NSDictionary *invoice = TGPayDict(type[@"invoice"]);
	long long total = 0;
	NSArray *parts = [self tg_priceParts:invoice[@"price_parts"]];
	for (NSDictionary *part in parts)
		total += [part[@"amount"] longLongValue];

	[out setObject:TGPayString(invoice[@"currency"]) forKey:@"currency"];
	[out setObject:parts forKey:@"priceParts"];
	[out setObject:@(total) forKey:@"totalAmount"];
	[out setObject:invoice[@"max_tip_amount"] ?: @0 forKey:@"maxTipAmount"];
	[out setObject:TGPayArray(invoice[@"suggested_tip_amounts"]) forKey:@"suggestedTips"];
	[out setObject:@([invoice[@"need_name"] boolValue]) forKey:@"needsName"];
	[out setObject:@([invoice[@"need_phone_number"] boolValue]) forKey:@"needsPhone"];
	[out setObject:@([invoice[@"need_email_address"] boolValue]) forKey:@"needsEmail"];
	[out setObject:@([invoice[@"need_shipping_address"] boolValue]) forKey:@"needsShippingAddress"];
	[out setObject:@([invoice[@"is_flexible"] boolValue]) forKey:@"isFlexible"];
	[out setObject:@([type[@"can_save_credentials"] boolValue]) forKey:@"canSaveCredentials"];
	[out setObject:@([type[@"need_password"] boolValue]) forKey:@"needsPassword"];

	NSDictionary *provider = TGPayDict(type[@"payment_provider"]);
	NSString *providerType = TGPayString(provider[@"@type"]);
	[out setObject:providerType forKey:@"providerType"];
	if ([providerType isEqualToString:@"paymentProviderOther"])
		[out setObject:TGPayString(provider[@"url"]) forKey:@"providerUrl"];

	NSMutableArray *saved = [NSMutableArray array];
	for (id entry in TGPayArray(type[@"saved_credentials"])) {
		NSDictionary *credentials = TGPayDict(entry);
		if (!credentials)
			continue;
		[saved addObject:@{
			@"id" : TGPayString(credentials[@"id"]),
			@"title" : TGPayString(credentials[@"title"]),
		}];
	}
	[out setObject:saved forKey:@"savedCredentials"];

	NSDictionary *savedOrder = TGPayDict(type[@"saved_order_info"]);
	if (savedOrder)
		[out setObject:[self tg_flattenOrderInfo:savedOrder] forKey:@"savedOrderInfo"];
	return out;
}

- (void)tg_paymentFormForInvoice:(NSDictionary *)inputInvoice
					  completion:(void (^)(NSDictionary *form))completion {
	[self request:@{@"@type" : @"getPaymentForm", @"input_invoice" : inputInvoice}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			completion([self tg_flattenForm:result inputInvoice:inputInvoice]);
		}];
}

- (void)paymentFormForMessage:(int64_t)messageId
					   inChat:(int64_t)chatId
				   completion:(void (^)(NSDictionary *))completion {
	[self tg_paymentFormForInvoice:@{
		@"@type" : @"inputInvoiceMessage",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
	}
						completion:completion];
}

- (void)paymentFormForInvoiceName:(NSString *)name
					   completion:(void (^)(NSDictionary *))completion {
	[self tg_paymentFormForInvoice:@{
		@"@type" : @"inputInvoiceName",
		@"name" : name ?: @"",
	}
						completion:completion];
}

- (void)paymentFormForPremiumGiftToUser:(int64_t)userId
							   currency:(NSString *)currency
								 amount:(long long)amount
							 monthCount:(NSInteger)monthCount
								   text:(NSString *)text
							 completion:(void (^)(NSDictionary *))completion {
	[self tg_paymentFormForInvoice:@{
		@"@type" : @"inputInvoiceTelegram",
		@"purpose" : @{
			@"@type" : @"telegramPaymentPurposePremiumGift",
			@"currency" : currency ?: @"",
			@"amount" : @(amount),
			@"user_id" : @(userId),
			@"month_count" : @(monthCount),
			@"text" : @{@"@type" : @"formattedText",
				@"text" : text ?: @"",
				@"entities" : [NSArray array]},
		},
	}
						completion:completion];
}

- (void)tg_sendPaymentForm:(NSDictionary *)form
			   credentials:(NSDictionary *)credentials
			   orderInfoId:(NSString *)orderInfoId
		  shippingOptionId:(NSString *)shippingOptionId
				 tipAmount:(long long)tipAmount
				completion:(void (^)(BOOL ok, NSString *verificationUrl))completion {
	NSDictionary *inputInvoice = TGPayDict(form[@"invoice"]);
	if (!inputInvoice) {
		if (completion)
			completion(NO, nil);
		return;
	}
	[self request:@{
		@"@type" : @"sendPaymentForm",
		@"input_invoice" : inputInvoice,
		@"payment_form_id" : form[@"formId"] ?: @0,
		@"order_info_id" : orderInfoId ?: @"",
		@"shipping_option_id" : shippingOptionId ?: @"",
		@"credentials" : credentials,
		@"tip_amount" : @(tipAmount),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, nil);
			return;
		}
		NSString *url = TGPayString(result[@"verification_url"]);
		completion([result[@"success"] boolValue] || url.length, url.length ? url : nil);
	}];
}

- (void)payStarsPaymentForm:(NSDictionary *)form completion:(void (^)(BOOL))completion {
	[self tg_sendPaymentForm:form
				 credentials:(NSDictionary *)[NSNull null]
				 orderInfoId:nil
			shippingOptionId:nil
				   tipAmount:0
				  completion:^(BOOL ok, NSString *url) {
					  if (completion)
						  completion(ok);
				  }];
}

- (void)unlockPaidMediaInMessage:(int64_t)messageId
						  inChat:(int64_t)chatId
					  completion:(void (^)(BOOL))completion {
	[self paymentFormForMessage:messageId inChat:chatId completion:^(NSDictionary *form) {
		if (!form) {
			if (completion)
				completion(NO);
			return;
		}
		[self payStarsPaymentForm:form completion:completion];
	}];
}

- (void)validateOrderInfo:(NSDictionary *)orderInfo
		   forPaymentForm:(NSDictionary *)form
					 save:(BOOL)save
			   completion:(void (^)(NSString *, NSArray *))completion {
	NSDictionary *inputInvoice = TGPayDict(form[@"invoice"]);
	if (!inputInvoice) {
		if (completion)
			completion(nil, [NSArray array]);
		return;
	}
	NSDictionary *info = @{
		@"@type" : @"orderInfo",
		@"name" : TGPayString(orderInfo[@"name"]),
		@"phone_number" : TGPayString(orderInfo[@"phone"]),
		@"email_address" : TGPayString(orderInfo[@"email"]),
		@"shipping_address" : @{
			@"@type" : @"address",
			@"country_code" : TGPayString(orderInfo[@"countryCode"]),
			@"state" : TGPayString(orderInfo[@"state"]),
			@"city" : TGPayString(orderInfo[@"city"]),
			@"street_line1" : TGPayString(orderInfo[@"street1"]),
			@"street_line2" : TGPayString(orderInfo[@"street2"]),
			@"postal_code" : TGPayString(orderInfo[@"postalCode"]),
		},
	};
	[self request:@{
		@"@type" : @"validateOrderInfo",
		@"input_invoice" : inputInvoice,
		@"order_info" : info,
		@"allow_save" : @(save),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, [NSArray array]);
			return;
		}
		NSMutableArray *options = [NSMutableArray array];
		for (id entry in TGPayArray(result[@"shipping_options"])) {
			NSDictionary *option = TGPayDict(entry);
			if (!option)
				continue;
			long long amount = 0;
			for (NSDictionary *part in [self tg_priceParts:option[@"price_parts"]])
				amount += [part[@"amount"] longLongValue];
			[options addObject:@{
				@"id" : TGPayString(option[@"id"]),
				@"title" : TGPayString(option[@"title"]),
				@"amount" : @(amount),
			}];
		}
		completion(TGPayString(result[@"order_info_id"]), options);
	}];
}

- (void)payCardPaymentForm:(NSDictionary *)form
		savedCredentialsId:(NSString *)savedCredentialsId
		newCredentialsData:(NSString *)newCredentialsData
			 allowSaveCard:(BOOL)allowSave
			   orderInfoId:(NSString *)orderInfoId
		  shippingOptionId:(NSString *)shippingOptionId
				 tipAmount:(long long)tipAmount
				completion:(void (^)(BOOL, NSString *))completion {
	NSDictionary *credentials = savedCredentialsId.length
		? [NSDictionary dictionaryWithObjectsAndKeys:
				  @"inputCredentialsSaved", @"@type",
			  savedCredentialsId, @"saved_credentials_id", nil]
		: [NSDictionary dictionaryWithObjectsAndKeys:
				  @"inputCredentialsNew", @"@type",
			  newCredentialsData ?: @"", @"data",
			  @(allowSave), @"allow_save", nil];
	[self tg_sendPaymentForm:form
				 credentials:credentials
				 orderInfoId:orderInfoId
			shippingOptionId:shippingOptionId
				   tipAmount:tipAmount
				  completion:completion];
}

- (void)paymentReceiptForMessage:(int64_t)messageId
						  inChat:(int64_t)chatId
					  completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"getPaymentReceipt",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSDictionary *product = TGPayDict(result[@"product_info"]);
		NSDictionary *type = TGPayDict(result[@"type"]);
		BOOL isStars = [type[@"@type"] isEqualToString:@"paymentReceiptTypeStars"];

		NSMutableDictionary *out = [NSMutableDictionary dictionary];
		[out setObject:result[@"date"] ?: @0 forKey:@"date"];
		[out setObject:result[@"seller_bot_user_id"] ?: @0 forKey:@"sellerBotUserId"];
		[out setObject:TGPayString(product[@"title"]) forKey:@"title"];
		[out setObject:TGPayPlainText(product[@"description"]) forKey:@"description"];
		[out setObject:@(isStars) forKey:@"isStars"];
		NSNumber *photoId = TGPayPhotoFileId(product[@"photo"]);
		if (photoId)
			[out setObject:photoId forKey:@"photoFileId"];

		if (isStars) {
			[out setObject:type[@"star_count"] ?: @0 forKey:@"starCount"];
			[out setObject:TGPayString(type[@"transaction_id"]) forKey:@"transactionId"];
			completion(out);
			return;
		}

		NSDictionary *invoice = TGPayDict(type[@"invoice"]);
		NSArray *parts = [self tg_priceParts:invoice[@"price_parts"]];
		long long total = 0;
		for (NSDictionary *part in parts)
			total += [part[@"amount"] longLongValue];
		[out setObject:TGPayString(invoice[@"currency"]) forKey:@"currency"];
		[out setObject:parts forKey:@"priceParts"];
		[out setObject:@(total + [type[@"tip_amount"] longLongValue]) forKey:@"totalAmount"];
		[out setObject:type[@"tip_amount"] ?: @0 forKey:@"tipAmount"];
		[out setObject:TGPayString(type[@"credentials_title"]) forKey:@"credentialsTitle"];
		NSDictionary *shipping = TGPayDict(type[@"shipping_option"]);
		if (shipping)
			[out setObject:TGPayString(shipping[@"title"]) forKey:@"shippingOption"];
		completion(out);
	}];
}

- (void)clearSavedPaymentInfoWithCompletion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"deleteSavedCredentials"} completion:^(NSDictionary *first) {
		BOOL okCredentials = !TGResultIsError(first);
		[self request:@{@"@type" : @"deleteSavedOrderInfo"} completion:^(NSDictionary *second) {
			if (completion)
				completion(okCredentials && !TGResultIsError(second));
		}];
	}];
}

#pragma mark - gift catalogue

- (void)availableGiftsWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getAvailableGifts"} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSMutableArray *out = [NSMutableArray array];
		for (id entry in TGPayArray(result[@"gifts"])) {
			NSDictionary *available = TGPayDict(entry);
			NSDictionary *gift = TGPayDict(available[@"gift"]);
			if (!gift)
				continue;
			NSMutableDictionary *row = [NSMutableDictionary dictionary];
			[row setObject:gift[@"id"] ?: @0 forKey:@"id"];
			NSString *title = TGPayString(available[@"title"]);
			[row setObject:title.length ? title : @"Gift" forKey:@"title"];
			[row setObject:gift[@"star_count"] ?: @0 forKey:@"starCount"];
			[row setObject:gift[@"upgrade_star_count"] ?: @0 forKey:@"upgradeStarCount"];
			[row setObject:@([gift[@"is_premium"] boolValue]) forKey:@"isPremium"];
			[row setObject:@([gift[@"is_for_birthday"] boolValue]) forKey:@"isForBirthday"];
			[row setObject:available[@"resale_count"] ?: @0 forKey:@"resaleCount"];
			[row setObject:available[@"min_resale_star_count"] ?: @0 forKey:@"minResaleStarCount"];
			[row setObject:TGPayString(TGPayDict(gift[@"sticker"])[@"emoji"]) forKey:@"emoji"];
			NSNumber *stickerId = TGPayStickerFileId(gift[@"sticker"]);
			if (stickerId)
				[row setObject:stickerId forKey:@"stickerFileId"];
			[out addObject:row];
		}
		completion(out);
	}];
}

- (void)tg_sendGiftWithId:(long long)giftId
					owner:(NSDictionary *)owner
					 text:(NSString *)text
				isPrivate:(BOOL)isPrivate
			payForUpgrade:(BOOL)payForUpgrade
			   completion:(void (^)(BOOL ok, NSString *error))completion {
	[self request:@{
		@"@type" : @"sendGift",
		@"gift_id" : @(giftId),
		@"owner_id" : owner,
		@"text" : @{@"@type" : @"formattedText",
			@"text" : text ?: @"",
			@"entities" : [NSArray array]},
		@"is_private" : @(isPrivate),
		@"pay_for_upgrade" : @(payForUpgrade),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGPayErrorText(result, nil));
			return;
		}
		completion(YES, nil);
	}];
}

- (void)sendGiftWithId:(long long)giftId
				toUser:(int64_t)userId
				  text:(NSString *)text
			 isPrivate:(BOOL)isPrivate
		 payForUpgrade:(BOOL)payForUpgrade
			completion:(void (^)(BOOL, NSString *))completion {
	[self tg_sendGiftWithId:giftId
					  owner:[self tg_senderForUser:userId]
					   text:text
				  isPrivate:isPrivate
			  payForUpgrade:payForUpgrade
				 completion:completion];
}

- (void)sendGiftWithId:(long long)giftId
				toChat:(int64_t)chatId
				  text:(NSString *)text
			 isPrivate:(BOOL)isPrivate
		 payForUpgrade:(BOOL)payForUpgrade
			completion:(void (^)(BOOL, NSString *))completion {
	[self tg_sendGiftWithId:giftId
					  owner:[self tg_senderForChat:chatId]
					   text:text
				  isPrivate:isPrivate
			  payForUpgrade:payForUpgrade
				 completion:completion];
}

#pragma mark - received gifts

- (NSDictionary *)tg_flattenReceivedGift:(NSDictionary *)received {
	NSDictionary *sent = TGPayDict(received[@"gift"]);
	BOOL isUnique = [sent[@"@type"] isEqualToString:@"sentGiftUpgraded"];
	NSDictionary *gift = TGPayDict(sent[@"gift"]) ?: sent;

	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	[out setObject:TGPayString(received[@"received_gift_id"]) forKey:@"giftId"];
	[out setObject:@(isUnique) forKey:@"isUnique"];
	NSString *title = TGPayString(gift[@"title"]);
	if (!title.length)
		title = @"Gift";
	[out setObject:title forKey:@"title"];
	if (isUnique) {
		[out setObject:@0 forKey:@"starCount"];
		[out setObject:TGPayString(gift[@"value_currency"]) forKey:@"valueCurrency"];
		[out setObject:gift[@"value_amount"] ?: @0 forKey:@"valueAmount"];
	} else {
		[out setObject:gift[@"star_count"] ?: @0 forKey:@"starCount"];
	}
	[out setObject:received[@"sell_star_count"] ?: @0 forKey:@"sellStarCount"];
	[out setObject:received[@"transfer_star_count"] ?: @0 forKey:@"transferStarCount"];
	[out setObject:received[@"next_transfer_date"] ?: @0 forKey:@"nextTransferDate"];
	[out setObject:gift[@"upgrade_star_count"] ?: @0 forKey:@"upgradeStarCount"];
	[out setObject:received[@"prepaid_upgrade_star_count"] ?: @0 forKey:@"prepaidUpgradeStarCount"];
	[out setObject:received[@"date"] ?: @0 forKey:@"date"];
	[out setObject:@([received[@"is_saved"] boolValue]) forKey:@"isSaved"];
	[out setObject:@([received[@"is_pinned"] boolValue]) forKey:@"isPinned"];
	[out setObject:@([received[@"is_private"] boolValue]) forKey:@"isPrivate"];
	[out setObject:@([received[@"can_be_upgraded"] boolValue]) forKey:@"canUpgrade"];
	[out setObject:@([received[@"can_be_transferred"] boolValue]) forKey:@"canTransfer"];
	[out setObject:TGPayPlainText(received[@"text"]) forKey:@"text"];

	NSDictionary *sender = TGPayDict(received[@"sender_id"]);
	BOOL senderIsChat = [TGPayString(sender[@"@type"])
		isEqualToString:@"messageSenderChat"];
	NSNumber *senderId = senderIsChat ? sender[@"chat_id"] : sender[@"user_id"];
	if (![senderId isKindOfClass:NSNumber.class])
		senderId = @0;
	[out setObject:senderId forKey:@"senderId"];
	[out setObject:@(senderIsChat) forKey:@"senderIsChat"];
	NSString *senderName = nil;
	if ([senderId longLongValue] != 0) {
		senderName = senderIsChat
			? TGPayString([self.chatsById[senderId] objectForKey:@"title"])
			: [self nameForUserId:[senderId longLongValue]];
	}
	[out setObject:senderName ?: @"" forKey:@"senderName"];

	if (isUnique) {
		[out setObject:TGPayString(gift[@"name"]) forKey:@"name"];
		[out setObject:gift[@"number"] ?: @0 forKey:@"number"];
		NSNumber *modelSticker = TGPayStickerFileId(TGPayDict(gift[@"model"])[@"sticker"]);
		if (modelSticker)
			[out setObject:modelSticker forKey:@"stickerFileId"];
		id coloursId = TGPayDict(gift[@"colors"])[@"id"];
		if ([coloursId isKindOfClass:NSNumber.class] || [coloursId isKindOfClass:NSString.class])
			[out setObject:@([coloursId longLongValue]) forKey:@"giftColoursId"];
	} else {
		NSNumber *stickerId = TGPayStickerFileId(gift[@"sticker"]);
		if (stickerId)
			[out setObject:stickerId forKey:@"stickerFileId"];
	}
	return out;
}

- (void)tg_receivedGiftsForOwner:(NSDictionary *)owner
					collectionId:(int32_t)collectionId
						  offset:(NSString *)offset
						   limit:(NSInteger)limit
					  completion:(void (^)(NSArray *, NSString *, NSInteger, BOOL))completion {
	[self request:@{
		@"@type" : @"getReceivedGifts",
		@"owner_id" : owner,
		@"collection_id" : @(collectionId),
		@"offset" : offset ?: @"",
		@"limit" : @(limit > 0 ? limit : 30),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion([NSArray array], @"", 0, NO);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (id entry in TGPayArray(result[@"gifts"])) {
			NSDictionary *received = TGPayDict(entry);
			if (received)
				[out addObject:[self tg_flattenReceivedGift:received]];
		}
		completion(out, TGPayString(result[@"next_offset"]),
			[result[@"total_count"] integerValue],
			[result[@"are_notifications_enabled"] boolValue]);
	}];
}

- (void)receivedGiftsForUser:(int64_t)userId
				collectionId:(int32_t)collectionId
					  offset:(NSString *)offset
					   limit:(NSInteger)limit
				  completion:(void (^)(NSArray *, NSString *, NSInteger))completion {
	[self tg_receivedGiftsForOwner:[self tg_senderForUser:userId]
					  collectionId:collectionId
							offset:offset
							 limit:limit
						completion:^(NSArray *gifts, NSString *nextOffset, NSInteger total, BOOL notificationsEnabled) {
							(void)notificationsEnabled;
							if (completion)
								completion(gifts, nextOffset, total);
						}];
}

- (void)receivedGiftsForChat:(int64_t)chatId
				collectionId:(int32_t)collectionId
					  offset:(NSString *)offset
					   limit:(NSInteger)limit
				  completion:(void (^)(NSArray *, NSString *, NSInteger))completion {
	[self tg_receivedGiftsForOwner:[self tg_senderForChat:chatId]
					  collectionId:collectionId
							offset:offset
							 limit:limit
						completion:^(NSArray *gifts, NSString *nextOffset, NSInteger total, BOOL notificationsEnabled) {
							(void)notificationsEnabled;
							if (completion)
								completion(gifts, nextOffset, total);
						}];
}

- (void)chatGiftNotificationsEnabledForChat:(int64_t)chatId
								  completion:(void (^)(BOOL enabled))completion {
	[self tg_receivedGiftsForOwner:[self tg_senderForChat:chatId]
					  collectionId:0
							offset:@""
							 limit:1
						completion:^(NSArray *gifts, NSString *nextOffset, NSInteger total, BOOL notificationsEnabled) {
							(void)gifts;
							(void)nextOffset;
							(void)total;
							if (completion)
								completion(notificationsEnabled);
						}];
}

- (void)receivedGiftWithId:(NSString *)giftId
				completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getReceivedGift", @"received_gift_id" : giftId ?: @""}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(TGResultIsError(result) ? nil : [self tg_flattenReceivedGift:result]);
		}];
}

- (void)setReceivedGift:(NSString *)giftId
				   saved:(BOOL)saved
			  completion:(void (^)(BOOL ok, NSString *error))completion {
	[self request:@{
		@"@type" : @"toggleGiftIsSaved",
		@"received_gift_id" : giftId ?: @"",
		@"is_saved" : @(saved),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGPayErrorText(result, nil));
			return;
		}
		completion(YES, nil);
	}];
}

- (void)sellReceivedGift:(NSString *)giftId completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type" : @"sellGift",
		@"business_connection_id" : @"",
		@"received_gift_id" : giftId ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGPayErrorText(result, nil));
			return;
		}
		completion(YES, nil);
	}];
}

- (void)setPinnedGiftIds:(NSArray *)giftIds
			  completion:(void (^)(BOOL ok, NSString *error))completion {
	[self request:@{
		@"@type" : @"setPinnedGifts",
		@"owner_id" : [self tg_ownSender],
		@"received_gift_ids" : giftIds ?: [NSArray array],
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGPayErrorText(result, nil));
			return;
		}
		completion(YES, nil);
	}];
}

- (void)tg_accumulatePinnedGiftIdsForOwner:(NSDictionary *)owner
									  offset:(NSString *)offset
								 accumulated:(NSMutableArray<NSString *> *)accumulated
								  completion:(void (^)(NSArray<NSString *> *pinnedGiftIds))completion {
	[self tg_receivedGiftsForOwner:owner
					  collectionId:0
							offset:offset
							 limit:100
						completion:^(NSArray *gifts, NSString *nextOffset, NSInteger total, BOOL notificationsEnabled) {
							(void)total;
							(void)notificationsEnabled;
							for (NSDictionary *gift in gifts) {
								if (![gift[@"isPinned"] boolValue])
									continue;
								NSString *giftId = gift[@"giftId"];
								if ([giftId isKindOfClass:[NSString class]] && giftId.length)
									[accumulated addObject:giftId];
							}
							if (nextOffset.length) {
								[self tg_accumulatePinnedGiftIdsForOwner:owner
																   offset:nextOffset
															  accumulated:accumulated
															   completion:completion];
								return;
							}
							if (completion)
								completion([accumulated copy]);
						}];
}

- (void)pinnedGiftIdsForCurrentUserWithCompletion:(void (^)(NSArray<NSString *> *pinnedGiftIds))completion {
	[self tg_accumulatePinnedGiftIdsForOwner:[self tg_ownSender]
									   offset:@""
								  accumulated:[NSMutableArray array]
								   completion:completion];
}

- (void)setChat:(int64_t)chatId
	giftNotificationsEnabled:(BOOL)enabled
				  completion:(void (^)(BOOL ok, NSString *error))completion {
	[self request:@{
		@"@type" : @"toggleChatGiftNotifications",
		@"chat_id" : @(chatId),
		@"are_enabled" : @(enabled),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGPayErrorText(result, nil));
			return;
		}
		completion(YES, nil);
	}];
}

- (void)giftSettingsWithCompletion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getUserFullInfo", @"user_id" : self.me[@"id"] ?: @0}
		completion:^(NSDictionary *full) {
			if (!completion)
				return;
			NSDictionary *settings = TGPayDict(full[@"gift_settings"]);
			NSDictionary *accepted = TGPayDict(settings[@"accepted_gift_types"]);
			completion(@{
				@"showGiftButton" : @([settings[@"show_gift_button"] boolValue]),
				@"unlimited" : @([accepted[@"unlimited_gifts"] boolValue]),
				@"limited" : @([accepted[@"limited_gifts"] boolValue]),
				@"upgraded" : @([accepted[@"upgraded_gifts"] boolValue]),
				@"fromChannels" : @([accepted[@"gifts_from_channels"] boolValue]),
				@"premiumSubscription" : @([accepted[@"premium_subscription"] boolValue]),
			});
		}];
}

- (void)setGiftSettings:(NSDictionary *)settings
			  completion:(void (^)(BOOL ok, NSString *error))completion {
	[self request:@{
		@"@type" : @"setGiftSettings",
		@"settings" : @{
			@"@type" : @"giftSettings",
			@"show_gift_button" : @([settings[@"showGiftButton"] boolValue]),
			@"accepted_gift_types" : @{
				@"@type" : @"acceptedGiftTypes",
				@"unlimited_gifts" : @([settings[@"unlimited"] boolValue]),
				@"limited_gifts" : @([settings[@"limited"] boolValue]),
				@"upgraded_gifts" : @([settings[@"upgraded"] boolValue]),
				@"gifts_from_channels" : @([settings[@"fromChannels"] boolValue]),
				@"premium_subscription" : @([settings[@"premiumSubscription"] boolValue]),
			},
		},
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGPayErrorText(result, nil));
			return;
		}
		completion(YES, nil);
	}];
}

#pragma mark - unique gifts

- (NSArray *)tg_giftAttributes:(id)attributes {
	NSMutableArray *out = [NSMutableArray array];
	for (id entry in TGPayArray(attributes)) {
		NSDictionary *attribute = TGPayDict(entry);
		if (!attribute)
			continue;
		NSMutableDictionary *row = [NSMutableDictionary dictionary];
		[row setObject:TGPayString(attribute[@"name"]) forKey:@"name"];
		[row setObject:TGPayDict(attribute[@"rarity"])[@"per_mille"] ?: @0
				forKey:@"rarity"];
		NSNumber *stickerId = TGPayStickerFileId(attribute[@"sticker"]);
		if (stickerId)
			[row setObject:stickerId forKey:@"stickerFileId"];
		[out addObject:row];
	}
	return out;
}

- (long long)tg_effectiveUpgradeStarCountForResult:(NSDictionary *)result {
	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	long long effective = 0;
	NSTimeInterval effectiveDate = -1;
	BOOL found = NO;
	NSArray *series = [TGPayArray(result[@"prices"])
		arrayByAddingObjectsFromArray:TGPayArray(result[@"next_prices"])];
	for (id entry in series) {
		NSDictionary *price = TGPayDict(entry);
		NSTimeInterval date = [price[@"date"] doubleValue];
		if (date <= now && date >= effectiveDate) {
			effective = [price[@"star_count"] longLongValue];
			effectiveDate = date;
			found = YES;
		}
	}
	if (found)
		return effective;
	NSDictionary *fallback = TGPayDict([TGPayArray(result[@"prices"]) firstObject]);
	return [fallback[@"star_count"] longLongValue];
}

- (void)giftUpgradePreviewForGiftId:(long long)giftId
						 completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getGiftUpgradePreview", @"regular_gift_id" : @(giftId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			completion(@{
				@"models" : [self tg_giftAttributes:result[@"models"]],
				@"symbols" : [self tg_giftAttributes:result[@"symbols"]],
				@"backdrops" : [self tg_giftAttributes:result[@"backdrops"]],
				@"starCount" : @([self tg_effectiveUpgradeStarCountForResult:result]),
			});
		}];
}

- (void)upgradeReceivedGift:(NSString *)giftId
		keepOriginalDetails:(BOOL)keepOriginalDetails
				  starCount:(long long)starCount
				 completion:(void (^)(NSDictionary *gift, NSString *error))completion {
	[self request:@{
		@"@type" : @"upgradeGift",
		@"business_connection_id" : @"",
		@"received_gift_id" : giftId ?: @"",
		@"keep_original_details" : @(keepOriginalDetails),
		@"star_count" : @(starCount),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, TGPayErrorText(result, nil));
			return;
		}
		NSDictionary *upgraded = TGPayDict(result[@"gift"]);
		NSMutableDictionary *received = [NSMutableDictionary dictionaryWithDictionary:@{
			@"received_gift_id" : TGPayString(result[@"received_gift_id"]),
			@"is_saved" : result[@"is_saved"] ?: @(NO),
			@"can_be_transferred" : result[@"can_be_transferred"] ?: @(NO),
			@"transfer_star_count" : result[@"transfer_star_count"] ?: @0,
		}];
		if (upgraded)
			[received setObject:@{@"@type" : @"sentGiftUpgraded", @"gift" : upgraded}
						 forKey:@"gift"];
		completion([self tg_flattenReceivedGift:received], nil);
	}];
}

- (void)transferReceivedGift:(NSString *)giftId
					  toUser:(int64_t)userId
				   starCount:(long long)starCount
				  completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type" : @"transferGift",
		@"business_connection_id" : @"",
		@"received_gift_id" : giftId ?: @"",
		@"new_owner_id" : [self tg_senderForUser:userId],
		@"star_count" : @(starCount),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGPayErrorText(result, nil));
			return;
		}
		completion(YES, nil);
	}];
}

- (void)dropOriginalDetailsOfGift:(NSString *)giftId
						starCount:(long long)starCount
					   completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type" : @"dropGiftOriginalDetails",
		@"received_gift_id" : giftId ?: @"",
		@"star_count" : @(starCount),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGPayErrorText(result, nil));
			return;
		}
		completion(YES, nil);
	}];
}

#pragma mark - resale

- (void)giftsForResaleWithGiftId:(long long)giftId
						  offset:(NSString *)offset
						   limit:(NSInteger)limit
					  completion:(void (^)(NSArray *, NSString *, NSInteger))completion {
	[self request:@{
		@"@type" : @"searchGiftsForResale",
		@"gift_id" : @(giftId),
		@"order" : @{@"@type" : @"giftForResaleOrderPrice"},
		@"for_crafting" : @(NO),
		@"for_stars" : @(YES),
		@"attributes" : [NSArray array],
		@"offset" : offset ?: @"",
		@"limit" : @(limit > 0 ? limit : 30),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion([NSArray array], @"", 0);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (id entry in TGPayArray(result[@"gifts"])) {
			NSDictionary *forResale = TGPayDict(entry);
			NSDictionary *upgraded = TGPayDict(forResale[@"gift"]);
			if (!upgraded)
				continue;
			NSDictionary *received = @{
				@"received_gift_id" : TGPayString(forResale[@"received_gift_id"]),
				@"gift" : @{@"@type" : @"sentGiftUpgraded", @"gift" : upgraded},
			};
			NSMutableDictionary *row = [NSMutableDictionary dictionaryWithDictionary:
					[self tg_flattenReceivedGift:received]];
			NSDictionary *resale = TGPayDict(upgraded[@"resale_parameters"]);
			[row setObject:resale[@"star_count"] ?: @0 forKey:@"resaleStarCount"];
			[out addObject:row];
		}
		completion(out, TGPayString(result[@"next_offset"]),
			[result[@"total_count"] integerValue]);
	}];
}

- (void)setResalePrice:(long long)starCount
	   forReceivedGift:(NSString *)giftId
			completion:(void (^)(BOOL, NSString *))completion {
	id price = starCount > 0
		? @{@"@type" : @"giftResalePriceStar", @"star_count" : @(starCount)}
		: (id)[NSNull null];
	[self request:@{
		@"@type" : @"setGiftResalePrice",
		@"received_gift_id" : giftId ?: @"",
		@"price" : price,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGPayErrorText(result, nil));
			return;
		}
		completion(YES, nil);
	}];
}

- (void)buyResoldGiftNamed:(NSString *)name
			  forStarCount:(long long)starCount
				completion:(void (^)(BOOL, long long, NSString *))completion {
	[self request:@{
		@"@type" : @"sendResoldGift",
		@"gift_name" : name ?: @"",
		@"owner_id" : [self tg_ownSender],
		@"price" : @{@"@type" : @"giftResalePriceStar",
			@"star_count" : @(starCount)},
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, 0, TGPayErrorText(result, nil));
			return;
		}
		NSString *type = TGPayString(result[@"@type"]);
		if ([type isEqualToString:@"giftResaleResultOk"]) {
			completion(YES, 0, nil);
			return;
		}
		if ([type isEqualToString:@"giftResaleResultPriceIncreased"]) {
			NSDictionary *newPrice = TGPayDict(result[@"price"]);
			completion(NO, [newPrice[@"star_count"] longLongValue], nil);
			return;
		}
		completion(NO, 0, nil);
	}];
}

#pragma mark - gift collections

- (NSDictionary *)tg_flattenCollection:(NSDictionary *)collection {
	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	[out setObject:collection[@"id"] ?: @0 forKey:@"id"];
	[out setObject:TGPayString(collection[@"name"]) forKey:@"name"];
	[out setObject:collection[@"gift_count"] ?: @0 forKey:@"giftCount"];
	NSNumber *stickerId = TGPayStickerFileId(collection[@"icon"]);
	if (stickerId)
		[out setObject:stickerId forKey:@"stickerFileId"];
	return out;
}

- (void)tg_collectionRequest:(NSDictionary *)request
				  completion:(void (^)(NSDictionary *collection))completion {
	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : [self tg_flattenCollection:result]);
	}];
}

- (void)giftCollectionsWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getGiftCollections", @"owner_id" : [self tg_ownSender]}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			NSMutableArray *out = [NSMutableArray array];
			for (id entry in TGPayArray(result[@"collections"])) {
				NSDictionary *collection = TGPayDict(entry);
				if (collection)
					[out addObject:[self tg_flattenCollection:collection]];
			}
			completion(out);
		}];
}

- (void)giftCollectionCountMaxWithCompletion:(void (^)(NSInteger))completion {
	static const NSInteger fallbackCountMax = 10;
	[self request:@{@"@type" : @"getOption", @"name" : @"gift_collection_count_max"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(fallbackCountMax);
				return;
			}
			long long value = [result[@"value"] longLongValue];
			completion(value > 0 ? (NSInteger)value : fallbackCountMax);
		}];
}

- (void)createGiftCollectionNamed:(NSString *)name
						  giftIds:(NSArray *)giftIds
					   completion:(void (^)(NSDictionary *))completion {
	[self tg_collectionRequest:@{
		@"@type" : @"createGiftCollection",
		@"owner_id" : [self tg_ownSender],
		@"name" : name ?: @"",
		@"received_gift_ids" : giftIds ?: [NSArray array],
	}
					completion:completion];
}

- (void)deleteGiftCollection:(int32_t)collectionId
				  completion:(void (^)(BOOL ok, NSString *error))completion {
	[self request:@{
		@"@type" : @"deleteGiftCollection",
		@"owner_id" : [self tg_ownSender],
		@"collection_id" : @(collectionId),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGPayErrorText(result, nil));
			return;
		}
		completion(YES, nil);
	}];
}

- (void)renameGiftCollection:(int32_t)collectionId
						  to:(NSString *)name
				  completion:(void (^)(NSDictionary *))completion {
	[self tg_collectionRequest:@{
		@"@type" : @"setGiftCollectionName",
		@"owner_id" : [self tg_ownSender],
		@"collection_id" : @(collectionId),
		@"name" : name ?: @"",
	}
					completion:completion];
}

- (void)addGiftIds:(NSArray *)giftIds toCollection:(int32_t)collectionId
		completion:(void (^)(NSDictionary *))completion {
	[self tg_collectionRequest:@{
		@"@type" : @"addGiftCollectionGifts",
		@"owner_id" : [self tg_ownSender],
		@"collection_id" : @(collectionId),
		@"received_gift_ids" : giftIds ?: [NSArray array],
	}
					completion:completion];
}

- (void)removeGiftIds:(NSArray *)giftIds fromCollection:(int32_t)collectionId
		   completion:(void (^)(NSDictionary *))completion {
	[self tg_collectionRequest:@{
		@"@type" : @"removeGiftCollectionGifts",
		@"owner_id" : [self tg_ownSender],
		@"collection_id" : @(collectionId),
		@"received_gift_ids" : giftIds ?: [NSArray array],
	}
					completion:completion];
}

- (void)reorderGiftCollections:(NSArray *)collectionIds
					 completion:(void (^)(BOOL ok, NSString *error))completion {
	[self request:@{
		@"@type" : @"reorderGiftCollections",
		@"owner_id" : [self tg_ownSender],
		@"collection_ids" : collectionIds ?: [NSArray array],
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGPayErrorText(result, nil));
			return;
		}
		completion(YES, nil);
	}];
}

- (void)reorderGifts:(NSArray *)giftIds inCollection:(int32_t)collectionId
		  completion:(void (^)(NSDictionary *))completion {
	[self tg_collectionRequest:@{
		@"@type" : @"reorderGiftCollectionGifts",
		@"owner_id" : [self tg_ownSender],
		@"collection_id" : @(collectionId),
		@"received_gift_ids" : giftIds ?: [NSArray array],
	}
					completion:completion];
}

#pragma mark - gift extras

- (void)canSendGiftWithId:(long long)giftId
			   completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{@"@type" : @"canSendGift", @"gift_id" : @(giftId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(NO, nil);
				return;
			}
			if ([TGPayString(result[@"@type"]) isEqualToString:@"canSendGiftResultOk"]) {
				completion(YES, nil);
				return;
			}
			completion(NO, TGPayPlainText(result[@"reason"]));
		}];
}

- (void)withdrawalUrlForUpgradedGift:(NSString *)giftId
							password:(NSString *)password
						  completion:(void (^)(NSString *, NSString *))completion {
	[self request:@{
		@"@type" : @"getUpgradedGiftWithdrawalUrl",
		@"received_gift_id" : giftId ?: @"",
		@"password" : password ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, TGPayErrorText(result, TGL(@"Stars.WithdrawLinkFailed", @"The withdrawal link could not be created.")));
			return;
		}
		NSString *url = TGPayString(result[@"url"]);
		completion(url.length ? url : nil, url.length ? nil : TGL(@"Stars.WithdrawLinkFailed", @"The withdrawal link could not be created."));
	}];
}

- (void)setProfileColoursFromGiftColoursId:(long long)coloursId
								completion:(void (^)(BOOL))completion {
	[self tg_request:@{
		@"@type" : @"setUpgradedGiftColors",
		@"upgraded_gift_colors_id" : @(coloursId),
	}
				  ok:completion];
}

#pragma mark - paid messages

- (void)paidMessageRevenueFromUser:(int64_t)userId
						completion:(void (^)(long long))completion {
	[self request:@{@"@type" : @"getPaidMessageRevenue", @"user_id" : @(userId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(TGResultIsError(result) ? 0 : [result[@"star_count"] longLongValue]);
		}];
}

- (void)allowUnpaidMessagesFromUser:(int64_t)userId
					  refundPayments:(BOOL)refund
						  completion:(void (^)(BOOL ok, NSString *error))completion {
	[self request:@{
		@"@type" : @"allowUnpaidMessagesFromUser",
		@"user_id" : @(userId),
		@"refund_payments" : @(refund),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(NO, TGPayErrorText(result, nil));
			return;
		}
		completion(YES, nil);
	}];
}

#pragma mark - paid reactions

static NSString *const TGPaidReactionAnonymousDefaultsKey = @"TGPaidReactionAnonymousDefault";
static BOOL TGPaidReactionAnonymousDefaultLoaded = NO;
static BOOL TGPaidReactionAnonymousDefault = NO;

- (BOOL)defaultPaidReactionIsAnonymous {
	if (!TGPaidReactionAnonymousDefaultLoaded) {
		TGPaidReactionAnonymousDefault =
			[[NSUserDefaults standardUserDefaults]
				boolForKey:[TGAccountManager defaultsKey:TGPaidReactionAnonymousDefaultsKey]];
		TGPaidReactionAnonymousDefaultLoaded = YES;
	}
	return TGPaidReactionAnonymousDefault;
}

- (void)setDefaultPaidReactionAnonymous:(BOOL)anonymous {
	TGPaidReactionAnonymousDefault = anonymous;
	TGPaidReactionAnonymousDefaultLoaded = YES;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:anonymous forKey:[TGAccountManager defaultsKey:TGPaidReactionAnonymousDefaultsKey]];
	[defaults synchronize];
}

- (void)resetPaidReactionDefaultCacheForAccountSwitch {
	TGPaidReactionAnonymousDefaultLoaded = NO;
	TGPaidReactionAnonymousDefault = NO;
}

- (void)applyServerDefaultPaidReactionType:(NSDictionary *)type {
	NSString *kind = [type isKindOfClass:NSDictionary.class] ? type[@"@type"] : nil;
	if (![kind isKindOfClass:NSString.class])
		return;
	if ([kind isEqualToString:@"paidReactionTypeAnonymous"])
		[self setDefaultPaidReactionAnonymous:YES];
	else if ([kind isEqualToString:@"paidReactionTypeRegular"])
		[self setDefaultPaidReactionAnonymous:NO];
}

- (void)addPaidReactionToMessage:(int64_t)messageId
						  inChat:(int64_t)chatId
					   starCount:(long long)starCount
					   anonymous:(BOOL)anonymous
					  completion:(void (^)(BOOL ok))completion {
	[self setDefaultPaidReactionAnonymous:anonymous];
	[self request:@{
		@"@type" : @"addPendingPaidMessageReaction",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"star_count" : @(starCount),
		@"type" : @{@"@type" : anonymous ? @"paidReactionTypeAnonymous"
										 : @"paidReactionTypeRegular"},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)commitPaidReactionsOnMessage:(int64_t)messageId
							   inChat:(int64_t)chatId
						   completion:(void (^)(BOOL ok))completion {
	[self request:@{
		@"@type" : @"commitPendingPaidMessageReactions",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)cancelPaidReactionsOnMessage:(int64_t)messageId inChat:(int64_t)chatId {
	[self send:@{
		@"@type" : @"removePendingPaidMessageReactions",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
	}];
}

- (void)paidReactionSendersInChat:(int64_t)chatId
					   completion:(void (^)(NSArray *))completion {
	[self request:@{
		@"@type" : @"getChatAvailablePaidMessageReactionSenders",
		@"chat_id" : @(chatId),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSMutableArray *out = [NSMutableArray array];
		for (id entry in TGPayArray(result[@"senders"])) {
			NSDictionary *sender = TGPayDict(entry);
			if (!sender)
				continue;
			NSNumber *userId = sender[@"user_id"];
			if ([userId isKindOfClass:NSNumber.class]) {
				[out addObject:@{
					@"id" : userId,
					@"name" : [self nameForUserId:[userId longLongValue]] ?: @"",
					@"isChat" : @(NO),
				}];
				continue;
			}
			NSNumber *senderChatId = sender[@"chat_id"];
			if (![senderChatId isKindOfClass:NSNumber.class])
				continue;
			NSString *title = TGPayString(
				[self.chatsById[senderChatId] objectForKey:@"title"]);
			[out addObject:@{
				@"id" : senderChatId,
				@"name" : title,
				@"isChat" : @(YES),
			}];
		}
		completion(out);
	}];
}

#pragma mark - premium gifts and codes

@end

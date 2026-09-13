#import "TGClient+Premium.h"
#import "TGDateUtils.h"
#import "TGClient+Private.h"
#import "TGClient+Notifications.h"
#import "TGClient+Payments.h"
#import "TGFlattenPremium.h"
#import "TGFlattenPayments.h"
#import "TGLocalization.h"

static NSString *TGPremiumShortDate(NSTimeInterval seconds) {
	if (seconds <= 0)
		return @"";
	return [TGDateUtils stringForFullDate:(int)seconds];
}

NSString *const TGSpeechRecognitionTrialDidChangeNotification = @"TGSpeechRecognitionTrialDidChangeNotification";

static NSString *TGPremiumErrorText(NSDictionary *result) {
	if (![result isKindOfClass:[NSDictionary class]])
		return TGL(@"Login.UnknownError", @"An error occurred, please try again later.");
	NSString *message = result[@"message"];
	if ([message isKindOfClass:[NSString class]] && message.length)
		return message;
	return TGL(@"Login.UnknownError", @"An error occurred, please try again later.");
}

static NSArray *TGPremiumArray(id value) {
	return [value isKindOfClass:[NSArray class]] ? value : [NSArray array];
}

static NSDictionary *TGPremiumDict(id value) {
	return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static NSString *TGPremiumString(id value) {
	return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSNumber *TGPremiumNumber(id value) {
	return [value isKindOfClass:[NSNumber class]] ? value : [NSNumber numberWithInt:0];
}

static NSNumber *TGPremiumInt64(id value) {
	if ([value isKindOfClass:[NSNumber class]])
		return value;
	if ([value isKindOfClass:[NSString class]])
		return [NSNumber numberWithLongLong:[value longLongValue]];
	return [NSNumber numberWithInt:0];
}

static NSArray *TGPremiumDisplayLimitTypes(void) {
	static NSArray *types = nil;
	if (!types)
		types = [[NSArray alloc] initWithObjects:
				@"pinnedChatCount", @"chatFolderCount",
			@"chatFolderChosenChatCount", @"pinnedArchivedChatCount",
			@"supergroupCount", @"createdPublicChatCount",
			@"savedAnimationCount", @"favoriteStickerCount",
			@"messageTextLength", @"captionLength", @"bioLength", nil];
	return types;
}

@implementation TGClient (Premium)

#pragma mark - account state

- (BOOL)isPremiumAccount {
	NSDictionary *me = self.me;
	return [me isKindOfClass:[NSDictionary class]] &&
		[me[@"is_premium"] boolValue];
}

+ (BOOL)isPremiumUser:(NSDictionary *)user {
	return [user isKindOfClass:[NSDictionary class]] &&
		[user[@"is_premium"] boolValue];
}

- (void)premiumOptionNamed:(NSString *)name completion:(void (^)(NSNumber *))completion {
	[self request:@{@"@type" : @"getOption", @"name" : name}
		completion:^(NSDictionary *option) {
			if (!completion)
				return;
			if (TGResultIsError(option)) {
				completion(nil);
				return;
			}
			id value = option[@"value"];
			if ([value isKindOfClass:[NSNumber class]]) {
				completion(value);
				return;
			}
			if ([value isKindOfClass:[NSString class]]) {
				completion([NSNumber numberWithLongLong:[value longLongValue]]);
				return;
			}
			completion(nil);
		}];
}

- (void)premiumSubscriptionWithCompletion:(void (^)(NSDictionary *))completion {
	BOOL active = [self isPremiumAccount];
	[self request:@{@"@type" : @"getPremiumState"} completion:^(NSDictionary *state) {
		if (!completion)
			return;
		if (TGResultIsError(state)) {
			completion(nil);
			return;
		}
		NSMutableDictionary *out = [NSMutableDictionary dictionary];
		[out setObject:[NSNumber numberWithBool:active] forKey:@"active"];

		NSDictionary *text = TGPremiumDict(state[@"state"]);
		[out setObject:TGPremiumString(text[@"text"]) forKey:@"text"];

		[out setObject:(active ? TGL(@"Stars.Subscription.Active", @"Active") : @"") forKey:@"expiresText"];

		NSMutableArray *options = [NSMutableArray array];
		NSArray *raw = TGPremiumArray(state[@"payment_options"]);
		for (id entry in raw) {
			NSDictionary *wrapper = TGPremiumDict(entry);
			if (!wrapper)
				continue;
			NSDictionary *option = TGPremiumDict(wrapper[@"payment_option"]);
			if (!option)
				continue;
			[options addObject:@{
				@"currency" : TGPremiumString(option[@"currency"]),
				@"amount" : TGPremiumNumber(option[@"amount"]),
				@"months" : TGPremiumNumber(option[@"month_count"]),
				@"discount" : TGPremiumNumber(option[@"discount_percentage"]),
				@"current" : [NSNumber numberWithBool:[wrapper[@"is_current"] boolValue]],
				@"upgrade" : [NSNumber numberWithBool:[wrapper[@"is_upgrade"] boolValue]],
				@"storeProductId" : TGPremiumString(option[@"store_product_id"])
			}];
		}
		[out setObject:options forKey:@"options"];
		completion(out);
	}];
}

- (void)premiumOptionsWithCompletion:(void (^)(NSDictionary *))completion {
	NSArray *names = [NSArray arrayWithObjects:
			@"is_premium", @"is_premium_available",
		@"premium_upload_speedup", @"premium_download_speedup",
		@"premium_max_upload_file_size", @"owned_star_count", nil];
	NSArray *keys = [NSArray arrayWithObjects:
			@"isPremium", @"isPremiumAvailable",
		@"uploadSpeedup", @"downloadSpeedup",
		@"maxUploadFileSize", @"starCount", nil];
	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	__block NSUInteger pending = names.count;
	NSInteger i = 0;
	for (i = 0; i < names.count; i++) {
		NSString *key = [keys objectAtIndex:i];
		[self premiumOptionNamed:[names objectAtIndex:i] completion:^(NSNumber *value) {
			[out setObject:(value ? value : [NSNumber numberWithInt:0]) forKey:key];
			pending--;
			if (pending == 0) {
				if (![out objectForKey:@"maxUploadFileSize"] ||
					![[out objectForKey:@"maxUploadFileSize"] longLongValue])
					[out setObject:[NSNumber numberWithLongLong:2000LL * 1024 * 1024]
							forKey:@"maxUploadFileSize"];
				if (completion)
					completion(out);
			}
		}];
	}
}

#pragma mark - limits

- (void)premiumLimit:(NSString *)limitType
		  completion:(void (^)(NSDictionary *))completion {
	NSString *type = TGPremiumFullType(limitType, @"premiumLimitType");
	if (!type) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{@"@type" : @"getPremiumLimit",
		@"limit_type" : @{@"@type" : type}}
		completion:^(NSDictionary *limit) {
			if (!completion)
				return;
			if (TGResultIsError(limit)) {
				completion(nil);
				return;
			}
			NSString *tag = TGPremiumTag(TGPremiumDict(limit[@"type"]), @"premiumLimitType");
			if (!tag.length)
				tag = limitType;
			completion(@{
				@"type" : tag,
				@"title" : TGPremiumLimitTitle(tag),
				@"default" : TGPremiumNumber(limit[@"default_value"]),
				@"premium" : TGPremiumNumber(limit[@"premium_value"])
			});
		}];
}

- (void)premiumLimitsWithCompletion:(void (^)(NSArray *))completion {
	NSArray *types = TGPremiumDisplayLimitTypes();
	NSMutableDictionary *byType = [NSMutableDictionary dictionary];
	__block NSUInteger pending = types.count;
	for (NSString *type in types) {
		[self premiumLimit:type completion:^(NSDictionary *limit) {
			if (limit)
				[byType setObject:limit forKey:type];
			pending--;
			if (pending == 0) {
				NSMutableArray *out = [NSMutableArray array];
				for (NSString *ordered in types) {
					NSDictionary *limit = [byType objectForKey:ordered];
					if (limit)
						[out addObject:limit];
				}
				if (completion)
					completion(out);
			}
		}];
	}
}

- (void)effectivePremiumLimit:(NSString *)limitType
				   completion:(void (^)(NSInteger))completion {
	BOOL premium = [self isPremiumAccount];
	[self premiumLimit:limitType completion:^(NSDictionary *limit) {
		if (!completion)
			return;
		if (!limit) {
			completion(0);
			return;
		}
		completion([limit[premium ? @"premium" : @"default"] integerValue]);
	}];
}

#pragma mark - feature catalogue

- (void)premiumFeaturesWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getPremiumFeatures",
		@"source" : @{@"@type" : @"premiumSourceSettings"}}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion([NSArray array]);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			for (id entry in TGPremiumArray(result[@"features"])) {
				NSString *tag = TGPremiumTag(TGPremiumDict(entry), @"premiumFeature");
				if (!tag.length)
					continue;
				[out addObject:@{
					@"type" : tag,
					@"title" : TGPremiumFeatureTitle(tag),
					@"subtitle" : TGPremiumFeatureSubtitle(tag),
					@"supported" : [NSNumber numberWithBool:TGPremiumFeatureSupported(tag)]
				}];
			}
			completion(out);
		}];
}

- (void)businessFeaturesWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getBusinessFeatures"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion([NSArray array]);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			for (id entry in TGPremiumArray(result[@"features"])) {
				NSString *tag = TGPremiumTag(TGPremiumDict(entry), @"businessFeature");
				if (!tag.length)
					continue;
				[out addObject:@{
					@"type" : tag,
					@"title" : TGPremiumBusinessTitle(tag),
					@"subtitle" : TGPremiumBusinessSubtitle(tag),
					@"supported" : [NSNumber numberWithBool:NO]
				}];
			}
			completion(out);
		}];
}

- (void)viewPremiumFeature:(NSString *)featureType {
	NSString *type = TGPremiumFullType(featureType, @"premiumFeature");
	if (!type)
		return;
	[self send:@{@"@type" : @"viewPremiumFeature",
		@"feature" : @{@"@type" : type}}];
}

- (void)clickPremiumSubscriptionButton {
	[self send:@{@"@type" : @"clickPremiumSubscriptionButton"}];
}

- (void)premiumInfoStickerForMonths:(NSInteger)monthCount
						 completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getPremiumInfoSticker",
		@"month_count" : [NSNumber numberWithInteger:monthCount]}
		completion:^(NSDictionary *sticker) {
			if (!completion)
				return;
			if (TGResultIsError(sticker)) {
				completion(nil);
				return;
			}
			NSDictionary *file = TGPremiumDict(sticker[@"sticker"]);
			NSDictionary *thumb = TGPremiumDict(sticker[@"thumbnail"]);
			NSDictionary *thumbFile = TGPremiumDict(thumb[@"file"]);
			completion(@{
				@"fileId" : TGPremiumNumber(file[@"id"]),
				@"thumbnailFileId" : TGPremiumNumber(thumbFile[@"id"]),
				@"emoji" : TGPremiumString(sticker[@"emoji"]),
				@"width" : TGPremiumNumber(sticker[@"width"]),
				@"height" : TGPremiumNumber(sticker[@"height"])
			});
		}];
}

#pragma mark - gift codes

- (void)checkGiftCode:(NSString *)code
		   completion:(void (^)(NSDictionary *))completion {
	if (![code isKindOfClass:[NSString class]] || !code.length) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{@"@type" : @"checkPremiumGiftCode", @"code" : code}
		completion:^(NSDictionary *info) {
			if (!completion)
				return;
			if (TGResultIsError(info)) {
				completion(nil);
				return;
			}
			NSDictionary *creator = TGPremiumDict(info[@"creator_id"]);
			BOOL creatorIsChat = [TGPremiumString(creator[@"@type"])
				isEqualToString:@"messageSenderChat"];
			NSNumber *creatorId = creatorIsChat ? TGPremiumNumber(creator[@"chat_id"])
												: TGPremiumNumber(creator[@"user_id"]);
			long long useDate = [TGPremiumNumber(info[@"use_date"]) longLongValue];
			completion(@{
				@"code" : code,
				@"creatorId" : creatorId,
				@"creatorIsChat" : [NSNumber numberWithBool:creatorIsChat],
				@"creationDate" : TGPremiumNumber(info[@"creation_date"]),
				@"fromGiveaway" : [NSNumber numberWithBool:[info[@"is_from_giveaway"] boolValue]],
				@"giveawayMessageId" : TGPremiumNumber(info[@"giveaway_message_id"]),
				@"months" : TGPremiumNumber(info[@"month_count"]),
				@"days" : TGPremiumNumber(info[@"day_count"]),
				@"userId" : TGPremiumNumber(info[@"user_id"]),
				@"useDate" : TGPremiumNumber(info[@"use_date"]),
				@"used" : [NSNumber numberWithBool:useDate > 0]
			});
		}];
}

- (void)applyGiftCode:(NSString *)code
		   completion:(void (^)(BOOL, NSString *))completion {
	if (![code isKindOfClass:[NSString class]] || !code.length) {
		if (completion)
			completion(NO, TGL(@"PrivacySettings.PleaseEnterTheCode", @"Please enter the code."));
		return;
	}
	[self request:@{@"@type" : @"applyPremiumGiftCode", @"code" : code}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(NO, TGPremiumErrorText(result));
				return;
			}
			completion(YES, nil);
		}];
}

- (void)redeemGiftCode:(NSString *)code
			completion:(void (^)(BOOL, NSDictionary *, NSString *))completion {
	[self checkGiftCode:code completion:^(NSDictionary *info) {
		if (!info) {
			if (completion)
				completion(NO, nil, TGL(@"Login.InvalidCodeError", @"Invalid code, please try again."));
			return;
		}
		if ([info[@"used"] boolValue]) {
			if (completion)
				completion(NO, info, TGL(@"Login.InvalidCodeError", @"Invalid code, please try again."));
			return;
		}
		[self applyGiftCode:code completion:^(BOOL ok, NSString *error) {
			if (completion)
				completion(ok, info, error);
		}];
	}];
}

#pragma mark - gifting premium

- (void)premiumGiftPaymentOptionsWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getPremiumGiftPaymentOptions"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion([NSArray array]);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			for (id entry in TGPremiumArray(result[@"options"])) {
				NSDictionary *option = TGPremiumDict(entry);
				if (!option)
					continue;
				long long stars = [TGPremiumNumber(option[@"star_count"]) longLongValue];
				if (stars <= 0)
					continue;
				[out addObject:@{
					@"months" : TGPremiumNumber(option[@"month_count"]),
					@"stars" : [NSNumber numberWithLongLong:stars],
					@"discount" : TGPremiumNumber(option[@"discount_percentage"]),
				}];
			}
			completion(out);
		}];
}

- (void)giftPremiumToUser:(int64_t)userId
				   months:(NSInteger)months
					stars:(long long)stars
				  message:(NSString *)message
			   completion:(void (^)(BOOL, NSString *))completion {
	NSString *text = [message isKindOfClass:[NSString class]] ? message : @"";
	__weak typeof(self) weakSelf = self;
	[self paymentFormForPremiumGiftToUser:userId
								 currency:@"XTR"
								   amount:stars
							   monthCount:months
									 text:text
							   completion:^(NSDictionary *form) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!form) {
			if (completion)
				completion(NO, TGL(@"Login.UnknownError", @"An error occurred, please try again later."));
			return;
		}
		[strongSelf payStarsPaymentForm:form completion:^(BOOL ok) {
			if (!completion)
				return;
			completion(ok, ok ? nil : TGL(@"Premium.GiftCouldNotBeSent", @"This gift could not be sent."));
		}];
	}];
}

#pragma mark - giveaways

- (void)giveawayInfoForMessage:(int64_t)messageId
						inChat:(int64_t)chatId
					completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getGiveawayInfo",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"message_id" : [NSNumber numberWithLongLong:messageId]}
		completion:^(NSDictionary *info) {
			if (!completion)
				return;
			if (TGResultIsError(info)) {
				completion(nil);
				return;
			}
			BOOL ongoing = [TGPremiumString(info[@"@type"])
				isEqualToString:@"giveawayInfoOngoing"];
			NSMutableDictionary *out = [NSMutableDictionary dictionary];
			[out setObject:[NSNumber numberWithBool:ongoing] forKey:@"ongoing"];
			[out setObject:TGPremiumNumber(info[@"creation_date"]) forKey:@"creationDate"];

			if (ongoing) {
				NSDictionary *status = TGPremiumDict(info[@"status"]);
				NSString *tag = TGPremiumTag(status, @"giveawayParticipantStatus");
				BOOL ended = [info[@"is_ended"] boolValue];
				NSString *channelTitle = [self titleForChatId:chatId];
				NSString *statusText;
				if ([tag isEqualToString:@"alreadyWasMember"]) {
					NSString *joinedDate = TGPremiumShortDate(
						[TGPremiumNumber(status[@"joined_chat_date"]) doubleValue]);
					statusText = [NSString stringWithFormat:
						TGL(@"Chat.Giveaway.Info.NotAllowedJoinedEarly",
							@"You are not eligible to participate in this giveaway, because you joined this channel on %@, which is before the contest started."
							 "because you joined this channel on %@, which is before the "
							 "contest started."), joinedDate];
				} else if ([tag isEqualToString:@"administrator"]) {
					long long adminChatId = [TGPremiumNumber(status[@"chat_id"]) longLongValue];
					NSString *adminChatTitle = adminChatId ? [self titleForChatId:adminChatId] : channelTitle;
					statusText = [NSString stringWithFormat:
						TGL(@"Chat.Giveaway.Info.NotAllowedAdmin",
							@"You are not eligible to participate in this giveaway, because you are an admin of participating channel (%@)."
							 "because you are an admin of participating channel (%@)."),
						adminChatTitle ?: @""];
				} else if ([tag isEqualToString:@"disallowedCountry"]) {
					statusText = TGL(@"Chat.Giveaway.Info.NotAllowedCountry",
						@"You are not eligible to participate in this giveaway, because your country is not included in the terms of the giveaway."
						 "because your country is not included in the terms of the giveaway.");
				} else {
					statusText = [NSString stringWithFormat:
						TGL(@"Chat.Giveaway.Info.Participating",
							@"You are participating in this giveaway, because you have joined the channel %@."
							 "joined the channel %@."), channelTitle ?: @""];
				}
				if (ended)
					statusText = [statusText stringByAppendingFormat:@" %@",
						TGL(@"Chat.Giveaway.Info.AlmostOver", @"The giveaway is almost over.")];
				[out setObject:[NSNumber numberWithBool:ended] forKey:@"ended"];
				[out setObject:tag forKey:@"status"];
				[out setObject:statusText forKey:@"statusText"];
				[out setObject:TGPremiumNumber(status[@"joined_chat_date"]) forKey:@"joinedDate"];
				[out setObject:TGPremiumNumber(status[@"chat_id"]) forKey:@"adminChatId"];
				[out setObject:TGPremiumString(status[@"user_country_code"]) forKey:@"countryCode"];
				completion(out);
				return;
			}

			BOOL winner = [info[@"is_winner"] boolValue];
			BOOL refunded = [info[@"was_refunded"] boolValue];
			NSString *giftCode = TGPremiumString(info[@"gift_code"]);
			long long wonStars = [TGPremiumNumber(info[@"won_star_count"]) longLongValue];
			NSString *statusText = TGL(@"Chat.Giveaway.Info.DidntWin",
				@"You didn't win a prize in this giveaway.");
			if (refunded) {
				statusText = TGL(@"Chat.Giveaway.Info.Refunded",
					@"The channel cancelled the prizes by reversing the payment for them.");
			} else if (winner && giftCode.length) {
				statusText = [NSString stringWithFormat:
					TGL(@"Chat.Giveaway.Info.Won", @"You won a prize in this giveaway. %@"),
					TGL(@"Chat.Giveaway.Info.ViewPrize", @"View My Prize")];
			} else if (winner && wonStars > 0) {
				NSString *starsWord = TGLPlural(@"Chat.Giveaway.Info.Stars.Stars",
					(NSInteger)wonStars, @"%lld Star", @"%lld Stars");
				statusText = [NSString stringWithFormat:
					TGL(@"Chat.Giveaway.Info.Won", @"You won a prize in this giveaway. %@"),
					starsWord];
			} else if (winner) {
				statusText = [[NSString stringWithFormat:
					TGL(@"Chat.Giveaway.Info.Won", @"You won a prize in this giveaway. %@"), @""]
					stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			}
			[out setObject:@"" forKey:@"status"];
			[out setObject:[NSNumber numberWithBool:YES] forKey:@"ended"];
			[out setObject:statusText forKey:@"statusText"];
			[out setObject:TGPremiumNumber(info[@"actual_winners_selection_date"])
					forKey:@"winnersDate"];
			[out setObject:TGPremiumNumber(info[@"winner_count"]) forKey:@"winnerCount"];
			[out setObject:TGPremiumNumber(info[@"activation_count"]) forKey:@"activationCount"];
			[out setObject:[NSNumber numberWithBool:winner] forKey:@"winner"];
			[out setObject:[NSNumber numberWithBool:refunded] forKey:@"refunded"];
			[out setObject:giftCode forKey:@"giftCode"];
			[out setObject:[NSNumber numberWithLongLong:wonStars] forKey:@"wonStars"];
			completion(out);
		}];
}

- (void)launchPrepaidGiveaway:(long long)giveawayId
					   inChat:(int64_t)chatId
				  winnerCount:(NSInteger)winnerCount
				  winnersDate:(NSTimeInterval)winnersDate
			   onlyNewMembers:(BOOL)onlyNewMembers
			 hasPublicWinners:(BOOL)hasPublicWinners
				 countryCodes:(NSArray *)countryCodes
			 prizeDescription:(NSString *)prizeDescription
						stars:(long long)stars
				   completion:(void (^)(BOOL, NSString *))completion {
	NSArray *countries = [countryCodes isKindOfClass:[NSArray class]]
		? countryCodes
		: [NSArray array];
	NSString *description = [prizeDescription isKindOfClass:[NSString class]]
		? prizeDescription
		: @"";
	NSDictionary *parameters = @{
		@"@type" : @"giveawayParameters",
		@"boosted_chat_id" : [NSNumber numberWithLongLong:chatId],
		@"additional_chat_ids" : [NSArray array],
		@"winners_selection_date" : [NSNumber numberWithLongLong:(long long)winnersDate],
		@"only_new_members" : [NSNumber numberWithBool:onlyNewMembers],
		@"has_public_winners" : [NSNumber numberWithBool:hasPublicWinners],
		@"country_codes" : countries,
		@"prize_description" : description
	};
	[self request:@{@"@type" : @"launchPrepaidGiveaway",
		@"giveaway_id" : [NSNumber numberWithLongLong:giveawayId],
		@"parameters" : parameters,
		@"winner_count" : [NSNumber numberWithInteger:winnerCount],
		@"star_count" : [NSNumber numberWithLongLong:stars]}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(NO, TGPremiumErrorText(result));
				return;
			}
			completion(YES, nil);
		}];
}

#pragma mark - channel boosts

- (void)chatBoostStatusForChat:(int64_t)chatId
					completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getChatBoostStatus",
		@"chat_id" : [NSNumber numberWithLongLong:chatId]}
		completion:^(NSDictionary *status) {
			if (!completion)
				return;
			if (TGResultIsError(status)) {
				completion(nil);
				return;
			}
			NSArray *applied = TGPremiumArray(status[@"applied_slot_ids"]);
			double current = [TGPremiumNumber(status[@"current_level_boost_count"]) doubleValue];
			double next = [TGPremiumNumber(status[@"next_level_boost_count"]) doubleValue];
			double have = [TGPremiumNumber(status[@"boost_count"]) doubleValue];
			double progress = 1.0;
			if (next > current)
				progress = (have - current) / (next - current);
			if (progress < 0.0)
				progress = 0.0;
			if (progress > 1.0)
				progress = 1.0;

			NSMutableArray *prepaid = [NSMutableArray array];
			for (id entry in TGPremiumArray(status[@"prepaid_giveaways"])) {
				NSDictionary *giveaway = TGPremiumDict(entry);
				if (!giveaway)
					continue;
				NSDictionary *prize = TGPremiumDict(giveaway[@"prize"]);
				[prepaid addObject:@{
					@"id" : TGPremiumInt64(giveaway[@"id"]),
					@"winnerCount" : TGPremiumNumber(giveaway[@"winner_count"]),
					@"boostCount" : TGPremiumNumber(giveaway[@"boost_count"]),
					@"paymentDate" : TGPremiumNumber(giveaway[@"payment_date"]),
					@"prizeMonths" : TGPremiumNumber(prize[@"month_count"]),
					@"prizeStars" : TGPremiumNumber(prize[@"star_count"])
				}];
			}

			completion(@{
				@"level" : TGPremiumNumber(status[@"level"]),
				@"boostCount" : TGPremiumNumber(status[@"boost_count"]),
				@"giftCodeBoostCount" : TGPremiumNumber(status[@"gift_code_boost_count"]),
				@"currentLevelBoostCount" : TGPremiumNumber(status[@"current_level_boost_count"]),
				@"nextLevelBoostCount" : TGPremiumNumber(status[@"next_level_boost_count"]),
				@"premiumMemberCount" : TGPremiumNumber(status[@"premium_member_count"]),
				@"premiumMemberPercentage" : TGPremiumNumber(status[@"premium_member_percentage"]),
				@"progress" : [NSNumber numberWithDouble:progress],
				@"boostUrl" : TGPremiumString(status[@"boost_url"]),
				@"appliedSlotIds" : applied,
				@"boosted" : [NSNumber numberWithBool:applied.count > 0],
				@"prepaidGiveaways" : prepaid
			});
		}];
}

- (void)chatBoostLinkForChat:(int64_t)chatId
				  completion:(void (^)(NSString *, BOOL))completion {
	[self request:@{@"@type" : @"getChatBoostLink",
		@"chat_id" : [NSNumber numberWithLongLong:chatId]}
		completion:^(NSDictionary *link) {
			if (!completion)
				return;
			if (TGResultIsError(link)) {
				completion(nil, NO);
				return;
			}
			completion(TGPremiumString(link[@"link"]), [link[@"is_public"] boolValue]);
		}];
}

- (NSDictionary *)giftCodeEntryFromMessage:(NSDictionary *)message {
	NSDictionary *content = TGPremiumDict(message[@"content"]);
	NSString *tag = TGPremiumTag(content, @"message");
	if (!([tag isEqualToString:@"premiumGiftCode"] ||
			[tag isEqualToString:@"giveawayPrizeStars"]))
		return nil;

	NSDictionary *creator = TGPremiumDict(content[@"creator_id"]);
	BOOL creatorIsChat = [TGPremiumString(creator[@"@type"])
		isEqualToString:@"messageSenderChat"];
	NSNumber *creatorId = creatorIsChat ? TGPremiumNumber(creator[@"chat_id"])
										: TGPremiumNumber(creator[@"user_id"]);
	NSString *creatorName = @"";
	if (creatorIsChat) {
		id title = [self.chatsById[creatorId] objectForKey:@"title"];
		if ([title isKindOfClass:[NSString class]])
			creatorName = title;
	} else {
		id name = [self.usersById objectForKey:creatorId];
		if ([name isKindOfClass:[NSString class]])
			creatorName = name;
	}

	NSDictionary *formatted = TGPremiumDict(content[@"text"]);
	NSString *text = TGPremiumString(formatted[@"text"]);

	return @{
		@"code" : TGPremiumString(content[@"code"]),
		@"months" : TGPremiumNumber(content[@"month_count"]),
		@"days" : TGPremiumNumber(content[@"day_count"]),
		@"stars" : TGPremiumNumber(content[@"star_count"]),
		@"fromGiveaway" : [NSNumber numberWithBool:
				[content[@"is_from_giveaway"] boolValue] ||
			[tag isEqualToString:@"giveawayPrizeStars"]],
		@"unclaimed" : [NSNumber numberWithBool:
				[content[@"is_unclaimed"] boolValue]],
		@"creatorId" : creatorId,
		@"creatorIsChat" : [NSNumber numberWithBool:creatorIsChat],
		@"creatorName" : creatorName,
		@"chatId" : TGPremiumNumber(message[@"chat_id"]),
		@"messageId" : TGPremiumNumber(message[@"id"]),
		@"boostedChatId" : TGPremiumNumber(content[@"boosted_chat_id"]),
		@"giveawayMessageId" : TGPremiumNumber(content[@"giveaway_message_id"]),
		@"date" : TGPremiumNumber(message[@"date"]),
		@"text" : text
	};
}

- (void)accountGiftCodesWithLimit:(NSInteger)limit
					   completion:(void (^)(NSArray *))completion {
	NSInteger count = limit > 0 ? limit : 100;
	if (count > 100)
		count = 100;
	[self request:@{@"@type" : @"createPrivateChat",
		@"user_id" : [NSNumber numberWithLongLong:777000LL],
		@"force" : [NSNumber numberWithBool:NO]}
		completion:^(NSDictionary *chat) {
			if (TGResultIsError(chat)) {
				if (completion)
					completion([NSArray array]);
				return;
			}
			long long chatId = [TGPremiumNumber(chat[@"id"]) longLongValue];
			if (!chatId)
				chatId = 777000LL;
			NSDictionary *query = @{@"@type" : @"getChatHistory",
				@"chat_id" : [NSNumber numberWithLongLong:chatId],
				@"from_message_id" : [NSNumber numberWithInt:0],
				@"offset" : [NSNumber numberWithInt:0],
				@"limit" : [NSNumber numberWithInteger:count],
				@"only_local" : [NSNumber numberWithBool:NO]};
			[self request:query completion:^(NSDictionary *first) {
				NSArray *loaded = TGPremiumArray(first[@"messages"]);
				NSArray *messages = TGResultIsError(first) ? [NSArray array] : loaded;
				if (messages.count) {
					if (completion)
						completion([self giftCodeEntriesFromMessages:messages]);
					return;
				}
				[self request:query completion:^(NSDictionary *second) {
					if (!completion)
						return;
					if (TGResultIsError(second)) {
						completion([NSArray array]);
						return;
					}
					completion([self giftCodeEntriesFromMessages:
							TGPremiumArray(second[@"messages"])]);
				}];
			}];
		}];
}

- (NSArray *)giftCodeEntriesFromMessages:(NSArray *)messages {
	NSMutableArray *out = [NSMutableArray array];
	for (id entry in TGPremiumArray(messages)) {
		NSDictionary *message = TGPremiumDict(entry);
		if (!message)
			continue;
		NSDictionary *code = [self giftCodeEntryFromMessage:message];
		if (code)
			[out addObject:code];
	}
	return out;
}

- (NSDictionary *)giveawayEntryFromMessage:(NSDictionary *)message {
	NSDictionary *content = TGPremiumDict(message[@"content"]);
	if (![TGPremiumTag(content, @"message") isEqualToString:@"giveaway"])
		return nil;
	NSDictionary *parameters = TGPremiumDict(content[@"parameters"]);
	NSDictionary *prize = TGPremiumDict(content[@"prize"]);
	NSNumber *chatId = TGPremiumNumber(message[@"chat_id"]);
	id title = [self.chatsById[chatId] objectForKey:@"title"];
	return @{
		@"chatId" : chatId,
		@"chatTitle" : [title isKindOfClass:[NSString class]] ? title : @"",
		@"messageId" : TGPremiumNumber(message[@"id"]),
		@"date" : TGPremiumNumber(message[@"date"]),
		@"winnerCount" : TGPremiumNumber(content[@"winner_count"]),
		@"months" : TGPremiumNumber(prize[@"month_count"]),
		@"stars" : TGPremiumNumber(prize[@"star_count"]),
		@"winnersDate" : TGPremiumNumber(parameters[@"winners_selection_date"])
	};
}

- (void)enteredGiveawaysWithLimit:(NSInteger)limit
					   completion:(void (^)(NSArray *))completion {
	NSInteger cap = limit > 0 ? limit : 20;
	[self request:@{@"@type" : @"getAvailableChatBoostSlots"}
		completion:^(NSDictionary *result) {
			NSMutableArray *chatIds = [NSMutableArray array];
			NSArray *slots = TGPremiumArray(result[@"slots"]);
			for (id entry in TGResultIsError(result) ? [NSArray array] : slots) {
				NSDictionary *slot = TGPremiumDict(entry);
				NSNumber *chatId = TGPremiumNumber(slot[@"currently_boosted_chat_id"]);
				if ([chatId longLongValue] && ![chatIds containsObject:chatId])
					[chatIds addObject:chatId];
			}
			if (!chatIds.count) {
				if (completion)
					completion([NSArray array]);
				return;
			}
			[self collectGiveawayMessagesFromChats:chatIds
											 index:0
										   results:[NSMutableArray array]
											   cap:cap
										completion:completion];
		}];
}

- (void)collectGiveawayMessagesFromChats:(NSArray *)chatIds
								   index:(NSUInteger)index
								 results:(NSMutableArray *)results
									 cap:(NSInteger)cap
							  completion:(void (^)(NSArray *))completion {
	if (index >= chatIds.count || (NSInteger)results.count >= cap) {
		[results sortUsingComparator:^NSComparisonResult(id a, id b) {
			long long left = [TGPremiumNumber([a objectForKey:@"date"]) longLongValue];
			long long right = [TGPremiumNumber([b objectForKey:@"date"]) longLongValue];
			if (left == right)
				return NSOrderedSame;
			return left > right ? NSOrderedAscending : NSOrderedDescending;
		}];
		[self attachGiveawayInfoAtIndex:0 entries:results completion:completion];
		return;
	}
	long long chatId = [TGPremiumNumber([chatIds objectAtIndex:index]) longLongValue];
	[self request:@{@"@type" : @"getChatHistory",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"from_message_id" : [NSNumber numberWithInt:0],
		@"offset" : [NSNumber numberWithInt:0],
		@"limit" : [NSNumber numberWithInt:40],
		@"only_local" : [NSNumber numberWithBool:NO]}
		completion:^(NSDictionary *history) {
			if (!TGResultIsError(history)) {
				for (id entry in TGPremiumArray(history[@"messages"])) {
					NSDictionary *message = TGPremiumDict(entry);
					if (!message)
						continue;
					NSDictionary *giveaway = [self giveawayEntryFromMessage:message];
					if (giveaway && (NSInteger)results.count < cap)
						[results addObject:[NSMutableDictionary
											   dictionaryWithDictionary:giveaway]];
				}
			}
			[self collectGiveawayMessagesFromChats:chatIds
											 index:index + 1
										   results:results
											   cap:cap
										completion:completion];
		}];
}

- (void)attachGiveawayInfoAtIndex:(NSUInteger)index
						  entries:(NSMutableArray *)entries
					   completion:(void (^)(NSArray *))completion {
	if (index >= entries.count) {
		if (completion)
			completion(entries);
		return;
	}
	NSMutableDictionary *entry = [entries objectAtIndex:index];
	long long chatId = [TGPremiumNumber([entry objectForKey:@"chatId"]) longLongValue];
	long long messageId = [TGPremiumNumber([entry objectForKey:@"messageId"]) longLongValue];
	[self giveawayInfoForMessage:messageId
						  inChat:chatId
					  completion:^(NSDictionary *info) {
						  if ([info isKindOfClass:[NSDictionary class]])
							  [entry addEntriesFromDictionary:info];
						  [self attachGiveawayInfoAtIndex:index + 1 entries:entries completion:completion];
					  }];
}

- (NSArray *)boostSlotsFromResult:(NSDictionary *)result {
	NSMutableArray *out = [NSMutableArray array];
	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	for (id entry in TGPremiumArray(result[@"slots"])) {
		NSDictionary *slot = TGPremiumDict(entry);
		if (!slot)
			continue;
		long long chatId = [TGPremiumNumber(slot[@"currently_boosted_chat_id"]) longLongValue];
		long long cooldown = [TGPremiumNumber(slot[@"cooldown_until_date"]) longLongValue];
		[out addObject:@{
			@"slotId" : TGPremiumNumber(slot[@"slot_id"]),
			@"chatId" : [NSNumber numberWithLongLong:chatId],
			@"startDate" : TGPremiumNumber(slot[@"start_date"]),
			@"expirationDate" : TGPremiumNumber(slot[@"expiration_date"]),
			@"cooldownUntil" : [NSNumber numberWithLongLong:cooldown],
			@"free" : [NSNumber numberWithBool:chatId == 0],
			@"reassignable" : [NSNumber numberWithBool:
					chatId != 0 && (double)cooldown <= now]
		}];
	}
	return out;
}

- (void)availableBoostSlotsWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getAvailableChatBoostSlots"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion([NSArray array]);
				return;
			}
			completion([self boostSlotsFromResult:result]);
		}];
}

- (void)boostersInChat:(int64_t)chatId
		 onlyGiftCodes:(BOOL)onlyGiftCodes
				offset:(NSString *)offset
				 limit:(NSInteger)limit
			completion:(void (^)(NSDictionary *))completion {
	NSString *from = [offset isKindOfClass:[NSString class]] ? offset : @"";
	NSInteger count = limit > 0 ? limit : 50;
	[self request:@{@"@type" : @"getChatBoosts",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"only_gift_codes" : [NSNumber numberWithBool:onlyGiftCodes],
		@"offset" : from,
		@"limit" : [NSNumber numberWithInteger:count]}
		completion:^(NSDictionary *found) {
			if (!completion)
				return;
			if (TGResultIsError(found)) {
				completion(nil);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			for (id entry in TGPremiumArray(found[@"boosts"])) {
				NSDictionary *boost = TGPremiumDict(entry);
				if (!boost)
					continue;
				NSDictionary *source = TGPremiumDict(boost[@"source"]);
				NSString *tag = TGPremiumTag(source, @"chatBoostSource");
				NSNumber *userId = TGPremiumNumber(source[@"user_id"]);
				id name = [self.usersById objectForKey:userId];
				[out addObject:@{
					@"id" : TGPremiumString(boost[@"id"]),
					@"count" : TGPremiumNumber(boost[@"count"]),
					@"startDate" : TGPremiumNumber(boost[@"start_date"]),
					@"expirationDate" : TGPremiumNumber(boost[@"expiration_date"]),
					@"userId" : userId,
					@"name" : [name isKindOfClass:[NSString class]] ? name : @"",
					@"source" : tag,
					@"giftCode" : TGPremiumString(source[@"gift_code"]),
					@"giveawayMessageId" : TGPremiumNumber(source[@"giveaway_message_id"]),
					@"unclaimed" : [NSNumber numberWithBool:
							[source[@"is_unclaimed"] boolValue]]
				}];
			}
			completion(@{
				@"totalCount" : TGPremiumNumber(found[@"total_count"]),
				@"nextOffset" : TGPremiumString(found[@"next_offset"]),
				@"boosts" : out
			});
		}];
}

- (void)boostFeaturesForChannel:(BOOL)isChannel
					 completion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getChatBoostFeatures",
		@"is_channel" : [NSNumber numberWithBool:isChannel]}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion([NSArray array]);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			for (id entry in TGPremiumArray(result[@"features"])) {
				NSDictionary *level = TGPremiumDict(entry);
				if (!level)
					continue;
				NSMutableArray *lines = [NSMutableArray array];
				NSInteger stories = [TGPremiumNumber(level[@"story_per_day_count"]) integerValue];
				if (stories > 0)
					[lines addObject:TGLPlural(@"ChannelBoost.Table.StoriesPerDay", stories,
						@"%@ Story Per Day", @"%@ Stories Per Day")];
				NSInteger reactions = [TGPremiumNumber(level[@"custom_emoji_reaction_count"]) integerValue];
				if (reactions > 0)
					[lines addObject:TGLPlural(@"ChannelBoost.Table.CustomReactions", reactions,
						@"%@ Custom Reaction", @"%@ Custom Reactions")];
				NSInteger titleColors = [TGPremiumNumber(level[@"title_color_count"]) integerValue];
				if (titleColors > 0)
					[lines addObject:TGLPlural(@"ChannelBoost.Table.NameColor", titleColors,
						@"%@ Channel Name Color", @"%@ Channel Name Colors")];
				NSInteger accents = [TGPremiumNumber(level[@"accent_color_count"]) integerValue];
				if (accents > 0)
					[lines addObject:TGLPlural(@"ChannelBoost.Table.ProfileColor", accents,
						@"%@ Color for Channel Cover", @"%@ Colors for Channel Cover")];
				NSInteger backgrounds = [TGPremiumNumber(level[@"chat_theme_background_count"]) integerValue];
				if (backgrounds > 0)
					[lines addObject:TGLPlural(@"ChannelBoost.Table.Wallpaper", backgrounds,
						@"%@ Channel Background", @"%@ Channel Backgrounds")];
				if ([level[@"can_set_custom_background"] boolValue])
					[lines addObject:TGL(@"ChannelBoost.Table.CustomWallpaper", @"Custom Channel Background")];
				if ([level[@"can_set_emoji_status"] boolValue])
					[lines addObject:TGL(@"ChannelBoost.Table.EmojiStatus", @"1000+ Emoji Statuses")];
				if ([level[@"can_set_custom_emoji_sticker_set"] boolValue])
					[lines addObject:TGL(@"GroupBoost.Table.Group.EmojiPack", @"Custom Emojipack")];
				if ([level[@"can_recognize_speech"] boolValue])
					[lines addObject:TGL(@"GroupBoost.Table.Group.VoiceToText", @"Voice-to-Text Conversion")];
				if ([level[@"can_enable_automatic_translation"] boolValue])
					[lines addObject:TGL(@"ChannelBoost.Table.AutoTranslate", @"Autotranslation of Messages")];
				[out addObject:@{
					@"level" : TGPremiumNumber(level[@"level"]),
					@"features" : lines
				}];
			}
			completion(out);
		}];
}

#pragma mark - affiliate programs

- (void)connectedAffiliateProgramsWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getConnectedAffiliatePrograms",
		@"affiliate" : @{@"@type" : @"affiliateTypeCurrentUser"},
		@"offset" : @"",
		@"limit" : @20}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion([NSArray array]);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			for (id entry in TGPremiumArray(result[@"programs"])) {
				NSDictionary *program = TGPremiumDict(entry);
				if (!program)
					continue;
				NSDictionary *parameters = TGPremiumDict(program[@"parameters"]);
				[out addObject:@{
					@"botUserId" : TGPremiumInt64(program[@"bot_user_id"]),
					@"commission" : TGPremiumNumber(parameters[@"commission_per_mille"]),
					@"months" : TGPremiumNumber(parameters[@"month_count"]),
					@"url" : TGPremiumString(program[@"url"]),
					@"connectionDate" : TGPremiumNumber(program[@"connection_date"]),
					@"disconnected" : [NSNumber numberWithBool:[program[@"is_disconnected"] boolValue]],
					@"userCount" : TGPremiumInt64(program[@"user_count"]),
					@"revenueStars" : TGPremiumNumber(program[@"revenue_star_count"]),
				}];
			}
			completion(out);
		}];
}

- (void)suggestedAffiliateProgramsWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"searchAffiliatePrograms",
		@"affiliate" : @{@"@type" : @"affiliateTypeCurrentUser"},
		@"sort_order" : @{@"@type" : @"affiliateProgramSortOrderProfitability"},
		@"offset" : @"",
		@"limit" : @20}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion([NSArray array]);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			for (id entry in TGPremiumArray(result[@"programs"])) {
				NSDictionary *found = TGPremiumDict(entry);
				if (!found)
					continue;
				NSDictionary *info = TGPremiumDict(found[@"info"]);
				NSDictionary *parameters = TGPremiumDict(info[@"parameters"]);
				NSDictionary *revenue = TGPremiumDict(info[@"daily_revenue_per_user_amount"]);
				[out addObject:@{
					@"botUserId" : TGPremiumInt64(found[@"bot_user_id"]),
					@"commission" : TGPremiumNumber(parameters[@"commission_per_mille"]),
					@"months" : TGPremiumNumber(parameters[@"month_count"]),
					@"endDate" : TGPremiumNumber(info[@"end_date"]),
					@"dailyRevenuePerUser" : revenue ? TGPremiumNumber(revenue[@"star_count"]) : @0,
				}];
			}
			completion(out);
		}];
}

- (void)connectAffiliateProgramForBot:(int64_t)botUserId
						   completion:(void (^)(NSString *, NSString *))completion {
	[self request:@{@"@type" : @"connectAffiliateProgram",
		@"affiliate" : @{@"@type" : @"affiliateTypeCurrentUser"},
		@"bot_user_id" : [NSNumber numberWithLongLong:botUserId]}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil, TGPremiumErrorText(result));
				return;
			}
			completion(TGPremiumString(result[@"url"]), nil);
		}];
}

- (void)disconnectAffiliateProgramWithUrl:(NSString *)url
							   completion:(void (^)(BOOL))completion {
	if (!url.length) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{@"@type" : @"disconnectAffiliateProgram",
		@"affiliate" : @{@"@type" : @"affiliateTypeCurrentUser"},
		@"url" : url}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

#pragma mark - stars

- (void)starTransactionsWithOffset:(NSString *)offset
							 limit:(NSInteger)limit
						completion:(void (^)(NSDictionary *))completion {
	NSDictionary *me = self.me;
	long long myId = [TGPremiumNumber(me[@"id"]) longLongValue];
	NSString *from = [offset isKindOfClass:[NSString class]] ? offset : @"";
	NSInteger count = limit > 0 ? limit : 50;
	[self request:@{@"@type" : @"getStarTransactions",
		@"owner_id" : @{@"@type" : @"messageSenderUser",
			@"user_id" : [NSNumber numberWithLongLong:myId]},
		@"subscription_id" : @"",
		@"offset" : from,
		@"limit" : [NSNumber numberWithInteger:count]}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			for (id entry in TGPremiumArray(result[@"transactions"])) {
				NSDictionary *transaction = TGPremiumDict(entry);
				if (!transaction)
					continue;
				NSDictionary *amount = TGPremiumDict(transaction[@"star_amount"]);
				NSDictionary *typeDict = TGPremiumDict(transaction[@"type"]);
				NSString *tag = TGPremiumTag(typeDict, @"starTransactionType");
				NSString *shortType = TGPayShortType(typeDict[@"@type"], @"starTransactionType");
				[out addObject:@{
					@"id" : TGPremiumString(transaction[@"id"]),
					@"stars" : TGPremiumNumber(amount[@"star_count"]),
					@"starsNanos" : @(TGPayStarsNanos(amount)),
					@"refund" : [NSNumber numberWithBool:[transaction[@"is_refund"] boolValue]],
					@"date" : TGPremiumNumber(transaction[@"date"]),
					@"type" : tag,
					@"title" : TGPayHumanType(shortType)
				}];
			}
			NSDictionary *balance = TGPremiumDict(result[@"star_amount"]);
			completion(@{
				@"balance" : TGPremiumNumber(balance[@"star_count"]),
				@"balanceNanos" : @(TGPayStarsNanos(balance)),
				@"nextOffset" : TGPremiumString(result[@"next_offset"]),
				@"transactions" : out
			});
		}];
}

#pragma mark - voice recognition

- (void)recognizeSpeechInMessage:(int64_t)messageId
						  inChat:(int64_t)chatId
					  completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{@"@type" : @"recognizeSpeech",
		@"chat_id" : [NSNumber numberWithLongLong:chatId],
		@"message_id" : [NSNumber numberWithLongLong:messageId]}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(NO, TGPremiumErrorText(result));
				return;
			}
			completion(YES, nil);
		}];
}

+ (NSDictionary *)speechRecognitionFromMessage:(NSDictionary *)message {
	NSDictionary *content = TGPremiumDict(TGPremiumDict(message)[@"content"]);
	NSDictionary *note = TGPremiumDict(content[@"voice_note"]);
	if (!note)
		note = TGPremiumDict(content[@"video_note"]);
	NSDictionary *result = TGPremiumDict(note[@"speech_recognition_result"]);
	if (!result)
		return @{@"state" : @"none", @"text" : @""};
	NSString *type = TGPremiumString(result[@"@type"]);
	if ([type isEqualToString:@"speechRecognitionResultPending"])
		return @{@"state" : @"pending",
			@"text" : TGPremiumString(result[@"partial_text"])};
	if ([type isEqualToString:@"speechRecognitionResultText"])
		return @{@"state" : @"text", @"text" : TGPremiumString(result[@"text"])};
	if ([type isEqualToString:@"speechRecognitionResultError"]) {
		NSDictionary *error = TGPremiumDict(result[@"error"]);
		return @{@"state" : @"error",
			@"text" : TGPremiumString(error[@"message"])};
	}
	return @{@"state" : @"none", @"text" : @""};
}

- (void)handleUpdateSpeechRecognitionTrial:(NSDictionary *)update {
	NSDictionary *body = TGPremiumDict(update);
	self.speechRecognitionTrialKnown = YES;
	self.speechRecognitionTrialMaxMediaDuration = [TGPremiumNumber(body[@"max_media_duration"]) integerValue];
	self.speechRecognitionTrialWeeklyCount = [TGPremiumNumber(body[@"weekly_count"]) integerValue];
	self.speechRecognitionTrialLeftCount = [TGPremiumNumber(body[@"left_count"]) integerValue];
	self.speechRecognitionTrialNextResetDate = [TGPremiumInt64(body[@"next_reset_date"]) longLongValue];
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGSpeechRecognitionTrialDidChangeNotification
					  object:nil];
}

- (void)clearSpeechRecognitionTrialForAccountSwitch {
	self.speechRecognitionTrialKnown = NO;
	self.speechRecognitionTrialMaxMediaDuration = 0;
	self.speechRecognitionTrialWeeklyCount = 0;
	self.speechRecognitionTrialLeftCount = 0;
	self.speechRecognitionTrialNextResetDate = 0;
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGSpeechRecognitionTrialDidChangeNotification
					  object:nil];
}

@end

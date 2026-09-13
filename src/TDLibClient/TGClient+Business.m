#import "TGClient+Business.h"
#import "TGClient+Private.h"
#import "TGClient+MessageContent.h"
#import "TGFlattenBusiness.h"

static NSDictionary *TGBizDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSDictionary *TGBizGreetingFrom(NSDictionary *greeting) {
	if (!greeting)
		return nil;
	return @{
		@"enabled" : @YES,
		@"shortcutId" : @([greeting[@"shortcut_id"] integerValue]),
		@"recipients" : TGBizRecipientsFrom(TGBizDict(greeting[@"recipients"])),
		@"inactivityDays" : @([greeting[@"inactivity_days"] integerValue]),
	};
}

static NSDictionary *TGBizLocationFrom(NSDictionary *location) {
	if (!location)
		return nil;
	NSDictionary *point = TGBizDict(location[@"location"]);
	return @{
		@"address" : [location[@"address"] isKindOfClass:NSString.class] ? location[@"address"] : @"",
		@"hasPoint" : @(point != nil),
		@"latitude" : point[@"latitude"] ?: @0,
		@"longitude" : point[@"longitude"] ?: @0,
	};
}

static NSDictionary *TGBizStartPageFrom(NSDictionary *page) {
	if (!page)
		return nil;
	return @{
		@"title" : [page[@"title"] isKindOfClass:NSString.class] ? page[@"title"] : @"",
		@"message" : [page[@"message"] isKindOfClass:NSString.class] ? page[@"message"] : @"",
		@"sticker" : TGBizDict(page[@"sticker"]) ?: [NSNull null],
	};
}

static id TGBizStartPageInputSticker(id sticker) {
	NSDictionary *stickerDict = TGBizDict(sticker);
	NSNumber *pickedFileId = stickerDict[@"fileId"];
	if ([pickedFileId isKindOfClass:NSNumber.class] && [pickedFileId longLongValue] != 0) {
		return @{
			@"@type" : @"inputFileId",
			@"id" : pickedFileId,
		};
	}
	NSDictionary *file = TGBizDict(stickerDict[@"sticker"]);
	NSDictionary *remote = TGBizDict(file[@"remote"]);
	NSString *remoteId = [remote[@"id"] isKindOfClass:NSString.class] ? remote[@"id"] : nil;
	if (!remoteId.length)
		return [NSNull null];
	return @{
		@"@type" : @"inputFileRemote",
		@"id" : remoteId,
	};
}

static NSString *TGBizErrorMessage(NSDictionary *result) {
	NSString *message = result[@"message"];
	return [message isKindOfClass:NSString.class] ? message : nil;
}

@implementation TGClient (Business)

- (void)businessSettingsWithCompletion:(void (^)(NSDictionary *, BOOL))completion {
	if (!completion)
		return;
	NSNumber *ownId = self.me[@"id"];
	[self request:@{@"@type" : @"getUserFullInfo", @"user_id" : ownId ?: @0}
		completion:^(NSDictionary *full) {
			if (TGResultIsError(full)) {
				completion(@{}, YES);
				return;
			}
			NSDictionary *info = TGBizDict(full[@"business_info"]);
			NSDictionary *greeting = TGBizGreetingFrom(TGBizDict(info[@"greeting_message_settings"]));
			NSDictionary *away = TGBizAwayFrom(TGBizDict(info[@"away_message_settings"]));
			NSDictionary *location = TGBizLocationFrom(TGBizDict(info[@"location"]));
			NSDictionary *hours = TGBizOpeningHoursFrom(TGBizDict(info[@"opening_hours"]));
			NSDictionary *startPage = TGBizStartPageFrom(TGBizDict(info[@"start_page"]));
			NSMutableDictionary *out = [NSMutableDictionary dictionary];
			out[@"greeting"] = greeting ?: @{@"enabled" : @NO};
			out[@"away"] = away ?: @{@"enabled" : @NO};
			out[@"location"] = location ?: @{@"address" : @"",
				@"hasPoint" : @NO};
			out[@"hours"] = hours ?: @{@"timeZoneId" : @"",
				@"days" : @[],
				@"hasComplexSchedule" : @NO};
			out[@"startPage"] = startPage ?: @{@"title" : @"", @"message" : @"", @"sticker" : [NSNull null]};
			completion(out, NO);
		}];
}

- (void)setBusinessAddress:(NSString *)address
				  latitude:(double)latitude
				 longitude:(double)longitude
				  hasPoint:(BOOL)hasPoint
				completion:(void (^)(BOOL))completion {
	id value = [NSNull null];
	if (address.length) {
		NSMutableDictionary *location = [NSMutableDictionary dictionaryWithDictionary:@{
			@"@type" : @"businessLocation",
			@"address" : address,
		}];
		if (hasPoint)
			location[@"location"] = @{
				@"@type" : @"location",
				@"latitude" : @(latitude),
				@"longitude" : @(longitude),
			};
		value = location;
	}
	[self request:@{@"@type" : @"setBusinessLocation", @"location" : value}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)setBusinessOpeningHoursTimeZoneId:(NSString *)timeZoneId
									 days:(NSArray *)days
							   completion:(void (^)(BOOL))completion {
	NSMutableArray *intervals = [NSMutableArray array];
	NSInteger day = 0;
	for (id entry in days) {
		NSDictionary *slot = TGBizDict(entry);
		if (slot && [slot[@"open"] boolValue]) {
			NSInteger start = day * 24 * 60 + [slot[@"startMinute"] integerValue];
			NSInteger end = day * 24 * 60 + [slot[@"endMinute"] integerValue];
			if (end > start)
				[intervals addObject:@{
					@"@type" : @"businessOpeningHoursInterval",
					@"start_minute" : @(start),
					@"end_minute" : @(end),
				}];
		}
		day++;
	}
	id value = [NSNull null];
	if (intervals.count)
		value = @{
			@"@type" : @"businessOpeningHours",
			@"time_zone_id" : timeZoneId.length ? timeZoneId : [[NSTimeZone localTimeZone] name],
			@"opening_hours" : intervals,
		};
	[self request:@{@"@type" : @"setBusinessOpeningHours", @"opening_hours" : value}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)setBusinessStartPageTitle:(NSString *)title
						  message:(NSString *)message
						  sticker:(id)sticker
					   completion:(void (^)(BOOL))completion {
	id value = [NSNull null];
	if (title.length || message.length) {
		value = @{
			@"@type" : @"inputBusinessStartPage",
			@"title" : title ?: @"",
			@"message" : message ?: @"",
			@"sticker" : TGBizStartPageInputSticker(sticker),
		};
	}
	[self request:@{@"@type" : @"setBusinessStartPage", @"start_page" : value}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)businessChatLinksWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getBusinessChatLinks"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			for (id entry in ([result[@"links"] isKindOfClass:NSArray.class] ? result[@"links"] : @[])) {
				NSDictionary *flat = TGBizFlattenLink(TGBizDict(entry));
				if (flat)
					[out addObject:flat];
			}
			completion(out);
		}];
}

- (void)businessChatLinkCountMaxWithCompletion:(void (^)(NSInteger))completion {
	if (!completion)
		return;
	[self request:@{@"@type" : @"getOption", @"name" : @"business_chat_link_count_max"}
		completion:^(NSDictionary *result) {
			NSNumber *value = TGResultIsError(result) ? nil : result[@"value"];
			completion([value isKindOfClass:NSNumber.class] ? [value integerValue] : 0);
		}];
}

- (void)createBusinessChatLinkWithText:(NSString *)text
								 title:(NSString *)title
							completion:(void (^)(NSDictionary *, NSString *))completion {
	__weak typeof(self) weakSelf = self;
	[self formattedTextFromMarkdown:text ?: @"" completion:^(NSString *plainText, NSArray *entities) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf request:@{
			@"@type" : @"createBusinessChatLink",
			@"link_info" : @{
				@"@type" : @"inputBusinessChatLink",
				@"text" : @{@"@type" : @"formattedText",
					@"text" : plainText ?: @"",
					@"entities" : entities ?: @[]},
				@"title" : title ?: @"",
			},
		} completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil, TGBizErrorMessage(result));
				return;
			}
			completion(TGBizFlattenLink(result), nil);
		}];
	}];
}

- (void)editBusinessChatLink:(NSString *)link
						text:(NSString *)text
					entities:(NSArray *)entities
					   title:(NSString *)title
				  completion:(void (^)(BOOL, NSString *))completion {
	__weak typeof(self) weakSelf = self;
	void (^doEdit)(NSString *, NSArray *) = ^(NSString *plainText, NSArray *finalEntities) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf request:@{
			@"@type" : @"editBusinessChatLink",
			@"link" : link ?: @"",
			@"link_info" : @{
				@"@type" : @"inputBusinessChatLink",
				@"text" : @{@"@type" : @"formattedText",
					@"text" : plainText ?: @"",
					@"entities" : finalEntities ?: @[]},
				@"title" : title ?: @"",
			},
		} completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(!TGResultIsError(result), TGResultIsError(result) ? TGBizErrorMessage(result) : nil);
		}];
	};
	if (entities)
		doEdit(text ?: @"", entities);
	else
		[self formattedTextFromMarkdown:text ?: @"" completion:doEdit];
}

- (void)deleteBusinessChatLink:(NSString *)link
					completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"deleteBusinessChatLink", @"link" : link ?: @""}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)setBusinessGreetingMessage:(NSDictionary *)settings
						completion:(void (^)(BOOL))completion {
	id value = [NSNull null];
	if (settings) {
		value = @{
			@"@type" : @"businessGreetingMessageSettings",
			@"shortcut_id" : @([settings[@"shortcutId"] integerValue]),
			@"recipients" : TGBizRecipientsInput(TGBizDict(settings[@"recipients"])),
			@"inactivity_days" : @([settings[@"inactivityDays"] integerValue]),
		};
	}
	[self request:@{@"@type" : @"setBusinessGreetingMessageSettings",
		@"greeting_message_settings" : value}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)setBusinessAwayMessage:(NSDictionary *)settings
					completion:(void (^)(BOOL))completion {
	id value = [NSNull null];
	if (settings) {
		NSString *scheduleType = [settings[@"schedule"] isKindOfClass:NSString.class]
			? settings[@"schedule"]
			: @"always";
		NSDictionary *schedule = @{@"@type" : @"businessAwayMessageScheduleAlways"};
		if ([scheduleType isEqualToString:@"outsideHours"])
			schedule = @{@"@type" : @"businessAwayMessageScheduleOutsideOfOpeningHours"};
		else if ([scheduleType isEqualToString:@"custom"])
			schedule = @{
				@"@type" : @"businessAwayMessageScheduleCustom",
				@"start_date" : @([settings[@"startDate"] longLongValue]),
				@"end_date" : @([settings[@"endDate"] longLongValue]),
			};
		value = @{
			@"@type" : @"businessAwayMessageSettings",
			@"shortcut_id" : @([settings[@"shortcutId"] integerValue]),
			@"recipients" : TGBizRecipientsInput(TGBizDict(settings[@"recipients"])),
			@"schedule" : schedule,
			@"offline_only" : @([settings[@"offlineOnly"] boolValue]),
		};
	}
	[self request:@{@"@type" : @"setBusinessAwayMessageSettings",
		@"away_message_settings" : value}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)businessConnectedBotWithCompletion:(void (^)(NSDictionary *))completion {
	if (!completion)
		return;
	[self request:@{@"@type" : @"getBusinessConnectedBot"}
		completion:^(NSDictionary *result) {
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			NSDictionary *bot = TGBizDict(result[@"bot"]);
			if (!bot) {
				completion(nil);
				return;
			}
			completion(@{
				@"botUserId" : bot[@"bot_user_id"] ?: @0,
				@"recipients" : TGBizRecipientsFrom(TGBizDict(bot[@"recipients"])),
				@"rights" : TGBizRightsFrom(TGBizDict(bot[@"rights"])),
			});
		}];
}

- (void)setBusinessConnectedBotUserId:(int64_t)botUserId
						   recipients:(NSDictionary *)recipients
							   rights:(NSDictionary *)rights
						   completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setBusinessConnectedBot",
		@"bot" : @{
			@"@type" : @"businessConnectedBot",
			@"bot_user_id" : @(botUserId),
			@"recipients" : TGBizRecipientsInput(recipients),
			@"rights" : TGBizRightsInput(rights),
		},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)deleteBusinessConnectedBotUserId:(int64_t)botUserId
							  completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"deleteBusinessConnectedBot", @"bot_user_id" : @(botUserId)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

@end

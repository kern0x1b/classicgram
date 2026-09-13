#import "TGFlattenBusiness.h"

static NSDictionary *TGBizDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSArray *TGBizArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : @[];
}

NSDictionary *TGBizRecipientsFrom(NSDictionary *recipients) {
	return @{
		@"existingChats" : @([recipients[@"select_existing_chats"] boolValue]),
		@"newChats" : @([recipients[@"select_new_chats"] boolValue]),
		@"contacts" : @([recipients[@"select_contacts"] boolValue]),
		@"nonContacts" : @([recipients[@"select_non_contacts"] boolValue]),
		@"chatIds" : TGBizArray(recipients[@"chat_ids"]),
		@"excludedChatIds" : TGBizArray(recipients[@"excluded_chat_ids"]),
		@"excludeSelected" : @([recipients[@"exclude_selected"] boolValue]),
	};
}

NSDictionary *TGBizRecipientsInput(NSDictionary *recipients) {
	return @{
		@"@type" : @"businessRecipients",
		@"chat_ids" : TGBizArray(recipients[@"chatIds"]),
		@"excluded_chat_ids" : TGBizArray(recipients[@"excludedChatIds"]),
		@"select_existing_chats" : @([recipients[@"existingChats"] boolValue]),
		@"select_new_chats" : @([recipients[@"newChats"] boolValue]),
		@"select_contacts" : @([recipients[@"contacts"] boolValue]),
		@"select_non_contacts" : @([recipients[@"nonContacts"] boolValue]),
		@"exclude_selected" : @([recipients[@"excludeSelected"] boolValue]),
	};
}

NSDictionary *TGBizAwayFrom(NSDictionary *away) {
	if (!away)
		return nil;
	NSDictionary *schedule = TGBizDict(away[@"schedule"]);
	NSString *scheduleType = @"always";
	long long startDate = 0, endDate = 0;
	NSString *tag = [schedule[@"@type"] isKindOfClass:NSString.class] ? schedule[@"@type"] : @"";
	if ([tag isEqualToString:@"businessAwayMessageScheduleOutsideOfOpeningHours"])
		scheduleType = @"outsideHours";
	else if ([tag isEqualToString:@"businessAwayMessageScheduleCustom"]) {
		scheduleType = @"custom";
		startDate = [schedule[@"start_date"] longLongValue];
		endDate = [schedule[@"end_date"] longLongValue];
	}
	return @{
		@"enabled" : @YES,
		@"shortcutId" : @([away[@"shortcut_id"] integerValue]),
		@"recipients" : TGBizRecipientsFrom(TGBizDict(away[@"recipients"])),
		@"schedule" : scheduleType,
		@"startDate" : @(startDate),
		@"endDate" : @(endDate),
		@"offlineOnly" : @([away[@"offline_only"] boolValue]),
	};
}

NSDictionary *TGBizOpeningHoursFrom(NSDictionary *hours) {
	if (!hours)
		return nil;
	NSMutableArray *days = [NSMutableArray arrayWithCapacity:7];
	for (NSInteger day = 0; day < 7; day++)
		[days addObject:[NSMutableDictionary dictionaryWithDictionary:@{
			@"open" : @NO,
			@"startMinute" : @(9 * 60),
			@"endMinute" : @(18 * 60),
			@"intervals" : @[],
		}]];
	for (id entry in ([hours[@"opening_hours"] isKindOfClass:NSArray.class] ? hours[@"opening_hours"] : @[])) {
		NSDictionary *interval = TGBizDict(entry);
		if (!interval)
			continue;
		NSInteger start = [interval[@"start_minute"] integerValue];
		NSInteger end = [interval[@"end_minute"] integerValue];
		NSInteger startDay = start / (24 * 60);
		if (startDay < 0 || startDay > 6 || end <= start)
			continue;
		NSInteger cursor = start;
		while (cursor < end) {
			NSInteger rawDay = cursor / (24 * 60);
			NSInteger day = ((rawDay % 7) + 7) % 7;
			NSInteger dayBoundary = (rawDay + 1) * 24 * 60;
			NSInteger segmentEnd = MIN(end, dayBoundary);
			NSInteger relativeStart = cursor - rawDay * 24 * 60;
			NSInteger relativeEnd = segmentEnd - rawDay * 24 * 60;
			NSMutableDictionary *slot = days[(NSUInteger)day];
			NSMutableArray *intervals = [slot[@"intervals"] mutableCopy];
			[intervals addObject:@{
				@"startMinute" : @(relativeStart),
				@"endMinute" : @(relativeEnd),
			}];
			slot[@"intervals"] = intervals;
			if (![slot[@"open"] boolValue]) {
				slot[@"open"] = @YES;
				slot[@"startMinute"] = @(relativeStart);
				slot[@"endMinute"] = @(relativeEnd);
			}
			cursor = segmentEnd;
		}
	}
	BOOL hasComplexSchedule = NO;
	for (NSMutableDictionary *slot in days) {
		if ([slot[@"intervals"] count] > 1) {
			hasComplexSchedule = YES;
			break;
		}
	}
	return @{
		@"timeZoneId" : [hours[@"time_zone_id"] isKindOfClass:NSString.class] ? hours[@"time_zone_id"] : @"",
		@"days" : days,
		@"hasComplexSchedule" : @(hasComplexSchedule),
	};
}

static NSArray *TGBizRightsKeys(void) {
	static NSArray *pairs = nil;
	if (!pairs)
		pairs = @[
			@[ @"canReply", @"can_reply" ],
			@[ @"canReadMessages", @"can_read_messages" ],
			@[ @"canDeleteSentMessages", @"can_delete_sent_messages" ],
			@[ @"canDeleteAllMessages", @"can_delete_all_messages" ],
			@[ @"canEditName", @"can_edit_name" ],
			@[ @"canEditBio", @"can_edit_bio" ],
			@[ @"canEditProfilePhoto", @"can_edit_profile_photo" ],
			@[ @"canEditUsername", @"can_edit_username" ],
			@[ @"canViewGiftsAndStars", @"can_view_gifts_and_stars" ],
			@[ @"canSellGifts", @"can_sell_gifts" ],
			@[ @"canChangeGiftSettings", @"can_change_gift_settings" ],
			@[ @"canTransferAndUpgradeGifts", @"can_transfer_and_upgrade_gifts" ],
			@[ @"canTransferStars", @"can_transfer_stars" ],
			@[ @"canManageStories", @"can_manage_stories" ],
		];
	return pairs;
}

NSDictionary *TGBizRightsFrom(NSDictionary *rights) {
	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	for (NSArray *pair in TGBizRightsKeys())
		out[pair[0]] = @([rights[pair[1]] boolValue]);
	return out;
}

NSDictionary *TGBizRightsInput(NSDictionary *rights) {
	NSMutableDictionary *out = [NSMutableDictionary dictionaryWithDictionary:@{@"@type" : @"businessBotRights"}];
	for (NSArray *pair in TGBizRightsKeys())
		out[pair[1]] = @([rights[pair[0]] boolValue]);
	return out;
}

NSDictionary *TGBizFlattenLink(NSDictionary *link) {
	if (!TGBizDict(link))
		return nil;
	NSDictionary *text = TGBizDict(link[@"text"]);
	return @{
		@"link" : [link[@"link"] isKindOfClass:NSString.class] ? link[@"link"] : @"",
		@"title" : [link[@"title"] isKindOfClass:NSString.class] ? link[@"title"] : @"",
		@"text" : [text[@"text"] isKindOfClass:NSString.class] ? text[@"text"] : @"",
		@"entities" : TGBizArray(text[@"entities"]),
		@"viewCount" : link[@"view_count"] ?: @0,
	};
}

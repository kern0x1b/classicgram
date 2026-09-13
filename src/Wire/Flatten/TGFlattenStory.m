#import "TGFlattenStory.h"
#import "TGLocalization.h"

static NSArray *TGStoryArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : @[];
}

static NSDictionary *TGStoryDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSString *TGStoryString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSNumber *TGStoryNumber(id value) {
	return [value isKindOfClass:NSNumber.class] ? value : nil;
}

static NSArray *TGStoryIdList(NSArray *ids) {
	NSMutableArray *out = [NSMutableArray array];
	for (id one in TGStoryArray(ids)) {
		NSNumber *n = TGStoryNumber(one);
		if (n)
			[out addObject:n];
	}
	return out;
}

int64_t TGStorySenderId(NSDictionary *sender) {
	NSDictionary *s = TGStoryDict(sender);
	if (!s)
		return 0;
	if ([s[@"@type"] isEqualToString:@"messageSenderChat"])
		return [TGStoryNumber(s[@"chat_id"]) longLongValue];
	return [TGStoryNumber(s[@"user_id"]) longLongValue];
}

NSDictionary *TGStoryPrivacyRules(NSString *privacy, NSArray *userIds) {
	NSArray *ids = TGStoryIdList(userIds);
	if ([privacy isEqualToString:@"closeFriends"])
		return @{@"@type" : @"storyPrivacySettingsCloseFriends"};
	if ([privacy isEqualToString:@"selected"])
		return @{@"@type" : @"storyPrivacySettingsSelectedUsers", @"user_ids" : ids};
	if ([privacy isEqualToString:@"contacts"])
		return @{@"@type" : @"storyPrivacySettingsContacts", @"except_user_ids" : ids};
	return @{@"@type" : @"storyPrivacySettingsEveryone", @"except_user_ids" : ids};
}

NSString *TGStoryPrivacyName(NSDictionary *settings) {
	NSString *t = TGStoryDict(settings)[@"@type"];
	if ([t isEqualToString:@"storyPrivacySettingsCloseFriends"])
		return @"closeFriends";
	if ([t isEqualToString:@"storyPrivacySettingsSelectedUsers"])
		return @"selected";
	if ([t isEqualToString:@"storyPrivacySettingsContacts"])
		return @"contacts";
	if ([t isEqualToString:@"storyPrivacySettingsEveryone"])
		return @"everyone";
	return @"";
}

NSString *TGStoryLimitReason(NSString *type) {
	if ([type isEqualToString:@"canPostStoryResultPremiumNeeded"])
		return TGL(@"Story.PostError.PremiumNeeded", @"Posting more stories requires Telegram Premium.");
	if ([type isEqualToString:@"canPostStoryResultBoostNeeded"])
		return TGL(@"Story.PostError.BoostNeeded", @"This channel needs more boosts before it can post stories.");
	if ([type isEqualToString:@"canPostStoryResultActiveStoryLimitExceeded"])
		return TGL(@"Story.PostError.ActiveLimitExceeded", @"Too many active stories. Delete one first.");
	if ([type isEqualToString:@"canPostStoryResultWeeklyLimitExceeded"])
		return TGL(@"Story.PostError.WeeklyLimitReached", @"The weekly story limit has been reached.");
	if ([type isEqualToString:@"canPostStoryResultMonthlyLimitExceeded"])
		return TGL(@"Story.PostError.MonthlyLimitReached", @"The monthly story limit has been reached.");
	if ([type isEqualToString:@"canPostStoryResultLiveStoryIsActive"])
		return TGL(@"Story.PostError.LiveStoryActive", @"A live story is still running.");
	return TGL(@"Story.PostError.CannotPostNow", @"Stories cannot be posted right now.");
}

static NSString *TGStoryFloodWaitDurationText(NSInteger seconds) {
	if (seconds > 3600)
		return [NSString stringWithFormat:@"%ld hours", (long)(seconds / 3600)];
	if (seconds > 60)
		return [NSString stringWithFormat:@"%ld minutes", (long)(seconds / 60)];
	return [NSString stringWithFormat:@"%ld seconds", (long)seconds];
}

NSString *TGStoryErrorText(NSDictionary *error) {
	NSDictionary *e = TGStoryDict(error);
	NSString *message = TGStoryString(e[@"message"]);
	if (!message.length)
		return TGL(@"Stories.TheStoryCouldNotBePosted", @"The story could not be posted.");

	if ([message hasPrefix:@"FLOOD_WAIT_"]) {
		NSInteger seconds = [[message substringFromIndex:11] integerValue];
		return [NSString stringWithFormat:TGL(@"Story.PostError.TooManyAttemptsFormat", @"Too many attempts. Try again in %@."),
			TGStoryFloodWaitDurationText(seconds)];
	}
	if ([message hasPrefix:@"STORY_SEND_FLOOD_WEEKLY_"])
		return TGL(@"Story.PostError.WeeklyLimitReached", @"The weekly story limit has been reached.");
	if ([message hasPrefix:@"STORY_SEND_FLOOD_MONTHLY_"])
		return TGL(@"Story.PostError.MonthlyLimitReached", @"The monthly story limit has been reached.");
	if ([message isEqualToString:@"STORIES_TOO_MUCH"])
		return TGL(@"Story.PostError.ActiveLimitExceeded", @"Too many active stories. Delete one first.");
	if ([message isEqualToString:@"PREMIUM_ACCOUNT_REQUIRED"])
		return TGL(@"Story.PostError.PremiumAccountRequired", @"This needs Telegram Premium.");
	if ([message isEqualToString:@"STORY_PERIOD_INVALID"])
		return TGL(@"Story.PostError.PeriodInvalid", @"That expiry needs Telegram Premium. Post for 24 hours instead.");
	if ([message isEqualToString:@"BOOSTS_REQUIRED"])
		return TGL(@"Story.PostError.BoostNeeded", @"This channel needs more boosts before it can post stories.");
	if ([message isEqualToString:@"CHAT_ADMIN_REQUIRED"] ||
		[message isEqualToString:@"CHAT_WRITE_FORBIDDEN"])
		return TGL(@"Story.PostError.NotAllowed", @"You are not allowed to post stories here.");
	if ([message isEqualToString:@"MEDIA_EMPTY"] ||
		[message isEqualToString:@"PHOTO_INVALID_DIMENSIONS"] ||
		[message isEqualToString:@"PHOTO_EXT_INVALID"])
		return TGL(@"Story.PostError.PhotoRejected", @"Telegram rejected that picture.");
	if ([message isEqualToString:@"VIDEO_FILE_INVALID"] ||
		[message hasPrefix:@"VIDEO_"])
		return TGL(@"Story.PostError.VideoRejected", @"Telegram rejected that video. Stories need a short MP4.");
	if ([message isEqualToString:@"Request timeout"] ||
		[message isEqualToString:@"Request aborted"])
		return TGL(@"Story.PostError.ConnectionDropped", @"The connection dropped before the story went out.");
	return message;
}

NSString *TGStoryReactionEmoji(NSDictionary *type) {
	NSDictionary *t = TGStoryDict(type);
	if (!t)
		return @"";
	return TGStoryString(t[@"emoji"]);
}

NSNumber *TGStoryLargestPhotoId(NSDictionary *photo) {
	NSArray *sizes = TGStoryArray(TGStoryDict(photo)[@"sizes"]);
	if (!sizes.count)
		return nil;
	NSDictionary *biggest = TGStoryDict([sizes lastObject]);
	return TGStoryNumber(TGStoryDict(biggest[@"photo"])[@"id"]);
}

NSDictionary *TGStoryAreaFlattened(NSDictionary *raw) {
	NSDictionary *area = TGStoryDict(raw);
	if (!area)
		return nil;
	NSDictionary *position = TGStoryDict(area[@"position"]);
	NSDictionary *type = TGStoryDict(area[@"type"]);
	NSString *rawType = TGStoryString(type[@"@type"]);

	NSString *kind = @"unsupported";
	NSString *url = @"";
	NSString *emoji = @"";
	NSString *title = @"";
	NSNumber *latitude = nil;
	NSNumber *longitude = nil;
	NSNumber *chatId = nil;
	NSNumber *messageId = nil;
	NSString *venueProvider = @"";
	NSString *venueId = @"";

	if ([rawType isEqualToString:@"storyAreaTypeLocation"]) {
		kind = @"location";
		NSDictionary *location = TGStoryDict(type[@"location"]);
		latitude = TGStoryNumber(location[@"latitude"]);
		longitude = TGStoryNumber(location[@"longitude"]);
		title = TGStoryString(TGStoryDict(type[@"address"])[@"city"]);
	} else if ([rawType isEqualToString:@"storyAreaTypeVenue"]) {
		kind = @"venue";
		NSDictionary *venue = TGStoryDict(type[@"venue"]);
		NSDictionary *location = TGStoryDict(venue[@"location"]);
		latitude = TGStoryNumber(location[@"latitude"]);
		longitude = TGStoryNumber(location[@"longitude"]);
		title = TGStoryString(venue[@"title"]);
		venueProvider = TGStoryString(venue[@"provider"]) ?: @"";
		venueId = TGStoryString(venue[@"id"]) ?: @"";
	} else if ([rawType isEqualToString:@"storyAreaTypeSuggestedReaction"]) {
		kind = @"reaction";
		emoji = TGStoryReactionEmoji(type[@"reaction_type"]);
	} else if ([rawType isEqualToString:@"storyAreaTypeMessage"]) {
		kind = @"message";
		chatId = TGStoryNumber(type[@"chat_id"]);
		messageId = TGStoryNumber(type[@"message_id"]);
	} else if ([rawType isEqualToString:@"storyAreaTypeLink"]) {
		kind = @"link";
		url = TGStoryString(type[@"url"]);
	} else if ([rawType isEqualToString:@"storyAreaTypeWeather"]) {
		kind = @"weather";
		emoji = TGStoryString(type[@"emoji"]);
		title = [NSString stringWithFormat:@"%.0f°",
			[TGStoryNumber(type[@"temperature"]) doubleValue]];
	} else if ([rawType isEqualToString:@"storyAreaTypeUpgradedGift"]) {
		kind = @"gift";
		title = TGStoryString(type[@"gift_name"]);
	}

	return @{
		@"kind" : kind,
		@"x" : TGStoryNumber(position[@"x_percentage"]) ?: @(0),
		@"y" : TGStoryNumber(position[@"y_percentage"]) ?: @(0),
		@"width" : TGStoryNumber(position[@"width_percentage"]) ?: @(0),
		@"height" : TGStoryNumber(position[@"height_percentage"]) ?: @(0),
		@"rotation" : TGStoryNumber(position[@"rotation_angle"]) ?: @(0),
		@"cornerRadius" : TGStoryNumber(position[@"corner_radius_percentage"]) ?: @(0),
		@"url" : url,
		@"emoji" : emoji,
		@"title" : title,
		@"latitude" : latitude ?: @(0),
		@"longitude" : longitude ?: @(0),
		@"chatId" : chatId ?: @(0),
		@"messageId" : messageId ?: @(0),
		@"venueProvider" : venueProvider,
		@"venueId" : venueId,
	};
}

NSDictionary *TGStoryFlattened(NSDictionary *raw) {
	NSDictionary *story = TGStoryDict(raw);
	if (!story || !TGStoryNumber(story[@"id"]))
		return nil;

	NSDictionary *content = TGStoryDict(story[@"content"]);
	NSString *contentType = TGStoryString(content[@"@type"]);
	NSString *kind = @"unsupported";
	NSNumber *photoId = nil;
	NSNumber *videoId = nil;
	NSNumber *duration = @(0);
	NSNumber *width = @(0);
	NSNumber *height = @(0);

	if ([contentType isEqualToString:@"storyContentPhoto"]) {
		kind = @"photo";
		photoId = TGStoryLargestPhotoId(content[@"photo"]);
	} else if ([contentType isEqualToString:@"storyContentVideo"]) {
		kind = @"video";
		NSDictionary *video = TGStoryDict(content[@"alternative_video"]) ?: TGStoryDict(content[@"video"]);
		videoId = TGStoryNumber(TGStoryDict(video[@"video"])[@"id"]);
		duration = TGStoryNumber(video[@"duration"]) ?: @(0);
		width = TGStoryNumber(video[@"width"]) ?: @(0);
		height = TGStoryNumber(video[@"height"]) ?: @(0);
		NSDictionary *thumbnail = TGStoryDict(video[@"thumbnail"]);
		photoId = TGStoryNumber(TGStoryDict(thumbnail[@"file"])[@"id"]);
	} else if ([contentType isEqualToString:@"storyContentLive"]) {
		kind = @"live";
	}

	NSDictionary *info = TGStoryDict(story[@"interaction_info"]);
	NSDictionary *repost = TGStoryDict(story[@"repost_info"]);
	NSDictionary *origin = TGStoryDict(repost[@"origin"]);
	NSString *repostFrom = @"";
	if ([origin[@"@type"] isEqualToString:@"storyOriginHiddenUser"])
		repostFrom = TGStoryString(origin[@"poster_name"]);

	NSMutableArray *areas = [NSMutableArray array];
	for (NSDictionary *area in TGStoryArray(story[@"areas"])) {
		NSDictionary *flat = TGStoryAreaFlattened(area);
		if (flat)
			[areas addObject:flat];
	}

	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	out[@"id"] = TGStoryNumber(story[@"id"]) ?: @(0);
	out[@"chatId"] = TGStoryNumber(story[@"poster_chat_id"]) ?: @(0);
	out[@"senderId"] = @(TGStorySenderId(story[@"poster_id"]));
	out[@"date"] = TGStoryNumber(story[@"date"]) ?: @(0);
	out[@"caption"] = TGStoryString(TGStoryDict(story[@"caption"])[@"text"]);
	out[@"kind"] = kind;
	if (photoId)
		out[@"photoId"] = photoId;
	if (videoId)
		out[@"videoId"] = videoId;
	out[@"duration"] = duration;
	out[@"width"] = width;
	out[@"height"] = height;
	out[@"views"] = TGStoryNumber(info[@"view_count"]) ?: @(0);
	out[@"forwards"] = TGStoryNumber(info[@"forward_count"]) ?: @(0);
	out[@"reactions"] = TGStoryNumber(info[@"reaction_count"]) ?: @(0);
	out[@"myReaction"] = TGStoryReactionEmoji(story[@"chosen_reaction_type"]);
	out[@"privacy"] = TGStoryPrivacyName(story[@"privacy_settings"]);
	out[@"privacyUserIds"] = TGStoryIdList(TGStoryDict(story[@"privacy_settings"])[@"user_ids"]);
	out[@"privacyExceptUserIds"] = TGStoryIdList(TGStoryDict(story[@"privacy_settings"])[@"except_user_ids"]);
	out[@"isEdited"] = @([story[@"is_edited"] boolValue]);
	out[@"isBeingPosted"] = @([story[@"is_being_posted"] boolValue]);
	out[@"isBeingEdited"] = @([story[@"is_being_edited"] boolValue]);
	out[@"onProfile"] = @([story[@"is_posted_to_chat_page"] boolValue]);
	out[@"canAddToAlbum"] = @([story[@"can_be_added_to_album"] boolValue]);
	out[@"canDelete"] = @([story[@"can_be_deleted"] boolValue]);
	out[@"canEdit"] = @([story[@"can_be_edited"] boolValue]);
	out[@"canForward"] = @([story[@"can_be_forwarded"] boolValue]);
	out[@"canReply"] = @([story[@"can_be_replied"] boolValue]);
	out[@"canSetPrivacy"] = @([story[@"can_set_privacy_settings"] boolValue]);
	out[@"canToggleProfile"] = @([story[@"can_toggle_is_posted_to_chat_page"] boolValue]);
	out[@"canGetViewers"] = @([story[@"can_get_interactions"] boolValue]);
	out[@"canGetStatistics"] = @([story[@"can_get_statistics"] boolValue]);
	out[@"expiredViewers"] = @([story[@"has_expired_viewers"] boolValue]);
	out[@"repostFrom"] = repostFrom;
	out[@"albumIds"] = TGStoryIdList(story[@"album_ids"]);
	out[@"areas"] = areas;
	return out;
}

NSArray *TGStoriesFlattened(NSArray *list) {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *one in TGStoryArray(list)) {
		@autoreleasepool {
			NSDictionary *flat = TGStoryFlattened(one);
			if (flat)
				[out addObject:flat];
		}
	}
	return out;
}

NSDictionary *TGStoryAlbumFlattened(NSDictionary *raw) {
	NSDictionary *album = TGStoryDict(raw);
	if (!album || !TGStoryNumber(album[@"id"]))
		return nil;
	return @{
		@"id" : TGStoryNumber(album[@"id"]),
		@"name" : TGStoryString(album[@"name"]),
	};
}

NSString *TGStoryNetworkType(NSString *type) {
	NSString *lower = [(type ?: @"") lowercaseString];
	if ([lower isEqualToString:@"wifi"])
		return @"networkTypeWiFi";
	if ([lower isEqualToString:@"roaming"] || [lower isEqualToString:@"mobileroaming"])
		return @"networkTypeMobileRoaming";
	if ([lower isEqualToString:@"other"])
		return @"networkTypeOther";
	if ([lower isEqualToString:@"none"])
		return @"networkTypeNone";
	return @"networkTypeMobile";
}

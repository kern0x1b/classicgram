#import "TGFlattenMessageContent.h"
#import "TGBase64.h"

static NSDictionary *TGFMCDict(id value) {
	return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static NSArray *TGFMCArray(id value) {
	return [value isKindOfClass:[NSArray class]] ? value : nil;
}

static NSString *TGFMCString(id value) {
	return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSNumber *TGFMCNumber(id value) {
	return [value isKindOfClass:[NSNumber class]] ? value : @0;
}

static NSNumber *TGFMCFileId(id file) {
	NSDictionary *dict = TGFMCDict(file);
	return dict ? TGFMCNumber(dict[@"id"]) : @0;
}

static NSNumber *TGFMCThumbId(id owner) {
	NSDictionary *dict = TGFMCDict(owner);
	NSDictionary *thumbnail = TGFMCDict(dict[@"thumbnail"]);
	return TGFMCFileId(thumbnail[@"file"]);
}

const NSInteger kSelfDestructViewOnce = -1;

NSDictionary *TGMCSelfDestruct(NSInteger seconds) {
	if (seconds == kSelfDestructViewOnce)
		return @{@"@type" : @"messageSelfDestructTypeImmediately"};
	if (seconds <= 0)
		return nil;
	return @{@"@type" : @"messageSelfDestructTypeTimer",
		@"self_destruct_time" : @(seconds)};
}

NSString *TGMCEntityKind(NSString *typeName) {
	if ([typeName hasPrefix:@"textEntityType"])
		return [typeName substringFromIndex:14];
	return typeName ?: @"";
}

NSArray *TGMCFlattenEntities(id rawEntities) {
	NSArray *entities = TGFMCArray(rawEntities);
	NSMutableArray *out = [NSMutableArray array];
	for (id item in entities) {
		NSDictionary *entity = TGFMCDict(item);
		NSDictionary *type = TGFMCDict(entity[@"type"]);
		if (!entity || !type)
			continue;
		[out addObject:@{
			@"offset" : TGFMCNumber(entity[@"offset"]),
			@"length" : TGFMCNumber(entity[@"length"]),
			@"kind" : TGMCEntityKind(TGFMCString(type[@"@type"])),
			@"url" : TGFMCString(type[@"url"]),
			@"userId" : TGFMCNumber(type[@"user_id"]),
			@"language" : TGFMCString(type[@"language"]),
			@"timestamp" : TGFMCNumber(type[@"media_timestamp"]),
			@"unixTime" : TGFMCNumber(type[@"unix_time"]),
			@"customEmojiId" : @([type[@"custom_emoji_id"] longLongValue]),
		}];
	}
	return out;
}

NSData *TGMCBase64(id value) {
	return TGBase64Decode(value);
}

NSDictionary *TGMCMediaInfo(NSDictionary *message) {
	NSDictionary *content = TGFMCDict(message[@"content"]);
	NSString *kind = TGFMCString(content[@"@type"]);
	if (!content.count)
		return nil;

	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	info[@"kind"] = kind;
	info[@"fileId"] = @0;
	info[@"thumbId"] = @0;
	info[@"fileName"] = @"";
	info[@"mimeType"] = @"";
	info[@"size"] = @0;
	info[@"width"] = @0;
	info[@"height"] = @0;
	info[@"duration"] = @0;
	info[@"title"] = @"";
	info[@"performer"] = @"";
	info[@"waveform"] = [NSData data];
	info[@"minithumb"] = [NSData data];
	info[@"hasSpoiler"] = @([content[@"has_spoiler"] boolValue]);
	info[@"isSecret"] = @([content[@"is_secret"] boolValue]);
	info[@"isViewed"] = @([content[@"is_viewed"] boolValue] ||
		[content[@"is_listened"] boolValue]);
	info[@"caption"] = TGFMCString(TGFMCDict(content[@"caption"])[@"text"]);

	NSDictionary *media = nil;
	NSDictionary *mainFile = nil;

	if ([kind isEqualToString:@"messagePhoto"]) {
		NSArray *sizes = TGFMCArray(TGFMCDict(content[@"photo"])[@"sizes"]);
		NSDictionary *largest = TGFMCDict([sizes lastObject]);
		mainFile = TGFMCDict(largest[@"photo"]);
		info[@"width"] = TGFMCNumber(largest[@"width"]);
		info[@"height"] = TGFMCNumber(largest[@"height"]);
		NSDictionary *smallest = TGFMCDict([sizes firstObject]);
		info[@"thumbId"] = TGFMCFileId(smallest[@"photo"]);
		media = TGFMCDict(content[@"photo"]);

	} else if ([kind isEqualToString:@"messageVideo"]) {
		media = TGFMCDict(content[@"video"]);
		mainFile = TGFMCDict(media[@"video"]);

	} else if ([kind isEqualToString:@"messageAnimation"]) {
		media = TGFMCDict(content[@"animation"]);
		mainFile = TGFMCDict(media[@"animation"]);

	} else if ([kind isEqualToString:@"messageDocument"]) {
		media = TGFMCDict(content[@"document"]);
		mainFile = TGFMCDict(media[@"document"]);

	} else if ([kind isEqualToString:@"messageAudio"]) {
		media = TGFMCDict(content[@"audio"]);
		mainFile = TGFMCDict(media[@"audio"]);
		info[@"title"] = TGFMCString(media[@"title"]);
		info[@"performer"] = TGFMCString(media[@"performer"]);
		NSDictionary *cover = TGFMCDict(media[@"album_cover_thumbnail"]);
		info[@"thumbId"] = TGFMCFileId(cover[@"file"]);

	} else if ([kind isEqualToString:@"messageVoiceNote"]) {
		media = TGFMCDict(content[@"voice_note"]);
		mainFile = TGFMCDict(media[@"voice"]);
		info[@"waveform"] = TGMCBase64(media[@"waveform"]);

	} else if ([kind isEqualToString:@"messageVideoNote"]) {
		media = TGFMCDict(content[@"video_note"]);
		mainFile = TGFMCDict(media[@"video"]);
		info[@"width"] = TGFMCNumber(media[@"length"]);
		info[@"height"] = TGFMCNumber(media[@"length"]);

	} else if ([kind isEqualToString:@"messageSticker"] ||
		[kind isEqualToString:@"messageAnimatedEmoji"]) {
		BOOL isAnimatedEmoji = [kind isEqualToString:@"messageAnimatedEmoji"];
		media = isAnimatedEmoji
			? TGFMCDict(TGFMCDict(content[@"animated_emoji"])[@"sticker"])
			: TGFMCDict(content[@"sticker"]);
		mainFile = TGFMCDict(media[@"sticker"]);
		info[@"title"] = isAnimatedEmoji
			? TGFMCString(content[@"emoji"])
			: TGFMCString(media[@"emoji"]);

	} else {
		return nil;
	}

	if (media) {
		if ([TGFMCNumber(info[@"width"]) integerValue] == 0)
			info[@"width"] = TGFMCNumber(media[@"width"]);
		if ([TGFMCNumber(info[@"height"]) integerValue] == 0)
			info[@"height"] = TGFMCNumber(media[@"height"]);
		info[@"duration"] = TGFMCNumber(media[@"duration"]);
		info[@"fileName"] = TGFMCString(media[@"file_name"]);
		info[@"mimeType"] = TGFMCString(media[@"mime_type"]);
		if ([TGFMCNumber(info[@"thumbId"]) longLongValue] == 0)
			info[@"thumbId"] = TGFMCThumbId(media);
		NSDictionary *mini = TGFMCDict(media[@"minithumbnail"]);
		if (mini)
			info[@"minithumb"] = TGMCBase64(mini[@"data"]);
	}

	if (mainFile) {
		info[@"fileId"] = TGFMCNumber(mainFile[@"id"]);
		info[@"size"] = TGFMCNumber(mainFile[@"size"]);
	}

	return info;
}

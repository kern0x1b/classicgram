#import "TGFlattenStorage.h"

static NSDictionary *TGFSDict(id value) {
	if (![value isKindOfClass:[NSDictionary class]])
		return nil;
	return value;
}

static NSArray *TGFSArray(id value) {
	if (![value isKindOfClass:[NSArray class]])
		return [NSArray array];
	return value;
}

NSString *TGStorageNetworkTypeName(NSString *type) {
	NSString *lower = [(type ?: @"") lowercaseString];
	if ([lower isEqualToString:@"wifi"])
		return @"networkTypeWiFi";
	if ([lower isEqualToString:@"mobile"] || [lower isEqualToString:@"cellular"])
		return @"networkTypeMobile";
	if ([lower isEqualToString:@"roaming"])
		return @"networkTypeMobileRoaming";
	if ([lower isEqualToString:@"none"])
		return @"networkTypeNone";
	return @"networkTypeOther";
}

NSString *TGStorageNetworkShortName(NSString *tdName) {
	if ([tdName isEqualToString:@"networkTypeWiFi"])
		return @"wifi";
	if ([tdName isEqualToString:@"networkTypeMobile"])
		return @"mobile";
	if ([tdName isEqualToString:@"networkTypeMobileRoaming"])
		return @"roaming";
	if ([tdName isEqualToString:@"networkTypeNone"])
		return @"none";
	return @"other";
}

long long TGStorageFreedBytes(NSDictionary *stats) {
	long long freed = 0;
	for (id chatEntry in TGFSArray(stats[@"by_chat"])) {
		NSDictionary *byChat = TGFSDict(chatEntry);
		if (!byChat)
			continue;
		for (id typeEntry in TGFSArray(byChat[@"by_file_type"])) {
			NSDictionary *byType = TGFSDict(typeEntry);
			if (byType)
				freed += [byType[@"size"] longLongValue];
		}
	}
	return freed;
}

NSDictionary *TGStorageSizesByFileType(NSDictionary *stats) {
	NSMutableDictionary *sizes = [NSMutableDictionary dictionary];
	for (id chatEntry in TGFSArray(stats[@"by_chat"])) {
		NSDictionary *byChat = TGFSDict(chatEntry);
		if (!byChat)
			continue;
		for (id typeEntry in TGFSArray(byChat[@"by_file_type"])) {
			NSDictionary *byType = TGFSDict(typeEntry);
			NSDictionary *kind = TGFSDict(byType[@"file_type"]);
			NSString *name = kind[@"@type"];
			if (![name isKindOfClass:[NSString class]])
				continue;
			NSDictionary *have = sizes[name];
			long long size = [have[@"size"] longLongValue] +
				[byType[@"size"] longLongValue];
			NSInteger count = [have[@"count"] integerValue] +
				[byType[@"count"] integerValue];
			sizes[name] = @{@"size" : @(size),
				@"count" : @(count)};
		}
	}
	return sizes;
}

NSArray *TGStorageChatIdsMissingTitles(NSArray *rows) {
	NSMutableArray *ids = [NSMutableArray array];
	for (id entry in TGFSArray(rows)) {
		NSDictionary *row = TGFSDict(entry);
		if (!row)
			continue;
		NSString *title = [row[@"title"] isKindOfClass:[NSString class]] ? row[@"title"] : nil;
		long long chatId = [row[@"chatId"] longLongValue];
		if (title.length || chatId == 0)
			continue;
		NSNumber *key = @(chatId);
		if (![ids containsObject:key])
			[ids addObject:key];
	}
	return ids;
}

NSArray *TGStorageChatRowsWithTitles(NSArray *rows, NSDictionary *titles) {
	NSDictionary *known = TGFSDict(titles) ?: [NSDictionary dictionary];
	NSMutableArray *out = [NSMutableArray array];
	for (id entry in TGFSArray(rows)) {
		NSDictionary *row = TGFSDict(entry);
		if (!row)
			continue;
		NSString *title = [row[@"title"] isKindOfClass:[NSString class]] ? row[@"title"] : nil;
		if (title.length) {
			[out addObject:row];
			continue;
		}
		NSString *resolved = known[@(([row[@"chatId"] longLongValue]))];
		if (![resolved isKindOfClass:[NSString class]] || !resolved.length) {
			[out addObject:row];
			continue;
		}
		NSMutableDictionary *filled = [row mutableCopy];
		filled[@"title"] = resolved;
		[out addObject:filled];
	}
	return out;
}

NSDictionary *TGStorageNormalizedAutoDownload(NSDictionary *values) {
	NSDictionary *source = TGFSDict(values) ?: [NSDictionary dictionary];
	return @{
		@"enabled" : source[@"enabled"] ?: @NO,
		@"maxPhotoSize" : source[@"maxPhotoSize"] ?: @(1024 * 1024),
		@"maxVideoSize" : source[@"maxVideoSize"] ?: @0,
		@"maxOtherSize" : source[@"maxOtherSize"] ?: @0,
		@"videoUploadBitrate" : source[@"videoUploadBitrate"] ?: @0,
		@"preloadLargeVideos" : source[@"preloadLargeVideos"] ?: @NO,
		@"preloadNextAudio" : source[@"preloadNextAudio"] ?: @NO,
		@"preloadStories" : source[@"preloadStories"] ?: @NO,
		@"useLessDataForCalls" : source[@"useLessDataForCalls"] ?: @YES,
	};
}

NSDictionary *TGStorageAutoDownloadFromPreset(NSDictionary *preset) {
	NSDictionary *source = TGFSDict(preset) ?: [NSDictionary dictionary];
	return @{
		@"enabled" : source[@"is_auto_download_enabled"] ?: @NO,
		@"maxPhotoSize" : source[@"max_photo_file_size"] ?: @0,
		@"maxVideoSize" : source[@"max_video_file_size"] ?: @0,
		@"maxOtherSize" : source[@"max_other_file_size"] ?: @0,
		@"videoUploadBitrate" : source[@"video_upload_bitrate"] ?: @0,
		@"preloadLargeVideos" : source[@"preload_large_videos"] ?: @NO,
		@"preloadNextAudio" : source[@"preload_next_audio"] ?: @NO,
		@"preloadStories" : source[@"preload_stories"] ?: @NO,
		@"useLessDataForCalls" : source[@"use_less_data_for_calls"] ?: @YES,
	};
}

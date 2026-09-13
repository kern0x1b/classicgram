#import "TGFlattenNetwork.h"

static NSString *TGFNString(id value) {
	if (![value isKindOfClass:[NSString class]])
		return @"";
	return value;
}

static NSNumber *TGFNNumber(id value) {
	if (![value isKindOfClass:[NSNumber class]])
		return @0;
	return value;
}

static NSNumber *TGFNBool(id value) {
	if (![value isKindOfClass:[NSNumber class]])
		return @NO;
	return [value boolValue] ? @YES : @NO;
}

static NSDictionary *TGFNDict(id value) {
	if (![value isKindOfClass:[NSDictionary class]])
		return nil;
	return value;
}

NSString *TGNetNetworkTypeName(NSString *kind) {
	NSString *name = [TGFNString(kind) lowercaseString];
	if ([name isEqualToString:@"none"])
		return @"networkTypeNone";
	if ([name isEqualToString:@"mobile"])
		return @"networkTypeMobile";
	if ([name isEqualToString:@"mobileroaming"] || [name isEqualToString:@"roaming"])
		return @"networkTypeMobileRoaming";
	if ([name isEqualToString:@"wifi"])
		return @"networkTypeWiFi";
	return @"networkTypeOther";
}

NSDictionary *TGNetProxyTypeObject(NSDictionary *proxy) {
	NSString *kind = [TGFNString(proxy[@"type"]) lowercaseString];
	if ([kind isEqualToString:@"mtproto"]) {
		return @{@"@type" : @"proxyTypeMtproto",
			@"secret" : TGFNString(proxy[@"secret"])};
	}
	if ([kind isEqualToString:@"http"]) {
		return @{@"@type" : @"proxyTypeHttp",
			@"username" : TGFNString(proxy[@"username"]),
			@"password" : TGFNString(proxy[@"password"]),
			@"http_only" : TGFNBool(proxy[@"httpOnly"])};
	}
	return @{@"@type" : @"proxyTypeSocks5",
		@"username" : TGFNString(proxy[@"username"]),
		@"password" : TGFNString(proxy[@"password"])};
}

NSDictionary *TGNetProxyDict(NSDictionary *proxy, NSDictionary *added) {
	NSDictionary *inner = TGFNDict(proxy);
	if (!inner)
		return nil;
	NSDictionary *type = TGFNDict(inner[@"type"]);
	NSString *typeName = TGFNString(type[@"@type"]);
	NSString *kind = @"socks5";
	if ([typeName isEqualToString:@"proxyTypeHttp"])
		kind = @"http";
	else if ([typeName isEqualToString:@"proxyTypeMtproto"])
		kind = @"mtproto";

	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	[out setObject:TGFNString(inner[@"server"]) forKey:@"server"];
	[out setObject:TGFNNumber(inner[@"port"]) forKey:@"port"];
	[out setObject:kind forKey:@"type"];
	[out setObject:TGFNString(type[@"username"]) forKey:@"username"];
	[out setObject:TGFNString(type[@"password"]) forKey:@"password"];
	[out setObject:TGFNString(type[@"secret"]) forKey:@"secret"];
	[out setObject:TGFNBool(type[@"http_only"]) forKey:@"httpOnly"];
	if (added) {
		[out setObject:TGFNNumber(added[@"id"]) forKey:@"id"];
		[out setObject:TGFNBool(added[@"is_enabled"]) forKey:@"isEnabled"];
		[out setObject:TGFNString(added[@"comment"]) forKey:@"comment"];
		[out setObject:TGFNNumber(added[@"last_used_date"]) forKey:@"lastUsedDate"];
	}
	return out;
}

NSDictionary *TGNetAddedProxyDict(NSDictionary *added) {
	NSDictionary *safe = TGFNDict(added);
	if (!safe)
		return nil;
	return TGNetProxyDict(TGFNDict(safe[@"proxy"]), safe);
}

NSDictionary *TGNetSettingsDict(NSDictionary *settings) {
	NSDictionary *safe = TGFNDict(settings);
	if (!safe)
		return nil;
	return @{
		@"enabled" : TGFNBool(safe[@"is_auto_download_enabled"]),
		@"maxPhotoSize" : TGFNNumber(safe[@"max_photo_file_size"]),
		@"maxVideoSize" : TGFNNumber(safe[@"max_video_file_size"]),
		@"maxOtherSize" : TGFNNumber(safe[@"max_other_file_size"]),
		@"videoUploadBitrate" : TGFNNumber(safe[@"video_upload_bitrate"]),
		@"preloadLargeVideos" : TGFNBool(safe[@"preload_large_videos"]),
		@"preloadNextAudio" : TGFNBool(safe[@"preload_next_audio"]),
		@"preloadStories" : TGFNBool(safe[@"preload_stories"]),
		@"useLessDataForCalls" : TGFNBool(safe[@"use_less_data_for_calls"]),
	};
}

NSDictionary *TGNetSettingsObject(NSDictionary *settings) {
	NSDictionary *safe = TGFNDict(settings);
	if (!safe)
		safe = [NSDictionary dictionary];
	return @{
		@"@type" : @"autoDownloadSettings",
		@"is_auto_download_enabled" : TGFNBool(safe[@"enabled"]),
		@"max_photo_file_size" : TGFNNumber(safe[@"maxPhotoSize"]),
		@"max_video_file_size" : TGFNNumber(safe[@"maxVideoSize"]),
		@"max_other_file_size" : TGFNNumber(safe[@"maxOtherSize"]),
		@"video_upload_bitrate" : TGFNNumber(safe[@"videoUploadBitrate"]),
		@"preload_large_videos" : TGFNBool(safe[@"preloadLargeVideos"]),
		@"preload_next_audio" : TGFNBool(safe[@"preloadNextAudio"]),
		@"preload_stories" : TGFNBool(safe[@"preloadStories"]),
		@"use_less_data_for_calls" : TGFNBool(safe[@"useLessDataForCalls"]),
	};
}

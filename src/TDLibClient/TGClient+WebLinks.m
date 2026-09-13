#import "TGClient+Private.h"
#import "TGStringTruncation.h"
#import "TGClient+WebLinks.h"
#import "TGFlattenWebLinks.h"

static NSString *TGWLString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSNumber *TGWLNumber(id value) {
	return [value isKindOfClass:NSNumber.class] ? value : @(0);
}

static NSNumber *TGWLBool(id value) {
	return @([TGWLNumber(value) boolValue]);
}

static NSDictionary *TGWLDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSArray *TGWLArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : nil;
}

static NSString *TGWLKind(id typeName, NSString *prefix) {
	NSString *name = TGWLString(typeName);
	if (prefix.length && name.length > prefix.length &&
		[name hasPrefix:prefix])
		name = [name substringFromIndex:prefix.length];
	if (name.length == 0)
		return @"unsupported";
	return TGStringWithFirstCharacterLowercased(name);
}

static void TGWLSetString(NSMutableDictionary *out, NSString *key, id raw) {
	if ([raw isKindOfClass:NSString.class] && [raw length])
		out[key] = raw;
}

static NSNumber *TGWLFileId(id file) {
	NSDictionary *f = TGWLDict(file);
	id fileId = f[@"id"];
	return [fileId isKindOfClass:NSNumber.class] ? fileId : nil;
}

static NSDictionary *TGWLBiggestSize(id photo) {
	NSArray *sizes = TGWLArray(TGWLDict(photo)[@"sizes"]);
	if (!sizes.count)
		return nil;
	NSDictionary *best = nil;
	NSInteger bestArea = -1;
	for (id raw in sizes) {
		NSDictionary *size = TGWLDict(raw);
		if (!size)
			continue;
		NSInteger area = [TGWLNumber(size[@"width"]) integerValue] *
			[TGWLNumber(size[@"height"]) integerValue];
		if (area > bestArea) {
			bestArea = area;
			best = size;
		}
	}
	return best;
}

static void TGWLAddPhoto(NSMutableDictionary *out, id photo) {
	NSDictionary *size = TGWLBiggestSize(photo);
	if (!size)
		return;
	NSNumber *fileId = TGWLFileId(size[@"photo"]);
	if (!fileId)
		return;
	out[@"photoFileId"] = fileId;
	out[@"width"] = TGWLNumber(size[@"width"]);
	out[@"height"] = TGWLNumber(size[@"height"]);
}

static void TGWLAddThumbnail(NSMutableDictionary *out, id thumbnail) {
	NSDictionary *thumb = TGWLDict(thumbnail);
	NSNumber *fileId = TGWLFileId(thumb[@"file"]);
	if (!fileId)
		return;
	out[@"photoFileId"] = fileId;
	if (!out[@"width"]) {
		out[@"width"] = TGWLNumber(thumb[@"width"]);
		out[@"height"] = TGWLNumber(thumb[@"height"]);
	}
}

#pragma mark - internal links

static BOOL TGWLKindSupported(NSString *kind) {
	static NSSet *unsupported = nil;
	if (!unsupported) {
		unsupported = [[NSSet alloc] initWithObjects:
				@"webApp", @"mainWebApp", @"attachmentMenuBot", @"passportDataRequest",
			@"premiumFeaturesPage",
			@"premiumGiftPurchase", @"starPurchase", @"restorePurchases",
			@"giftAuction", @"giftCollection",
			@"chatFolderInvite",
			@"requestManagedBot", @"textCompositionStyle", @"newStory",
			@"storyAlbum", @"liveStory", @"business", @"businessChat",
			@"chatSelection", @"unsupported", nil];
	}
	return ![unsupported containsObject:kind];
}

static NSDictionary *TGWLInternalLink(NSDictionary *result, NSString *original) {
	NSString *kind = TGWLKind(result[@"@type"], @"internalLinkType");
	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	out[@"kind"] = kind;
	out[@"supported"] = @(TGWLKindSupported(kind));
	out[@"link"] = TGWLString(original);

	TGWLSetString(out, @"username", result[@"username"]);
	TGWLSetString(out, @"username", result[@"chat_username"]);
	TGWLSetString(out, @"username", result[@"channel_username"]);
	TGWLSetString(out, @"username", result[@"story_poster_username"]);
	TGWLSetString(out, @"draftText", result[@"draft_text"]);
	TGWLSetString(out, @"phoneNumber", result[@"phone_number"]);
	TGWLSetString(out, @"token", result[@"token"]);
	TGWLSetString(out, @"inviteLink", result[@"invite_link"]);
	TGWLSetString(out, @"url", result[@"url"]);
	TGWLSetString(out, @"fallbackUrl", result[@"fallback_url"]);
	TGWLSetString(out, @"stickerSetName", result[@"sticker_set_name"]);
	TGWLSetString(out, @"botUsername", result[@"bot_username"]);
	TGWLSetString(out, @"startParameter", result[@"start_parameter"]);
	TGWLSetString(out, @"gameShortName", result[@"game_short_name"]);
	TGWLSetString(out, @"themeName", result[@"theme_name"]);
	TGWLSetString(out, @"languagePackId", result[@"language_pack_id"]);
	TGWLSetString(out, @"backgroundName", result[@"background_name"]);
	TGWLSetString(out, @"code", result[@"code"]);
	TGWLSetString(out, @"invoiceName", result[@"invoice_name"]);
	TGWLSetString(out, @"deepLink", result[@"link"]);
	TGWLSetString(out, @"webAppShortName", result[@"web_app_short_name"]);
	TGWLSetString(out, @"referrer", result[@"referrer"]);
	TGWLSetString(out, @"inviteHash", result[@"invite_hash"]);
	if ([kind isEqualToString:@"settings"])
		TGWLSetString(out, @"section",
			TGWLKind(TGWLDict(result[@"section"])[@"@type"], @"settingsSection"));
	else
		TGWLSetString(out, @"section", result[@"section"]);
	TGWLSetString(out, @"upgradedGiftName", result[@"name"]);
	if (result[@"open_profile"])
		out[@"openProfile"] = TGWLBool(result[@"open_profile"]);
	if (result[@"autostart"])
		out[@"autostart"] = TGWLBool(result[@"autostart"]);
	if (result[@"expect_custom_emoji"])
		out[@"expectCustomEmoji"] = TGWLBool(result[@"expect_custom_emoji"]);
	if (result[@"is_live_stream"])
		out[@"isLiveStream"] = TGWLBool(result[@"is_live_stream"]);
	if (result[@"story_id"])
		out[@"storyId"] = TGWLNumber(result[@"story_id"]);
	if (result[@"bot_user_id"])
		out[@"botUserId"] = TGWLNumber(result[@"bot_user_id"]);
	if ([kind isEqualToString:@"messageDraft"]) {
		NSDictionary *text = TGWLDict(result[@"text"]);
		TGWLSetString(out, @"draftText", text[@"text"]);
	}
	return out;
}

static NSDictionary *TGWLLoginUrlInfo(NSDictionary *result) {
	NSString *type = TGWLString(result[@"@type"]);
	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	out[@"url"] = TGWLString(result[@"url"]);
	if ([type isEqualToString:@"loginUrlInfoOpen"]) {
		out[@"needsConfirmation"] = @(![TGWLNumber(result[@"skip_confirmation"]) boolValue]);
		return out;
	}
	out[@"needsConfirmation"] = @YES;
	out[@"domain"] = TGWLString(result[@"domain"]);
	out[@"botUserId"] = TGWLNumber(result[@"bot_user_id"]);
	out[@"requestWriteAccess"] = TGWLBool(result[@"request_write_access"]);
	return out;
}

@implementation TGClient (WebLinks)

#pragma mark - link routing

- (void)resolveLink:(NSString *)url
		 completion:(void (^)(NSDictionary *))completion {
	NSString *link = TGWLString(url);
	if (link.length == 0) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{@"@type" : @"getInternalLinkType", @"link" : link}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			completion(TGWLInternalLink(result, link));
		}];
}

- (void)linkForInternalType:(NSDictionary *)type
					 isHttp:(BOOL)isHttp
				 completion:(void (^)(NSString *))completion {
	if (![type isKindOfClass:NSDictionary.class] || !type[@"@type"]) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{
		@"@type" : @"getInternalLink",
		@"type" : type,
		@"is_http" : @(isHttp),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSString *link = TGWLString(result[@"url"]);
		completion((TGResultIsError(result) || !link.length) ? nil : link);
	}];
}

- (void)publicLinkForUsername:(NSString *)username
				   completion:(void (^)(NSString *))completion {
	NSString *name = TGWLString(username);
	if ([name hasPrefix:@"@"])
		name = [name substringFromIndex:1];
	if (name.length == 0) {
		if (completion)
			completion(nil);
		return;
	}
	[self linkForInternalType:@{
		@"@type" : @"internalLinkTypePublicChat",
		@"chat_username" : name,
		@"draft_text" : @"",
		@"open_profile" : @NO,
	}
					   isHttp:YES
				   completion:completion];
}

- (void)publicLinkForStickerSetName:(NSString *)name
						 completion:(void (^)(NSString *))completion {
	NSString *setName = TGWLString(name);
	if (setName.length == 0) {
		if (completion)
			completion(nil);
		return;
	}
	[self linkForInternalType:@{
		@"@type" : @"internalLinkTypeStickerSet",
		@"sticker_set_name" : setName,
		@"expect_custom_emoji" : @NO,
	}
					   isHttp:YES
				   completion:completion];
}

#pragma mark - external links

- (void)externalLinkInfoForUrl:(NSString *)url
					completion:(void (^)(NSDictionary *))completion {
	NSString *link = TGWLString(url);
	if (link.length == 0) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{@"@type" : @"getExternalLinkInfo", @"link" : link}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			completion(TGWLLoginUrlInfo(result));
		}];
}

- (void)externalLinkForUrl:(NSString *)url
		  allowWriteAccess:(BOOL)allowWriteAccess
				completion:(void (^)(NSString *))completion {
	NSString *link = TGWLString(url);
	if (link.length == 0) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{
		@"@type" : @"getExternalLink",
		@"link" : link,
		@"allow_write_access" : @(allowWriteAccess),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSString *opened = TGWLString(result[@"url"]);
		completion((TGResultIsError(result) || !opened.length) ? link : opened);
	}];
}

- (void)loginUrlInfoForButton:(int64_t)buttonId
					inMessage:(int64_t)messageId
					   inChat:(int64_t)chatId
				   completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"getLoginUrlInfo",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"button_id" : @(buttonId),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		completion(TGWLLoginUrlInfo(result));
	}];
}

- (void)loginUrlForButton:(int64_t)buttonId
				inMessage:(int64_t)messageId
				   inChat:(int64_t)chatId
		 allowWriteAccess:(BOOL)allowWriteAccess
			   completion:(void (^)(NSString *))completion {
	[self request:@{
		@"@type" : @"getLoginUrl",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"button_id" : @(buttonId),
		@"allow_write_access" : @(allowWriteAccess),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSString *link = TGWLString(result[@"url"]);
		completion((TGResultIsError(result) || !link.length) ? nil : link);
	}];
}

- (void)deepLinkInfoForUrl:(NSString *)url
				completion:(void (^)(NSString *, BOOL))completion {
	NSString *link = TGWLString(url);
	if (link.length == 0) {
		if (completion)
			completion(nil, NO);
		return;
	}
	[self request:@{@"@type" : @"getDeepLinkInfo", @"link" : link}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil, NO);
				return;
			}
			NSString *text = TGWLString(TGWLDict(result[@"text"])[@"text"]);
			completion(text.length ? text : nil,
				[TGWLNumber(result[@"need_update_application"]) boolValue]);
		}];
}

#pragma mark - third-party login (oauth)

- (void)oauthLinkInfoForUrl:(NSString *)url
				 completion:(void (^)(NSDictionary *))completion {
	NSString *link = TGWLString(url);
	if (link.length == 0) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{@"@type" : @"getOauthLinkInfo", @"url" : link, @"in_app_origin" : @""}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			NSMutableArray *codes = [NSMutableArray array];
			for (id entry in TGWLArray(result[@"match_codes"])) {
				NSString *code = TGWLString(entry);
				if (code.length)
					[codes addObject:code];
			}
			completion(@{
				@"userId" : TGWLNumber(result[@"user_id"]),
				@"url" : TGWLString(result[@"url"]),
				@"domain" : TGWLString(result[@"domain"]),
				@"fromApp" : TGWLBool(result[@"from_app"]),
				@"verifiedAppName" : TGWLString(result[@"verified_app_name"]),
				@"botUserId" : TGWLNumber(result[@"bot_user_id"]),
				@"requestWriteAccess" : TGWLBool(result[@"request_write_access"]),
				@"requestPhoneNumberAccess" : TGWLBool(result[@"request_phone_number_access"]),
				@"browser" : TGWLString(result[@"browser"]),
				@"platform" : TGWLString(result[@"platform"]),
				@"location" : TGWLString(result[@"location"]),
				@"matchCodeFirst" : TGWLBool(result[@"match_code_first"]),
				@"matchCodes" : codes,
			});
		}];
}

- (void)checkOauthMatchCode:(NSString *)matchCode
					 forUrl:(NSString *)url
				 completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"checkOauthRequestMatchCode",
		@"url" : TGWLString(url),
		@"match_code" : TGWLString(matchCode),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)acceptOauthRequestForUrl:(NSString *)url
					   matchCode:(NSString *)matchCode
				allowWriteAccess:(BOOL)allowWriteAccess
		  allowPhoneNumberAccess:(BOOL)allowPhoneNumberAccess
					  completion:(void (^)(NSString *))completion {
	[self request:@{
		@"@type" : @"acceptOauthRequest",
		@"url" : TGWLString(url),
		@"match_code" : TGWLString(matchCode),
		@"allow_write_access" : @(allowWriteAccess),
		@"allow_phone_number_access" : @(allowPhoneNumberAccess),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGWLString(result[@"url"]));
	}];
}

- (void)declineOauthRequestForUrl:(NSString *)url {
	[self send:@{@"@type" : @"declineOauthRequest", @"url" : TGWLString(url)}];
}

#pragma mark - link previews

+ (NSDictionary *)linkPreviewOptionsDisabled:(BOOL)disabled
										 url:(NSString *)url
							 forceSmallMedia:(BOOL)forceSmall
							 forceLargeMedia:(BOOL)forceLarge
							   showAboveText:(BOOL)showAboveText {
	return @{
		@"@type" : @"linkPreviewOptions",
		@"is_disabled" : @(disabled),
		@"url" : TGWLString(url),
		@"force_small_media" : @(forceSmall && !forceLarge),
		@"force_large_media" : @(forceLarge),
		@"show_above_text" : @(showAboveText),
	};
}

+ (NSDictionary *)flattenedLinkPreview:(NSDictionary *)preview {
	NSDictionary *raw = TGWLDict(preview);
	if (!raw)
		return nil;

	NSDictionary *type = TGWLDict(raw[@"type"]);
	NSString *kind = TGWLKind(type[@"@type"], @"linkPreviewType");

	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	out[@"url"] = TGWLString(raw[@"url"]);
	out[@"displayUrl"] = TGWLString(raw[@"display_url"]);
	out[@"siteName"] = TGWLString(raw[@"site_name"]);
	out[@"title"] = TGWLString(raw[@"title"]);
	out[@"description"] = TGWLString(TGWLDict(raw[@"description"])[@"text"]);
	out[@"author"] = TGWLString(raw[@"author"]);
	out[@"kind"] = kind;
	out[@"hasLargeMedia"] = TGWLBool(raw[@"has_large_media"]);
	out[@"showLargeMedia"] = TGWLBool(raw[@"show_large_media"]);
	out[@"showMediaAboveDescription"] = TGWLBool(raw[@"show_media_above_description"]);
	out[@"showAboveText"] = TGWLBool(raw[@"show_above_text"]);
	out[@"skipConfirmation"] = TGWLBool(raw[@"skip_confirmation"]);
	out[@"instantViewVersion"] = TGWLNumber(raw[@"instant_view_version"]);
	out[@"hasInstantView"] = @([TGWLNumber(raw[@"instant_view_version"]) integerValue] > 0);

	NSString *mediaKind = @"none";
	if (type) {
		if (type[@"photo"])
			TGWLAddPhoto(out, type[@"photo"]);
		if (type[@"thumbnail"] && !out[@"photoFileId"])
			TGWLAddPhoto(out, type[@"thumbnail"]);
		if (type[@"cover"] && !out[@"photoFileId"])
			TGWLAddPhoto(out, type[@"cover"]);

		if ([kind isEqualToString:@"photo"] || [kind isEqualToString:@"article"] ||
			[kind isEqualToString:@"app"] || [kind isEqualToString:@"user"] ||
			[kind isEqualToString:@"chat"] || [kind isEqualToString:@"webApp"]) {
			mediaKind = out[@"photoFileId"] ? @"photo" : @"none";
		}

		NSDictionary *video = TGWLDict(type[@"video"]);
		NSDictionary *animation = TGWLDict(type[@"animation"]);
		NSDictionary *audio = TGWLDict(type[@"audio"]);
		NSDictionary *voice = TGWLDict(type[@"voice_note"]);
		NSDictionary *document = TGWLDict(type[@"document"]);
		NSDictionary *sticker = TGWLDict(type[@"sticker"]);

		if (video) {
			mediaKind = @"video";
			NSNumber *fileId = TGWLFileId(video[@"video"]);
			if (fileId)
				out[@"mediaFileId"] = fileId;
			out[@"duration"] = TGWLNumber(video[@"duration"]);
			if (!out[@"photoFileId"])
				TGWLAddThumbnail(out, video[@"thumbnail"]);
		} else if (animation) {
			mediaKind = @"animation";
			NSNumber *fileId = TGWLFileId(animation[@"animation"]);
			if (fileId)
				out[@"mediaFileId"] = fileId;
			out[@"duration"] = TGWLNumber(animation[@"duration"]);
			if (!out[@"photoFileId"])
				TGWLAddThumbnail(out, animation[@"thumbnail"]);
		} else if (voice) {
			mediaKind = @"voice";
			NSNumber *fileId = TGWLFileId(voice[@"voice"]);
			if (fileId)
				out[@"mediaFileId"] = fileId;
			out[@"duration"] = TGWLNumber(voice[@"duration"]);
		} else if (audio) {
			mediaKind = @"audio";
			NSNumber *fileId = TGWLFileId(audio[@"audio"]);
			if (fileId)
				out[@"mediaFileId"] = fileId;
			out[@"duration"] = TGWLNumber(audio[@"duration"]);
			TGWLSetString(out, @"fileName", audio[@"file_name"]);
		} else if (sticker) {
			mediaKind = @"sticker";
			NSNumber *fileId = TGWLFileId(sticker[@"sticker"]);
			if (fileId)
				out[@"mediaFileId"] = fileId;
			out[@"width"] = TGWLNumber(sticker[@"width"]);
			out[@"height"] = TGWLNumber(sticker[@"height"]);
		} else if (document) {
			mediaKind = @"document";
			NSNumber *fileId = TGWLFileId(document[@"document"]);
			if (fileId)
				out[@"mediaFileId"] = fileId;
			TGWLSetString(out, @"fileName", document[@"file_name"]);
			TGWLSetString(out, @"mimeType", document[@"mime_type"]);
		}

		if ([kind isEqualToString:@"externalVideo"] ||
			[kind isEqualToString:@"externalAudio"]) {
			mediaKind = @"external";
			TGWLSetString(out, @"externalUrl", type[@"url"]);
			TGWLSetString(out, @"mimeType", type[@"mime_type"]);
			out[@"duration"] = TGWLNumber(type[@"duration"]);
			if (type[@"width"])
				out[@"width"] = TGWLNumber(type[@"width"]);
			if (type[@"height"])
				out[@"height"] = TGWLNumber(type[@"height"]);
		} else if ([kind hasPrefix:@"embedded"]) {
			TGWLSetString(out, @"externalUrl", type[@"url"]);
		}
	}
	out[@"mediaKind"] = mediaKind;
	return out;
}

+ (NSArray *)tappableEntitiesIn:(NSDictionary *)formattedText {
	NSDictionary *formatted = TGWLDict(formattedText);
	NSString *text = TGWLString(formatted[@"text"]);
	NSArray *entities = TGWLArray(formatted[@"entities"]);
	if (!entities.count)
		return @[];

	static NSSet *tappableKinds = nil;
	if (!tappableKinds) {
		tappableKinds = [[NSSet alloc] initWithObjects:
				@"url", @"textUrl", @"emailAddress", @"phoneNumber", @"mention",
			@"mentionName", @"hashtag", @"cashtag", @"bankCardNumber",
			@"botCommand", nil];
	}

	NSMutableArray *out = [NSMutableArray array];
	for (id raw in entities) {
		NSDictionary *entity = TGWLDict(raw);
		if (!entity)
			continue;
		NSInteger offset = [TGWLNumber(entity[@"offset"]) integerValue];
		NSInteger length = [TGWLNumber(entity[@"length"]) integerValue];
		if (offset < 0 || length <= 0 ||
			(NSUInteger)(offset + length) > text.length)
			continue;
		NSDictionary *type = TGWLDict(entity[@"type"]);
		NSString *kind = TGWLKind(type[@"@type"], @"textEntityType");

		NSMutableDictionary *flat = [NSMutableDictionary dictionary];
		flat[@"offset"] = @(offset);
		flat[@"length"] = @(length);
		flat[@"kind"] = kind;
		flat[@"tappable"] = @([tappableKinds containsObject:kind]);
		flat[@"text"] = [text substringWithRange:NSMakeRange(offset, length)];
		TGWLSetString(flat, @"url", type[@"url"]);
		TGWLSetString(flat, @"language", type[@"language"]);
		if (type[@"user_id"])
			flat[@"userId"] = TGWLNumber(type[@"user_id"]);
		if (type[@"custom_emoji_id"])
			flat[@"customEmojiId"] = TGWLString(type[@"custom_emoji_id"]);
		[out addObject:flat];
	}
	[out sortUsingComparator:^NSComparisonResult(id a, id b) {
		return [((NSDictionary *)a)[@"offset"] compare:((NSDictionary *)b)[@"offset"]];
	}];
	return out;
}

- (void)linkPreviewForText:(NSString *)text
			   withOptions:(NSDictionary *)options
				completion:(void (^)(NSDictionary *))completion {
	NSString *body = TGWLString(text);
	if (body.length == 0) {
		if (completion)
			completion(nil);
		return;
	}
	NSDictionary *previewOptions = TGWLDict(options) ?: [TGClient linkPreviewOptionsDisabled:NO url:@"" forceSmallMedia:NO forceLargeMedia:NO showAboveText:NO];
	[self request:@{
		@"@type" : @"getLinkPreview",
		@"text" : @{@"@type" : @"formattedText",
			@"text" : body,
			@"entities" : @[]},
		@"link_preview_options" : previewOptions,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		completion([TGClient flattenedLinkPreview:result]);
	}];
}

#pragma mark - instant view

- (void)instantViewForUrl:(NSString *)url
				onlyLocal:(BOOL)onlyLocal
			   completion:(void (^)(NSDictionary *))completion {
	NSString *link = TGWLString(url);
	if (link.length == 0) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{
		@"@type" : @"getWebPageInstantView",
		@"url" : link,
		@"only_local" : @(onlyLocal),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSMutableDictionary *view = [NSMutableDictionary dictionary];
		view[@"blocks"] = TGWLBlocks(result[@"blocks"]);
		view[@"viewCount"] = TGWLNumber(result[@"view_count"]);
		view[@"version"] = TGWLNumber(result[@"version"]);
		view[@"isRtl"] = TGWLBool(result[@"is_rtl"]);
		view[@"isFull"] = TGWLBool(result[@"is_full"]);
		NSDictionary *feedback = TGWLDict(result[@"feedback_link"]);
		if (feedback[@"@type"]) {
			[self linkForInternalType:feedback isHttp:YES completion:^(NSString *feedbackLink) {
				TGWLSetString(view, @"feedbackLink", feedbackLink);
				completion(view);
			}];
			return;
		}
		completion(view);
	}];
}

- (void)instantViewForUrl:(NSString *)url
			   completion:(void (^)(NSDictionary *))completion {
	NSString *link = TGWLString(url);
	if (link.length == 0) {
		if (completion)
			completion(nil);
		return;
	}
	[self instantViewForUrl:link onlyLocal:YES completion:^(NSDictionary *cached) {
		NSArray *blocks = TGWLArray(cached[@"blocks"]);
		BOOL isFull = [TGWLNumber(cached[@"isFull"]) boolValue];
		if (blocks.count && isFull) {
			if (completion)
				completion(cached);
			return;
		}
		[self instantViewForUrl:link onlyLocal:NO completion:^(NSDictionary *fresh) {
			if (!completion)
				return;
			completion(fresh ? fresh : (blocks.count ? cached : nil));
		}];
	}];
}

#pragma mark - rich messages

+ (NSArray *)flattenedPageBlocks:(NSArray *)rawBlocks {
	return TGWLBlocks(rawBlocks);
}

- (void)fullRichMessageForMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
					   completion:(void (^)(NSArray *, BOOL))completion {
	[self request:@{
		@"@type" : @"getFullRichMessage",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, NO);
			return;
		}
		completion(TGWLBlocks(result[@"blocks"]), [TGWLBool(result[@"is_rtl"]) boolValue]);
	}];
}

#pragma mark - misc t.me

- (void)recentlyVisitedTMeUrlsWithReferrer:(NSString *)referrer
								completion:(void (^)(NSArray *))completion {
	[self request:@{
		@"@type" : @"getRecentlyVisitedTMeUrls",
		@"referrer" : TGWLString(referrer),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(@[]);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (id raw in (TGWLArray(result[@"urls"]) ?: @[])) {
			NSDictionary *entry = TGWLDict(raw);
			if (!entry)
				continue;
			NSDictionary *type = TGWLDict(entry[@"type"]);
			NSString *kind = TGWLKind(type[@"@type"], @"tMeUrlType");
			NSMutableDictionary *flat = [NSMutableDictionary dictionary];
			flat[@"url"] = TGWLString(entry[@"url"]);
			flat[@"kind"] = kind;
			if (type[@"user_id"])
				flat[@"userId"] = TGWLNumber(type[@"user_id"]);
			if (type[@"supergroup_id"])
				flat[@"supergroupId"] = TGWLNumber(type[@"supergroup_id"]);
			if (type[@"sticker_set_id"])
				flat[@"stickerSetId"] = TGWLString(type[@"sticker_set_id"]);
			NSDictionary *info = TGWLDict(type[@"info"]);
			if (info) {
				flat[@"title"] = TGWLString(info[@"title"]);
				flat[@"memberCount"] = TGWLNumber(info[@"member_count"]);
				if (info[@"chat_id"])
					flat[@"chatId"] = TGWLNumber(info[@"chat_id"]);
				NSNumber *photoId = TGWLFileId(TGWLDict(info[@"photo"])[@"small"]);
				if (photoId)
					flat[@"photoFileId"] = photoId;
			}
			[out addObject:flat];
		}
		completion(out);
	}];
}

- (void)applicationDownloadLinkWithCompletion:(void (^)(NSString *))completion {
	[self request:@{@"@type" : @"getApplicationDownloadLink"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			NSString *link = TGWLString(result[@"url"]);
			completion((TGResultIsError(result) || !link.length) ? nil : link);
		}];
}

@end

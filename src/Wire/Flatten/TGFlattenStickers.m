#import "TGFlattenStickers.h"

static NSArray *TGStickerArray(id value) {
	return [value isKindOfClass:[NSArray class]] ? value : nil;
}

static NSDictionary *TGStickerDict(id value) {
	return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static NSString *TGStickerString(id value) {
	return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSNumber *TGStickerNumber(id value) {
	if ([value isKindOfClass:[NSNumber class]])
		return value;
	if ([value isKindOfClass:[NSString class]])
		return [NSNumber numberWithLongLong:[value longLongValue]];
	return @0;
}

static NSNumber *TGStickerDouble(id value) {
	return [value isKindOfClass:[NSNumber class]] ? value : @0;
}

static NSString *TGStickerRemoteUniqueId(NSDictionary *file) {
	return TGStickerString(TGStickerDict(file[@"remote"])[@"unique_id"]) ?: @"";
}

NSDictionary *TGFlattenSticker(id object) {
	NSDictionary *sticker = TGStickerDict(object);
	NSDictionary *stickerFile = TGStickerDict(sticker[@"sticker"]);
	NSNumber *fileId = stickerFile[@"id"];
	if (![fileId isKindOfClass:[NSNumber class]])
		return nil;

	NSString *format = TGStickerString(TGStickerDict(sticker[@"format"])[@"@type"]) ?: @"";
	NSDictionary *fullType = TGStickerDict(sticker[@"full_type"]);
	NSNumber *customEmojiId = @0;
	if ([TGStickerString(fullType[@"@type"]) isEqualToString:@"stickerFullTypeCustomEmoji"])
		customEmojiId = TGStickerNumber(fullType[@"custom_emoji_id"]);

	NSDictionary *thumbFile = TGStickerDict(TGStickerDict(sticker[@"thumbnail"])[@"file"]);
	NSNumber *thumbId = thumbFile[@"id"];
	if (![thumbId isKindOfClass:[NSNumber class]])
		thumbId = @0;

	return @{
		@"fileId" : fileId,
		@"setId" : TGStickerNumber(sticker[@"set_id"]),
		@"emoji" : TGStickerString(sticker[@"emoji"]) ?: @"",
		@"width" : TGStickerDouble(sticker[@"width"]),
		@"height" : TGStickerDouble(sticker[@"height"]),
		@"isAnimated" : @([format isEqualToString:@"stickerFormatTgs"]),
		@"isVideo" : @([format isEqualToString:@"stickerFormatWebm"]),
		@"thumbId" : thumbId,
		@"uniqueId" : TGStickerRemoteUniqueId(stickerFile),
		@"thumbUniqueId" : TGStickerRemoteUniqueId(thumbFile),
		@"customEmojiId" : customEmojiId,
	};
}

BOOL TGIsFlattenableSticker(id object) {
	NSDictionary *sticker = TGStickerDict(object);
	return [TGStickerDict(sticker[@"sticker"])[@"id"] isKindOfClass:[NSNumber class]];
}

NSArray *TGFlattenStickerRange(id list, NSUInteger location, NSUInteger length) {
	NSMutableArray *out = [NSMutableArray arrayWithCapacity:length];
	NSInteger index = 0;
	for (id item in TGStickerArray(list)) {
		if (!TGIsFlattenableSticker(item))
			continue;
		if (index++ < location)
			continue;
		if (out.count >= length)
			break;
		@autoreleasepool {
			NSDictionary *sticker = TGFlattenSticker(item);
			if (sticker)
				[out addObject:sticker];
		}
	}
	return out;
}

NSUInteger TGCountFlattenableStickers(id list) {
	NSInteger count = 0;
	for (id item in TGStickerArray(list))
		if (TGIsFlattenableSticker(item))
			count++;
	return count;
}

NSArray *TGFlattenStickers(id list) {
	NSMutableArray *out = [NSMutableArray array];
	for (id item in TGStickerArray(list)) {
		@autoreleasepool {
			NSDictionary *sticker = TGFlattenSticker(item);
			if (sticker)
				[out addObject:sticker];
		}
	}
	return out;
}

NSDictionary *TGFlattenStickerSet(id object) {
	NSDictionary *set = TGStickerDict(object);
	if (!set[@"id"])
		return nil;

	NSDictionary *thumbFile = TGStickerDict(TGStickerDict(set[@"thumbnail"])[@"file"]);
	NSNumber *thumbId = thumbFile[@"id"];
	if (![thumbId isKindOfClass:[NSNumber class]])
		thumbId = @0;

	NSArray *stickers = TGFlattenStickers(set[@"stickers"]);
	NSArray *covers = TGFlattenStickers(set[@"covers"]);
	NSNumber *count = [set[@"size"] isKindOfClass:[NSNumber class]]
		? set[@"size"]
		: @(stickers.count);
	NSString *type = TGStickerString(TGStickerDict(set[@"sticker_type"])[@"@type"]) ?: @"";

	return @{
		@"id" : TGStickerNumber(set[@"id"]),
		@"title" : TGStickerString(set[@"title"]) ?: @"",
		@"name" : TGStickerString(set[@"name"]) ?: @"",
		@"count" : count,
		@"installed" : @([set[@"is_installed"] boolValue]),
		@"archived" : @([set[@"is_archived"] boolValue]),
		@"official" : @([set[@"is_official"] boolValue]),
		@"viewed" : @([set[@"is_viewed"] boolValue]),
		@"owned" : @([set[@"is_owned"] boolValue]),
		@"isEmoji" : @([type isEqualToString:@"stickerTypeCustomEmoji"]),
		@"isMask" : @([type isEqualToString:@"stickerTypeMask"]),
		@"thumbId" : thumbId,
		@"thumbUniqueId" : TGStickerRemoteUniqueId(thumbFile),
		@"covers" : covers.count ? covers : stickers,
		@"stickers" : stickers,
	};
}

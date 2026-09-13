#import "TGClient+Private.h"
#import "TGClient+Stickers.h"
#import "TGFlattenStickers.h"

static NSArray *TGArray(id value) {
	return [value isKindOfClass:[NSArray class]] ? value : nil;
}

static NSDictionary *TGDict(id value) {
	return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static NSString *TGString(id value) {
	return [value isKindOfClass:[NSString class]] ? value : nil;
}

static long long TGInt64(id value) {
	if ([value isKindOfClass:[NSNumber class]])
		return [value longLongValue];
	if ([value isKindOfClass:[NSString class]])
		return [value longLongValue];
	return 0;
}

static NSNumber *TGDouble(id value) {
	return [value isKindOfClass:[NSNumber class]] ? value : @0;
}

static NSArray *TGFlattenStickerSets(id list) {
	NSMutableArray *out = [NSMutableArray array];
	for (id item in TGArray(list)) {
		NSDictionary *set = TGFlattenStickerSet(item);
		if (set)
			[out addObject:set];
	}
	return out;
}

static NSDictionary *TGStickerTypeRegular(void) {
	return @{@"@type" : @"stickerTypeRegular"};
}

static NSDictionary *TGStickerTypeCustomEmoji(void) {
	return @{@"@type" : @"stickerTypeCustomEmoji"};
}

static NSDictionary *TGStickerTypeMask(void) {
	return @{@"@type" : @"stickerTypeMask"};
}

static NSDictionary *TGStickerFormatWebp(void) {
	return @{@"@type" : @"stickerFormatWebp"};
}

static NSDictionary *TGInputFileWithId(long long fileId) {
	return @{@"@type" : @"inputFileId",
		@"id" : @(fileId)};
}

@implementation TGClient (Stickers)

- (void)stickerSetsOfType:(NSDictionary *)type
			   completion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getInstalledStickerSets", @"sticker_type" : type}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			completion(TGFlattenStickerSets(result[@"sets"]));
		}];
}

- (void)installedStickerSetsWithCompletion:(void (^)(NSArray *))completion {
	[self stickerSetsOfType:TGStickerTypeRegular() completion:completion];
}

- (void)installedEmojiStickerSetsWithCompletion:(void (^)(NSArray *))completion {
	[self stickerSetsOfType:TGStickerTypeCustomEmoji() completion:completion];
}

- (void)archivedStickerSetsFromSetId:(int64_t)offsetSetId
							   limit:(NSInteger)limit
						  completion:(void (^)(NSArray *, NSInteger))completion {
	if (limit <= 0)
		limit = 100;

	[self request:@{
		@"@type" : @"getArchivedStickerSets",
		@"sticker_type" : TGStickerTypeRegular(),
		@"offset_sticker_set_id" : [NSString stringWithFormat:@"%lld", offsetSetId],
		@"limit" : @(limit),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, 0);
			return;
		}
		NSArray *sets = TGFlattenStickerSets(result[@"sets"]);
		completion(sets, (NSInteger)[result[@"total_count"] integerValue]);
	}];
}

- (void)trendingStickerSetsWithOffset:(NSInteger)offset
								limit:(NSInteger)limit
						   completion:(void (^)(NSArray *, NSInteger))completion {
	if (limit <= 0)
		limit = 20;

	[self request:@{
		@"@type" : @"getTrendingStickerSets",
		@"sticker_type" : TGStickerTypeRegular(),
		@"offset" : @(offset),
		@"limit" : @(limit),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, 0);
			return;
		}
		NSArray *sets = TGFlattenStickerSets(result[@"sets"]);
		completion(sets, (NSInteger)[result[@"total_count"] integerValue]);
	}];
}

- (void)markTrendingStickerSetsViewed:(NSArray *)setIds {
	NSMutableArray *ids = [NSMutableArray array];
	for (id item in TGArray(setIds))
		[ids addObject:[NSString stringWithFormat:@"%lld", TGInt64(item)]];
	if (!ids.count)
		return;

	[self send:@{@"@type" : @"viewTrendingStickerSets", @"sticker_set_ids" : ids}];
}

- (void)stickerSetWithId:(int64_t)setId completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"getStickerSet",
		@"set_id" : [NSString stringWithFormat:@"%lld", setId],
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGFlattenStickerSet(result));
	}];
}

- (void)stickerSetWithName:(NSString *)name completion:(void (^)(NSDictionary *))completion {
	if (!name.length) {
		if (completion)
			completion(nil);
		return;
	}

	[self request:@{
		@"@type" : @"searchStickerSet",
		@"name" : name,
		@"ignore_cache" : @NO,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGFlattenStickerSet(result));
	}];
}

- (void)changeStickerSet:(int64_t)setId
			   installed:(BOOL)installed
				archived:(BOOL)archived
			  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"changeStickerSet",
		@"set_id" : [NSString stringWithFormat:@"%lld", setId],
		@"is_installed" : @(installed),
		@"is_archived" : @(archived),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)installStickerSet:(int64_t)setId completion:(void (^)(BOOL))completion {
	[self changeStickerSet:setId installed:YES archived:NO completion:completion];
}

- (void)uninstallStickerSet:(int64_t)setId completion:(void (^)(BOOL))completion {
	[self changeStickerSet:setId installed:NO archived:NO completion:completion];
}

- (void)archiveStickerSet:(int64_t)setId completion:(void (^)(BOOL))completion {
	[self changeStickerSet:setId installed:NO archived:YES completion:completion];
}

- (void)searchInstalledStickerSets:(NSString *)query
							 limit:(NSInteger)limit
						completion:(void (^)(NSArray *))completion {
	if (limit <= 0)
		limit = 50;

	[self request:@{
		@"@type" : @"searchInstalledStickerSets",
		@"sticker_type" : TGStickerTypeRegular(),
		@"query" : query ?: @"",
		@"limit" : @(limit),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGFlattenStickerSets(result[@"sets"]));
	}];
}

- (void)searchStickerSets:(NSString *)query completion:(void (^)(NSArray *))completion {
	[self request:@{
		@"@type" : @"searchStickerSets",
		@"sticker_type" : TGStickerTypeRegular(),
		@"query" : query ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGFlattenStickerSets(result[@"sets"]));
	}];
}

- (void)favoriteStickersWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getFavoriteStickers"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(TGResultIsError(result) ? nil : TGFlattenStickers(result[@"stickers"]));
		}];
}

- (void)addFavoriteStickerWithFileId:(long long)fileId completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"addFavoriteSticker",
		@"sticker" : TGInputFileWithId(fileId)} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)removeFavoriteStickerWithFileId:(long long)fileId completion:(void (^)(BOOL ok))completion {
	[self request:@{@"@type" : @"removeFavoriteSticker",
		@"sticker" : TGInputFileWithId(fileId)} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)addRecentStickerWithFileId:(long long)fileId {
	[self send:@{@"@type" : @"addRecentSticker",
		@"is_attached" : @NO,
		@"sticker" : TGInputFileWithId(fileId)}];
}

- (void)removeRecentStickerWithFileId:(long long)fileId {
	[self send:@{@"@type" : @"removeRecentSticker",
		@"is_attached" : @NO,
		@"sticker" : TGInputFileWithId(fileId)}];
}

- (void)clearRecentStickers {
	[self send:@{@"@type" : @"clearRecentStickers", @"is_attached" : @NO}];
}

- (void)searchStickersByEmoji:(NSString *)emoji
						query:(NSString *)query
						limit:(NSInteger)limit
				   completion:(void (^)(NSArray *))completion {
	if (limit <= 0)
		limit = 50;

	[self request:@{
		@"@type" : @"searchStickers",
		@"sticker_type" : TGStickerTypeRegular(),
		@"emojis" : emoji ?: @"",
		@"query" : query ?: @"",
		@"input_language_codes" : @[],
		@"offset" : @0,
		@"limit" : @(limit),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGFlattenStickers(result[@"stickers"]));
	}];
}

- (void)installedStickersMatching:(NSString *)query
							limit:(NSInteger)limit
					   completion:(void (^)(NSArray *))completion {
	if (limit <= 0)
		limit = 50;

	[self request:@{
		@"@type" : @"getStickers",
		@"sticker_type" : TGStickerTypeRegular(),
		@"query" : query ?: @"",
		@"limit" : @(limit),
		@"chat_id" : @0,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGFlattenStickers(result[@"stickers"]));
	}];
}

- (void)allStickerEmojisForQuery:(NSString *)query
					  completion:(void (^)(NSArray *))completion {
	[self request:@{
		@"@type" : @"getAllStickerEmojis",
		@"sticker_type" : TGStickerTypeRegular(),
		@"query" : query ?: @"",
		@"chat_id" : @0,
		@"return_only_main_emoji" : @YES,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (id emoji in TGArray(result[@"emojis"]))
			if ([emoji isKindOfClass:[NSString class]])
				[out addObject:emoji];
		completion(out);
	}];
}

- (void)emojiSuggestionsForText:(NSString *)text
					 completion:(void (^)(NSArray *))completion {
	if (!text.length) {
		if (completion)
			completion(@[]);
		return;
	}

	[self request:@{
		@"@type" : @"searchEmojis",
		@"text" : text,
		@"input_language_codes" : @[],
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (id item in TGArray(result[@"emoji_keywords"])) {
			NSDictionary *entry = TGDict(item);
			NSString *emoji = TGString(entry[@"emoji"]);
			if (!emoji.length)
				continue;
			[out addObject:@{@"emoji" : emoji,
				@"keyword" : TGString(entry[@"keyword"]) ?: @""}];
		}
		completion(out);
	}];
}

- (void)keywordEmojisForText:(NSString *)text
				  completion:(void (^)(NSArray *))completion {
	[self request:@{
		@"@type" : @"getKeywordEmojis",
		@"text" : text ?: @"",
		@"input_language_codes" : @[],
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (id emoji in TGArray(result[@"emojis"]))
			if ([emoji isKindOfClass:[NSString class]])
				[out addObject:emoji];
		completion(out);
	}];
}

- (void)emojiCategoriesForStickers:(BOOL)forStickers
						completion:(void (^)(NSArray *))completion {
	NSString *type = forStickers ? @"emojiCategoryTypeRegularStickers"
								 : @"emojiCategoryTypeDefault";

	[self request:@{@"@type" : @"getEmojiCategories", @"type" : @{@"@type" : type}}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			for (id item in TGArray(result[@"categories"])) {
				NSDictionary *category = TGDict(item);
				if (!category)
					continue;
				NSMutableArray *emojis = [NSMutableArray array];
				NSDictionary *source = TGDict(category[@"source"]);
				for (id emoji in TGArray(source[@"emojis"]))
					if ([emoji isKindOfClass:[NSString class]])
						[emojis addObject:emoji];
				NSMutableDictionary *entry = [NSMutableDictionary dictionary];
				[entry setObject:(TGString(category[@"name"]) ?: @"") forKey:@"name"];
				[entry setObject:@([category[@"is_greeting"] boolValue]) forKey:@"isGreeting"];
				[entry setObject:emojis forKey:@"emojis"];
				NSDictionary *icon = TGFlattenSticker(category[@"icon"]);
				if (icon)
					[entry setObject:icon forKey:@"icon"];
				[out addObject:entry];
			}
			completion(out);
		}];
}

- (void)greetingStickersWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getGreetingStickers"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(TGResultIsError(result) ? nil : TGFlattenStickers(result[@"stickers"]));
		}];
}

- (void)customEmojiStickersWithIds:(NSArray *)customEmojiIds
						completion:(void (^)(NSArray *))completion {
	NSMutableArray *ids = [NSMutableArray array];
	for (id item in TGArray(customEmojiIds))
		[ids addObject:[NSString stringWithFormat:@"%lld", TGInt64(item)]];

	if (!ids.count) {
		if (completion)
			completion(@[]);
		return;
	}

	[self request:@{@"@type" : @"getCustomEmojiStickers", @"custom_emoji_ids" : ids}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(TGResultIsError(result) ? nil : TGFlattenStickers(result[@"stickers"]));
		}];
}

- (void)attachedStickerSetsForFileId:(long long)fileId
						  completion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getAttachedStickerSets", @"file_id" : @(fileId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(TGResultIsError(result) ? nil : TGFlattenStickerSets(result[@"sets"]));
		}];
}

- (void)setStickerSet:(int64_t)setId
		forSupergroup:(int64_t)supergroupId
		   completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setSupergroupStickerSet",
		@"supergroup_id" : @(supergroupId),
		@"sticker_set_id" : [NSString stringWithFormat:@"%lld", setId],
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)setCustomEmojiStickerSet:(int64_t)setId
				   forSupergroup:(int64_t)supergroupId
					  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setSupergroupCustomEmojiStickerSet",
		@"supergroup_id" : @(supergroupId),
		@"custom_emoji_sticker_set_id" : [NSString stringWithFormat:@"%lld", setId],
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)stickerOutlineForFileId:(long long)fileId
					 completion:(void (^)(NSArray *))completion {
	[self request:@{
		@"@type" : @"getStickerOutline",
		@"sticker_file_id" : @(fileId),
		@"for_animated_emoji" : @NO,
		@"for_clicked_animated_emoji_message" : @NO,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSMutableArray *paths = [NSMutableArray array];
		for (id item in TGArray(result[@"paths"])) {
			NSDictionary *path = TGDict(item);
			NSMutableArray *commands = [NSMutableArray array];
			for (id rawCommand in TGArray(path[@"commands"])) {
				NSDictionary *command = TGDict(rawCommand);
				NSDictionary *end = TGDict(command[@"end_point"]);
				if (!end)
					continue;
				NSString *type = TGString(command[@"@type"]) ?: @"";
				if ([type isEqualToString:@"vectorPathCommandCubicBezierCurve"]) {
					NSDictionary *c1 = TGDict(command[@"start_control_point"]);
					NSDictionary *c2 = TGDict(command[@"end_control_point"]);
					[commands addObject:@{
						@"type" : @"curve",
						@"x" : TGDouble(end[@"x"]),
						@"y" : TGDouble(end[@"y"]),
						@"c1x" : TGDouble(c1[@"x"]),
						@"c1y" : TGDouble(c1[@"y"]),
						@"c2x" : TGDouble(c2[@"x"]),
						@"c2y" : TGDouble(c2[@"y"]),
					}];
				} else {
					[commands addObject:@{
						@"type" : @"line",
						@"x" : TGDouble(end[@"x"]),
						@"y" : TGDouble(end[@"y"]),
					}];
				}
			}
			if (commands.count)
				[paths addObject:commands];
		}
		completion(paths);
	}];
}

- (void)recentStickersAttached:(BOOL)attached
					completion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getRecentStickers", @"is_attached" : @(attached)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(TGResultIsError(result) ? nil : TGFlattenStickers(result[@"stickers"]));
		}];
}

- (void)installedMaskStickerSetsWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getInstalledStickerSets",
		@"sticker_type" : TGStickerTypeMask()}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(TGResultIsError(result) ? nil : TGFlattenStickerSets(result[@"sets"]));
		}];
}

- (void)archivedStickerSetsOfType:(NSDictionary *)type
						fromSetId:(int64_t)offsetSetId
							limit:(NSInteger)limit
					   completion:(void (^)(NSArray *, NSInteger))completion {
	if (limit <= 0)
		limit = 100;

	[self request:@{
		@"@type" : @"getArchivedStickerSets",
		@"sticker_type" : type,
		@"offset_sticker_set_id" : [NSString stringWithFormat:@"%lld", offsetSetId],
		@"limit" : @(limit),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, 0);
			return;
		}
		completion(TGFlattenStickerSets(result[@"sets"]),
			(NSInteger)[result[@"total_count"] integerValue]);
	}];
}

- (void)archivedEmojiStickerSetsFromSetId:(int64_t)offsetSetId
									limit:(NSInteger)limit
							   completion:(void (^)(NSArray *, NSInteger))completion {
	[self archivedStickerSetsOfType:TGStickerTypeCustomEmoji()
						  fromSetId:offsetSetId
							  limit:limit
						 completion:completion];
}

- (void)archivedMaskStickerSetsFromSetId:(int64_t)offsetSetId
								   limit:(NSInteger)limit
							  completion:(void (^)(NSArray *, NSInteger))completion {
	[self archivedStickerSetsOfType:TGStickerTypeMask()
						  fromSetId:offsetSetId
							  limit:limit
						 completion:completion];
}

- (void)trendingEmojiStickerSetsWithOffset:(NSInteger)offset
									 limit:(NSInteger)limit
								completion:(void (^)(NSArray *, NSInteger))completion {
	if (limit <= 0)
		limit = 20;

	[self request:@{
		@"@type" : @"getTrendingStickerSets",
		@"sticker_type" : TGStickerTypeCustomEmoji(),
		@"offset" : @(offset),
		@"limit" : @(limit),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, 0);
			return;
		}
		completion(TGFlattenStickerSets(result[@"sets"]),
			(NSInteger)[result[@"total_count"] integerValue]);
	}];
}

- (void)searchInstalledMaskStickerSets:(NSString *)query
								 limit:(NSInteger)limit
							completion:(void (^)(NSArray *))completion {
	if (limit <= 0)
		limit = 50;

	[self request:@{
		@"@type" : @"searchInstalledStickerSets",
		@"sticker_type" : TGStickerTypeMask(),
		@"query" : query ?: @"",
		@"limit" : @(limit),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGFlattenStickerSets(result[@"sets"]));
	}];
}

- (void)searchEmojiStickerSets:(NSString *)query
					completion:(void (^)(NSArray *))completion {
	[self request:@{
		@"@type" : @"searchStickerSets",
		@"sticker_type" : TGStickerTypeCustomEmoji(),
		@"query" : query ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGFlattenStickerSets(result[@"sets"]));
	}];
}

- (void)reorderStickerSetsOfType:(NSDictionary *)type
							 ids:(NSArray *)setIds
					  completion:(void (^)(BOOL))completion {
	NSMutableArray *ids = [NSMutableArray array];
	for (id item in TGArray(setIds))
		[ids addObject:[NSString stringWithFormat:@"%lld", TGInt64(item)]];
	if (!ids.count) {
		if (completion)
			completion(NO);
		return;
	}

	[self request:@{
		@"@type" : @"reorderInstalledStickerSets",
		@"sticker_type" : type,
		@"sticker_set_ids" : ids,
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)reorderInstalledStickerSets:(NSArray *)setIds
						 completion:(void (^)(BOOL))completion {
	[self reorderStickerSetsOfType:TGStickerTypeRegular() ids:setIds completion:completion];
}

- (void)reorderInstalledEmojiStickerSets:(NSArray *)setIds
							  completion:(void (^)(BOOL))completion {
	[self reorderStickerSetsOfType:TGStickerTypeCustomEmoji() ids:setIds completion:completion];
}

- (void)reorderInstalledMaskStickerSets:(NSArray *)setIds
							 completion:(void (^)(BOOL))completion {
	[self reorderStickerSetsOfType:TGStickerTypeMask() ids:setIds completion:completion];
}

- (void)isStickerFavoriteWithFileId:(long long)fileId
						 completion:(void (^)(BOOL, BOOL))completion {
	[self request:@{@"@type" : @"getFavoriteStickers"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(NO, YES);
				return;
			}
			BOOL found = NO;
			for (id item in TGArray(result[@"stickers"])) {
				NSNumber *stickerFileId = TGDict(TGDict(item)[@"sticker"])[@"id"];
				if (![stickerFileId isKindOfClass:[NSNumber class]])
					continue;
				if ([stickerFileId longLongValue] == fileId) {
					found = YES;
					break;
				}
			}
			completion(found, NO);
		}];
}

- (void)stickerSetNameForId:(int64_t)setId completion:(void (^)(NSString *))completion {
	[self request:@{
		@"@type" : @"getStickerSetName",
		@"set_id" : [NSString stringWithFormat:@"%lld", setId],
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSString *name = TGString(result[@"text"]);
		completion(name.length ? name : nil);
	}];
}

- (void)premiumStickersWithLimit:(NSInteger)limit
					  completion:(void (^)(NSArray *))completion {
	if (limit <= 0)
		limit = 50;
	if (limit > 100)
		limit = 100;

	[self request:@{@"@type" : @"getPremiumStickers", @"limit" : @(limit)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(TGResultIsError(result) ? nil : TGFlattenStickers(result[@"stickers"]));
		}];
}

- (void)stickersFromSetId:(int64_t)setId
				   offset:(NSInteger)offset
					limit:(NSInteger)limit
			   completion:(void (^)(NSArray *, NSInteger))completion {
	if (limit <= 0)
		limit = 40;
	if (offset < 0)
		offset = 0;

	[self request:@{
		@"@type" : @"getStickerSet",
		@"set_id" : [NSString stringWithFormat:@"%lld", setId],
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, 0);
			return;
		}
		id raw = result[@"stickers"];
		NSInteger total = (NSInteger)TGCountFlattenableStickers(raw);
		if (offset >= total) {
			completion([NSArray array], total);
			return;
		}
		NSInteger length = total - offset;
		if (length > limit)
			length = limit;
		completion(TGFlattenStickerRange(raw, (NSUInteger)offset, (NSUInteger)length), total);
	}];
}

#pragma mark - authoring owned sticker sets

- (void)ownedStickerSetsFromSetId:(int64_t)offsetSetId
							limit:(NSInteger)limit
					   completion:(void (^)(NSArray *, NSInteger))completion {
	if (limit <= 0 || limit > 100)
		limit = 100;

	[self request:@{
		@"@type" : @"getOwnedStickerSets",
		@"offset_sticker_set_id" : [NSString stringWithFormat:@"%lld", offsetSetId],
		@"limit" : @(limit),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, 0);
			return;
		}
		NSArray *sets = TGFlattenStickerSets(result[@"sets"]);
		completion(sets, (NSInteger)[result[@"total_count"] integerValue]);
	}];
}

- (void)suggestedStickerSetNameForTitle:(NSString *)title
							 completion:(void (^)(NSString *))completion {
	[self request:@{@"@type" : @"getSuggestedStickerSetName", @"title" : title ?: @""}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(TGResultIsError(result) ? nil : TGString(result[@"text"]));
		}];
}

- (void)checkStickerSetNameAvailability:(NSString *)name
							 completion:(void (^)(NSString *))completion {
	if (!name.length) {
		if (completion)
			completion(@"invalid");
		return;
	}
	[self request:@{@"@type" : @"checkStickerSetName", @"name" : name}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			NSString *type = TGString(result[@"@type"]);
			if ([type isEqualToString:@"checkStickerSetNameResultOk"])
				completion(@"ok");
			else if ([type isEqualToString:@"checkStickerSetNameResultNameOccupied"])
				completion(@"occupied");
			else if ([type isEqualToString:@"checkStickerSetNameResultNameInvalid"])
				completion(@"invalid");
			else
				completion(@"error");
		}];
}

static NSDictionary *TGNewStickerDict(NSString *path, NSString *emoji) {
	return @{
		@"@type" : @"newSticker",
		@"sticker" : @{@"@type" : @"inputFileLocal", @"path" : path ?: @""},
		@"format" : TGStickerFormatWebp(),
		@"emojis" : emoji.length ? emoji : @"🙂",
		@"keywords" : @[],
	};
}

- (void)createStickerSetForUser:(int64_t)userId
						  title:(NSString *)title
						   name:(NSString *)name
					   stickers:(NSArray *)stickers
					 completion:(void (^)(NSDictionary *, NSString *))completion {
	NSMutableArray *stickerDicts = [NSMutableArray arrayWithCapacity:stickers.count];
	for (NSDictionary *sticker in stickers)
		[stickerDicts addObject:TGNewStickerDict(sticker[@"path"], sticker[@"emoji"])];
	[self request:@{
		@"@type" : @"createNewStickerSet",
		@"user_id" : @(userId),
		@"title" : title ?: @"",
		@"name" : name ?: @"",
		@"sticker_type" : TGStickerTypeRegular(),
		@"needs_repainting" : @NO,
		@"stickers" : stickerDicts,
		@"source" : @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil, TGString(result[@"message"]) ?: @"");
			return;
		}
		completion(TGFlattenStickerSet(result), nil);
	}];
}

- (void)addStickerForUser:(int64_t)userId
			   toSetNamed:(NSString *)name
		  stickerFilePath:(NSString *)path
					emoji:(NSString *)emoji
			   completion:(void (^)(NSString *))completion {
	[self request:@{
		@"@type" : @"addStickerToSet",
		@"user_id" : @(userId),
		@"name" : name ?: @"",
		@"sticker" : TGNewStickerDict(path, emoji),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? (TGString(result[@"message"]) ?: @"") : nil);
	}];
}

- (void)removeStickerWithFileId:(long long)fileId
					 completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"removeStickerFromSet",
		@"sticker" : TGInputFileWithId(fileId),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)setPosition:(NSInteger)position
	forStickerWithFileId:(long long)fileId
			  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setStickerPositionInSet",
		@"sticker" : TGInputFileWithId(fileId),
		@"position" : @(position),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)setEmoji:(NSString *)emoji
	forStickerWithFileId:(long long)fileId
			  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setStickerEmojis",
		@"sticker" : TGInputFileWithId(fileId),
		@"emojis" : emoji ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)setKeywords:(NSArray *)keywords
	forStickerWithFileId:(long long)fileId
			  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setStickerKeywords",
		@"sticker" : TGInputFileWithId(fileId),
		@"keywords" : keywords ?: @[],
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)renameStickerSetNamed:(NSString *)name
						title:(NSString *)title
				   completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setStickerSetTitle",
		@"name" : name ?: @"",
		@"title" : title ?: @"",
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)setThumbnailForStickerSetNamed:(NSString *)name
								userId:(int64_t)userId
								atPath:(NSString *)path
							completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type" : @"setStickerSetThumbnail",
		@"user_id" : @(userId),
		@"name" : name ?: @"",
		@"thumbnail" : @{@"@type" : @"inputFileLocal", @"path" : path ?: @""},
		@"format" : TGStickerFormatWebp(),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result))
			completion(NO, TGString(result[@"message"]) ?: @"");
		else
			completion(YES, nil);
	}];
}

- (void)deleteStickerSetNamed:(NSString *)name
				   completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"deleteStickerSet", @"name" : name ?: @""}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

@end

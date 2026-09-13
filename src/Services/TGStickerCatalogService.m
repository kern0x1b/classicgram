#import "TGClient+Messages.h"
#import "TGStickerCatalogService.h"
#import "TGClient+Stickers.h"

NSString *const TGStickerSuggestModeKey = @"TGStickerSuggestMode";

TGStickerSuggestMode TGStickersSuggestMode(void) {
	NSNumber *stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGStickerSuggestModeKey];
	if (!stored)
		return TGStickerSuggestModeAll;
	NSInteger value = [stored integerValue];
	if (value < TGStickerSuggestModeAll || value > TGStickerSuggestModeNone)
		return TGStickerSuggestModeAll;
	return (TGStickerSuggestMode)value;
}

@implementation TGStickerCatalogService

+ (void)installedStickerSetsWithCompletion:(void (^)(NSArray *sets))completion {
	[[TGClient shared] installedStickerSetsWithCompletion:completion];
}

+ (void)installedEmojiStickerSetsWithCompletion:(void (^)(NSArray *sets))completion {
	[[TGClient shared] installedEmojiStickerSetsWithCompletion:completion];
}

+ (void)installedMaskStickerSetsWithCompletion:(void (^)(NSArray *sets))completion {
	[[TGClient shared] installedMaskStickerSetsWithCompletion:completion];
}

+ (void)favoriteStickersWithCompletion:(void (^)(NSArray *stickers))completion {
	[[TGClient shared] favoriteStickersWithCompletion:completion];
}

+ (void)recentStickersWithCompletion:(void (^)(NSArray *stickers))completion {
	[[TGClient shared] recentStickersWithCompletion:completion];
}

+ (void)recentStickersAttached:(BOOL)attached completion:(void (^)(NSArray *stickers))completion {
	[[TGClient shared] recentStickersAttached:attached completion:completion];
}

+ (void)archivedStickerSetsFromSetId:(int64_t)offsetSetId
							   limit:(NSInteger)limit
						  completion:(void (^)(NSArray *sets, NSInteger totalCount))completion {
	[[TGClient shared] archivedStickerSetsFromSetId:offsetSetId limit:limit completion:completion];
}

+ (void)archivedEmojiStickerSetsFromSetId:(int64_t)offsetSetId
									limit:(NSInteger)limit
							   completion:(void (^)(NSArray *sets, NSInteger totalCount))completion {
	[[TGClient shared] archivedEmojiStickerSetsFromSetId:offsetSetId limit:limit completion:completion];
}

+ (void)archivedMaskStickerSetsFromSetId:(int64_t)offsetSetId
								   limit:(NSInteger)limit
							  completion:(void (^)(NSArray *sets, NSInteger totalCount))completion {
	[[TGClient shared] archivedMaskStickerSetsFromSetId:offsetSetId limit:limit completion:completion];
}

+ (void)trendingStickerSetsWithOffset:(NSInteger)offset
								limit:(NSInteger)limit
						   completion:(void (^)(NSArray *sets, NSInteger totalCount))completion {
	[[TGClient shared] trendingStickerSetsWithOffset:offset limit:limit completion:completion];
}

+ (void)trendingEmojiStickerSetsWithOffset:(NSInteger)offset
									 limit:(NSInteger)limit
								completion:(void (^)(NSArray *sets, NSInteger totalCount))completion {
	[[TGClient shared] trendingEmojiStickerSetsWithOffset:offset limit:limit completion:completion];
}

+ (void)markTrendingStickerSetsViewed:(NSArray *)setIds {
	[[TGClient shared] markTrendingStickerSetsViewed:setIds];
}

+ (void)stickerSetWithId:(int64_t)setId completion:(void (^)(NSDictionary *set))completion {
	[[TGClient shared] stickerSetWithId:setId completion:completion];
}

+ (void)stickerSetWithName:(NSString *)name completion:(void (^)(NSDictionary *set))completion {
	[[TGClient shared] stickerSetWithName:name completion:completion];
}

+ (void)installStickerSet:(int64_t)setId completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] installStickerSet:setId completion:completion];
}

+ (void)uninstallStickerSet:(int64_t)setId completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] uninstallStickerSet:setId completion:completion];
}

+ (void)archiveStickerSet:(int64_t)setId completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] archiveStickerSet:setId completion:completion];
}

+ (void)reorderInstalledStickerSets:(NSArray *)setIds completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] reorderInstalledStickerSets:setIds completion:completion];
}

+ (void)reorderInstalledEmojiStickerSets:(NSArray *)setIds completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] reorderInstalledEmojiStickerSets:setIds completion:completion];
}

+ (void)reorderInstalledMaskStickerSets:(NSArray *)setIds completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] reorderInstalledMaskStickerSets:setIds completion:completion];
}

+ (void)searchInstalledStickerSets:(NSString *)query
							 limit:(NSInteger)limit
						completion:(void (^)(NSArray *sets))completion {
	[[TGClient shared] searchInstalledStickerSets:query limit:limit completion:completion];
}

+ (void)searchInstalledMaskStickerSets:(NSString *)query
								 limit:(NSInteger)limit
							completion:(void (^)(NSArray *sets))completion {
	[[TGClient shared] searchInstalledMaskStickerSets:query limit:limit completion:completion];
}

+ (void)searchEmojiStickerSets:(NSString *)query completion:(void (^)(NSArray *sets))completion {
	[[TGClient shared] searchEmojiStickerSets:query completion:completion];
}

+ (void)searchStickerSets:(NSString *)query completion:(void (^)(NSArray *sets))completion {
	[[TGClient shared] searchStickerSets:query completion:completion];
}

+ (void)addFavoriteStickerWithFileId:(long long)fileId completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] addFavoriteStickerWithFileId:fileId completion:completion];
}

+ (void)removeFavoriteStickerWithFileId:(long long)fileId completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] removeFavoriteStickerWithFileId:fileId completion:completion];
}

+ (void)isStickerFavoriteWithFileId:(long long)fileId completion:(void (^)(BOOL favorite, BOOL failed))completion {
	[[TGClient shared] isStickerFavoriteWithFileId:fileId completion:completion];
}

+ (void)addRecentStickerWithFileId:(long long)fileId {
	[[TGClient shared] addRecentStickerWithFileId:fileId];
}

+ (void)removeRecentStickerWithFileId:(long long)fileId {
	[[TGClient shared] removeRecentStickerWithFileId:fileId];
}

+ (void)clearRecentStickers {
	[[TGClient shared] clearRecentStickers];
}

+ (void)searchStickersByEmoji:(NSString *)emoji
						query:(NSString *)query
						limit:(NSInteger)limit
				   completion:(void (^)(NSArray *stickers))completion {
	[[TGClient shared] searchStickersByEmoji:emoji query:query limit:limit completion:completion];
}

+ (void)installedStickersMatching:(NSString *)query
							limit:(NSInteger)limit
					   completion:(void (^)(NSArray *stickers))completion {
	[[TGClient shared] installedStickersMatching:query limit:limit completion:completion];
}

+ (void)allStickerEmojisForQuery:(NSString *)query
					  completion:(void (^)(NSArray *emojis))completion {
	[[TGClient shared] allStickerEmojisForQuery:query completion:completion];
}

+ (void)stickersFromSetId:(int64_t)setId
				   offset:(NSInteger)offset
					limit:(NSInteger)limit
			   completion:(void (^)(NSArray *stickers, NSInteger totalCount))completion {
	[[TGClient shared] stickersFromSetId:setId offset:offset limit:limit completion:completion];
}

+ (void)customEmojiStickersWithIds:(NSArray *)customEmojiIds
						completion:(void (^)(NSArray *stickers))completion {
	[[TGClient shared] customEmojiStickersWithIds:customEmojiIds completion:completion];
}

+ (void)ownedStickerSetsFromSetId:(int64_t)offsetSetId
							limit:(NSInteger)limit
					   completion:(void (^)(NSArray *sets, NSInteger totalCount))completion {
	[[TGClient shared] ownedStickerSetsFromSetId:offsetSetId limit:limit completion:completion];
}

@end

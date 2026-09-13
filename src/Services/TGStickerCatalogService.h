#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TGStickerSuggestMode) {
	TGStickerSuggestModeAll = 0,
	TGStickerSuggestModeInstalled = 1,
	TGStickerSuggestModeNone = 2
};

extern NSString *const TGStickerSuggestModeKey;

TGStickerSuggestMode TGStickersSuggestMode(void);

@interface TGStickerCatalogService : NSObject

+ (void)installedStickerSetsWithCompletion:(void (^)(NSArray *sets))completion;
+ (void)installedEmojiStickerSetsWithCompletion:(void (^)(NSArray *sets))completion;
+ (void)installedMaskStickerSetsWithCompletion:(void (^)(NSArray *sets))completion;

+ (void)favoriteStickersWithCompletion:(void (^)(NSArray *stickers))completion;
+ (void)recentStickersWithCompletion:(void (^)(NSArray *stickers))completion;
+ (void)recentStickersAttached:(BOOL)attached completion:(void (^)(NSArray *stickers))completion;

+ (void)archivedStickerSetsFromSetId:(int64_t)offsetSetId
							   limit:(NSInteger)limit
						  completion:(void (^)(NSArray *sets, NSInteger totalCount))completion;
+ (void)archivedEmojiStickerSetsFromSetId:(int64_t)offsetSetId
									limit:(NSInteger)limit
							   completion:(void (^)(NSArray *sets, NSInteger totalCount))completion;
+ (void)archivedMaskStickerSetsFromSetId:(int64_t)offsetSetId
								   limit:(NSInteger)limit
							  completion:(void (^)(NSArray *sets, NSInteger totalCount))completion;

+ (void)trendingStickerSetsWithOffset:(NSInteger)offset
								limit:(NSInteger)limit
						   completion:(void (^)(NSArray *sets, NSInteger totalCount))completion;
+ (void)trendingEmojiStickerSetsWithOffset:(NSInteger)offset
									 limit:(NSInteger)limit
								completion:(void (^)(NSArray *sets, NSInteger totalCount))completion;
+ (void)markTrendingStickerSetsViewed:(NSArray *)setIds;

+ (void)stickerSetWithId:(int64_t)setId completion:(void (^)(NSDictionary *set))completion;
+ (void)stickerSetWithName:(NSString *)name completion:(void (^)(NSDictionary *set))completion;

+ (void)installStickerSet:(int64_t)setId completion:(void (^)(BOOL ok))completion;
+ (void)uninstallStickerSet:(int64_t)setId completion:(void (^)(BOOL ok))completion;
+ (void)archiveStickerSet:(int64_t)setId completion:(void (^)(BOOL ok))completion;

+ (void)reorderInstalledStickerSets:(NSArray *)setIds completion:(void (^)(BOOL ok))completion;
+ (void)reorderInstalledEmojiStickerSets:(NSArray *)setIds completion:(void (^)(BOOL ok))completion;
+ (void)reorderInstalledMaskStickerSets:(NSArray *)setIds completion:(void (^)(BOOL ok))completion;

+ (void)searchInstalledStickerSets:(NSString *)query
							 limit:(NSInteger)limit
						completion:(void (^)(NSArray *sets))completion;
+ (void)searchInstalledMaskStickerSets:(NSString *)query
								 limit:(NSInteger)limit
							completion:(void (^)(NSArray *sets))completion;
+ (void)searchEmojiStickerSets:(NSString *)query completion:(void (^)(NSArray *sets))completion;
+ (void)searchStickerSets:(NSString *)query completion:(void (^)(NSArray *sets))completion;

+ (void)addFavoriteStickerWithFileId:(long long)fileId completion:(void (^)(BOOL ok))completion;
+ (void)removeFavoriteStickerWithFileId:(long long)fileId completion:(void (^)(BOOL ok))completion;
+ (void)isStickerFavoriteWithFileId:(long long)fileId completion:(void (^)(BOOL favorite, BOOL failed))completion;

+ (void)addRecentStickerWithFileId:(long long)fileId;
+ (void)removeRecentStickerWithFileId:(long long)fileId;
+ (void)clearRecentStickers;

+ (void)searchStickersByEmoji:(NSString *)emoji
						query:(NSString *)query
						limit:(NSInteger)limit
				   completion:(void (^)(NSArray *stickers))completion;
+ (void)installedStickersMatching:(NSString *)query
							limit:(NSInteger)limit
					   completion:(void (^)(NSArray *stickers))completion;
+ (void)allStickerEmojisForQuery:(NSString *)query
					  completion:(void (^)(NSArray *emojis))completion;

+ (void)stickersFromSetId:(int64_t)setId
				   offset:(NSInteger)offset
					limit:(NSInteger)limit
			   completion:(void (^)(NSArray *stickers, NSInteger totalCount))completion;

+ (void)customEmojiStickersWithIds:(NSArray *)customEmojiIds
						completion:(void (^)(NSArray *stickers))completion;

+ (void)ownedStickerSetsFromSetId:(int64_t)offsetSetId
							limit:(NSInteger)limit
					   completion:(void (^)(NSArray *sets, NSInteger totalCount))completion;

@end

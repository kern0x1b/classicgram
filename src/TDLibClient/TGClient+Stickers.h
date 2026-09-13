#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (Stickers)

- (void)installedStickerSetsWithCompletion:(void (^ _Nullable)(NSArray *sets))completion;

- (void)installedEmojiStickerSetsWithCompletion:(void (^ _Nullable)(NSArray *sets))completion;

- (void)archivedStickerSetsFromSetId:(int64_t)offsetSetId
							   limit:(NSInteger)limit
						  completion:(void (^ _Nullable)(NSArray *sets, NSInteger totalCount))completion;

- (void)trendingStickerSetsWithOffset:(NSInteger)offset
								limit:(NSInteger)limit
						   completion:(void (^ _Nullable)(NSArray *sets, NSInteger totalCount))completion;

- (void)markTrendingStickerSetsViewed:(NSArray *)setIds;

- (void)stickerSetWithId:(int64_t)setId completion:(void (^ _Nullable)(NSDictionary *set))completion;

- (void)stickerSetWithName:(NSString *)name completion:(void (^ _Nullable)(NSDictionary *set))completion;

- (void)installStickerSet:(int64_t)setId completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)uninstallStickerSet:(int64_t)setId completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)archiveStickerSet:(int64_t)setId completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)searchInstalledStickerSets:(NSString *)query
							 limit:(NSInteger)limit
						completion:(void (^ _Nullable)(NSArray *sets))completion;

- (void)searchStickerSets:(NSString *)query completion:(void (^ _Nullable)(NSArray *sets))completion;

- (void)favoriteStickersWithCompletion:(void (^ _Nullable)(NSArray *stickers))completion;

- (void)addFavoriteStickerWithFileId:(long long)fileId completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)removeFavoriteStickerWithFileId:(long long)fileId completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)addRecentStickerWithFileId:(long long)fileId;

- (void)removeRecentStickerWithFileId:(long long)fileId;

- (void)clearRecentStickers;

- (void)searchStickersByEmoji:(NSString *)emoji
						query:(NSString *)query
						limit:(NSInteger)limit
				   completion:(void (^ _Nullable)(NSArray *stickers))completion;

- (void)installedStickersMatching:(NSString *)query
							limit:(NSInteger)limit
					   completion:(void (^ _Nullable)(NSArray *stickers))completion;

- (void)allStickerEmojisForQuery:(NSString *)query
					  completion:(void (^ _Nullable)(NSArray *emojis))completion;

- (void)emojiSuggestionsForText:(NSString *)text
					 completion:(void (^ _Nullable)(NSArray *suggestions))completion;

- (void)keywordEmojisForText:(NSString *)text
				  completion:(void (^ _Nullable)(NSArray *emojis))completion;

- (void)emojiCategoriesForStickers:(BOOL)forStickers
						completion:(void (^ _Nullable)(NSArray *categories))completion;

- (void)greetingStickersWithCompletion:(void (^ _Nullable)(NSArray *stickers))completion;

- (void)customEmojiStickersWithIds:(NSArray *)customEmojiIds
						completion:(void (^ _Nullable)(NSArray *stickers))completion;

- (void)attachedStickerSetsForFileId:(long long)fileId
						  completion:(void (^ _Nullable)(NSArray *sets))completion;

- (void)setStickerSet:(int64_t)setId
		forSupergroup:(int64_t)supergroupId
		   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setCustomEmojiStickerSet:(int64_t)setId
				   forSupergroup:(int64_t)supergroupId
					  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)recentStickersAttached:(BOOL)attached
					completion:(void (^ _Nullable)(NSArray *stickers))completion;

- (void)installedMaskStickerSetsWithCompletion:(void (^ _Nullable)(NSArray *sets))completion;

- (void)archivedEmojiStickerSetsFromSetId:(int64_t)offsetSetId
									limit:(NSInteger)limit
							   completion:(void (^ _Nullable)(NSArray *sets, NSInteger totalCount))completion;

- (void)archivedMaskStickerSetsFromSetId:(int64_t)offsetSetId
								   limit:(NSInteger)limit
							  completion:(void (^ _Nullable)(NSArray *sets, NSInteger totalCount))completion;

- (void)trendingEmojiStickerSetsWithOffset:(NSInteger)offset
									 limit:(NSInteger)limit
								completion:(void (^ _Nullable)(NSArray *sets, NSInteger totalCount))completion;

- (void)searchInstalledMaskStickerSets:(NSString *)query
								 limit:(NSInteger)limit
							completion:(void (^ _Nullable)(NSArray *sets))completion;

- (void)searchEmojiStickerSets:(NSString *)query
					completion:(void (^ _Nullable)(NSArray *sets))completion;

- (void)reorderInstalledStickerSets:(NSArray *)setIds
						 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)reorderInstalledEmojiStickerSets:(NSArray *)setIds
							  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)reorderInstalledMaskStickerSets:(NSArray *)setIds
							 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)isStickerFavoriteWithFileId:(long long)fileId
						 completion:(void (^ _Nullable)(BOOL favorite, BOOL failed))completion;

- (void)stickerSetNameForId:(int64_t)setId completion:(void (^ _Nullable)(NSString *name))completion;

- (void)premiumStickersWithLimit:(NSInteger)limit
					  completion:(void (^ _Nullable)(NSArray *stickers))completion;

- (void)stickersFromSetId:(int64_t)setId
				   offset:(NSInteger)offset
					limit:(NSInteger)limit
			   completion:(void (^ _Nullable)(NSArray *stickers, NSInteger totalCount))completion;

- (void)stickerOutlineForFileId:(long long)fileId
					 completion:(void (^ _Nullable)(NSArray *paths))completion;

#pragma mark - authoring owned sticker sets

- (void)ownedStickerSetsFromSetId:(int64_t)offsetSetId
							limit:(NSInteger)limit
					   completion:(void (^ _Nullable)(NSArray *sets, NSInteger totalCount))completion;

- (void)suggestedStickerSetNameForTitle:(NSString *)title
							 completion:(void (^ _Nullable)(NSString *name))completion;

- (void)checkStickerSetNameAvailability:(NSString *)name
							 completion:(void (^ _Nullable)(NSString *status))completion;

- (void)createStickerSetForUser:(int64_t)userId
						  title:(NSString *)title
						   name:(NSString *)name
					   stickers:(NSArray *)stickers
					 completion:(void (^ _Nullable)(NSDictionary *set, NSString *errorText))completion;

- (void)addStickerForUser:(int64_t)userId
			   toSetNamed:(NSString *)name
		  stickerFilePath:(NSString *)path
					emoji:(NSString *)emoji
			   completion:(void (^ _Nullable)(NSString *errorText))completion;

- (void)removeStickerWithFileId:(long long)fileId
					 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setPosition:(NSInteger)position
	forStickerWithFileId:(long long)fileId
			  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setEmoji:(NSString *)emoji
	forStickerWithFileId:(long long)fileId
			  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setKeywords:(NSArray *)keywords
	forStickerWithFileId:(long long)fileId
			  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)renameStickerSetNamed:(NSString *)name
						title:(NSString *)title
				   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setThumbnailForStickerSetNamed:(NSString *)name
								userId:(int64_t)userId
								atPath:(NSString *)path
							completion:(void (^ _Nullable)(BOOL ok, NSString *errorText))completion;

- (void)deleteStickerSetNamed:(NSString *)name
				   completion:(void (^ _Nullable)(BOOL ok))completion;

@end

NS_ASSUME_NONNULL_END

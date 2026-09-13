#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (Gifs)

#pragma mark - the saved list

- (void)savedGifsWithCompletion:(void (^ _Nullable)(NSArray *gifs))completion;

- (void)saveGifWithFileId:(long long)fileId completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)unsaveGifWithFileId:(long long)fileId completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)isGifSavedWithFileId:(long long)fileId completion:(void (^ _Nullable)(BOOL saved))completion;

#pragma mark - trending and search

- (void)resetGifSearchBotCacheForAccountSwitch;

- (void)trendingGifsWithCompletion:(void (^ _Nullable)(NSArray *gifs, NSString *nextOffset))completion;

- (void)searchGifs:(NSString *)query
			offset:(nullable NSString *)offset
		completion:(void (^ _Nullable)(NSArray *gifs, NSString *nextOffset))completion;

- (void)gifSearchCategoriesWithCompletion:(void (^ _Nullable)(NSArray *categories))completion;

#pragma mark - sending

- (void)sendGif:(NSDictionary *)gif
		 toChat:(int64_t)chatId
		 thread:(int64_t)threadId
directMessagesTopic:(int64_t)directMessagesTopicId
	 savedTopic:(int64_t)savedTopicId
		replyTo:(int64_t)replyToId
		options:(NSDictionary *)options;

@end

NS_ASSUME_NONNULL_END

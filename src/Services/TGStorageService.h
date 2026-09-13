#import <Foundation/Foundation.h>

@interface TGStorageService : NSObject

+ (void)storageStatsWithCompletion:(void (^)(long long bytes, NSInteger files))completion;

+ (void)storageOverviewWithCompletion:(void (^)(NSDictionary *overview))completion;

+ (void)downloadTotalsWithCompletion:(void (^)(NSDictionary *counts))completion;

+ (void)storageUsageByFileTypeWithCompletion:
	(void (^)(NSDictionary *sizes, long long totalBytes))completion;

+ (void)storageUsageByChatWithLimit:(NSInteger)limit
						 completion:(void (^)(NSArray *chats))completion;

+ (void)storageUsageDetailWithChatLimit:(NSInteger)limit
							  completion:(void (^)(NSDictionary *sizes, long long totalBytes,
											  NSArray *chats))completion;

+ (void)storageUsageForChat:(int64_t)chatId
				 completion:(void (^)(long long bytes, NSInteger files))completion;

+ (void)storageUsageByFileTypeForChat:(int64_t)chatId
							completion:(void (^)(NSDictionary *sizes))completion;

+ (void)databaseStatisticsWithCompletion:(void (^)(NSString *text))completion;

+ (NSDictionary *)cachePolicy;

+ (void)setCachePolicyMaxBytes:(long long)maxBytes
					ttlSeconds:(NSInteger)ttlSeconds
			   excludedChatIds:(NSArray *)excludedChatIds;

+ (void)applyCachePolicyMaxBytes:(long long)maxBytes
					  ttlSeconds:(NSInteger)ttlSeconds
				 excludedChatIds:(NSArray *)excludedChatIds
					  completion:(void (^)(long long freed))completion;

+ (void)applyPersistedCachePolicyWithCompletion:(void (^)(long long freed))completion;

+ (void)clearCacheCategories:(NSArray *)kinds
				  completion:(void (^)(long long freed))completion;

+ (void)clearAllCacheWithCompletion:(void (^)(long long freed))completion;

+ (void)clearCacheForChat:(int64_t)chatId
			   completion:(void (^)(long long freed))completion;

+ (void)optimizeStorageToSize:(long long)maxBytes
				   ttlSeconds:(NSInteger)ttlSeconds
		 immunityDelaySeconds:(NSInteger)immunityDelaySeconds
					fileTypes:(NSArray *)kinds
			  excludedChatIds:(NSArray *)excludedChatIds
				   completion:(void (^)(long long freed))completion;

+ (void)clearAllDraftMessagesExcludingSecretChats:(BOOL)excludeSecretChats
									   completion:(void (^)(BOOL ok))completion;

+ (void)setAllDownloadsPaused:(BOOL)paused;

+ (void)downloadsWithQuery:(NSString *)query
				onlyActive:(BOOL)onlyActive
			 onlyCompleted:(BOOL)onlyCompleted
					offset:(NSString *)offset
					 limit:(NSInteger)limit
				completion:(void (^)(NSArray *files, NSDictionary *counts,
							   NSString *nextOffset))completion;

+ (void)suggestedFileNameForFile:(long long)fileId
					 inDirectory:(NSString *)directory
					  completion:(void (^)(NSString *name))completion;

+ (void)clearDownloadsOnlyActive:(BOOL)onlyActive
				   onlyCompleted:(BOOL)onlyCompleted
				 deleteFromCache:(BOOL)deleteFromCache;

+ (void)setDownloadPaused:(BOOL)paused forFile:(long long)fileId;

+ (void)cancelDownloadFile:(long long)fileId onlyIfPending:(BOOL)onlyIfPending;

+ (void)removeFileFromDownloads:(long long)fileId deleteFromCache:(BOOL)deleteFromCache;

+ (void)deleteCachedFile:(long long)fileId;

@end

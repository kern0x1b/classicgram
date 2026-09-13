#import "TGStorageService.h"
#import "TGClient+Storage.h"
#import "TGClient+ChatList.h"

@implementation TGStorageService

+ (void)storageStatsWithCompletion:(void (^)(long long bytes, NSInteger files))completion {
	[[TGClient shared] storageStatsWithCompletion:completion];
}

+ (void)storageOverviewWithCompletion:(void (^)(NSDictionary *overview))completion {
	[[TGClient shared] storageOverviewWithCompletion:completion];
}

+ (void)downloadTotalsWithCompletion:(void (^)(NSDictionary *counts))completion {
	[[TGClient shared] downloadTotalsWithCompletion:completion];
}

+ (void)storageUsageByFileTypeWithCompletion:
	(void (^)(NSDictionary *sizes, long long totalBytes))completion {
	[[TGClient shared] storageUsageByFileTypeWithCompletion:completion];
}

+ (void)storageUsageByChatWithLimit:(NSInteger)limit
						 completion:(void (^)(NSArray *chats))completion {
	[[TGClient shared] storageUsageByChatWithLimit:limit completion:completion];
}

+ (void)storageUsageDetailWithChatLimit:(NSInteger)limit
							  completion:(void (^)(NSDictionary *sizes, long long totalBytes,
											  NSArray *chats))completion {
	[[TGClient shared] storageUsageDetailWithChatLimit:limit completion:completion];
}

+ (void)storageUsageForChat:(int64_t)chatId
				 completion:(void (^)(long long bytes, NSInteger files))completion {
	[[TGClient shared] storageUsageForChat:chatId completion:completion];
}

+ (void)storageUsageByFileTypeForChat:(int64_t)chatId
							completion:(void (^)(NSDictionary *sizes))completion {
	[[TGClient shared] storageUsageByFileTypeForChat:chatId completion:completion];
}

+ (void)databaseStatisticsWithCompletion:(void (^)(NSString *text))completion {
	[[TGClient shared] databaseStatisticsWithCompletion:completion];
}

+ (NSDictionary *)cachePolicy {
	return [[TGClient shared] cachePolicy];
}

+ (void)setCachePolicyMaxBytes:(long long)maxBytes
					ttlSeconds:(NSInteger)ttlSeconds
			   excludedChatIds:(NSArray *)excludedChatIds {
	[[TGClient shared] setCachePolicyMaxBytes:maxBytes
								   ttlSeconds:ttlSeconds
							  excludedChatIds:excludedChatIds];
}

+ (void)applyCachePolicyMaxBytes:(long long)maxBytes
					  ttlSeconds:(NSInteger)ttlSeconds
				 excludedChatIds:(NSArray *)excludedChatIds
					  completion:(void (^)(long long freed))completion {
	[[TGClient shared] applyCachePolicyMaxBytes:maxBytes
									 ttlSeconds:ttlSeconds
								excludedChatIds:excludedChatIds
									 completion:completion];
}

+ (void)applyPersistedCachePolicyWithCompletion:(void (^)(long long freed))completion {
	[[TGClient shared] applyPersistedCachePolicyWithCompletion:completion];
}

+ (void)clearCacheCategories:(NSArray *)kinds
				  completion:(void (^)(long long freed))completion {
	[[TGClient shared] clearCacheCategories:kinds completion:completion];
}

+ (void)clearAllCacheWithCompletion:(void (^)(long long freed))completion {
	[[TGClient shared] clearAllCacheWithCompletion:completion];
}

+ (void)clearCacheForChat:(int64_t)chatId
			   completion:(void (^)(long long freed))completion {
	[[TGClient shared] clearCacheForChat:chatId completion:completion];
}

+ (void)optimizeStorageToSize:(long long)maxBytes
				   ttlSeconds:(NSInteger)ttlSeconds
		 immunityDelaySeconds:(NSInteger)immunityDelaySeconds
					fileTypes:(NSArray *)kinds
			  excludedChatIds:(NSArray *)excludedChatIds
				   completion:(void (^)(long long freed))completion {
	[[TGClient shared] optimizeStorageToSize:maxBytes
								  ttlSeconds:ttlSeconds
						immunityDelaySeconds:immunityDelaySeconds
								   fileTypes:kinds
							 excludedChatIds:excludedChatIds
								  completion:completion];
}

+ (void)clearAllDraftMessagesExcludingSecretChats:(BOOL)excludeSecretChats
									   completion:(void (^)(BOOL ok))completion {
	TGClient *client = [TGClient shared];
	[client clearAllDraftMessagesExcludingSecretChats:excludeSecretChats
										   completion:completion];
}

+ (void)setAllDownloadsPaused:(BOOL)paused {
	[[TGClient shared] setAllDownloadsPaused:paused];
}

+ (void)downloadsWithQuery:(NSString *)query
				onlyActive:(BOOL)onlyActive
			 onlyCompleted:(BOOL)onlyCompleted
					offset:(NSString *)offset
					 limit:(NSInteger)limit
				completion:(void (^)(NSArray *files, NSDictionary *counts,
							   NSString *nextOffset))completion {
	[[TGClient shared] downloadsWithQuery:query
							   onlyActive:onlyActive
							onlyCompleted:onlyCompleted
								   offset:offset
									limit:limit
							   completion:completion];
}

+ (void)suggestedFileNameForFile:(long long)fileId
					 inDirectory:(NSString *)directory
					  completion:(void (^)(NSString *name))completion {
	[[TGClient shared] suggestedFileNameForFile:fileId
									inDirectory:directory
									 completion:completion];
}

+ (void)clearDownloadsOnlyActive:(BOOL)onlyActive
				   onlyCompleted:(BOOL)onlyCompleted
				 deleteFromCache:(BOOL)deleteFromCache {
	[[TGClient shared] clearDownloadsOnlyActive:onlyActive
								  onlyCompleted:onlyCompleted
								deleteFromCache:deleteFromCache];
}

+ (void)setDownloadPaused:(BOOL)paused forFile:(long long)fileId {
	[[TGClient shared] setDownloadPaused:paused forFile:fileId];
}

+ (void)cancelDownloadFile:(long long)fileId onlyIfPending:(BOOL)onlyIfPending {
	[[TGClient shared] cancelDownloadFile:fileId onlyIfPending:onlyIfPending];
}

+ (void)removeFileFromDownloads:(long long)fileId deleteFromCache:(BOOL)deleteFromCache {
	[[TGClient shared] removeFileFromDownloads:fileId deleteFromCache:deleteFromCache];
}

+ (void)deleteCachedFile:(long long)fileId {
	[[TGClient shared] deleteCachedFile:fileId];
}

@end

#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (Storage)

#pragma mark - statistics

- (void)storageOverviewWithCompletion:(void (^ _Nullable)(NSDictionary *overview))completion;

- (void)storageUsageByFileTypeWithCompletion:
	(void (^ _Nullable)(NSDictionary *sizes, long long totalBytes))completion;

- (void)storageUsageByChatWithLimit:(NSInteger)limit
						 completion:(void (^ _Nullable)(NSArray *chats))completion;

- (void)storageUsageDetailWithChatLimit:(NSInteger)limit
							  completion:(void (^ _Nullable)(NSDictionary *sizes, long long totalBytes,
											  NSArray *chats))completion;

- (void)storageUsageForChat:(int64_t)chatId
				 completion:(void (^ _Nullable)(long long bytes, NSInteger files))completion;

- (void)storageUsageByFileTypeForChat:(int64_t)chatId
							completion:(void (^ _Nullable)(NSDictionary *sizes))completion;

- (void)databaseStatisticsWithCompletion:(void (^ _Nullable)(NSString *text))completion;

#pragma mark - clearing

- (void)clearCacheCategories:(NSArray *)kinds
				  completion:(void (^ _Nullable)(long long freed))completion;

- (void)clearAllCacheWithCompletion:(void (^ _Nullable)(long long freed))completion;

- (void)clearCacheForChat:(int64_t)chatId
			   completion:(void (^ _Nullable)(long long freed))completion;

- (void)optimizeStorageToSize:(long long)maxBytes
				   ttlSeconds:(NSInteger)ttlSeconds
		 immunityDelaySeconds:(NSInteger)immunityDelaySeconds
					fileTypes:(NSArray *)kinds
			  excludedChatIds:(NSArray * _Nullable)excludedChatIds
				   completion:(void (^ _Nullable)(long long freed))completion;

- (void)applyCachePolicyMaxBytes:(long long)maxBytes
					  ttlSeconds:(NSInteger)ttlSeconds
				 excludedChatIds:(NSArray * _Nullable)excludedChatIds
					  completion:(void (^ _Nullable)(long long freed))completion;

- (void)deleteCachedFile:(long long)fileId;

#pragma mark - downloads

- (void)cancelDownloadFile:(long long)fileId onlyIfPending:(BOOL)onlyIfPending;

- (void)addFileToDownloads:(long long)fileId
					inChat:(int64_t)chatId
				   message:(int64_t)messageId
				completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)clearDownloadsOnlyActive:(BOOL)onlyActive
				   onlyCompleted:(BOOL)onlyCompleted
				 deleteFromCache:(BOOL)deleteFromCache;

- (void)setDownloadPaused:(BOOL)paused forFile:(long long)fileId;

- (void)removeFileFromDownloads:(long long)fileId deleteFromCache:(BOOL)deleteFromCache;

- (void)setAllDownloadsPaused:(BOOL)paused;

- (void)downloadsWithQuery:(NSString *)query
				onlyActive:(BOOL)onlyActive
			 onlyCompleted:(BOOL)onlyCompleted
					offset:(NSString *)offset
					 limit:(NSInteger)limit
				completion:(void (^ _Nullable)(NSArray *files, NSDictionary *counts,
							   NSString *nextOffset))completion;

- (void)downloadTotalsWithCompletion:(void (^ _Nullable)(NSDictionary *counts))completion;

#pragma mark - network usage

- (void)networkStatsOnlyCurrent:(BOOL)onlyCurrent
					 completion:(void (^ _Nullable)(NSArray *entries, NSInteger sinceDate))completion;

- (void)networkTotalsOnlyCurrent:(BOOL)onlyCurrent
					  completion:(void (^ _Nullable)(long long sent, long long received,
									 NSDictionary *byNetwork))completion;

#pragma mark - auto-download

- (void)setAutoDownloadSettings:(NSDictionary *)settings
				 forNetworkType:(NSString *)type
					 completion:(nullable void (^)(BOOL ok))completion;

- (NSDictionary *)autoDownloadSettingsForNetworkType:(NSString *)type;

- (void)forgetAutoDownloadSettingsMirror;

- (void)autoDownloadPresetNamed:(NSString *)name
					 completion:(void (^ _Nullable)(NSDictionary *settings))completion;

- (void)applyAutoDownloadPresetNamed:(NSString *)name
					  toNetworkTypes:(NSArray *)types
						  completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - cache policy

- (NSDictionary *)cachePolicy;

- (void)setCachePolicyMaxBytes:(long long)maxBytes
					ttlSeconds:(NSInteger)ttlSeconds
			   excludedChatIds:(NSArray * _Nullable)excludedChatIds;

- (void)applyPersistedCachePolicyWithCompletion:(void (^ _Nullable)(long long freed))completion;

- (void)applyPersistedCachePolicyIfDueWithCompletion:(void (^ _Nullable)(long long freed))completion;

#pragma mark - autosave

- (void)autosaveSettingsWithCompletion:
	(void (^ _Nullable)(NSDictionary *privateChats, NSDictionary *groups,
		NSDictionary *channels))completion;

- (void)setAutosavePhotos:(BOOL)photos
				   videos:(BOOL)videos
			maxVideoBytes:(long long)maxVideoBytes
				 forScope:(NSString *)scope;

- (void)setAutosavePhotos:(BOOL)photos
				   videos:(BOOL)videos
			maxVideoBytes:(long long)maxVideoBytes
				 forScope:(NSString *)scope
			   completion:(nullable void (^)(BOOL ok))completion;

- (void)autosaveExceptionsWithCompletion:(void (^ _Nullable)(NSArray *exceptions))completion;

- (void)setAutosavePhotos:(BOOL)photos
				   videos:(BOOL)videos
			maxVideoBytes:(long long)maxVideoBytes
				  forChat:(int64_t)chatId;

- (void)clearAutosaveExceptionsWithCompletion:(nullable void (^)(BOOL ok))completion;

- (void)loadAutosaveSettingsDefaults;
- (void)applyAutosaveSettingsUpdate:(NSDictionary *)update;
- (NSDictionary *)autosaveSettingsForScope:(NSString *)scope;
- (NSString *)autosaveScopeForChat:(int64_t)chatId;
- (NSDictionary *)autosaveExceptionForChat:(int64_t)chatId;

#pragma mark - file name helpers

- (void)suggestedFileNameForFile:(long long)fileId
					 inDirectory:(NSString *)directory
					  completion:(void (^ _Nullable)(NSString *name))completion;

- (void)storageStatsWithCompletion:(void (^ _Nullable)(long long size, NSInteger count))completion;

@end

NS_ASSUME_NONNULL_END

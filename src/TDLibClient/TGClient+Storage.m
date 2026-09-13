#import "TGClient+Storage.h"
#import "TGFlattenSavedMessages.h"
#import "TGClient+Private.h"
#import "TGFlattenStorage.h"
#import "TGClient+ChatList.h"
#import "TGFlattenChatState.h"
#import "TGLocalization.h"
#import "TGStorageCachePolicyLimits.h"
#import "TGAccountManager.h"

static NSArray *TGStorageUserMediaTypes(void) {
	return [NSArray arrayWithObjects:
			@"fileTypePhoto", @"fileTypeVideo", @"fileTypeDocument",
		@"fileTypeAudio", @"fileTypeVoiceNote", @"fileTypeVideoNote",
		@"fileTypeAnimation", nil];
}

static NSArray *TGStorageAllTypes(void) {
	NSMutableArray *all = [TGStorageUserMediaTypes() mutableCopy];
	[all addObject:@"fileTypeSticker"];
	[all addObject:@"fileTypeWallpaper"];
	[all addObject:@"fileTypeThumbnail"];
	[all addObject:@"fileTypeProfilePhoto"];
	return all;
}

static NSDictionary *TGStorageDictionary(id value) {
	return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static NSArray *TGStorageArray(id value) {
	return [value isKindOfClass:[NSArray class]] ? value : [NSArray array];
}

static BOOL TGStorageFailed(NSDictionary *result) {
	return !TGStorageDictionary(result) ||
		[result[@"@type"] isEqualToString:@"error"];
}

static NSString *const TGStorageAutoDownloadDefaultsKey = @"TGStorageAutoDownloadMirror";

static NSString *TGStorageCachePolicyDefaultsKey(void) {
	return [TGAccountManager defaultsKey:@"TGStorageCachePolicy"];
}

static NSString *TGStorageCachePolicyLastAppliedDefaultsKey(void) {
	return [TGAccountManager defaultsKey:@"TGStorageCachePolicyLastApplied"];
}
static const NSTimeInterval kStorageCachePolicyReapplyInterval = 24 * 60 * 60;
static const long long TGStorageDefaultAutosaveMaxVideoBytes = 10 * 1024 * 1024;
static const NSInteger kTGStorageAllChatsLimit = 2147483647;

static NSString *TGStorageNetworkKey(NSString *type) {
	return TGStorageNetworkShortName(TGStorageNetworkTypeName(type));
}

static void TGStorageRememberAutoDownload(NSDictionary *values, NSString *type) {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	id stored = [defaults objectForKey:TGStorageAutoDownloadDefaultsKey];
	NSMutableDictionary *mirror = [TGStorageDictionary(stored) mutableCopy];
	if (!mirror)
		mirror = [NSMutableDictionary dictionary];
	mirror[TGStorageNetworkKey(type)] = TGStorageNormalizedAutoDownload(values);
	[defaults setObject:mirror forKey:TGStorageAutoDownloadDefaultsKey];
	[defaults synchronize];
}

@interface TGClient (StorageInternal)
- (void)optimizeStorageToSize:(long long)maxBytes
				   ttlSeconds:(NSInteger)ttlSeconds
		 immunityDelaySeconds:(NSInteger)immunityDelaySeconds
					fileTypes:(NSArray *)kinds
					  chatIds:(NSArray *)chatIds
			  excludedChatIds:(NSArray *)excludedChatIds
				   completion:(void (^)(long long freed))completion;
- (NSString *)nameOfDownloadedFileInMessage:(NSDictionary *)message fileId:(long long)fileId;
- (NSDictionary *)fileInMessage:(NSDictionary *)message withId:(long long)fileId;
- (NSDictionary *)flattenAutosave:(id)value;
- (void)storeAutosaveSettings:(NSDictionary *)settings forScope:(NSString *)scope;
@end

@implementation TGClient (Storage)

#pragma mark - statistics

- (void)storageOverviewWithCompletion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getStorageStatisticsFast"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGStorageFailed(result)) {
				completion(nil);
				return;
			}
			long long files = [result[@"files_size"] longLongValue];
			long long database = [result[@"database_size"] longLongValue];
			long long pack = [result[@"language_pack_database_size"] longLongValue];
			long long log = [result[@"log_size"] longLongValue];
			completion(@{
				@"files" : @(files),
				@"fileCount" : @([result[@"file_count"] integerValue]),
				@"database" : @(database),
				@"languagePack" : @(pack),
				@"log" : @(log),
				@"total" : @(files + database + pack + log),
			});
		}];
}

- (void)storageUsageByFileTypeWithCompletion:
	(void (^)(NSDictionary *, long long))completion {
	[self request:@{@"@type" : @"getStorageStatistics", @"chat_limit" : @(0)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGStorageFailed(result)) {
				completion([NSDictionary dictionary], 0);
				return;
			}
			completion(TGStorageSizesByFileType(result), [result[@"size"] longLongValue]);
		}];
}

- (NSArray *)chatRowsFromByChatArray:(NSArray *)byChatArray {
	NSMutableArray *out = [NSMutableArray array];
	for (id chatEntry in byChatArray) {
		NSDictionary *byChat = TGStorageDictionary(chatEntry);
		if (!byChat)
			continue;
		NSNumber *chatId = [byChat[@"chat_id"] isKindOfClass:[NSNumber class]]
			? byChat[@"chat_id"]
			: @0;
		NSDictionary *known = TGStorageDictionary(self.chatsById[chatId]);
		NSString *title = known[@"title"];
		if (![title isKindOfClass:[NSString class]])
			title = @"";
		[out addObject:@{
			@"chatId" : chatId,
			@"title" : title,
			@"size" : @([byChat[@"size"] longLongValue]),
			@"count" : @([byChat[@"count"] integerValue]),
		}];
	}
	[out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
		long long sa = [a[@"size"] longLongValue];
		long long sb = [b[@"size"] longLongValue];
		if (sa == sb)
			return NSOrderedSame;
		return sa > sb ? NSOrderedAscending : NSOrderedDescending;
	}];
	return out;
}

- (void)resolveTitlesForChatRows:(NSArray *)rows completion:(void (^)(NSArray *))completion {
	NSArray *missing = TGStorageChatIdsMissingTitles(rows);
	if (!missing.count) {
		completion(rows);
		return;
	}
	[self titlesForChatIds:missing completion:^(NSDictionary *titles) {
		completion(TGStorageChatRowsWithTitles(rows, titles));
	}];
}

- (void)storageUsageByChatWithLimit:(NSInteger)limit
						 completion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getStorageStatistics", @"chat_limit" : @(limit)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGStorageFailed(result)) {
				completion([NSArray array]);
				return;
			}
			[self resolveTitlesForChatRows:[self chatRowsFromByChatArray:TGStorageArray(result[@"by_chat"])]
								completion:completion];
		}];
}

- (void)storageUsageDetailWithChatLimit:(NSInteger)limit
							  completion:(void (^)(NSDictionary *, long long, NSArray *))completion {
	[self request:@{@"@type" : @"getStorageStatistics", @"chat_limit" : @(limit)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGStorageFailed(result)) {
				completion([NSDictionary dictionary], 0, [NSArray array]);
				return;
			}
			NSDictionary *sizes = TGStorageSizesByFileType(result);
			long long total = [result[@"size"] longLongValue];
			[self resolveTitlesForChatRows:[self chatRowsFromByChatArray:TGStorageArray(result[@"by_chat"])]
								completion:^(NSArray *chats) {
									completion(sizes, total, chats);
								}];
		}];
}

- (void)storageUsageForChat:(int64_t)chatId
				 completion:(void (^)(long long, NSInteger))completion {
	[self storageUsageByChatWithLimit:kTGStorageAllChatsLimit completion:^(NSArray *chats) {
		if (!completion)
			return;
		for (NSDictionary *entry in chats) {
			if ([entry[@"chatId"] longLongValue] == chatId) {
				completion([entry[@"size"] longLongValue],
					[entry[@"count"] integerValue]);
				return;
			}
		}
		completion(0, 0);
	}];
}

- (void)storageUsageByFileTypeForChat:(int64_t)chatId
							completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getStorageStatistics", @"chat_limit" : @(kTGStorageAllChatsLimit)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGStorageFailed(result)) {
				completion([NSDictionary dictionary]);
				return;
			}
			NSMutableDictionary *sizes = [NSMutableDictionary dictionary];
			for (id chatEntry in TGStorageArray(result[@"by_chat"])) {
				NSDictionary *byChat = TGStorageDictionary(chatEntry);
				if (!byChat || [byChat[@"chat_id"] longLongValue] != chatId)
					continue;
				for (id typeEntry in TGStorageArray(byChat[@"by_file_type"])) {
					NSDictionary *byType = TGStorageDictionary(typeEntry);
					NSDictionary *kind = TGStorageDictionary(byType[@"file_type"]);
					NSString *name = kind[@"@type"];
					if (![name isKindOfClass:[NSString class]])
						continue;
					sizes[name] = @{@"size" : byType[@"size"] ?: @0,
						@"count" : byType[@"count"] ?: @0};
				}
				break;
			}
			completion(sizes);
		}];
}

- (void)databaseStatisticsWithCompletion:(void (^)(NSString *))completion {
	[self request:@{@"@type" : @"getDatabaseStatistics"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			NSString *text = TGStorageFailed(result) ? nil : result[@"statistics"];
			completion([text isKindOfClass:[NSString class]] ? text : nil);
		}];
}

#pragma mark - clearing

- (void)optimizeStorageToSize:(long long)maxBytes
				   ttlSeconds:(NSInteger)ttlSeconds
		 immunityDelaySeconds:(NSInteger)immunityDelaySeconds
					fileTypes:(NSArray *)kinds
			  excludedChatIds:(NSArray *)excludedChatIds
				   completion:(void (^)(long long))completion {
	[self optimizeStorageToSize:maxBytes
					 ttlSeconds:ttlSeconds
		   immunityDelaySeconds:immunityDelaySeconds
					  fileTypes:kinds
						chatIds:nil
				excludedChatIds:excludedChatIds
					 completion:completion];
}

- (void)optimizeStorageToSize:(long long)maxBytes
				   ttlSeconds:(NSInteger)ttlSeconds
		 immunityDelaySeconds:(NSInteger)immunityDelaySeconds
					fileTypes:(NSArray *)kinds
					  chatIds:(NSArray *)chatIds
			  excludedChatIds:(NSArray *)excludedChatIds
				   completion:(void (^)(long long))completion {
	NSMutableArray *types = [NSMutableArray array];
	for (NSString *kind in TGStorageArray(kinds)) {
		if ([kind isKindOfClass:[NSString class]])
			[types addObject:@{@"@type" : kind}];
	}
	[self request:@{
		@"@type" : @"optimizeStorage",
		@"size" : @(maxBytes),
		@"ttl" : @(ttlSeconds),
		@"count" : @(-1),
		@"immunity_delay" : @(immunityDelaySeconds),
		@"file_types" : types,
		@"chat_ids" : TGStorageArray(chatIds),
		@"exclude_chat_ids" : TGStorageArray(excludedChatIds),
		@"return_deleted_file_statistics" : @YES,
		@"chat_limit" : @(0),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGStorageFailed(result) ? 0 : TGStorageFreedBytes(result));
	}];
}

- (void)clearCacheCategories:(NSArray *)kinds
				  completion:(void (^)(long long))completion {
	NSArray *types = TGStorageArray(kinds).count ? kinds : TGStorageUserMediaTypes();
	[self optimizeStorageToSize:0
					 ttlSeconds:0
		   immunityDelaySeconds:0
					  fileTypes:types
				excludedChatIds:nil
					 completion:completion];
}

- (void)clearAllCacheWithCompletion:(void (^)(long long))completion {
	[self optimizeStorageToSize:0
					 ttlSeconds:0
		   immunityDelaySeconds:0
					  fileTypes:TGStorageAllTypes()
				excludedChatIds:nil
					 completion:completion];
}

- (void)clearCacheForChat:(int64_t)chatId
			   completion:(void (^)(long long))completion {
	[self optimizeStorageToSize:0
					 ttlSeconds:0
		   immunityDelaySeconds:0
					  fileTypes:TGStorageAllTypes()
						chatIds:@[ @(chatId) ]
				excludedChatIds:nil
					 completion:completion];
}

- (void)applyCachePolicyMaxBytes:(long long)maxBytes
					  ttlSeconds:(NSInteger)ttlSeconds
				 excludedChatIds:(NSArray *)excludedChatIds
					  completion:(void (^)(long long))completion {
	TGStorageCachePolicyEffectiveLimits limits = TGStorageCachePolicyEffectiveLimitsForPolicy(maxBytes, ttlSeconds);
	if (!limits.shouldRun) {
		if (completion)
			completion(0);
		return;
	}
	[self optimizeStorageToSize:limits.effectiveMaxBytes
					 ttlSeconds:limits.effectiveTTLSeconds
		   immunityDelaySeconds:60 * 60
					  fileTypes:TGStorageUserMediaTypes()
				excludedChatIds:excludedChatIds
					 completion:completion];
}

- (void)deleteCachedFile:(long long)fileId {
	[self send:@{@"@type" : @"deleteFile", @"file_id" : @(fileId)}];
}

#pragma mark - downloads

- (void)cancelDownloadFile:(long long)fileId onlyIfPending:(BOOL)onlyIfPending {
	[self send:@{
		@"@type" : @"cancelDownloadFile",
		@"file_id" : @(fileId),
		@"only_if_pending" : @(onlyIfPending),
	}];
}

- (void)addFileToDownloads:(long long)fileId
					inChat:(int64_t)chatId
				   message:(int64_t)messageId
				completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"addFileToDownloads",
		@"file_id" : @(fileId),
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"priority" : @(1),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGStorageFailed(result));
	}];
}

- (void)clearDownloadsOnlyActive:(BOOL)onlyActive
				   onlyCompleted:(BOOL)onlyCompleted
				 deleteFromCache:(BOOL)deleteFromCache {
	[self send:@{
		@"@type" : @"removeAllFilesFromDownloads",
		@"only_active" : @(onlyActive),
		@"only_completed" : @(onlyCompleted),
		@"delete_from_cache" : @(deleteFromCache),
	}];
}

- (void)setDownloadPaused:(BOOL)paused forFile:(long long)fileId {
	[self send:@{
		@"@type" : @"toggleDownloadIsPaused",
		@"file_id" : @(fileId),
		@"is_paused" : @(paused),
	}];
}

- (void)removeFileFromDownloads:(long long)fileId deleteFromCache:(BOOL)deleteFromCache {
	[self send:@{
		@"@type" : @"removeFileFromDownloads",
		@"file_id" : @(fileId),
		@"delete_from_cache" : @(deleteFromCache),
	}];
}

- (void)setAllDownloadsPaused:(BOOL)paused {
	[self send:@{
		@"@type" : @"toggleAllDownloadsArePaused",
		@"are_paused" : @(paused),
	}];
}

- (NSString *)nameOfDownloadedFileInMessage:(NSDictionary *)message fileId:(long long)fileId {
	NSDictionary *content = TGStorageDictionary(message[@"content"]);
	NSArray *holders = [NSArray arrayWithObjects:@"document", @"audio", @"video",
		@"animation", @"voice_note", @"video_note", nil];
	for (NSString *key in holders) {
		NSDictionary *holder = TGStorageDictionary(content[key]);
		if (!holder)
			continue;
		NSString *name = holder[@"file_name"];
		if ([name isKindOfClass:[NSString class]] && name.length)
			return name;
		NSString *title = holder[@"title"];
		if ([title isKindOfClass:[NSString class]] && title.length)
			return title;
	}
	NSString *preview = TGSavedPreview(@{@"content" : content ?: @{}});
	if (preview.length)
		return preview;
	return [NSString stringWithFormat:TGL(@"Storage.FileNumbered", @"File %lld"), fileId];
}

- (NSDictionary *)fileInMessage:(NSDictionary *)message withId:(long long)fileId {
	NSDictionary *content = TGStorageDictionary(message[@"content"]);
	NSArray *holders = [NSArray arrayWithObjects:@"document", @"audio", @"video",
		@"animation", @"voice_note", @"video_note", @"sticker", nil];
	for (NSString *key in holders) {
		NSDictionary *holder = TGStorageDictionary(content[key]);
		NSDictionary *file = TGStorageDictionary(holder[key]) ?: TGStorageDictionary(holder[@"document"]) ?
			: TGStorageDictionary(holder[@"video"])														  ?
			: TGStorageDictionary(holder[@"audio"])														  ?
			: TGStorageDictionary(holder[@"voice"])														  ?
			: TGStorageDictionary(holder[@"animation"])													  ?
																										  : TGStorageDictionary(holder[@"sticker"]);
		if (file && [file[@"id"] longLongValue] == fileId)
			return file;
	}
	for (id size in TGStorageArray(TGStorageDictionary(content[@"photo"])[@"sizes"])) {
		NSDictionary *file = TGStorageDictionary(TGStorageDictionary(size)[@"photo"]);
		if (file && [file[@"id"] longLongValue] == fileId)
			return file;
	}
	return nil;
}

- (void)downloadsWithQuery:(NSString *)query
				onlyActive:(BOOL)onlyActive
			 onlyCompleted:(BOOL)onlyCompleted
					offset:(NSString *)offset
					 limit:(NSInteger)limit
				completion:(void (^)(NSArray *, NSDictionary *, NSString *))completion {
	[self request:@{
		@"@type" : @"searchFileDownloads",
		@"query" : query ?: @"",
		@"only_active" : @(onlyActive),
		@"only_completed" : @(onlyCompleted),
		@"offset" : offset ?: @"",
		@"limit" : @(limit > 0 ? limit : 20),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGStorageFailed(result)) {
			completion([NSArray array], @{@"active" : @0,
				@"paused" : @0,
				@"completed" : @0},
				@"");
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (id entry in TGStorageArray(result[@"files"])) {
			NSDictionary *download = TGStorageDictionary(entry);
			if (!download)
				continue;
			long long fileId = [download[@"file_id"] longLongValue];
			NSDictionary *message = TGStorageDictionary(download[@"message"]);
			NSDictionary *file = [self fileInMessage:message withId:fileId];
			NSDictionary *local = TGStorageDictionary(file[@"local"]);
			NSInteger complete = [download[@"complete_date"] integerValue];
			[out addObject:@{
				@"fileId" : @(fileId),
				@"chatId" : message[@"chat_id"] ?: @0,
				@"messageId" : message[@"id"] ?: @0,
				@"name" : [self nameOfDownloadedFileInMessage:message fileId:fileId],
				@"size" : file[@"size"] ?: @0,
				@"downloaded" : local[@"downloaded_size"] ?: @0,
				@"isPaused" : download[@"is_paused"] ?: @NO,
				@"isComplete" : @(complete != 0),
				@"date" : download[@"add_date"] ?: @0,
			}];
		}
		NSDictionary *totals = TGStorageDictionary(result[@"total_counts"]);
		NSDictionary *counts = @{
			@"active" : totals[@"active_count"] ?: @0,
			@"paused" : totals[@"paused_count"] ?: @0,
			@"completed" : totals[@"completed_count"] ?: @0,
		};
		NSString *next = result[@"next_offset"];
		completion(out, counts,
			[next isKindOfClass:[NSString class]] ? next : @"");
	}];
}

#pragma mark - network usage

- (void)networkStatsOnlyCurrent:(BOOL)onlyCurrent
					 completion:(void (^)(NSArray *, NSInteger))completion {
	[self request:@{@"@type" : @"getNetworkStatistics", @"only_current" : @(onlyCurrent)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGStorageFailed(result)) {
				completion([NSArray array], 0);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			for (id item in TGStorageArray(result[@"entries"])) {
				NSDictionary *entry = TGStorageDictionary(item);
				if (!entry)
					continue;
				BOOL isCall = [entry[@"@type"] isEqualToString:@"networkStatisticsEntryCall"];
				NSString *kind = @"calls";
				if (!isCall) {
					NSString *name = TGStorageDictionary(entry[@"file_type"])[@"@type"];
					kind = [name isKindOfClass:[NSString class]] ? name : @"fileTypeUnknown";
				}
				NSString *network = TGStorageDictionary(entry[@"network_type"])[@"@type"];
				[out addObject:@{
					@"kind" : kind,
					@"network" : TGStorageNetworkShortName(
						[network isKindOfClass:[NSString class]] ? network : @""),
					@"sent" : entry[@"sent_bytes"] ?: @0,
					@"received" : entry[@"received_bytes"] ?: @0,
					@"duration" : entry[@"duration"] ?: @0,
				}];
			}
			completion(out, [result[@"since_date"] integerValue]);
		}];
}

- (void)networkTotalsOnlyCurrent:(BOOL)onlyCurrent
					  completion:(void (^)(long long, long long, NSDictionary *))completion {
	[self networkStatsOnlyCurrent:onlyCurrent
					   completion:^(NSArray *entries, NSInteger sinceDate) {
						   if (!completion)
							   return;
						   long long sent = 0;
						   long long received = 0;
						   NSMutableDictionary *byNetwork = [NSMutableDictionary dictionary];
						   for (NSDictionary *entry in entries) {
							   long long entrySent = [entry[@"sent"] longLongValue];
							   long long entryReceived = [entry[@"received"] longLongValue];
							   sent += entrySent;
							   received += entryReceived;
							   NSString *network = entry[@"network"] ?: @"other";
							   NSDictionary *have = byNetwork[network];
							   byNetwork[network] = @{
								   @"sent" : @([have[@"sent"] longLongValue] + entrySent),
								   @"received" : @([have[@"received"] longLongValue] + entryReceived),
							   };
						   }
						   completion(sent, received, byNetwork);
					   }];
}

#pragma mark - auto-download

- (void)setAutoDownloadSettings:(NSDictionary *)settings
				 forNetworkType:(NSString *)type
					 completion:(void (^)(BOOL ok))completion {
	NSDictionary *values = TGStorageDictionary(settings) ?: [NSDictionary dictionary];
	TGStorageRememberAutoDownload(values, type);
	[self request:@{
		@"@type" : @"setAutoDownloadSettings",
		@"settings" : @{
			@"@type" : @"autoDownloadSettings",
			@"is_auto_download_enabled" : values[@"enabled"] ?: @NO,
			@"max_photo_file_size" : values[@"maxPhotoSize"] ?: @(1024 * 1024),
			@"max_video_file_size" : values[@"maxVideoSize"] ?: @(0),
			@"max_other_file_size" : values[@"maxOtherSize"] ?: @(0),
			@"video_upload_bitrate" : values[@"videoUploadBitrate"] ?: @(0),
			@"preload_large_videos" : values[@"preloadLargeVideos"] ?: @NO,
			@"preload_next_audio" : values[@"preloadNextAudio"] ?: @NO,
			@"preload_stories" : values[@"preloadStories"] ?: @NO,
			@"use_less_data_for_calls" : values[@"useLessDataForCalls"] ?: @YES,
		},
		@"type" : @{@"@type" : TGStorageNetworkTypeName(type)},
	}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGStorageFailed(result));
		}];
}

#pragma mark - autosave

- (NSDictionary *)flattenAutosave:(id)value {
	NSDictionary *scope = TGStorageDictionary(value);
	if (!scope)
		return nil;
	return @{
		@"photos" : scope[@"autosave_photos"] ?: @NO,
		@"videos" : scope[@"autosave_videos"] ?: @NO,
		@"maxVideoBytes" : scope[@"max_video_file_size"] ?: @0,
	};
}

- (void)autosaveSettingsWithCompletion:
	(void (^)(NSDictionary *, NSDictionary *, NSDictionary *))completion {
	[self request:@{@"@type" : @"getAutosaveSettings"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGStorageFailed(result)) {
				completion(nil, nil, nil);
				return;
			}
			completion([self flattenAutosave:result[@"private_chat_settings"]],
				[self flattenAutosave:result[@"group_settings"]],
				[self flattenAutosave:result[@"channel_settings"]]);
		}];
}

- (void)setAutosavePhotos:(BOOL)photos
				   videos:(BOOL)videos
			maxVideoBytes:(long long)maxVideoBytes
				 forScope:(NSString *)scope {
	[self setAutosavePhotos:photos videos:videos maxVideoBytes:maxVideoBytes forScope:scope completion:nil];
}

- (void)setAutosavePhotos:(BOOL)photos
				   videos:(BOOL)videos
			maxVideoBytes:(long long)maxVideoBytes
				 forScope:(NSString *)scope
			   completion:(void (^)(BOOL ok))completion {
	NSString *scopeType = @"autosaveSettingsScopePrivateChats";
	if ([scope isEqualToString:@"groups"])
		scopeType = @"autosaveSettingsScopeGroupChats";
	else if ([scope isEqualToString:@"channels"])
		scopeType = @"autosaveSettingsScopeChannelChats";
	[self request:@{
		@"@type" : @"setAutosaveSettings",
		@"scope" : @{@"@type" : scopeType},
		@"settings" : @{
			@"@type" : @"scopeAutosaveSettings",
			@"autosave_photos" : @(photos),
			@"autosave_videos" : @(videos),
			@"max_video_file_size" : @(maxVideoBytes > 0 ? maxVideoBytes : TGStorageDefaultAutosaveMaxVideoBytes),
		},
	}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGStorageFailed(result));
		}];
}

- (void)clearAutosaveExceptionsWithCompletion:(void (^)(BOOL ok))completion {
	[self request:@{@"@type" : @"clearAutosaveSettingsExceptions"}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGStorageFailed(result));
		}];
}

- (void)storeAutosaveSettings:(NSDictionary *)settings forScope:(NSString *)scope {
	if (settings)
		self.autosaveSettingsByScope[scope] = settings;
	else
		[self.autosaveSettingsByScope removeObjectForKey:scope];
}

- (void)loadAutosaveSettingsDefaults {
	__weak typeof(self) weakSelf = self;
	[self autosaveSettingsWithCompletion:^(NSDictionary *privateChats, NSDictionary *groups,
			NSDictionary *channels) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf storeAutosaveSettings:privateChats forScope:@"private"];
		[strongSelf storeAutosaveSettings:groups forScope:@"groups"];
		[strongSelf storeAutosaveSettings:channels forScope:@"channels"];
	}];
	[self autosaveExceptionsWithCompletion:^(NSArray *exceptions) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf.autosaveExceptionsByChatId removeAllObjects];
		for (NSDictionary *entry in exceptions) {
			NSNumber *chatId = [entry[@"chatId"] isKindOfClass:[NSNumber class]]
				? entry[@"chatId"]
				: nil;
			if (chatId)
				strongSelf.autosaveExceptionsByChatId[chatId] = entry;
		}
	}];
}

- (void)applyAutosaveSettingsUpdate:(NSDictionary *)update {
	NSDictionary *scope = TGStorageDictionary(update[@"scope"]);
	NSString *scopeType = scope[@"@type"];
	NSDictionary *settings = [self flattenAutosave:update[@"settings"]];

	if ([scopeType isEqualToString:@"autosaveSettingsScopeChat"]) {
		NSNumber *chatId = [scope[@"chat_id"] isKindOfClass:[NSNumber class]]
			? scope[@"chat_id"]
			: nil;
		if (!chatId)
			return;
		if (settings) {
			NSMutableDictionary *row = [settings mutableCopy];
			row[@"chatId"] = chatId;
			self.autosaveExceptionsByChatId[chatId] = row;
		} else {
			[self.autosaveExceptionsByChatId removeObjectForKey:chatId];
		}
		return;
	}

	NSString *scopeName = @"private";
	if ([scopeType isEqualToString:@"autosaveSettingsScopeGroupChats"])
		scopeName = @"groups";
	else if ([scopeType isEqualToString:@"autosaveSettingsScopeChannelChats"])
		scopeName = @"channels";
	[self storeAutosaveSettings:settings forScope:scopeName];
}

- (NSDictionary *)autosaveSettingsForScope:(NSString *)scope {
	return self.autosaveSettingsByScope[scope ?: @""];
}

- (NSString *)autosaveScopeForChat:(int64_t)chatId {
	NSDictionary *info = self.chatsById[@(chatId)];
	return TGScopeForChatFlags([info[@"isChannel"] boolValue], [info[@"isGroup"] boolValue]);
}

- (NSDictionary *)autosaveExceptionForChat:(int64_t)chatId {
	return self.autosaveExceptionsByChatId[@(chatId)];
}

#pragma mark - file name helpers

- (void)suggestedFileNameForFile:(long long)fileId
					 inDirectory:(NSString *)directory
					  completion:(void (^)(NSString *))completion {
	[self request:@{
		@"@type" : @"getSuggestedFileName",
		@"file_id" : @(fileId),
		@"directory" : directory ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSString *text = TGStorageFailed(result) ? nil : result[@"text"];
		completion([text isKindOfClass:[NSString class]] ? text : nil);
	}];
}

#pragma mark - auto-download mirror and presets

- (NSDictionary *)autoDownloadSettingsForNetworkType:(NSString *)type {
	id stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGStorageAutoDownloadDefaultsKey];
	NSDictionary *mirror = TGStorageDictionary(stored);
	return TGStorageDictionary(mirror[TGStorageNetworkKey(type)]);
}

- (void)forgetAutoDownloadSettingsMirror {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:TGStorageAutoDownloadDefaultsKey];
	[defaults synchronize];
}

- (void)autoDownloadPresetNamed:(NSString *)name
					 completion:(void (^)(NSDictionary *))completion {
	NSString *wanted = [(name ?: @"medium") lowercaseString];
	if (![wanted isEqualToString:@"low"] && ![wanted isEqualToString:@"high"])
		wanted = @"medium";
	[self request:@{@"@type" : @"getAutoDownloadSettingsPresets"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGStorageFailed(result)) {
				completion(nil);
				return;
			}
			NSDictionary *preset = TGStorageDictionary(result[wanted]);
			completion(preset ? TGStorageAutoDownloadFromPreset(preset) : nil);
		}];
}

- (void)applyAutoDownloadPresetNamed:(NSString *)name
					  toNetworkTypes:(NSArray *)types
						  completion:(void (^)(BOOL))completion {
	NSArray *targets = [types isKindOfClass:[NSArray class]] && types.count ? types : [NSArray arrayWithObjects:@"wifi", @"mobile", @"roaming", @"other", nil];
	[self autoDownloadPresetNamed:name completion:^(NSDictionary *settings) {
		if (!settings) {
			if (completion)
				completion(NO);
			return;
		}
		NSMutableArray *stringTargets = [NSMutableArray array];
		for (id target in targets) {
			if ([target isKindOfClass:[NSString class]])
				[stringTargets addObject:target];
		}
		if (!stringTargets.count) {
			if (completion)
				completion(YES);
			return;
		}
		__block NSInteger remaining = (NSInteger)stringTargets.count;
		__block BOOL anyFailed = NO;
		for (NSString *target in stringTargets) {
			[self setAutoDownloadSettings:settings
							forNetworkType:target
								completion:^(BOOL ok) {
				if (!ok)
					anyFailed = YES;
				remaining--;
				if (remaining > 0)
					return;
				if (completion)
					completion(!anyFailed);
			}];
		}
	}];
}

#pragma mark - cache policy

- (NSDictionary *)cachePolicy {
	id stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGStorageCachePolicyDefaultsKey()];
	NSDictionary *policy = TGStorageDictionary(stored);
	NSArray *excluded = [policy[@"excludedChatIds"] isKindOfClass:[NSArray class]] ? policy[@"excludedChatIds"] : [NSArray array];
	return @{
		@"maxBytes" : policy[@"maxBytes"] ?: @(-1),
		@"ttlSeconds" : policy[@"ttlSeconds"] ?: @(-1),
		@"excludedChatIds" : excluded,
	};
}

- (void)setCachePolicyMaxBytes:(long long)maxBytes
					ttlSeconds:(NSInteger)ttlSeconds
			   excludedChatIds:(NSArray *)excludedChatIds {
	NSMutableArray *chats = [NSMutableArray array];
	for (id chatId in TGStorageArray(excludedChatIds)) {
		if ([chatId isKindOfClass:[NSNumber class]])
			[chats addObject:chatId];
	}
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:@{
		@"maxBytes" : @(maxBytes),
		@"ttlSeconds" : @(ttlSeconds),
		@"excludedChatIds" : chats,
	}
				 forKey:TGStorageCachePolicyDefaultsKey()];
	[defaults synchronize];
}

- (void)applyPersistedCachePolicyWithCompletion:(void (^)(long long))completion {
	NSDictionary *policy = [self cachePolicy];
	[self applyCachePolicyMaxBytes:[policy[@"maxBytes"] longLongValue]
						ttlSeconds:[policy[@"ttlSeconds"] integerValue]
				   excludedChatIds:policy[@"excludedChatIds"]
						completion:completion];
}

- (void)applyPersistedCachePolicyIfDueWithCompletion:(void (^)(long long))completion {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	NSTimeInterval last = [defaults doubleForKey:TGStorageCachePolicyLastAppliedDefaultsKey()];
	if (last > 0 && now - last < kStorageCachePolicyReapplyInterval) {
		if (completion)
			completion(0);
		return;
	}
	[defaults setDouble:now forKey:TGStorageCachePolicyLastAppliedDefaultsKey()];
	[defaults synchronize];
	[self applyPersistedCachePolicyWithCompletion:completion];
}

#pragma mark - autosave exceptions

- (void)autosaveExceptionsWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getAutosaveSettings"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGStorageFailed(result)) {
				completion([NSArray array]);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			for (id item in TGStorageArray(result[@"exceptions"])) {
				NSDictionary *exception = TGStorageDictionary(item);
				if (!exception)
					continue;
				NSDictionary *settings = [self flattenAutosave:exception[@"settings"]];
				if (!settings)
					continue;
				NSMutableDictionary *row = [settings mutableCopy];
				row[@"chatId"] = exception[@"chat_id"] ?: @0;
				[out addObject:row];
			}
			completion(out);
		}];
}

- (void)setAutosavePhotos:(BOOL)photos
				   videos:(BOOL)videos
			maxVideoBytes:(long long)maxVideoBytes
				  forChat:(int64_t)chatId {
	[self send:@{
		@"@type" : @"setAutosaveSettings",
		@"scope" : @{@"@type" : @"autosaveSettingsScopeChat",
			@"chat_id" : @(chatId)},
		@"settings" : @{
			@"@type" : @"scopeAutosaveSettings",
			@"autosave_photos" : @(photos),
			@"autosave_videos" : @(videos),
			@"max_video_file_size" : @(maxVideoBytes > 0 ? maxVideoBytes : TGStorageDefaultAutosaveMaxVideoBytes),
		},
	}];
}

#pragma mark - download totals

- (void)downloadTotalsWithCompletion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"searchFileDownloads",
		@"query" : @"",
		@"only_active" : @NO,
		@"only_completed" : @NO,
		@"offset" : @"",
		@"limit" : @(1),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSDictionary *totals = TGStorageFailed(result) ? nil : TGStorageDictionary(result[@"total_counts"]);
		completion(@{
			@"active" : totals[@"active_count"] ?: @0,
			@"paused" : totals[@"paused_count"] ?: @0,
			@"completed" : totals[@"completed_count"] ?: @0,
		});
	}];
}

- (void)storageStatsWithCompletion:(void (^)(long long, NSInteger))completion {
	[self request:@{@"@type" : @"getStorageStatisticsFast"}
		completion:^(NSDictionary *stats) {
			if (completion)
				completion([stats[@"files_size"] longLongValue],
					[stats[@"file_count"] integerValue]);
		}];
}

@end

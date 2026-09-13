#import "TGClient+UpdateHandling.h"
#import "TGClient+Private.h"
#import "TGClient+Files.h"
#import "TGFlattenFiles.h"

NSString *const TGFileTypePhoto = @"fileTypePhoto";
NSString *const TGFileTypeVideo = @"fileTypeVideo";
NSString *const TGFileTypeDocument = @"fileTypeDocument";
NSString *const TGFileTypeSticker = @"fileTypeSticker";
NSString *const TGFileTypeAudio = @"fileTypeAudio";
NSString *const TGFileTypeVoiceNote = @"fileTypeVoiceNote";
NSString *const TGFileTypeAnimation = @"fileTypeAnimation";
NSString *const TGFileTypeThumbnail = @"fileTypeThumbnail";

NSString *const TGNetworkTypeWiFi = @"networkTypeWiFi";
NSString *const TGNetworkTypeMobile = @"networkTypeMobile";
NSString *const TGNetworkTypeMobileRoaming = @"networkTypeMobileRoaming";
NSString *const TGNetworkTypeOther = @"networkTypeOther";
NSString *const TGNetworkTypeNone = @"networkTypeNone";

static NSArray *TGFilesArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : nil;
}

static NSDictionary *TGFilesDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSString *TGFilesString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static const NSTimeInterval kSynchronousDownloadDeadline = 21600.0;

@implementation TGClient (Files)

#pragma mark - file state

- (void)fileInfo:(long long)fileId completion:(void (^)(NSDictionary *))completion {
	if (fileId <= 0) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{@"@type" : @"getFile", @"file_id" : @(fileId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(TGResultIsError(result) ? nil : TGFileInfo(result));
		}];
}

- (void)resolveRemoteFileId:(NSString *)remoteId
					   type:(NSString *)type
				 completion:(void (^)(NSDictionary *))completion {
	if (!remoteId.length) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{
		@"@type" : @"getRemoteFile",
		@"remote_file_id" : remoteId,
		@"file_type" : @{@"@type" : type.length ? type : TGFileTypeDocument},
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGFileInfo(result));
	}];
}

#pragma mark - downloading

- (void)startDownloadingFile:(long long)fileId
					priority:(NSInteger)priority
				  completion:(void (^)(NSDictionary *))completion {
	if (fileId <= 0) {
		if (completion)
			completion(nil);
		return;
	}
	if (priority < 1)
		priority = 1;
	if (priority > 32)
		priority = 32;
	self.downloadPriorityHints[@(fileId)] = @(priority);
	[self request:@{
		@"@type" : @"downloadFile",
		@"file_id" : @(fileId),
		@"priority" : @(priority),
		@"offset" : @(0),
		@"limit" : @(0),
		@"synchronous" : @NO,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGFileInfo(result));
	}];
}

- (void)cancelDownloadOfFile:(long long)fileId onlyIfPending:(BOOL)onlyIfPending {
	if (fileId <= 0)
		return;
	[self send:@{
		@"@type" : @"cancelDownloadFile",
		@"file_id" : @(fileId),
		@"only_if_pending" : @(onlyIfPending),
	}];
}

- (void)deleteCachedFile:(long long)fileId completion:(void (^)(BOOL))completion {
	if (fileId <= 0) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{@"@type" : @"deleteFile", @"file_id" : @(fileId)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)suggestedFileNameForFile:(long long)fileId
					  completion:(void (^)(NSString *))completion {
	if (fileId <= 0) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{
		@"@type" : @"getSuggestedFileName",
		@"file_id" : @(fileId),
		@"directory" : @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSString *text = TGFilesString(result[@"text"]);
		completion(text.length ? text : nil);
	}];
}

#pragma mark - downloads list

- (void)addFileToDownloads:(long long)fileId
					inChat:(int64_t)chatId
				 messageId:(int64_t)messageId
				  priority:(NSInteger)priority
				completion:(void (^)(NSDictionary *))completion {
	if (fileId <= 0 || messageId == 0) {
		if (completion)
			completion(nil);
		return;
	}
	if (priority < 1)
		priority = 1;
	if (priority > 32)
		priority = 32;
	[self request:@{
		@"@type" : @"addFileToDownloads",
		@"file_id" : @(fileId),
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId),
		@"priority" : @(priority),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGFileInfo(result));
	}];
}

- (void)searchDownloadsWithQuery:(NSString *)query
					  onlyActive:(BOOL)onlyActive
				   onlyCompleted:(BOOL)onlyCompleted
						  offset:(NSString *)offset
						   limit:(NSInteger)limit
					  completion:(void (^)(NSDictionary *))completion {
	if (limit <= 0)
		limit = 30;
	[self request:@{
		@"@type" : @"searchFileDownloads",
		@"query" : query ?: @"",
		@"only_active" : @(onlyActive),
		@"only_completed" : @(onlyCompleted),
		@"offset" : offset ?: @"",
		@"limit" : @(limit),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}

		NSMutableArray *downloads = [NSMutableArray array];
		for (NSDictionary *entry in TGFilesArray(result[@"files"])) {
			if (![entry isKindOfClass:NSDictionary.class])
				continue;
			NSDictionary *message = TGFilesDict(entry[@"message"]) ?: @{};
			NSDictionary *media = TGFileOfMessageContent(TGFilesDict(message[@"content"]),
				[entry[@"file_id"] longLongValue]);
			NSDictionary *file = TGFileInfo(media[@"file"]);
			[downloads addObject:@{
				@"fileId" : entry[@"file_id"] ?: @0,
				@"chatId" : message[@"chat_id"] ?: @0,
				@"messageId" : message[@"id"] ?: @0,
				@"addDate" : entry[@"add_date"] ?: @0,
				@"completeDate" : entry[@"complete_date"] ?: @0,
				@"isPaused" : entry[@"is_paused"] ?: @NO,
				@"fileName" : TGFilesString(media[@"name"]),
				@"file" : file ?: @{},
			}];
		}

		NSDictionary *counts = TGFilesDict(result[@"total_counts"]) ?: @{};
		completion(@{
			@"downloads" : downloads,
			@"nextOffset" : TGFilesString(result[@"next_offset"]),
			@"activeCount" : counts[@"active_count"] ?: @0,
			@"pausedCount" : counts[@"paused_count"] ?: @0,
			@"completedCount" : counts[@"completed_count"] ?: @0,
		});
	}];
}

#pragma mark - streaming and partial reads

- (void)downloadedPrefixSizeForFile:(long long)fileId
							 offset:(long long)offset
						 completion:(void (^)(long long))completion {
	if (fileId <= 0) {
		if (completion)
			completion(0);
		return;
	}
	[self request:@{
		@"@type" : @"getFileDownloadedPrefixSize",
		@"file_id" : @(fileId),
		@"offset" : @(offset),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? 0 : [result[@"size"] longLongValue]);
	}];
}

- (void)downloadFile:(long long)fileId
			  offset:(long long)offset
			   limit:(long long)limit
		  completion:(void (^)(NSDictionary *))completion {
	if (fileId <= 0) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{
		@"@type" : @"downloadFile",
		@"file_id" : @(fileId),
		@"priority" : @(32),
		@"offset" : @(offset < 0 ? 0 : offset),
		@"limit" : @(limit < 0 ? 0 : limit),
		@"synchronous" : @YES,
	} deadline:kSynchronousDownloadDeadline completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGFileInfo(result));
	}];
}

- (void)readFile:(long long)fileId
		  offset:(long long)offset
		   count:(long long)count
	  completion:(void (^)(NSData *))completion {
	if (fileId <= 0 || count <= 0) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{
		@"@type" : @"readFilePart",
		@"file_id" : @(fileId),
		@"offset" : @(offset < 0 ? 0 : offset),
		@"count" : @(count),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGFilesDataFromBase64(result[@"data"]));
	}];
}

- (void)streamFile:(long long)fileId
			offset:(long long)offset
			 count:(long long)count
		completion:(void (^)(NSData *))completion {
	if (fileId <= 0 || count <= 0) {
		if (completion)
			completion(nil);
		return;
	}
	if (offset < 0)
		offset = 0;

	__weak typeof(self) weakSelf = self;
	[self downloadedPrefixSizeForFile:fileId offset:offset
						   completion:^(long long ready) {
							   TGClient *strongSelf = weakSelf;
							   if (!strongSelf) {
								   if (completion)
									   completion(nil);
								   return;
							   }
							   if (ready >= count) {
								   [strongSelf readFile:fileId offset:offset count:count completion:completion];
								   return;
							   }
							   [strongSelf downloadFile:fileId offset:offset limit:count
									 completion:^(NSDictionary *file) {
										 TGClient *innerSelf = weakSelf;
										 if (!file || !innerSelf) {
											 if (completion)
												 completion(nil);
											 return;
										 }
										 long long available = [file[@"prefixSize"] longLongValue];
										 long long wanted = available < count ? available : count;
										 if (wanted <= 0) {
											 if (completion)
												 completion(nil);
											 return;
										 }
										 [innerSelf readFile:fileId offset:offset count:wanted completion:completion];
									 }];
						   }];
}

#pragma mark - thumbnails

- (void)downloadPhotoSizes:(NSArray *)sizes
				  forWidth:(CGFloat)width
					 scale:(CGFloat)scale
				completion:(void (^)(NSString *, NSDictionary *))completion {
	NSDictionary *size = TGBestPhotoSizeInSizesForWidthScale(sizes, width, scale);
	if (!size) {
		if (completion)
			completion(nil, nil);
		return;
	}
	NSString *ready = size[@"path"];
	if ([size[@"isDownloaded"] boolValue] && [ready isKindOfClass:NSString.class] &&
		ready.length) {
		if (completion)
			completion(ready, size);
		return;
	}
	[self downloadFile:[size[@"fileId"] longLongValue] completion:^(NSString *path) {
		if (completion)
			completion(path, size);
	}];
}

- (NSData *)minithumbnailData:(NSDictionary *)minithumbnail {
	NSDictionary *thumb = TGFilesDict(minithumbnail);
	if (!thumb)
		return nil;
	return TGFilesDataFromBase64(thumb[@"data"]);
}

#pragma mark - uploading

- (void)uploadFileAtPath:(NSString *)path
					type:(NSString *)type
				priority:(NSInteger)priority
			  completion:(void (^)(NSDictionary *))completion {
	if (!path.length) {
		if (completion)
			completion(nil);
		return;
	}
	if (priority < 1)
		priority = 1;
	if (priority > 32)
		priority = 32;
	[self request:@{
		@"@type" : @"preliminaryUploadFile",
		@"file" : @{@"@type" : @"inputFileLocal", @"path" : path},
		@"file_type" : @{@"@type" : type.length ? type : TGFileTypeDocument},
		@"priority" : @(priority),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGFileInfo(result));
	}];
}

- (void)cancelUploadOfFile:(long long)fileId {
	if (fileId <= 0)
		return;
	[self send:@{@"@type" : @"cancelPreliminaryUploadFile", @"file_id" : @(fileId)}];
}

#pragma mark - auto-download settings

- (void)setAutoDownloadSettings:(NSDictionary *)settings
					 forNetwork:(NSString *)networkType
					 completion:(void (^)(BOOL))completion {
	NSDictionary *from = TGFilesDict(settings) ?: @{};
	id lessDataForCalls = from[@"useLessDataForCalls"] ?: @NO;
	NSDictionary *payload = @{
		@"@type" : @"autoDownloadSettings",
		@"is_auto_download_enabled" : from[@"enabled"] ?: @NO,
		@"max_photo_file_size" : from[@"maxPhotoSize"] ?: @(1048576),
		@"max_video_file_size" : from[@"maxVideoSize"] ?: @(1048576),
		@"max_other_file_size" : from[@"maxOtherSize"] ?: @(1048576),
		@"video_upload_bitrate" : from[@"videoUploadBitrate"] ?: @(0),
		@"preload_large_videos" : from[@"preloadLargeVideos"] ?: @NO,
		@"preload_next_audio" : from[@"preloadNextAudio"] ?: @NO,
		@"preload_stories" : from[@"preloadStories"] ?: @NO,
		@"use_less_data_for_calls" : lessDataForCalls,
	};
	[self request:@{
		@"@type" : @"setAutoDownloadSettings",
		@"settings" : payload,
		@"type" : @{@"@type" : networkType.length ? networkType : TGNetworkTypeOther},
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - statistics

#pragma mark - small helpers

- (void)tg_filesTextCall:(NSString *)method
					 key:(NSString *)key
				   value:(NSString *)value
			  completion:(void (^)(NSString *))completion {
	[self request:@{@"@type" : method, key : value ?: @""}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			NSString *text = TGFilesString(result[@"text"]);
			completion(text.length ? text : nil);
		}];
}

- (void)fileExtensionForMimeType:(NSString *)mimeType
					  completion:(void (^)(NSString *))completion {
	[self tg_filesTextCall:@"getFileExtension" key:@"mime_type" value:mimeType completion:completion];
}

- (void)downloadFile:(long long)fileId completion:(void (^)(NSString *))completion {
	if (fileId <= 0) {
		if (completion)
			completion(nil);
		return;
	}

	NSNumber *hint = self.downloadPriorityHints[@(fileId)];
	NSInteger priority = hint ? hint.integerValue : 1;

	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"downloadFile",
		@"file_id" : @(fileId),
		@"priority" : @(priority),
		@"offset" : @(0),
		@"limit" : @(0),
		@"synchronous" : @YES,
	} deadline:kSynchronousDownloadDeadline completion:^(NSDictionary *result) {
		TGClient *strongSelf = weakSelf;
		BOOL isError = TGResultIsError(result);
		if (strongSelf && !isError)
			[strongSelf rememberStateOfFileObject:result notify:YES];
		NSString *path = isError ? nil : result[@"local"][@"path"];
		BOOL done = !isError && [result[@"local"][@"is_downloading_completed"] boolValue];
		if (strongSelf && done)
			[strongSelf.downloadPriorityHints removeObjectForKey:@(fileId)];
		if (completion)
			completion((done && path.length) ? path : nil);
	}];
}

- (void)reportAudioListened:(long long)fileId durationSeconds:(NSInteger)seconds {
	if (fileId <= 0 || seconds <= 0)
		return;

	[self send:@{
		@"@type" : @"listenToAudio",
		@"audio_file_id" : @(fileId),
		@"duration" : @(seconds),
	}];
}

@end

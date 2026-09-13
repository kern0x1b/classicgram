#import "TGFlattenFiles.h"
#import "TGBase64.h"

static NSArray *TGFilesArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : nil;
}

static NSDictionary *TGFilesDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSString *TGFilesString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

NSData *TGFilesDataFromBase64(id value) {
	return TGBase64Decode(value);
}

NSDictionary *TGFileInfo(NSDictionary *file) {
	if (![file isKindOfClass:NSDictionary.class] || !file[@"id"])
		return nil;
	NSDictionary *local = TGFilesDict(file[@"local"]) ?: @{};
	NSDictionary *remote = TGFilesDict(file[@"remote"]) ?: @{};
	id expectedSize = file[@"expected_size"] ?: (file[@"size"] ?: @0);
	return @{
		@"id" : file[@"id"] ?: @0,
		@"size" : file[@"size"] ?: @0,
		@"expectedSize" : expectedSize,
		@"path" : TGFilesString(local[@"path"]),
		@"downloadedSize" : local[@"downloaded_size"] ?: @0,
		@"prefixSize" : local[@"downloaded_prefix_size"] ?: @0,
		@"downloadOffset" : local[@"download_offset"] ?: @0,
		@"canBeDownloaded" : local[@"can_be_downloaded"] ?: @NO,
		@"canBeDeleted" : local[@"can_be_deleted"] ?: @NO,
		@"isDownloading" : local[@"is_downloading_active"] ?: @NO,
		@"isDownloaded" : local[@"is_downloading_completed"] ?: @NO,
		@"isUploading" : remote[@"is_uploading_active"] ?: @NO,
		@"isUploaded" : remote[@"is_uploading_completed"] ?: @NO,
		@"uploadedSize" : remote[@"uploaded_size"] ?: @0,
		@"remoteId" : TGFilesString(remote[@"id"]),
		@"uniqueId" : TGFilesString(remote[@"unique_id"]),
	};
}

NSDictionary *TGFileOfMessageContent(NSDictionary *content, long long preferredFileId) {
	if (![content isKindOfClass:NSDictionary.class])
		return nil;
	NSString *type = content[@"@type"];
	NSDictionary *file = nil;
	NSString *name = @"";
	if ([type isEqualToString:@"messageDocument"]) {
		NSDictionary *doc = TGFilesDict(content[@"document"]);
		file = TGFilesDict(doc[@"document"]);
		name = TGFilesString(doc[@"file_name"]);
	} else if ([type isEqualToString:@"messageVideo"]) {
		NSDictionary *video = TGFilesDict(content[@"video"]);
		file = TGFilesDict(video[@"video"]);
		name = TGFilesString(video[@"file_name"]);
	} else if ([type isEqualToString:@"messageAudio"]) {
		NSDictionary *audio = TGFilesDict(content[@"audio"]);
		file = TGFilesDict(audio[@"audio"]);
		name = TGFilesString(audio[@"file_name"]);
	} else if ([type isEqualToString:@"messageAnimation"]) {
		NSDictionary *animation = TGFilesDict(content[@"animation"]);
		file = TGFilesDict(animation[@"animation"]);
		name = TGFilesString(animation[@"file_name"]);
	} else if ([type isEqualToString:@"messageVoiceNote"]) {
		file = TGFilesDict(TGFilesDict(content[@"voice_note"])[@"voice"]);
	} else if ([type isEqualToString:@"messageVideoNote"]) {
		file = TGFilesDict(TGFilesDict(content[@"video_note"])[@"video"]);
	} else if ([type isEqualToString:@"messagePhoto"]) {
		NSArray *sizes = TGFilesArray(TGFilesDict(content[@"photo"])[@"sizes"]);
		NSDictionary *photoFile = TGFilesDict([sizes lastObject][@"photo"]);
		NSDictionary *liveVideo = TGFilesDict(content[@"video"]);
		NSDictionary *liveVideoFile = TGFilesDict(liveVideo[@"video"]);
		if (preferredFileId && liveVideoFile &&
			[liveVideoFile[@"id"] longLongValue] == preferredFileId) {
			file = liveVideoFile;
			name = TGFilesString(liveVideo[@"file_name"]);
		} else {
			file = photoFile;
		}
	} else if ([type isEqualToString:@"messageSticker"]) {
		NSDictionary *sticker = TGFilesDict(content[@"sticker"]);
		file = TGFilesDict(sticker[@"sticker"]);
		name = TGFilesString(sticker[@"emoji"]);
	}
	if (!file)
		return nil;
	return @{@"file" : file, @"name" : name};
}

NSDictionary *TGBestPhotoSizeInSizesForWidthScale(NSArray *sizes, CGFloat width, CGFloat scale) {
	NSArray *list = TGFilesArray(sizes);
	if (!list.count)
		return nil;
	if (scale <= 0)
		scale = 1;
	CGFloat wanted = width * scale;

	NSDictionary *best = nil;
	NSInteger bestWidth = 0;
	NSDictionary *largest = nil;
	NSInteger largestWidth = -1;

	for (NSDictionary *size in list) {
		if (![size isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *file = TGFilesDict(size[@"photo"]);
		if (!file)
			continue;
		NSInteger sizeWidth = [size[@"width"] integerValue];
		if (sizeWidth > largestWidth) {
			largestWidth = sizeWidth;
			largest = size;
		}
		if (sizeWidth >= wanted && (!best || sizeWidth < bestWidth)) {
			best = size;
			bestWidth = sizeWidth;
		}
	}

	NSDictionary *chosen = best ?: largest;
	if (!chosen)
		return nil;
	NSDictionary *file = TGFilesDict(chosen[@"photo"]) ?: @{};
	NSDictionary *local = TGFilesDict(file[@"local"]) ?: @{};
	NSDictionary *remote = TGFilesDict(file[@"remote"]) ?: @{};
	return @{
		@"fileId" : file[@"id"] ?: @0,
		@"uniqueId" : TGFilesString(remote[@"unique_id"]),
		@"width" : chosen[@"width"] ?: @0,
		@"height" : chosen[@"height"] ?: @0,
		@"type" : TGFilesString(chosen[@"type"]),
		@"path" : TGFilesString(local[@"path"]),
		@"isDownloaded" : local[@"is_downloading_completed"] ?: @NO,
	};
}

NSDictionary *TGDecodableThumbnail(NSDictionary *thumbnail) {
	NSDictionary *thumb = TGFilesDict(thumbnail);
	if (!thumb)
		return nil;
	NSString *format = TGFilesDict(thumb[@"format"])[@"@type"];
	if (![format isEqualToString:@"thumbnailFormatJpeg"] &&
		![format isEqualToString:@"thumbnailFormatPng"])
		return nil;

	NSDictionary *file = TGFilesDict(thumb[@"file"]);
	if (!file)
		return nil;
	NSDictionary *local = TGFilesDict(file[@"local"]) ?: @{};
	NSDictionary *remote = TGFilesDict(file[@"remote"]) ?: @{};
	return @{
		@"fileId" : file[@"id"] ?: @0,
		@"uniqueId" : TGFilesString(remote[@"unique_id"]),
		@"width" : thumb[@"width"] ?: @0,
		@"height" : thumb[@"height"] ?: @0,
		@"type" : format ?: @"",
		@"path" : TGFilesString(local[@"path"]),
		@"isDownloaded" : local[@"is_downloading_completed"] ?: @NO,
	};
}

#import "TGDownloadsUpdate.h"

static NSNumber *TGDownloadsNumber(id value) {
	if ([value isKindOfClass:[NSNumber class]])
		return value;
	if ([value isKindOfClass:[NSString class]])
		return [NSNumber numberWithLongLong:[(NSString *)value longLongValue]];
	return [NSNumber numberWithLongLong:0];
}

NSDictionary *TGDownloadsSummaryFromUpdate(NSDictionary *update) {
	if (![update isKindOfClass:[NSDictionary class]])
		return nil;
	if (![update[@"@type"] isEqualToString:@"updateFileDownloads"])
		return nil;
	return @{
		@"totalSize" : TGDownloadsNumber(update[@"total_size"]),
		@"totalCount" : TGDownloadsNumber(update[@"total_count"]),
		@"downloadedSize" : TGDownloadsNumber(update[@"downloaded_size"]),
	};
}

BOOL TGDownloadsListShowsFileId(NSArray *entries, long long fileId) {
	if (![entries isKindOfClass:[NSArray class]] || !fileId)
		return NO;
	for (NSDictionary *entry in entries) {
		if (![entry isKindOfClass:[NSDictionary class]])
			continue;
		if ([entry[@"fileId"] longLongValue] == fileId)
			return YES;
	}
	return NO;
}

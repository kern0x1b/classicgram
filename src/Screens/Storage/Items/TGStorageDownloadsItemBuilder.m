#import "TGStorageDownloadsItemBuilder.h"
#import "TGStorageDownloadsCellCatalogue.h"
#import "TGLocalization.h"
#import "TGByteFormat.h"

@implementation TGStorageDownloadsItemBuilder

+ (TGStorageDownloadsItem *)itemWithKind:(TGStorageDownloadsRowKind)kind
							   titleText:(NSString *)titleText
							  detailText:(NSString *)detailText {
	return [[TGStorageDownloadsItem alloc]
		   initWithKind:kind
		reuseIdentifier:[TGStorageDownloadsCellCatalogue reuseIdentifierForKind:kind]
			  cellClass:[TGStorageDownloadsCellCatalogue cellClassForKind:kind]
			  titleText:titleText
			 detailText:detailText];
}

+ (TGStorageDownloadsItem *)itemForClearRow {
	return [self itemWithKind:TGStorageDownloadsRowKindClear
					titleText:TGL(@"DownloadList.ClearDownloadList", @"Clear Download List")
				   detailText:nil];
}

+ (TGStorageDownloadsItem *)itemForLoadingRow {
	return [self itemWithKind:TGStorageDownloadsRowKindLoading
					titleText:TGL(@"Channel.NotificationLoading", @"Loading…")
				   detailText:nil];
}

+ (TGStorageDownloadsItem *)itemForEmptyRow {
	return [self itemWithKind:TGStorageDownloadsRowKindEmpty
					titleText:TGL(@"Storage.NothingDownloaded", @"Nothing downloaded")
				   detailText:nil];
}

+ (TGStorageDownloadsItem *)itemForMoreRowLoading:(BOOL)loading {
	NSString *titleText = loading
		? TGL(@"Channel.NotificationLoading", @"Loading…")
		: TGL(@"Chat.RichText.ShowMore", @"Show more");
	return [self itemWithKind:TGStorageDownloadsRowKindMore titleText:titleText detailText:nil];
}

+ (NSString *)titleForEntry:(NSDictionary *)entry suggestedNames:(NSDictionary *)suggestedNames {
	NSString *name = [entry objectForKey:@"name"];
	if ([name isKindOfClass:[NSString class]] && name.length)
		return name;
	NSString *suggested = [suggestedNames objectForKey:[entry objectForKey:@"fileId"]];
	if (suggested.length)
		return suggested;
	return [NSString stringWithFormat:TGL(@"Storage.FileNumbered", @"File %lld"),
		[[entry objectForKey:@"fileId"] longLongValue]];
}

+ (NSString *)detailForEntry:(NSDictionary *)entry {
	long long size = [[entry objectForKey:@"size"] longLongValue];
	long long done = [[entry objectForKey:@"downloaded"] longLongValue];
	BOOL complete = [[entry objectForKey:@"isComplete"] boolValue];
	BOOL paused = [[entry objectForKey:@"isPaused"] boolValue];
	if (complete)
		return size > 0 ? TGMediaFormatBytes(size) : TGL(@"Storage.Downloaded", @"Downloaded");
	NSString *progress = size > 0
		? [NSString stringWithFormat:TGL(@"Storage.SizeProgress", @"%@ of %@"),
			  TGMediaFormatBytes(done), TGMediaFormatBytes(size)]
		: TGMediaFormatBytes(done);
	return paused
		? [NSString stringWithFormat:TGL(@"Storage.Paused", @"paused, %@"), progress]
		: progress;
}

+ (TGStorageDownloadsItem *)itemForEntry:(NSDictionary *)entry suggestedNames:(NSDictionary *)suggestedNames {
	return [self itemWithKind:TGStorageDownloadsRowKindEntry
					titleText:[self titleForEntry:entry suggestedNames:suggestedNames]
				   detailText:[self detailForEntry:entry]];
}

@end

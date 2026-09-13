#import "TGAudioMetadata.h"
#import "TGLazyFramework.h"
#import "TGFileDownloadService.h"
#import <AVFoundation/AVFoundation.h>

NSString *const TGAudioMetadataChangedNotification = @"TGAudioMetadataChanged";
NSString *const TGAudioMetadataFileIdKey = @"fileId";

static NSMutableDictionary *sCache = nil;
static NSMutableSet *sPending = nil;
static NSMutableSet *sRequested = nil;
static NSMutableDictionary *sTiles = nil;

static NSString *TGAudioMetadataTrim(id value) {
	if (![value isKindOfClass:NSString.class])
		return nil;
	NSString *trimmed = [value stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	return trimmed.length ? trimmed : nil;
}

static NSData *TGAudioMetadataImageData(id value) {
	if ([value isKindOfClass:NSData.class])
		return value;
	if ([value isKindOfClass:NSDictionary.class]) {
		id data = value[@"data"];
		return [data isKindOfClass:NSData.class] ? data : nil;
	}
	return nil;
}

static NSString *TGAudioMetadataCommonKey(const char *symbol, NSString *fallback) {
	NSString *value = TGAVString(symbol);
	return value.length ? value : fallback;
}

@implementation TGAudioMetadata

+ (void)initialize {
	if (self != TGAudioMetadata.class)
		return;
	sCache = [NSMutableDictionary dictionary];
	sPending = [NSMutableSet set];
	sRequested = [NSMutableSet set];
	sTiles = [NSMutableDictionary dictionary];
}

+ (TGAudioMetadata *)cachedForFileId:(int64_t)fileId {
	if (fileId == 0)
		return nil;
	@synchronized(sCache) {
		return sCache[[NSNumber numberWithLongLong:fileId]];
	}
}

+ (void)readForFileId:(int64_t)fileId path:(NSString *)path {
	if (fileId == 0 || !path.length)
		return;
	NSNumber *key = [NSNumber numberWithLongLong:fileId];
	@synchronized(sCache) {
		if (sCache[key] || [sPending containsObject:key])
			return;
		[sPending addObject:key];
	}

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		TGAudioMetadata *parsed = [self parseFileAtPath:path];
		dispatch_async(dispatch_get_main_queue(), ^{
			@synchronized(sCache) {
				[sPending removeObject:key];
				if (!parsed)
					return;
				sCache[key] = parsed;
			}
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGAudioMetadataChangedNotification
							  object:nil
							userInfo:@{TGAudioMetadataFileIdKey : key}];
		});
	});
}

+ (void)requestForFileId:(int64_t)fileId {
	if (fileId == 0)
		return;
	NSNumber *key = [NSNumber numberWithLongLong:fileId];
	@synchronized(sCache) {
		if (sCache[key] || [sRequested containsObject:key])
			return;
		[sRequested addObject:key];
	}
	[TGFileDownloadService downloadFile:fileId completion:^(NSString *path) {
		if (path.length)
			[self readForFileId:fileId path:path];
	}];
}

+ (TGAudioMetadata *)parseFileAtPath:(NSString *)path {
	Class assetClass = TGAVClass(AVURLAsset);
	if (!assetClass)
		return nil;
	if (![[NSFileManager defaultManager] fileExistsAtPath:path])
		return nil;

	AVURLAsset *asset = nil;
	@try {
		asset = [assetClass URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
	} @catch (NSException *exception) {
		return nil;
	}
	if (!asset)
		return nil;

	NSString *titleKey = TGAudioMetadataCommonKey("AVMetadataCommonKeyTitle", @"title");
	NSString *artistKey = TGAudioMetadataCommonKey("AVMetadataCommonKeyArtist", @"artist");
	NSString *albumKey = TGAudioMetadataCommonKey("AVMetadataCommonKeyAlbumName", @"albumName");
	NSString *artworkKey = TGAudioMetadataCommonKey("AVMetadataCommonKeyArtwork", @"artwork");

	TGAudioMetadata *parsed = [[TGAudioMetadata alloc] init];
	NSData *artworkData = nil;

	NSArray *items = nil;
	@try {
		items = asset.commonMetadata;
	} @catch (NSException *exception) {
		return nil;
	}

	for (AVMetadataItem *item in items) {
		NSString *common = item.commonKey;
		if (!common.length)
			continue;
		if ([common isEqualToString:titleKey])
			parsed.title = TGAudioMetadataTrim(item.value);
		else if ([common isEqualToString:artistKey])
			parsed.performer = TGAudioMetadataTrim(item.value);
		else if ([common isEqualToString:albumKey])
			parsed.album = TGAudioMetadataTrim(item.value);
		else if ([common isEqualToString:artworkKey] && !artworkData)
			artworkData = TGAudioMetadataImageData(item.value);
	}

	if (artworkData.length)
		parsed.artwork = [UIImage imageWithData:artworkData];

	if (!parsed.title && !parsed.performer && !parsed.artwork)
		return nil;
	return parsed;
}

+ (UIImage *)artworkTileOfSide:(CGFloat)side forMetadata:(TGAudioMetadata *)metadata {
	return [self artworkTileOfSide:side cornerRadius:side / 2 scrim:YES forMetadata:metadata];
}

+ (UIImage *)artworkTileOfSide:(CGFloat)side
				  cornerRadius:(CGFloat)cornerRadius
						 scrim:(BOOL)scrim
				   forMetadata:(TGAudioMetadata *)metadata {
	UIImage *source = metadata.artwork;
	if (!source || side <= 0)
		return nil;

	NSString *key = [NSString stringWithFormat:@"%p-%.0f-%.0f-%d",
		source, side, cornerRadius, scrim ? 1 : 0];
	UIImage *cached = sTiles[key];
	if (cached)
		return cached;

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
	[[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, side, side)
								cornerRadius:cornerRadius] addClip];

	CGSize pixels = source.size;
	CGFloat scale = MAX(side / MAX(pixels.width, (CGFloat)1),
		side / MAX(pixels.height, (CGFloat)1));
	CGSize drawn = CGSizeMake(pixels.width * scale, pixels.height * scale);
	[source drawInRect:CGRectMake((side - drawn.width) / 2, (side - drawn.height) / 2,
						   drawn.width, drawn.height)];

	if (scrim) {
		[[UIColor colorWithWhite:0 alpha:0.3f] set];
		UIRectFillUsingBlendMode(CGRectMake(0, 0, side, side), kCGBlendModeNormal);
	}

	UIImage *tile = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	if (tile && sTiles.count < 48)
		sTiles[key] = tile;
	return tile;
}

+ (void)flush {
	@synchronized(sCache) {
		[sCache removeAllObjects];
		[sPending removeAllObjects];
		[sRequested removeAllObjects];
	}
	[sTiles removeAllObjects];
}

@end

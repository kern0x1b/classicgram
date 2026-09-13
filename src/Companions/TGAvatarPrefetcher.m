#import "TGAvatarPrefetcher.h"
#import "TGImageDecode.h"

@interface TGAvatarPrefetcher () {
	NSTimeInterval _lastSweep;
}
@end

@implementation TGAvatarPrefetcher

- (instancetype)initWithAvatarSide:(CGFloat)avatarSide
					 prefetchMargin:(NSInteger)prefetchMargin
					   retainMargin:(NSInteger)retainMargin {
	self = [super init];
	if (self) {
		_avatarSide = avatarSide;
		_prefetchMargin = prefetchMargin;
		_retainMargin = retainMargin;
		_photos = [NSMutableDictionary dictionary];
		_photosRequested = [NSMutableSet set];
	}
	return self;
}

- (NSSet *)photoKeysWithinRows:(NSInteger)margin {
	NSMutableSet *keys = [NSMutableSet set];
	NSArray *visible = [self.tableView indexPathsForVisibleRows] ?: [NSArray array];
	NSInteger first = NSIntegerMax;
	NSInteger last = -1;
	for (NSIndexPath *path in visible) {
		first = MIN(first, path.row);
		last = MAX(last, path.row);
	}
	if (last < 0) {
		first = 0;
		last = margin;
	} else {
		first -= margin;
		last += margin;
	}
	NSInteger rowCount = self.rowCountProvider ? self.rowCountProvider() : 0;
	for (NSInteger row = MAX(first, 0); row <= last; row++) {
		if (row >= rowCount)
			break;
		NSNumber *key = self.rowKeyProvider ? self.rowKeyProvider(row) : nil;
		if (key)
			[keys addObject:key];
	}
	return keys;
}

- (void)evictPhotosOutsideRows:(NSInteger)margin {
	if (self.evictionSkipHandler && self.evictionSkipHandler())
		return;
	NSSet *keep = [self photoKeysWithinRows:margin];
	for (NSNumber *key in [self.photos allKeys]) {
		if ([keep containsObject:key])
			continue;
		[self.photos removeObjectForKey:key];
		[self.photosRequested removeObject:key];
	}
}

- (void)fetchPhotosForRows {
	_lastSweep = [NSDate timeIntervalSinceReferenceDate];
	__weak typeof(self) weakSelf = self;
	for (NSNumber *key in [self photoKeysWithinRows:self.prefetchMargin]) {
		if ([self.photos objectForKey:key] || [self.photosRequested containsObject:key])
			continue;
		NSNumber *fileId = self.fileIdProvider ? self.fileIdProvider([key longLongValue]) : nil;
		if (![fileId isKindOfClass:NSNumber.class])
			continue;
		if (!self.downloadProvider)
			continue;
		[self.photosRequested addObject:key];

		self.downloadProvider([fileId longLongValue], ^(NSString *path) {
			TGAvatarPrefetcher *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!path.length) {
				[strongSelf.photosRequested removeObject:key];
				return;
			}
			CGFloat side = strongSelf.avatarSide;
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				UIImage *thumb = TGDecodeSquareThumbnail(path, side);
				dispatch_async(dispatch_get_main_queue(), ^{
					TGAvatarPrefetcher *innerSelf = weakSelf;
					if (!innerSelf || !thumb)
						return;
					[innerSelf.photos setObject:thumb forKey:key];
					if (innerSelf.photosChangedHandler)
						innerSelf.photosChangedHandler(key);
				});
			});
		});
	}
	[self evictPhotosOutsideRows:self.retainMargin];
}

- (void)fetchPhotosForRowsThrottled {
	if ([NSDate timeIntervalSinceReferenceDate] - _lastSweep < 0.15)
		return;
	[self fetchPhotosForRows];
}

@end

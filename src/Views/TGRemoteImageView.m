#import "TGRemoteImageView.h"
#import "TGFileDownloadService.h"
#import "TGImageDecode.h"
#import "TGDiskCache.h"

@interface TGRemoteImageView ()
@property (nonatomic, strong) UIImage *placeholderImage;
@property (nonatomic, assign) BOOL cancelled;
@property (nonatomic, strong) NSString *currentCacheKey;
@property (nonatomic, assign) NSUInteger loadToken;
@property (nonatomic, strong) NSNumber *activeDownloadFileId;
@end

static NSCache *TGRemoteImageMemoryCache(void) {
	static NSCache *cache = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		cache = [[NSCache alloc] init];
		cache.totalCostLimit = 6 * 1024 * 1024;
		NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
		NSOperationQueue *main = [NSOperationQueue mainQueue];
		void (^purge)(NSNotification *) = ^(NSNotification *__unused note) {
			[cache removeAllObjects];
		};
		[center addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
							object:nil
							 queue:main
						usingBlock:purge];
		[center addObserverForName:UIApplicationDidEnterBackgroundNotification
							object:nil
							 queue:main
						usingBlock:purge];
	});
	return cache;
}

static NSUInteger TGRemoteImageCost(UIImage *image) {
	CGImageRef cg = image.CGImage;
	if (!cg)
		return 1;
	NSUInteger cost = CGImageGetHeight(cg) * CGImageGetBytesPerRow(cg);
	return cost > 0 ? cost : 1;
}

@implementation TGRemoteImageView

+ (void)tgPurgeMemoryCache {
	[TGRemoteImageMemoryCache() removeAllObjects];
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		self.fadeTransitionDuration = 0.14;
	}
	return self;
}

- (void)prepareForReuse {
	[self cancelLoading];
	self.fileId = nil;
	self.currentCacheKey = nil;
	self.image = nil;
	self.placeholderImage = nil;
}

- (void)prepareForRecycle:(TGViewRecycler *)__unused recycler {
	[self cancelLoading];
	self.fileId = nil;
	self.currentCacheKey = nil;
	self.image = nil;
	self.placeholderImage = nil;
}

- (UIImage *)currentImage {
	return self.image;
}

- (void)applyImage:(UIImage *)image fade:(bool)fade {
	if (!image)
		return;
	if (fade) {
		NSTimeInterval duration = self.fadeTransitionDuration > FLT_EPSILON ? self.fadeTransitionDuration : 0.14;
		[UIView transitionWithView:self duration:duration
						   options:UIViewAnimationOptionTransitionCrossDissolve
						animations:^{ self.image = image; }
						completion:nil];
	} else {
		self.image = image;
	}
}

- (void)stopActiveDownloadUnlessFileId:(NSNumber *)keptFileId {
	NSNumber *active = self.activeDownloadFileId;
	if (!active)
		return;
	if (keptFileId && [active isEqualToNumber:keptFileId])
		return;
	self.activeDownloadFileId = nil;
	[TGFileDownloadService cancelDownloadOfFile:active.longLongValue onlyIfPending:YES];
}

- (void)loadWithFileId:(NSNumber *)fileId square:(CGFloat)side placeholder:(UIImage *)placeholder forceFade:(bool)forceFade {
	[self loadWithFileId:fileId stableKey:nil square:side placeholder:placeholder forceFade:forceFade];
}

- (void)loadWithFileId:(NSNumber *)fileId stableKey:(NSString *)stableKey square:(CGFloat)side placeholder:(UIImage *)placeholder forceFade:(bool)forceFade {
	[self stopActiveDownloadUnlessFileId:fileId];
	self.loadToken = self.loadToken + 1;
	NSInteger token = self.loadToken;
	self.placeholderImage = placeholder;
	self.fileId = fileId;
	self.cancelled = false;

	if (![fileId isKindOfClass:NSNumber.class] || side < 1.0f) {
		self.currentCacheKey = nil;
		self.image = placeholder;
		return;
	}

	NSString *cacheIdentity = stableKey.length ? stableKey : fileId.stringValue;
	NSString *cacheKey = [NSString stringWithFormat:@"%@_%d", cacheIdentity, (int)(side + 0.5f)];
	self.currentCacheKey = cacheKey;

	UIImage *memoryCached = [TGRemoteImageMemoryCache() objectForKey:cacheKey];
	if (memoryCached) {
		[self stopActiveDownloadUnlessFileId:nil];
		self.image = memoryCached;
		return;
	}

	self.image = placeholder;

	NSString *diskKey = stableKey.length
		? [NSString stringWithFormat:@"remote_%@_%d", stableKey, (int)(side + 0.5f)]
		: nil;
	bool fade = self.fadeTransition || forceFade;
	CGFloat screenScale = [UIScreen mainScreen].scale;
	if (screenScale < 1.0f)
		screenScale = 1.0f;
	__weak typeof(self) weakSelf = self;

	void (^deliver)(UIImage *) = ^(UIImage *image) {
		TGRemoteImageView *strongSelf = weakSelf;
		if (!strongSelf || strongSelf.loadToken != token || strongSelf.cancelled || ![strongSelf.fileId isEqual:fileId] || ![strongSelf.currentCacheKey isEqualToString:cacheKey])
			return;
		strongSelf.activeDownloadFileId = nil;
		if (!image) {
			strongSelf.currentCacheKey = nil;
			if (strongSelf.placeholderImage)
				strongSelf.image = strongSelf.placeholderImage;
			return;
		}
		[strongSelf applyImage:image fade:fade];
	};

	dispatch_async(TGImageDecodeQueue(), ^{
		UIImage *cached = nil;
		@autoreleasepool {
			UIImage *decoded = diskKey ? [TGDiskCache imageForKey:diskKey scale:screenScale] : nil;
			CGFloat expected = side * screenScale;
			if (decoded && fabs(decoded.size.width * decoded.scale - expected) <= 0.5f &&
				fabs(decoded.size.height * decoded.scale - expected) <= 0.5f)
				cached = decoded;
		}
		if (cached) {
			[TGRemoteImageMemoryCache() setObject:cached forKey:cacheKey cost:TGRemoteImageCost(cached)];
			dispatch_async(dispatch_get_main_queue(), ^{ deliver(cached); });
			return;
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			TGRemoteImageView *strongSelf = weakSelf;
			if (!strongSelf || strongSelf.loadToken != token || strongSelf.cancelled || ![strongSelf.fileId isEqual:fileId])
				return;
			strongSelf.activeDownloadFileId = fileId;
			[TGFileDownloadService downloadFile:fileId.longLongValue completion:^(NSString *path) {
				if (path.length == 0) {
					deliver(nil);
					return;
				}
				dispatch_async(TGImageDecodeQueue(), ^{
					UIImage *thumb = TGDecodeSquareThumbnail(path, side);
					if (!thumb) {
						dispatch_async(dispatch_get_main_queue(), ^{ deliver(nil); });
						return;
					}
					if (diskKey)
						[TGDiskCache storeImage:thumb forKey:diskKey];
					[TGRemoteImageMemoryCache() setObject:thumb forKey:cacheKey cost:TGRemoteImageCost(thumb)];
					dispatch_async(dispatch_get_main_queue(), ^{ deliver(thumb); });
				});
			}];
		});
	});
}

- (void)loadPlaceholder:(UIImage *)placeholder {
	[self cancelLoading];
	self.loadToken = self.loadToken + 1;
	self.fileId = nil;
	self.currentCacheKey = nil;
	self.placeholderImage = placeholder;
	self.image = placeholder;
}

- (void)cancelLoading {
	self.cancelled = true;
	self.loadToken = self.loadToken + 1;
	[self stopActiveDownloadUnlessFileId:nil];
}

@end

#import "TGStickerThumbnailCache.h"

#import "TGFileDownloadService.h"
#import "TGDiskCache.h"
#import "TGImageDecode.h"
#import "WebP.framework/Headers/decode.h"

static const NSUInteger kStickerThumbnailMemoryLimit = 3 * 1024 * 1024;

static NSUInteger TGStickerThumbnailMemoryHits = 0;
static NSUInteger TGStickerThumbnailDiskHits = 0;
static NSUInteger TGStickerThumbnailDecodes = 0;
static NSUInteger TGStickerThumbnailFailures = 0;
static NSTimeInterval TGStickerThumbnailDecodeSeconds = 0;

@interface TGStickerThumbnailRequest : NSObject {
  @public

	volatile BOOL abandoned;
}

@property (nonatomic, copy) NSString *memoryKey;
@property (nonatomic, copy) NSString *diskKey;
@property (nonatomic, assign) long long fileId;
@property (nonatomic, assign) CGFloat side;
@property (nonatomic, strong) NSMutableArray *tokens;
@property (nonatomic, assign) BOOL downloadStarted;

@end

@implementation TGStickerThumbnailRequest
@end

@interface TGStickerThumbnailToken : NSObject

@property (nonatomic, strong) TGStickerThumbnailRequest *request;
@property (nonatomic, copy) void (^completion)(UIImage *);

@end

@implementation TGStickerThumbnailToken
@end

static NSCache *TGStickerThumbnailMemory(void) {
	static NSCache *cache = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		cache = [[NSCache alloc] init];
		cache.totalCostLimit = kStickerThumbnailMemoryLimit;
		[[NSNotificationCenter defaultCenter]
			addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
						object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *__unused note) {
						[cache removeAllObjects];
					}];
		[[NSNotificationCenter defaultCenter]
			addObserverForName:UIApplicationDidEnterBackgroundNotification
						object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *__unused note) {
						[cache removeAllObjects];
					}];
	});
	return cache;
}

static NSMutableDictionary *TGStickerThumbnailRequests(void) {
	static NSMutableDictionary *requests = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		requests = [[NSMutableDictionary alloc] init];
	});
	return requests;
}

static dispatch_queue_t TGStickerThumbnailDecodeQueue(void) {
	static dispatch_queue_t queue = NULL;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		queue = dispatch_queue_create("tg.stickerthumb.decode", NULL);
	});
	return queue;
}

static dispatch_queue_t TGStickerThumbnailLookupQueue(void) {
	static dispatch_queue_t queue = NULL;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		queue = dispatch_queue_create("tg.stickerthumb.lookup", NULL);
	});
	return queue;
}

static CGFloat TGStickerThumbnailScreenScale(void) {
	CGFloat scale = [UIScreen mainScreen].scale;
	return scale < 1.0f ? 1.0f : scale;
}

static NSUInteger TGStickerThumbnailCost(UIImage *image) {
	CGImageRef bitmap = image.CGImage;
	if (bitmap == NULL)
		return 1;
	NSUInteger cost = CGImageGetHeight(bitmap) * CGImageGetBytesPerRow(bitmap);
	return cost > 0 ? cost : 1;
}

static void TGStickerThumbnailFreePixels(void *__unused info, const void *data, size_t __unused size) {
	free((void *)data);
}

static UIImage *TGStickerThumbnailDecodeWebP(NSData *data, CGFloat pixelSide, CGFloat scale) {
	WebPDecoderConfig config;
	if (!WebPInitDecoderConfig(&config))
		return nil;
	if (WebPGetFeatures(data.bytes, data.length, &config.input) != VP8_STATUS_OK)
		return nil;

	int width = config.input.width;
	int height = config.input.height;
	if (width <= 0 || height <= 0)
		return nil;

	CGFloat fit = MIN(pixelSide / width, pixelSide / height);
	if (fit > 1.0f)
		fit = 1.0f;
	int targetWidth = (int)floorf(width * fit);
	int targetHeight = (int)floorf(height * fit);
	if (targetWidth < 1 || targetHeight < 1)
		return nil;

	size_t stride = (size_t)targetWidth * 4;
	size_t bytes = stride * (size_t)targetHeight;
	uint8_t *pixels = malloc(bytes);
	if (pixels == NULL)
		return nil;

	config.options.use_scaling = (targetWidth != width || targetHeight != height) ? 1 : 0;
	config.options.scaled_width = targetWidth;
	config.options.scaled_height = targetHeight;
	config.options.no_fancy_upsampling = 1;
	config.options.bypass_filtering = 1;
	config.output.colorspace = MODE_rgbA;
	config.output.is_external_memory = 1;
	config.output.u.RGBA.rgba = pixels;
	config.output.u.RGBA.stride = (int)stride;
	config.output.u.RGBA.size = bytes;

	if (WebPDecode(data.bytes, data.length, &config) != VP8_STATUS_OK) {
		free(pixels);
		return nil;
	}

	CGDataProviderRef provider =
		CGDataProviderCreateWithData(NULL, pixels, bytes, TGStickerThumbnailFreePixels);
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGImageRef bitmap = CGImageCreate(targetWidth, targetHeight, 8, 32, stride, space,
		kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast,
		provider, NULL, NO, kCGRenderingIntentDefault);

	UIImage *image = bitmap ? [UIImage imageWithCGImage:bitmap scale:scale
											orientation:UIImageOrientationUp]
							: nil;

	if (bitmap)
		CGImageRelease(bitmap);
	CGColorSpaceRelease(space);
	CGDataProviderRelease(provider);
	return image;
}

static UIImage *TGStickerThumbnailForceDecode(UIImage *image) {
	CGImageRef source = image.CGImage;
	if (source == NULL)
		return image;

	size_t width = CGImageGetWidth(source);
	size_t height = CGImageGetHeight(source);
	if (width == 0 || height == 0)
		return image;

	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space,
		(CGBitmapInfo)kCGImageAlphaPremultipliedLast);
	CGColorSpaceRelease(space);
	if (context == NULL)
		return image;

	CGContextDrawImage(context, CGRectMake(0, 0, width, height), source);
	CGImageRef flattened = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	if (flattened == NULL)
		return image;

	UIImage *result = [UIImage imageWithCGImage:flattened scale:image.scale
									orientation:image.imageOrientation];
	CGImageRelease(flattened);
	return result;
}

static BOOL TGStickerThumbnailLooksLikeWebP(NSData *data) {
	if (data.length < 12)
		return NO;
	const uint8_t *bytes = data.bytes;
	return memcmp(bytes, "RIFF", 4) == 0 && memcmp(bytes + 8, "WEBP", 4) == 0;
}

static UIImage *TGStickerThumbnailDecodeFile(NSString *path, CGFloat side, CGFloat scale) {
	CGFloat pixelSide = side * scale;
	NSData *data = [NSData dataWithContentsOfFile:path
										  options:NSDataReadingMappedIfSafe
											error:NULL];
	if (data.length == 0)
		return nil;
	if (TGStickerThumbnailLooksLikeWebP(data))
		return TGStickerThumbnailDecodeWebP(data, pixelSide, scale);

	UIImage *decoded = TGDecodeThumbnail(path, pixelSide);
	if (decoded == nil)
		return nil;
	return [UIImage imageWithCGImage:decoded.CGImage scale:scale
						 orientation:UIImageOrientationUp];
}

@implementation TGStickerThumbnailCache

+ (NSString *)memoryKeyForFileId:(long long)fileId uniqueId:(NSString *)uniqueId side:(CGFloat)side {
	if (uniqueId.length > 0)
		return [NSString stringWithFormat:@"u:%@@%d", uniqueId, (int)side];
	return [NSString stringWithFormat:@"f:%lld@%d", fileId, (int)side];
}

+ (NSString *)diskKeyForUniqueId:(NSString *)uniqueId side:(CGFloat)side {
	if (uniqueId.length == 0)
		return nil;
	return [NSString stringWithFormat:@"sticker_%@_%d", uniqueId, (int)side];
}

+ (UIImage *)cachedThumbnailForUniqueId:(NSString *)uniqueId side:(CGFloat)side {
	if (uniqueId.length == 0)
		return nil;
	UIImage *cached = [TGStickerThumbnailMemory() objectForKey:
			[self memoryKeyForFileId:0 uniqueId:uniqueId side:side]];
	if (cached != nil)
		TGStickerThumbnailMemoryHits += 1;
	return cached;
}

+ (void)purgeMemory {
	[TGStickerThumbnailMemory() removeAllObjects];
}

+ (void)resetStatistics {
	TGStickerThumbnailMemoryHits = 0;
	TGStickerThumbnailDiskHits = 0;
	TGStickerThumbnailDecodes = 0;
	TGStickerThumbnailFailures = 0;
	TGStickerThumbnailDecodeSeconds = 0;
}

+ (NSString *)statisticsSummary {
	return [NSString stringWithFormat:@"memory=%lu disk=%lu decoded=%lu failed=%lu decode=%.0f ms",
		(unsigned long)TGStickerThumbnailMemoryHits,
		(unsigned long)TGStickerThumbnailDiskHits,
		(unsigned long)TGStickerThumbnailDecodes,
		(unsigned long)TGStickerThumbnailFailures,
		TGStickerThumbnailDecodeSeconds * 1000.0];
}

+ (void)finishRequest:(TGStickerThumbnailRequest *)request withImage:(UIImage *)image {
	NSArray *tokens = [request.tokens copy];
	[request.tokens removeAllObjects];
	if (TGStickerThumbnailRequests()[request.memoryKey] == request)
		[TGStickerThumbnailRequests() removeObjectForKey:request.memoryKey];
	for (TGStickerThumbnailToken *token in tokens) {
		if (token.completion)
			token.completion(image);
		token.completion = nil;
		token.request = nil;
	}
}

+ (void)storeImage:(UIImage *)image forRequest:(TGStickerThumbnailRequest *)request {
	if (image == nil)
		return;
	[TGStickerThumbnailMemory() setObject:image forKey:request.memoryKey
									 cost:TGStickerThumbnailCost(image)];
}

+ (void)decodeDownloadedFile:(NSString *)path forRequest:(TGStickerThumbnailRequest *)request {
	CGFloat scale = TGStickerThumbnailScreenScale();
	CGFloat side = request.side;
	NSString *diskKey = request.diskKey;

	dispatch_async(TGStickerThumbnailDecodeQueue(), ^{
		if (request->abandoned) {
			dispatch_async(dispatch_get_main_queue(), ^{
				[self finishRequest:request withImage:nil];
			});
			return;
		}

		NSTimeInterval decodeStarted = [NSDate timeIntervalSinceReferenceDate];
		UIImage *decoded = nil;
		@autoreleasepool {
			decoded = TGStickerThumbnailDecodeFile(path, side, scale);
		}
		NSTimeInterval decodeTook = [NSDate timeIntervalSinceReferenceDate] - decodeStarted;
		if (decoded != nil && diskKey != nil)
			[TGDiskCache storeImage:decoded forKey:diskKey];

		dispatch_async(dispatch_get_main_queue(), ^{
			if (decoded != nil) {
				TGStickerThumbnailDecodes += 1;
				TGStickerThumbnailDecodeSeconds += decodeTook;
			} else
				TGStickerThumbnailFailures += 1;
			[self storeImage:decoded forRequest:request];
			[self finishRequest:request withImage:decoded];
		});
	});
}

+ (void)downloadForRequest:(TGStickerThumbnailRequest *)request {
	if (request->abandoned) {
		[self finishRequest:request withImage:nil];
		return;
	}

	request.downloadStarted = YES;
	[TGFileDownloadService downloadFile:request.fileId completion:^(NSString *path) {
		if (path.length == 0) {
			[self finishRequest:request withImage:nil];
			return;
		}
		if (request->abandoned) {
			[self finishRequest:request withImage:nil];
			return;
		}
		[self decodeDownloadedFile:path forRequest:request];
	}];
}

+ (void)startRequest:(TGStickerThumbnailRequest *)request {
	NSString *diskKey = request.diskKey;
	if (diskKey == nil) {
		[self downloadForRequest:request];
		return;
	}

	CGFloat scale = TGStickerThumbnailScreenScale();
	CGFloat side = request.side;

	dispatch_async(TGStickerThumbnailLookupQueue(), ^{
		if (request->abandoned) {
			dispatch_async(dispatch_get_main_queue(), ^{
				[self finishRequest:request withImage:nil];
			});
			return;
		}

		UIImage *cached = nil;
		@autoreleasepool {
			UIImage *stored = [TGDiskCache imageForKey:diskKey scale:scale];
			CGFloat longest = MAX(stored.size.width, stored.size.height);
			if (stored != nil && longest > 0.0f && longest <= side + 0.5f)
				cached = TGStickerThumbnailForceDecode(stored);
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			if (cached != nil) {
				TGStickerThumbnailDiskHits += 1;
				[self storeImage:cached forRequest:request];
				[self finishRequest:request withImage:cached];
				return;
			}
			[self downloadForRequest:request];
		});
	});
}

+ (id)thumbnailForFileId:(long long)fileId
				uniqueId:(NSString *)uniqueId
					side:(CGFloat)side
			  completion:(void (^)(UIImage *))completion {
	if (side < 1.0f || (fileId <= 0 && uniqueId.length == 0)) {
		if (completion)
			completion(nil);
		return nil;
	}

	NSString *memoryKey = [self memoryKeyForFileId:fileId uniqueId:uniqueId side:side];
	UIImage *cached = [TGStickerThumbnailMemory() objectForKey:memoryKey];
	if (cached != nil) {
		TGStickerThumbnailMemoryHits += 1;
		if (completion)
			completion(cached);
		return nil;
	}

	if (fileId <= 0) {
		if (completion)
			completion(nil);
		return nil;
	}

	TGStickerThumbnailRequest *request = TGStickerThumbnailRequests()[memoryKey];
	BOOL fresh = (request == nil);
	if (fresh) {
		request = [[TGStickerThumbnailRequest alloc] init];
		request.memoryKey = memoryKey;
		request.diskKey = [self diskKeyForUniqueId:uniqueId side:side];
		request.fileId = fileId;
		request.side = side;
		request.tokens = [[NSMutableArray alloc] init];
		TGStickerThumbnailRequests()[memoryKey] = request;
	}
	TGStickerThumbnailToken *token = [[TGStickerThumbnailToken alloc] init];
	token.request = request;
	token.completion = completion;
	[request.tokens addObject:token];

	if (fresh)
		[self startRequest:request];
	return token;
}

+ (void)cancelRequest:(id)opaque {
	if (![opaque isKindOfClass:[TGStickerThumbnailToken class]])
		return;

	TGStickerThumbnailToken *token = opaque;
	TGStickerThumbnailRequest *request = token.request;
	token.completion = nil;
	token.request = nil;
	if (request == nil)
		return;

	[request.tokens removeObjectIdenticalTo:token];
	if (request.tokens.count > 0)
		return;

	request->abandoned = YES;
	[TGStickerThumbnailRequests() removeObjectForKey:request.memoryKey];
	if (request.downloadStarted && request.fileId > 0)
		[TGFileDownloadService cancelDownloadOfFile:request.fileId onlyIfPending:YES];
}

@end

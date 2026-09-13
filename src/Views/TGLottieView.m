#import "TGLottieView.h"
#import "TGPerfLogging.h"
#include <zlib.h>

#pragma mark - gunzip

static NSData *TGGunzip(NSData *input) {
	if (!input.length)
		return nil;

	z_stream stream;
	memset(&stream, 0, sizeof(stream));
	stream.next_in = (Bytef *)input.bytes;
	stream.avail_in = (uInt)input.length;

	if (inflateInit2(&stream, 15 + 32) != Z_OK)
		return nil;

	NSMutableData *out = [NSMutableData dataWithLength:input.length * 8];
	int status;
	do {
		if (stream.total_out >= out.length)
			[out increaseLengthBy:input.length * 4];
		stream.next_out = (Bytef *)out.mutableBytes + stream.total_out;
		stream.avail_out = (uInt)(out.length - stream.total_out);
		status = inflate(&stream, Z_SYNC_FLUSH);
	} while (status == Z_OK);

	inflateEnd(&stream);
	if (status != Z_STREAM_END)
		return nil;

	[out setLength:stream.total_out];
	return out;
}

#pragma mark - keyframed values

static NSArray *TGNumbers(id v) {
	if ([v isKindOfClass:NSArray.class])
		return v;
	if ([v isKindOfClass:NSNumber.class])
		return @[ v ];
	return nil;
}

static NSArray *TGValueAt(NSDictionary *prop, double frame, NSMapTable *cursors) {
	if (![prop isKindOfClass:NSDictionary.class])
		return nil;

	id k = prop[@"k"];
	if (!k)
		return nil;

	if (![k isKindOfClass:NSArray.class] ||
		![[k firstObject] isKindOfClass:NSDictionary.class])
		return TGNumbers(k);

	NSArray *keys = k;
	NSInteger count = keys.count;
	NSInteger start = 0;

	NSNumber *cached = cursors ? [cursors objectForKey:prop] : nil;
	if (cached) {
		NSInteger idx = cached.unsignedIntegerValue;
		if (idx < count) {
			NSDictionary *kf = keys[idx];
			if ([kf isKindOfClass:NSDictionary.class] && [kf[@"t"] doubleValue] <= frame)
				start = idx;
		}
	}

	NSDictionary *before = nil, *after = nil;
	NSInteger beforeIdx = 0;

	for (NSInteger i = start; i < count; i++) {
		NSDictionary *kf = keys[i];
		if (![kf isKindOfClass:NSDictionary.class])
			continue;
		double t = [kf[@"t"] doubleValue];
		if (t <= frame) {
			before = kf;
			beforeIdx = i;
		} else {
			after = kf;
			break;
		}
	}

	if (cursors && before)
		[cursors setObject:@(beforeIdx) forKey:prop];

	if (!before)
		return TGNumbers([[keys firstObject] objectForKey:@"s"]);
	if (!after)
		return TGNumbers(before[@"s"] ?: before[@"e"]);

	NSArray *from = TGNumbers(before[@"s"]);
	NSArray *to = TGNumbers(before[@"e"] ?: after[@"s"]);
	if (!from || !to)
		return from ?: to;

	double t0 = [before[@"t"] doubleValue];
	double t1 = [after[@"t"] doubleValue];
	double p = (t1 > t0) ? (frame - t0) / (t1 - t0) : 0.0;
	if (p < 0)
		p = 0;
	if (p > 1)
		p = 1;

	NSMutableArray *out = [NSMutableArray arrayWithCapacity:from.count];
	for (NSInteger i = 0; i < from.count; i++) {
		double a = [from[i] doubleValue];
		double b = (i < to.count) ? [to[i] doubleValue] : a;
		[out addObject:@(a + (b - a) * p)];
	}
	return out;
}

static double TGScalarAt(NSDictionary *prop, double frame, double fallback, NSMapTable *cursors) {
	NSArray *v = TGValueAt(prop, frame, cursors);
	return v.count ? [v[0] doubleValue] : fallback;
}

#pragma mark - view

@interface TGLottieView (TGLottieTick)
- (void)tick;
@end

@interface TGLottieTimerProxy : NSObject
@property (nonatomic, weak) TGLottieView *target;
@end

@implementation TGLottieTimerProxy
- (void)tick:(NSTimer *)timer {
	TGLottieView *t = self.target;
	if (t)
		[t tick];
	else
		[timer invalidate];
}
@end

@interface TGLottieView ()
@property (nonatomic, strong) NSArray *reversedLayers;
@property (nonatomic, assign) double inPoint;
@property (nonatomic, assign) double outPoint;
@property (nonatomic, assign) double frameRate;
@property (nonatomic, assign) CGSize canvas;
@property (nonatomic, assign) double currentFrame;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL wantsPlayback;
@property (nonatomic, strong) NSDictionary *layersByIndex;
@property (nonatomic, copy) NSString *loadedPath;
@property (nonatomic, copy) NSString *pendingPath;
@property (nonatomic, strong) id memoryWarningObserverToken;
@property (nonatomic, strong) id didEnterBackgroundObserverToken;
@property (nonatomic, strong) id willEnterForegroundObserverToken;
@end

static dispatch_queue_t TGLottieParseQueue(void) {
	static dispatch_queue_t queue = NULL;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		queue = dispatch_queue_create("com.kern0x1b.telegram.lottie.parse", DISPATCH_QUEUE_SERIAL);
	});
	return queue;
}

static NSDictionary *TGLottieParseFile(NSString *path) {
	NSData *raw = [NSData dataWithContentsOfFile:path];
	if (!raw.length)
		return nil;

	NSData *json = TGGunzip(raw);
	if (!json.length)
		json = raw;

	NSError *err = nil;
	id parsed = [NSJSONSerialization JSONObjectWithData:json options:0 error:&err];
	if (![parsed isKindOfClass:NSDictionary.class]) {
		NSLog(@"TGLottie: bad JSON: %@", err);
		return nil;
	}
	NSDictionary *anim = parsed;

	NSArray *layers = anim[@"layers"];
	if (![layers isKindOfClass:NSArray.class])
		layers = nil;

	CGSize canvas = CGSizeMake([anim[@"w"] doubleValue], [anim[@"h"] doubleValue]);
	if (layers.count == 0 || canvas.width <= 0 || canvas.height <= 0)
		return nil;

	NSMutableDictionary *byIndex = [NSMutableDictionary dictionary];
	for (NSDictionary *layer in layers) {
		if (![layer isKindOfClass:NSDictionary.class])
			continue;
		id ind = layer[@"ind"];
		if ([ind isKindOfClass:NSNumber.class])
			byIndex[ind] = layer;
	}

	return @{@"reversed" : [[layers reverseObjectEnumerator] allObjects],
		@"byIndex" : byIndex,
		@"ip" : @([anim[@"ip"] doubleValue]),
		@"op" : @([anim[@"op"] doubleValue]),
		@"fr" : @([anim[@"fr"] doubleValue]),
		@"w" : @(canvas.width),
		@"h" : @(canvas.height)};
}

static void TGLottieGradientColourAt(NSArray *stops, NSInteger stopCount,
	CGFloat at, CGFloat *out) {
	CGFloat firstAt = [stops[0] doubleValue];
	if (at <= firstAt) {
		for (NSInteger c = 0; c < 3; c++)
			out[c] = [stops[1 + c] doubleValue];
		return;
	}
	for (NSInteger i = 1; i < stopCount; i++) {
		CGFloat here = [stops[i * 4] doubleValue];
		if (at > here)
			continue;
		CGFloat before = [stops[(i - 1) * 4] doubleValue];
		CGFloat span = here - before;
		CGFloat t = span > 0.0001 ? (at - before) / span : 0;
		for (NSInteger c = 0; c < 3; c++) {
			CGFloat from = [stops[(i - 1) * 4 + 1 + c] doubleValue];
			CGFloat to = [stops[i * 4 + 1 + c] doubleValue];
			out[c] = from + (to - from) * t;
		}
		return;
	}
	for (NSInteger c = 0; c < 3; c++)
		out[c] = [stops[(stopCount - 1) * 4 + 1 + c] doubleValue];
}

static CGFloat TGLottieGradientAlphaAt(NSArray *stops, NSInteger stopCount,
	NSInteger transparencyStops, CGFloat at) {
	if (transparencyStops <= 0)
		return 1.0;

	NSInteger base = stopCount * 4;
	CGFloat firstAt = [stops[base] doubleValue];
	if (at <= firstAt)
		return [stops[base + 1] doubleValue];

	for (NSInteger i = 1; i < transparencyStops; i++) {
		CGFloat here = [stops[base + i * 2] doubleValue];
		if (at > here)
			continue;
		CGFloat before = [stops[base + (i - 1) * 2] doubleValue];
		CGFloat span = here - before;
		CGFloat t = span > 0.0001 ? (at - before) / span : 0;
		CGFloat from = [stops[base + (i - 1) * 2 + 1] doubleValue];
		CGFloat to = [stops[base + i * 2 + 1] doubleValue];
		return from + (to - from) * t;
	}
	return [stops[base + (transparencyStops - 1) * 2 + 1] doubleValue];
}

enum { kLottieGradientMaxStops = 16 };
static const CFIndex kLottieBezierCacheLimit = 2048;
static const size_t kLottieFrameCacheBudget = 6 * 1024 * 1024;
static const NSInteger kLottieMaxFrameCount = 4096;
static const NSTimeInterval kLottieExpensiveFrame = 0.02;

static size_t TGLottieFrameCacheSpent = 0;

static BOOL TGLottieFrameCacheTake(size_t bytes) {
	if (TGLottieFrameCacheSpent + bytes > kLottieFrameCacheBudget)
		return NO;
	TGLottieFrameCacheSpent += bytes;
	return YES;
}

static void TGLottieFrameCacheGiveBack(size_t bytes) {
	TGLottieFrameCacheSpent = bytes > TGLottieFrameCacheSpent
		? 0
		: TGLottieFrameCacheSpent - bytes;
}

@implementation TGLottieView {
	double _cumulativeAlpha;
	NSMapTable *_kfCursors;
	CFMutableDictionaryRef _bezierPaths;
	CFMutableDictionaryRef _gradients;
	CFMutableDictionaryRef _frameImages;
	NSInteger _frameIndex;
	NSInteger _frameCount;
	size_t _cachedFrameBytes;
	CGSize _cachedFrameSize;
	BOOL _cachesFrames;
	NSTimeInterval _renderCost;
	BOOL _appActive;
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		self.backgroundColor = [UIColor clearColor];
		self.opaque = NO;
		self.loopEnabled = YES;
		_kfCursors = [NSMapTable mapTableWithKeyOptions:NSMapTableObjectPointerPersonality | NSMapTableStrongMemory
										   valueOptions:NSMapTableStrongMemory];
		_bezierPaths = CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks);
		_gradients = CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks);
		_frameImages = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks,
			&kCFTypeDictionaryValueCallBacks);
		NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
		__weak typeof(self) weakSelf = self;
		self.memoryWarningObserverToken = [centre
			addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
						object:nil
						 queue:nil
					usingBlock:^(NSNotification *note) {
						__strong typeof(weakSelf) strongSelf = weakSelf;
						if (!strongSelf)
							return;
						[strongSelf handleMemoryWarning];
					}];
		_appActive = [UIApplication sharedApplication].applicationState != UIApplicationStateBackground;
		self.didEnterBackgroundObserverToken = [centre
			addObserverForName:UIApplicationDidEnterBackgroundNotification
						object:nil
						 queue:nil
					usingBlock:^(NSNotification *note) {
						__strong typeof(weakSelf) strongSelf = weakSelf;
						if (!strongSelf)
							return;
						[strongSelf handleDidEnterBackground];
					}];
		self.willEnterForegroundObserverToken = [centre
			addObserverForName:UIApplicationWillEnterForegroundNotification
						object:nil
						 queue:nil
					usingBlock:^(NSNotification *note) {
						__strong typeof(weakSelf) strongSelf = weakSelf;
						if (!strongSelf)
							return;
						[strongSelf handleWillEnterForeground];
					}];
	}
	return self;
}

- (void)dealloc {
	[_timer invalidate];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.memoryWarningObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.memoryWarningObserverToken];
	if (self.didEnterBackgroundObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.didEnterBackgroundObserverToken];
	if (self.willEnterForegroundObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.willEnterForegroundObserverToken];
	if (_bezierPaths)
		CFRelease(_bezierPaths);
	if (_gradients)
		CFRelease(_gradients);
	[self dropFrameCache];
	if (_frameImages)
		CFRelease(_frameImages);
}

- (void)dropFrameCache {
	if (!_frameImages)
		return;
	CFDictionaryRemoveAllValues(_frameImages);
	TGLottieFrameCacheGiveBack(_cachedFrameBytes);
	_cachedFrameBytes = 0;
	_cachesFrames = NO;
}

- (void)handleMemoryWarning {
	[self dropFrameCache];
}

- (void)handleDidEnterBackground {
	_appActive = NO;
	[self updatePlaybackState];
}

- (void)handleWillEnterForeground {
	_appActive = YES;
	[self updatePlaybackState];
}

- (BOOL)loadTGSFile:(NSString *)path {
	if (path.length && self.loaded && [path isEqualToString:self.loadedPath])
		return YES;

	if (path.length && [path isEqualToString:self.pendingPath])
		return YES;

	[self stop];
	self.wantsPlayback = NO;
	self.loaded = NO;
	self.reversedLayers = nil;
	self.layersByIndex = nil;
	self.loadedPath = nil;
	self.pendingPath = nil;

	if (!path.length || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		[self clearContents];
		return NO;
	}

	NSString *wanted = [path copy];
	self.pendingPath = wanted;

	__weak TGLottieView *weakSelf = self;
	dispatch_async(TGLottieParseQueue(), ^{
		NSDictionary *animation = TGLottieParseFile(wanted);
		dispatch_async(dispatch_get_main_queue(), ^{
			TGLottieView *strongSelf = weakSelf;
			if (!strongSelf || ![wanted isEqualToString:strongSelf.pendingPath])
				return;
			strongSelf.pendingPath = nil;
			[strongSelf applyAnimation:animation path:wanted];
		});
	});

	[self clearContents];
	return YES;
}

- (void)clearContents {
	[self dropFrameCache];
	self.layer.contents = nil;
}

- (void)applyAnimation:(NSDictionary *)animation path:(NSString *)path {
	if (!animation) {
		[self clearContents];
		return;
	}

	double ip = [animation[@"ip"] doubleValue];
	double op = [animation[@"op"] doubleValue];
	double fr = [animation[@"fr"] doubleValue];

	self.reversedLayers = animation[@"reversed"];
	self.layersByIndex = animation[@"byIndex"];
	self.inPoint = ip;
	self.outPoint = (op > ip) ? op : (ip + 1.0);
	self.frameRate = (fr > 0.0) ? fr : 60.0;
	self.canvas = CGSizeMake([animation[@"w"] doubleValue],
		[animation[@"h"] doubleValue]);
	self.currentFrame = ip;
	self.loaded = YES;
	_frameIndex = 0;
	_frameCount = (NSInteger)ceil((self.outPoint - self.inPoint) / [self frameStep]);
	if (_frameCount < 1)
		_frameCount = 1;
	if (_frameCount > kLottieMaxFrameCount)
		_frameCount = kLottieMaxFrameCount;
	_cachedFrameSize = self.bounds.size;
	CFDictionaryRemoveAllValues(_bezierPaths);
	CFDictionaryRemoveAllValues(_gradients);
	[self dropFrameCache];
	self.loadedPath = path;
	[_kfCursors removeAllObjects];

	[self updatePlaybackState];
	[self showCurrentFrame];
}

- (void)play {
	self.wantsPlayback = YES;
	[self updatePlaybackState];
}

- (void)stop {
	self.wantsPlayback = NO;
	[self.timer invalidate];
	self.timer = nil;
}

- (void)updatePlaybackState {
	BOOL shouldPlay = self.wantsPlayback && self.loaded && self.window != nil &&
		!self.hidden && self.alpha > 0.01 && _appActive;

	if (shouldPlay && !self.timer) {
		TGLottieTimerProxy *proxy = [[TGLottieTimerProxy alloc] init];
		proxy.target = self;

		self.timer = [NSTimer timerWithTimeInterval:1.0 / 20.0
											 target:proxy
										   selector:@selector(tick:)
										   userInfo:nil
											repeats:YES];
		[[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
	} else if (!shouldPlay && self.timer) {
		[self.timer invalidate];
		self.timer = nil;
	}
}

- (void)didMoveToWindow {
	[super didMoveToWindow];
	[self updatePlaybackState];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	if (CGSizeEqualToSize(_cachedFrameSize, self.bounds.size))
		return;
	_cachedFrameSize = self.bounds.size;
	[self dropFrameCache];
	[self showCurrentFrame];
}

- (void)setHidden:(BOOL)hidden {
	[super setHidden:hidden];
	[self updatePlaybackState];
}

- (void)tick {
	if (!self.loaded)
		return;
	if (!self.loopEnabled && _frameCount > 0 && _frameIndex >= _frameCount - 1) {
		[self stop];
		return;
	}
	_frameIndex = (_frameCount > 0) ? (_frameIndex + 1) % _frameCount : 0;
	self.currentFrame = self.inPoint + _frameIndex * [self frameStep];

	if ([self drawsEveryOtherTick] && (_frameIndex % 2) != 0)
		return;
	[self showCurrentFrame];
}

- (BOOL)drawsEveryOtherTick {
	return !_cachesFrames && _renderCost > kLottieExpensiveFrame;
}

- (double)frameStep {
	double step = self.frameRate / 20.0;
	return step > 0.0 ? step : 1.0;
}

#pragma mark - drawing

- (void)renderIntoContext:(CGContextRef)ctx {
	if (!self.loaded || !ctx)
		return;
	if (self.canvas.width <= 0 || self.canvas.height <= 0 ||
		self.bounds.size.width <= 0 || self.bounds.size.height <= 0)
		return;

	CGContextSaveGState(ctx);
	_cumulativeAlpha = 1.0;

	CGFloat scale = MIN(self.bounds.size.width / self.canvas.width,
		self.bounds.size.height / self.canvas.height);
	CGContextTranslateCTM(ctx,
		(self.bounds.size.width - self.canvas.width * scale) / 2,
		(self.bounds.size.height - self.canvas.height * scale) / 2);
	CGContextScaleCTM(ctx, scale, scale);

	for (NSDictionary *layer in self.reversedLayers) {
		@autoreleasepool {
			[self drawLottieLayer:layer inContext:ctx];
		}
	}

	CGContextRestoreGState(ctx);
}

- (void)reserveFrameCacheIfWorthIt {
	if (_cachesFrames || _cachedFrameBytes > 0 || _frameCount < 1)
		return;

	CGFloat scale = self.contentScaleFactor > 0 ? self.contentScaleFactor : 1;
	size_t width = (size_t)(self.bounds.size.width * scale);
	size_t height = (size_t)(self.bounds.size.height * scale);
	if (width == 0 || height == 0)
		return;

	uint64_t wanted64 = (uint64_t)width * (uint64_t)height * 4ULL * (uint64_t)_frameCount;
	if (wanted64 > (uint64_t)kLottieFrameCacheBudget)
		return;

	size_t wanted = (size_t)wanted64;
	if (!TGLottieFrameCacheTake(wanted))
		return;

	_cachedFrameBytes = wanted;
	_cachesFrames = YES;
}

- (CGImageRef)renderedFrameImage CF_RETURNS_RETAINED {
	NSTimeInterval started = [NSDate timeIntervalSinceReferenceDate];
	CGFloat scale = self.contentScaleFactor > 0 ? self.contentScaleFactor : 1;
	size_t width = (size_t)(self.bounds.size.width * scale);
	size_t height = (size_t)(self.bounds.size.height * scale);
	if (width == 0 || height == 0)
		return NULL;

	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(NULL, width, height, 8, 0, space,
		kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
	CGColorSpaceRelease(space);
	if (!ctx)
		return NULL;

	CGContextScaleCTM(ctx, scale, scale);
	CGContextTranslateCTM(ctx, 0, self.bounds.size.height);
	CGContextScaleCTM(ctx, 1, -1);
	[self renderIntoContext:ctx];

	CGImageRef image = CGBitmapContextCreateImage(ctx);
	CGContextRelease(ctx);

	_renderCost = [NSDate timeIntervalSinceReferenceDate] - started;
	if (TGPerfLogging())
		NSLog(@"PERF lottie renders %.0fx%.0f in %.1f ms, caching %@",
			self.bounds.size.width, self.bounds.size.height,
			_renderCost * 1000.0, _cachesFrames ? @"on" : @"off");
	return image;
}

- (void)showCurrentFrame {
	if (!self.loaded)
		return;

	[self reserveFrameCacheIfWorthIt];

	NSNumber *key = @(_frameIndex);
	CGImageRef cached = (CGImageRef)CFDictionaryGetValue(_frameImages, (__bridge const void *)key);
	CGFloat scale = self.contentScaleFactor > 0 ? self.contentScaleFactor : 1;
	if (cached) {
		self.layer.contentsScale = scale;
		self.layer.contents = (__bridge id)cached;
		return;
	}

	CGImageRef image = [self renderedFrameImage];
	if (!image)
		return;

	self.layer.contentsScale = scale;
	self.layer.contents = (__bridge id)image;

	if (_cachesFrames)
		CFDictionarySetValue(_frameImages, (__bridge const void *)key, image);
	CGImageRelease(image);
}

- (void)drawLottieLayer:(NSDictionary *)layer inContext:(CGContextRef)ctx {
	if (![layer isKindOfClass:NSDictionary.class])
		return;

	if ([layer[@"ty"] intValue] != 4)
		return;

	if ([layer[@"hd"] boolValue] || [layer[@"td"] intValue] != 0)
		return;

	double frame = self.currentFrame;
	double ip = [layer[@"ip"] doubleValue];
	double op = [layer[@"op"] doubleValue];
	if (frame < ip || frame > op)
		return;

	NSArray *shapes = layer[@"shapes"];
	if (![shapes isKindOfClass:NSArray.class] || shapes.count == 0)
		return;

	double savedAlpha = _cumulativeAlpha;
	CGContextSaveGState(ctx);
	NSArray *chain = [self transformChainForLayer:layer];
	for (NSDictionary *ancestor in chain)
		[self applyTransform:ancestor[@"ks"] atFrame:frame inContext:ctx
					 opacity:NO];
	[self applyTransform:layer[@"ks"] atFrame:frame inContext:ctx opacity:YES];
	[self drawShapes:shapes atFrame:frame inContext:ctx];
	CGContextRestoreGState(ctx);
	_cumulativeAlpha = savedAlpha;
}

- (NSArray *)transformChainForLayer:(NSDictionary *)layer {
	if (self.layersByIndex.count == 0)
		return nil;

	NSMutableArray *chain = nil;
	NSMutableSet *seen = nil;
	id parent = layer[@"parent"];
	NSInteger depth = 0;

	while ([parent isKindOfClass:NSNumber.class] && depth < 16) {
		NSDictionary *p = self.layersByIndex[parent];
		if (![p isKindOfClass:NSDictionary.class])
			break;
		if (!seen)
			seen = [NSMutableSet set];
		if ([seen containsObject:parent])
			break;
		[seen addObject:parent];

		if (!chain)
			chain = [NSMutableArray array];
		[chain insertObject:p atIndex:0];

		parent = p[@"parent"];
		depth++;
	}

	return chain;
}

- (void)applyTransform:(NSDictionary *)ks atFrame:(double)frame inContext:(CGContextRef)ctx {
	[self applyTransform:ks atFrame:frame inContext:ctx opacity:YES];
}

- (void)applyTransform:(NSDictionary *)ks
			   atFrame:(double)frame
			 inContext:(CGContextRef)ctx
			   opacity:(BOOL)appliesOpacity {
	if (![ks isKindOfClass:NSDictionary.class])
		return;

	NSArray *pos = TGValueAt(ks[@"p"], frame, _kfCursors);
	NSArray *anchor = TGValueAt(ks[@"a"], frame, _kfCursors);
	NSArray *scale = TGValueAt(ks[@"s"], frame, _kfCursors);
	double rotation = TGScalarAt(ks[@"r"], frame, 0, _kfCursors);
	double opacity = TGScalarAt(ks[@"o"], frame, 100, _kfCursors);

	if (pos.count >= 2)
		CGContextTranslateCTM(ctx, [pos[0] doubleValue], [pos[1] doubleValue]);
	if (rotation != 0)
		CGContextRotateCTM(ctx, rotation * M_PI / 180.0);
	if (scale.count >= 2) {
		double sx = [scale[0] doubleValue] / 100.0;
		double sy = [scale[1] doubleValue] / 100.0;
		if (sx != 0.0 && sy != 0.0)
			CGContextScaleCTM(ctx, sx, sy);
	}
	if (anchor.count >= 2)
		CGContextTranslateCTM(ctx, -[anchor[0] doubleValue], -[anchor[1] doubleValue]);

	if (!appliesOpacity)
		return;

	if (opacity < 0)
		opacity = 0;
	if (opacity > 100)
		opacity = 100;
	_cumulativeAlpha *= opacity / 100.0;
	CGContextSetAlpha(ctx, _cumulativeAlpha);
}

- (void)drawShapes:(NSArray *)shapes atFrame:(double)frame inContext:(CGContextRef)ctx {
	if (![shapes isKindOfClass:NSArray.class])
		return;

	CGMutablePathRef path = CGPathCreateMutable();

	for (NSDictionary *shape in [shapes reverseObjectEnumerator]) {
		if (![shape isKindOfClass:NSDictionary.class] || [shape[@"hd"] boolValue])
			continue;
		if (![shape[@"ty"] isEqualToString:@"gr"])
			continue;
		NSArray *items = shape[@"it"];
		if (![items isKindOfClass:NSArray.class])
			continue;

		double savedAlpha = _cumulativeAlpha;
		CGContextSaveGState(ctx);
		for (NSDictionary *item in items) {
			if (![item isKindOfClass:NSDictionary.class])
				continue;
			id ity = item[@"ty"];
			if ([ity isKindOfClass:NSString.class] &&
				[(NSString *)ity isEqualToString:@"tr"])
				[self applyTransform:item atFrame:frame inContext:ctx];
		}
		[self drawShapes:items atFrame:frame inContext:ctx];
		CGContextRestoreGState(ctx);
		_cumulativeAlpha = savedAlpha;
	}

	for (NSDictionary *shape in shapes) {
		if (![shape isKindOfClass:NSDictionary.class] || [shape[@"hd"] boolValue])
			continue;

		NSString *ty = shape[@"ty"];
		if (![ty isKindOfClass:NSString.class])
			continue;

		if ([ty isEqualToString:@"gr"]) {
			continue;

		} else if ([ty isEqualToString:@"sh"]) {
			[self appendBezier:shape[@"ks"] atFrame:frame toPath:path];

		} else if ([ty isEqualToString:@"el"]) {
			NSArray *p = TGValueAt(shape[@"p"], frame, _kfCursors);
			NSArray *s = TGValueAt(shape[@"s"], frame, _kfCursors);
			if (p.count >= 2 && s.count >= 2) {
				CGRect r = CGRectMake([p[0] doubleValue] - [s[0] doubleValue] / 2,
					[p[1] doubleValue] - [s[1] doubleValue] / 2,
					[s[0] doubleValue], [s[1] doubleValue]);
				CGPathAddEllipseInRect(path, NULL, r);
			}

		} else if ([ty isEqualToString:@"rc"]) {
			NSArray *p = TGValueAt(shape[@"p"], frame, _kfCursors);
			NSArray *s = TGValueAt(shape[@"s"], frame, _kfCursors);
			double radius = TGScalarAt(shape[@"r"], frame, 0, _kfCursors);
			if (p.count >= 2 && s.count >= 2) {
				CGRect r = CGRectMake([p[0] doubleValue] - [s[0] doubleValue] / 2,
					[p[1] doubleValue] - [s[1] doubleValue] / 2,
					[s[0] doubleValue], [s[1] doubleValue]);
				if (radius > 0) {
					UIBezierPath *rounded = [UIBezierPath bezierPathWithRoundedRect:r
																	   cornerRadius:radius];
					CGPathAddPath(path, NULL, rounded.CGPath);
				} else {
					CGPathAddRect(path, NULL, r);
				}
			}

		} else if ([ty isEqualToString:@"fl"]) {
			[self fillPath:path withShape:shape atFrame:frame inContext:ctx];

		} else if ([ty isEqualToString:@"gf"]) {
			[self fillPath:path withGradientShape:shape atFrame:frame inContext:ctx];

		} else if ([ty isEqualToString:@"st"]) {
			[self strokePath:path withShape:shape atFrame:frame inContext:ctx];
		}
	}

	CGPathRelease(path);
}

- (CGPathRef)cachedBezierForValue:(NSArray *)value key:(const void *)key {
	if (!key)
		return NULL;

	CGPathRef cached = (CGPathRef)CFDictionaryGetValue(_bezierPaths, key);
	if (cached)
		return cached;

	CGMutablePathRef built = CGPathCreateMutable();
	for (NSDictionary *shape in value) {
		if (![shape isKindOfClass:NSDictionary.class])
			continue;

		NSArray *v = shape[@"v"], *in = shape[@"i"], *out = shape[@"o"];
		if (![v isKindOfClass:NSArray.class] || v.count < 2 ||
			![in isKindOfClass:NSArray.class] || in.count < v.count ||
			![out isKindOfClass:NSArray.class] || out.count < v.count)
			continue;

		BOOL malformed = NO;
		for (NSInteger i = 0; i < v.count; i++) {
			NSArray *vi = v[i], *ii = in[i], *oi = out[i];
			if (![vi isKindOfClass:NSArray.class] || vi.count < 2 ||
				![ii isKindOfClass:NSArray.class] || ii.count < 2 ||
				![oi isKindOfClass:NSArray.class] || oi.count < 2) {
				malformed = YES;
				break;
			}
		}
		if (malformed)
			continue;

		CGPathMoveToPoint(built, NULL, [v[0][0] doubleValue], [v[0][1] doubleValue]);
		for (NSInteger i = 1; i < v.count; i++) {
			NSInteger p = i - 1;
			CGPathAddCurveToPoint(built, NULL,
				[v[p][0] doubleValue] + [out[p][0] doubleValue],
				[v[p][1] doubleValue] + [out[p][1] doubleValue],
				[v[i][0] doubleValue] + [in[i][0] doubleValue],
				[v[i][1] doubleValue] + [in[i][1] doubleValue],
				[v[i][0] doubleValue], [v[i][1] doubleValue]);
		}

		if ([shape[@"c"] boolValue]) {
			NSInteger last = v.count - 1;
			CGPathAddCurveToPoint(built, NULL,
				[v[last][0] doubleValue] + [out[last][0] doubleValue],
				[v[last][1] doubleValue] + [out[last][1] doubleValue],
				[v[0][0] doubleValue] + [in[0][0] doubleValue],
				[v[0][1] doubleValue] + [in[0][1] doubleValue],
				[v[0][0] doubleValue], [v[0][1] doubleValue]);
			CGPathCloseSubpath(built);
		}
	}

	if (CFDictionaryGetCount(_bezierPaths) > kLottieBezierCacheLimit)
		CFDictionaryRemoveAllValues(_bezierPaths);
	CFDictionarySetValue(_bezierPaths, key, built);
	CGPathRelease(built);
	return (CGPathRef)CFDictionaryGetValue(_bezierPaths, key);
}

- (void)appendBezier:(NSDictionary *)ks atFrame:(double)frame toPath:(CGMutablePathRef)path {
	if (![ks isKindOfClass:NSDictionary.class])
		return;

	NSArray *value = nil;
	const void *key = NULL;
	id k = ks[@"k"];

	if ([k isKindOfClass:NSDictionary.class]) {
		value = @[ k ];
		key = (__bridge const void *)ks;
	} else if ([k isKindOfClass:NSArray.class] &&
		[[k firstObject] isKindOfClass:NSDictionary.class] &&
		[[k firstObject] objectForKey:@"t"]) {
		NSDictionary *chosen = [k firstObject];
		for (NSDictionary *kf in k)
			if ([kf isKindOfClass:NSDictionary.class] &&
				[kf[@"t"] doubleValue] <= frame)
				chosen = kf;
		id s = chosen[@"s"];
		value = [s isKindOfClass:NSArray.class] ? s : (s ? @[ s ] : nil);
		key = (__bridge const void *)chosen;
	} else if ([k isKindOfClass:NSArray.class]) {
		value = k;
		key = (__bridge const void *)k;
	}

	CGPathRef built = [self cachedBezierForValue:value key:key];
	if (built)
		CGPathAddPath(path, NULL, built);
}

- (void)fillPath:(CGPathRef)path withShape:(NSDictionary *)shape
		 atFrame:(double)frame
	   inContext:(CGContextRef)ctx {
	NSArray *c = TGValueAt(shape[@"c"], frame, _kfCursors);
	if (c.count < 3 || CGPathIsEmpty(path))
		return;

	double alpha = TGScalarAt(shape[@"o"], frame, 100, _kfCursors) / 100.0;
	if (alpha <= 0.0)
		return;
	if (alpha > 1.0)
		alpha = 1.0;

	CGContextSetRGBFillColor(ctx, [c[0] doubleValue], [c[1] doubleValue],
		[c[2] doubleValue], alpha);
	CGContextAddPath(ctx, path);

	if ([shape[@"r"] intValue] == 2)
		CGContextEOFillPath(ctx);
	else
		CGContextFillPath(ctx);
}

- (void)fillPath:(CGPathRef)path
	withGradientShape:(NSDictionary *)shape
			  atFrame:(double)frame
			inContext:(CGContextRef)ctx {
	if (CGPathIsEmpty(path))
		return;

	NSDictionary *gradient = shape[@"g"];
	if (![gradient isKindOfClass:NSDictionary.class])
		return;

	NSInteger stopCount = [gradient[@"p"] integerValue];
	NSArray *stops = TGValueAt(gradient[@"k"], frame, _kfCursors);
	if (stopCount < 2 || stops.count < (NSUInteger)(stopCount * 4))
		return;

	NSArray *start = TGValueAt(shape[@"s"], frame, _kfCursors);
	NSArray *end = TGValueAt(shape[@"e"], frame, _kfCursors);
	if (start.count < 2 || end.count < 2)
		return;

	double alpha = TGScalarAt(shape[@"o"], frame, 100, _kfCursors) / 100.0;
	if (alpha <= 0.0)
		return;
	if (alpha > 1.0)
		alpha = 1.0;

	NSInteger transparencyStops = (NSInteger)(stops.count - stopCount * 4) / 2;
	CGFloat positions[kLottieGradientMaxStops];
	NSInteger used = 0;
	for (NSInteger i = 0; i < stopCount && used < (NSInteger)kLottieGradientMaxStops; i++)
		positions[used++] = [stops[i * 4] doubleValue];
	for (NSInteger i = 0; i < transparencyStops && used < (NSInteger)kLottieGradientMaxStops; i++) {
		CGFloat at = [stops[stopCount * 4 + i * 2] doubleValue];
		BOOL known = NO;
		for (NSInteger j = 0; j < used; j++)
			known = known || fabs(positions[j] - at) < 0.0001;
		if (!known)
			positions[used++] = at;
	}
	for (NSInteger i = 1; i < used; i++)
		for (NSInteger j = i; j > 0 && positions[j] < positions[j - 1]; j--) {
			CGFloat swap = positions[j];
			positions[j] = positions[j - 1];
			positions[j - 1] = swap;
		}

	CGFloat components[kLottieGradientMaxStops * 4];
	for (NSInteger i = 0; i < used; i++) {
		CGFloat colour[3];
		TGLottieGradientColourAt(stops, stopCount, positions[i], colour);
		components[i * 4 + 0] = colour[0];
		components[i * 4 + 1] = colour[1];
		components[i * 4 + 2] = colour[2];
		components[i * 4 + 3] = alpha * TGLottieGradientAlphaAt(stops, stopCount, transparencyStops, positions[i]);
	}

	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGGradientRef ramp = CGGradientCreateWithColorComponents(space, components,
		positions, (size_t)used);
	CGColorSpaceRelease(space);
	if (!ramp)
		return;

	CGPoint from = CGPointMake([start[0] doubleValue], [start[1] doubleValue]);
	CGPoint to = CGPointMake([end[0] doubleValue], [end[1] doubleValue]);
	CGGradientDrawingOptions edges = kCGGradientDrawsBeforeStartLocation |
		kCGGradientDrawsAfterEndLocation;

	CGContextSaveGState(ctx);
	CGContextAddPath(ctx, path);
	if ([shape[@"r"] intValue] == 2)
		CGContextEOClip(ctx);
	else
		CGContextClip(ctx);

	if ([shape[@"t"] intValue] == 2) {
		CGFloat radius = hypotf(to.x - from.x, to.y - from.y);
		CGContextDrawRadialGradient(ctx, ramp, from, 0, from, radius, edges);
	} else {
		CGContextDrawLinearGradient(ctx, ramp, from, to, edges);
	}
	CGContextRestoreGState(ctx);
	CGGradientRelease(ramp);
}

- (void)strokePath:(CGPathRef)path withShape:(NSDictionary *)shape
		   atFrame:(double)frame
		 inContext:(CGContextRef)ctx {
	NSArray *c = TGValueAt(shape[@"c"], frame, _kfCursors);
	if (c.count < 3 || CGPathIsEmpty(path))
		return;

	double alpha = TGScalarAt(shape[@"o"], frame, 100, _kfCursors) / 100.0;
	double width = TGScalarAt(shape[@"w"], frame, 1, _kfCursors);
	if (alpha <= 0.0 || width <= 0.0)
		return;
	if (alpha > 1.0)
		alpha = 1.0;

	CGContextSetRGBStrokeColor(ctx, [c[0] doubleValue], [c[1] doubleValue],
		[c[2] doubleValue], alpha);
	CGContextSetLineWidth(ctx, width);

	switch ([shape[@"lc"] intValue]) {
		case 2:
			CGContextSetLineCap(ctx, kCGLineCapRound);
			break;
		case 3:
			CGContextSetLineCap(ctx, kCGLineCapSquare);
			break;
		default:
			CGContextSetLineCap(ctx, kCGLineCapButt);
			break;
	}
	switch ([shape[@"lj"] intValue]) {
		case 2:
			CGContextSetLineJoin(ctx, kCGLineJoinRound);
			break;
		case 3:
			CGContextSetLineJoin(ctx, kCGLineJoinBevel);
			break;
		default:
			CGContextSetLineJoin(ctx, kCGLineJoinMiter);
			break;
	}
	double miter = TGScalarAt(shape[@"ml"], frame, 0, _kfCursors);
	if (miter > 0)
		CGContextSetMiterLimit(ctx, miter);
	CGContextAddPath(ctx, path);
	CGContextStrokePath(ctx);
}

@end

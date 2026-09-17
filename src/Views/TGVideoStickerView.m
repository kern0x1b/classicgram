#import "TGVideoStickerView.h"
#import "TGWebMStickerDecoder.h"

static dispatch_queue_t TGVideoStickerDecodeQueue(void) {
	static dispatch_queue_t queue;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		queue = dispatch_queue_create("telegram.video-sticker.decode", DISPATCH_QUEUE_SERIAL);
	});
	return queue;
}

@interface TGVideoStickerTimerProxy : NSObject
@property (nonatomic, weak) TGVideoStickerView *target;
@end

@interface TGVideoStickerView ()
@property (nonatomic, assign, readwrite) BOOL loaded;
@property (nonatomic, assign) BOOL wantsPlayback;
@property (nonatomic, assign) BOOL appActive;
@property (nonatomic, assign) BOOL decoding;
@property (nonatomic, assign) BOOL reachedEnd;
@property (nonatomic, assign) BOOL reopening;
@property (nonatomic, copy) NSString *loadedPath;
@property (nonatomic, copy) NSString *pendingPath;
@property (nonatomic, strong) TGWebMStickerDecoder *decoder;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) id didEnterBackgroundObserverToken;
@property (nonatomic, strong) id willEnterForegroundObserverToken;
- (void)tick;
@end

@implementation TGVideoStickerTimerProxy

- (void)tick:(NSTimer *)timer {
	TGVideoStickerView *target = self.target;
	if (target)
		[target tick];
	else
		[timer invalidate];
}

@end

@implementation TGVideoStickerView

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self)
		return nil;

	self.backgroundColor = [UIColor clearColor];
	self.opaque = NO;
	self.loopEnabled = YES;
	self.layer.contentsGravity = kCAGravityResizeAspect;
	self.appActive = [UIApplication sharedApplication].applicationState != UIApplicationStateBackground;

	__weak typeof(self) weakSelf = self;
	NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
	self.didEnterBackgroundObserverToken = [centre addObserverForName:UIApplicationDidEnterBackgroundNotification
															   object:nil
																queue:nil
														   usingBlock:^(NSNotification *note) {
		weakSelf.appActive = NO;
		[weakSelf updatePlaybackState];
	}];
	self.willEnterForegroundObserverToken = [centre addObserverForName:UIApplicationWillEnterForegroundNotification
																object:nil
																 queue:nil
															usingBlock:^(NSNotification *note) {
		weakSelf.appActive = YES;
		[weakSelf updatePlaybackState];
	}];
	return self;
}

- (void)dealloc {
	[_timer invalidate];
	if (_didEnterBackgroundObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_didEnterBackgroundObserverToken];
	if (_willEnterForegroundObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_willEnterForegroundObserverToken];
}

- (BOOL)loadWebMFile:(NSString *)path {
	if (path.length && self.loaded && [path isEqualToString:self.loadedPath])
		return YES;
	if (path.length && [path isEqualToString:self.pendingPath])
		return YES;

	[self stop];
	self.loaded = NO;
	self.reopening = NO;
	self.decoder = nil;
	self.loadedPath = nil;
	self.pendingPath = nil;
	self.reachedEnd = NO;
	self.layer.contents = nil;

	if (!path.length || ![[NSFileManager defaultManager] fileExistsAtPath:path])
		return NO;

	NSString *wanted = [path copy];
	self.pendingPath = wanted;
	NSUInteger side = [self pixelSide];
	__weak TGVideoStickerView *weakSelf = self;
	dispatch_async(TGVideoStickerDecodeQueue(), ^{
		TGWebMStickerDecoder *decoder = [[TGWebMStickerDecoder alloc] initWithPath:wanted];
		CGImageRef first = [decoder copyNextFrameFittingSide:side];
		dispatch_async(dispatch_get_main_queue(), ^{
			TGVideoStickerView *strongSelf = weakSelf;
			if (strongSelf && [wanted isEqualToString:strongSelf.pendingPath]) {
				strongSelf.pendingPath = nil;
				if (decoder && first) {
					strongSelf.decoder = decoder;
					strongSelf.loadedPath = wanted;
					strongSelf.loaded = YES;
					strongSelf.layer.contents = (__bridge id)first;
					[strongSelf updatePlaybackState];
				}
			}
			if (first)
				CGImageRelease(first);
		});
	});
	return YES;
}

- (NSUInteger)pixelSide {
	CGFloat scale = self.window.screen.scale ?: [UIScreen mainScreen].scale;
	CGFloat side = MAX(self.bounds.size.width, self.bounds.size.height) * scale;
	return side > 0 ? (NSUInteger)ceil(side) : 256;
}

- (void)play {
	self.wantsPlayback = YES;
	if (self.reachedEnd) {
		self.reachedEnd = NO;
		TGWebMStickerDecoder *decoder = self.decoder;
		dispatch_async(TGVideoStickerDecodeQueue(), ^{
			[decoder rewind];
		});
	}
	[self updatePlaybackState];
}

- (void)stop {
	self.wantsPlayback = NO;
	[self.timer invalidate];
	self.timer = nil;
}

- (void)updatePlaybackState {
	BOOL shouldPlay = self.wantsPlayback && self.loaded && !self.reachedEnd && self.window != nil &&
		!self.hidden && self.alpha > 0.01 && self.appActive;
	if (shouldPlay && !self.decoder) {
		[self reopenDecoder];
		shouldPlay = NO;
	}

	if (shouldPlay && !self.timer) {
		TGVideoStickerTimerProxy *proxy = [[TGVideoStickerTimerProxy alloc] init];
		proxy.target = self;
		self.timer = [NSTimer timerWithTimeInterval:self.decoder.frameDuration
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
	if (!self.window)
		self.decoder = nil;
	[self updatePlaybackState];
}

- (void)reopenDecoder {
	if (self.reopening || !self.loadedPath)
		return;
	self.reopening = YES;
	self.reachedEnd = NO;
	NSString *path = self.loadedPath;
	__weak TGVideoStickerView *weakSelf = self;
	dispatch_async(TGVideoStickerDecodeQueue(), ^{
		TGWebMStickerDecoder *decoder = [[TGWebMStickerDecoder alloc] initWithPath:path];
		dispatch_async(dispatch_get_main_queue(), ^{
			TGVideoStickerView *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			strongSelf.reopening = NO;
			if (![path isEqualToString:strongSelf.loadedPath])
				return;
			if (!decoder) {
				strongSelf.loaded = NO;
				return;
			}
			strongSelf.decoder = decoder;
			[strongSelf updatePlaybackState];
		});
	});
}

- (void)setHidden:(BOOL)hidden {
	[super setHidden:hidden];
	[self updatePlaybackState];
}

- (void)tick {
	if (self.decoding || !self.decoder)
		return;
	self.decoding = YES;

	TGWebMStickerDecoder *decoder = self.decoder;
	NSString *path = self.loadedPath;
	BOOL loops = self.loopEnabled;
	NSUInteger side = [self pixelSide];
	__weak TGVideoStickerView *weakSelf = self;
	dispatch_async(TGVideoStickerDecodeQueue(), ^{
		CGImageRef frame = [decoder copyNextFrameFittingSide:side];
		BOOL ended = frame == NULL;
		if (ended && loops) {
			[decoder rewind];
			frame = [decoder copyNextFrameFittingSide:side];
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			TGVideoStickerView *strongSelf = weakSelf;
			if (strongSelf) {
				strongSelf.decoding = NO;
				if ([path isEqualToString:strongSelf.loadedPath]) {
					if (frame)
						strongSelf.layer.contents = (__bridge id)frame;
					if (ended && !loops) {
						strongSelf.reachedEnd = YES;
						[strongSelf updatePlaybackState];
					}
				}
			}
			if (frame)
				CGImageRelease(frame);
		});
	});
}

@end

#import "TGBackgroundSession.h"
#import "TGClient+Private.h"
#import "TGClient+Network.h"
#import "TGReachabilityMonitor.h"

#include <dlfcn.h>
#include <errno.h>
#include <limits.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <time.h>

#import <CFNetwork/CFNetwork.h>

typedef void (*TGPrimarySocketCallback)(int fd);
typedef void (*TGSetPrimarySocketCallbackFn)(TGPrimarySocketCallback callback);

static const NSTimeInterval kKeepAliveTimeout = 600.0;
static const NSTimeInterval kHealthIntervalDay = 30.0 * 60.0;
static const NSTimeInterval kHealthIntervalNight = 60.0 * 60.0;
static const NSTimeInterval kHealthProbeTimeout = 8.0;
static const NSTimeInterval kColdLaunchLeaseCap = 120.0;
static const int kTcpKeepAliveIdleSeconds = 60;

static NSString *const TGBackgroundSessionDefaultsKey = @"backgroundDeliveryEnabled";

static CFReadStreamRef TGVoipReadStream = NULL;
static CFWriteStreamRef TGVoipWriteStream = NULL;
static int TGVoipSocket = -1;
static volatile int32_t TGVoipMarked = 0;
static NSLock *TGVoipLock = nil;

static void TGVoipReleaseStreamsLocked(void) {
	if (TGVoipReadStream) {
		CFReadStreamClose(TGVoipReadStream);
		CFRelease(TGVoipReadStream);
		TGVoipReadStream = NULL;
	}
	if (TGVoipWriteStream) {
		CFWriteStreamClose(TGVoipWriteStream);
		CFRelease(TGVoipWriteStream);
		TGVoipWriteStream = NULL;
	}
}

static void TGVoipMarkPrimarySocket(int fd) {
	if (fd < 0)
		return;

	@autoreleasepool {
		[TGVoipLock lock];

		TGVoipReleaseStreamsLocked();
		TGVoipSocket = fd;
		TGVoipMarked = 0;

		CFReadStreamRef readStream = NULL;
		CFWriteStreamRef writeStream = NULL;
		CFStreamCreatePairWithSocket(NULL, (CFSocketNativeHandle)fd, &readStream, &writeStream);

		BOOL ok = readStream != NULL && writeStream != NULL;
		if (ok) {
			CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanFalse);
			CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanFalse);

			BOOL r1 = CFReadStreamSetProperty(readStream, kCFStreamNetworkServiceType,
				kCFStreamNetworkServiceTypeVoIP);
			BOOL r2 = CFWriteStreamSetProperty(writeStream, kCFStreamNetworkServiceType,
				kCFStreamNetworkServiceTypeVoIP);
			ok = r1 && r2;

			if (ok)
				ok = CFReadStreamOpen(readStream) && CFWriteStreamOpen(writeStream);
		}

		int keepAlive = 1;
		int keepAliveResult = setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &keepAlive, sizeof(keepAlive));
		int keepAliveError = keepAliveResult == 0 ? 0 : errno;
		int idle = kTcpKeepAliveIdleSeconds;
		int idleResult = setsockopt(fd, IPPROTO_TCP, TCP_KEEPALIVE, &idle, sizeof(idle));
		int idleError = idleResult == 0 ? 0 : errno;

		if (ok) {
			TGVoipReadStream = readStream;
			TGVoipWriteStream = writeStream;
			TGVoipMarked = 1;
		} else {
			if (readStream) {
				CFReadStreamClose(readStream);
				CFRelease(readStream);
			}
			if (writeStream) {
				CFWriteStreamClose(writeStream);
				CFRelease(writeStream);
			}
		}

		[TGVoipLock unlock];

		NSLog(@"BGSESSION socket fd=%d voip=%d soKeepAlive=%d/%d tcpKeepAlive=%d/%d",
			fd, ok ? 1 : 0, keepAliveResult, keepAliveError, idleResult, idleError);
	}
}

@interface TGBackgroundSession ()

@property (nonatomic, assign) BOOL launchedIntoBackground;
@property (nonatomic, assign) BOOL hookInstalled;
@property (nonatomic, assign) BOOL keepAliveInstalled;
@property (nonatomic, assign) time_t lastReceive;
@property (nonatomic, assign) NSTimeInterval lastHealthCheck;
@property (nonatomic, assign) BOOL healthCheckRunning;
@property (nonatomic, assign) NSUInteger healthCheckGeneration;
@property (nonatomic, assign) UIBackgroundTaskIdentifier healthTask;
@property (nonatomic, assign) UIBackgroundTaskIdentifier coldLaunchTask;

@end

@implementation TGBackgroundSession {
	time_t _lastReceive;
}

+ (instancetype)shared {
	static TGBackgroundSession *shared = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		TGVoipLock = [[NSLock alloc] init];
		shared = [[TGBackgroundSession alloc] init];
	});
	return shared;
}

- (id)init {
	self = [super init];
	if (!self)
		return nil;
	_healthTask = UIBackgroundTaskInvalid;
	_coldLaunchTask = UIBackgroundTaskInvalid;
	return self;
}

#pragma mark - gate

+ (BOOL)enabled {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	id stored = [defaults objectForKey:TGBackgroundSessionDefaultsKey];
	return stored == nil ? YES : [stored boolValue];
}

- (BOOL)isLegacySystem {
	return [[UIDevice currentDevice].systemVersion intValue] <= 8;
}

#pragma mark - TDLib hook

- (void)attachToTDLibHandle:(void *)handle {
	if (self.hookInstalled || !handle)
		return;

	TGSetPrimarySocketCallbackFn setter =
		(TGSetPrimarySocketCallbackFn)dlsym(handle, "td_ios_set_primary_socket_callback");
	if (!setter) {
		NSLog(@"BGSESSION no td_ios_set_primary_socket_callback in libtdjson.dylib - "
			   "rebuild it with scripts/build-tdlib-dylib.sh");
		return;
	}

	self.hookInstalled = YES;
	if (![TGBackgroundSession enabled]) {
		setter(NULL);
		NSLog(@"BGSESSION disabled by user default %@", TGBackgroundSessionDefaultsKey);
		return;
	}

	setter(&TGVoipMarkPrimarySocket);
	NSLog(@"BGSESSION primary socket hook installed");
}

- (BOOL)voipSocketMarked {
	return TGVoipMarked != 0;
}

- (int)primarySocketDescriptor {
	return TGVoipSocket;
}

#pragma mark - liveness bookkeeping

- (time_t)lastReceive {
	[TGVoipLock lock];
	time_t value = _lastReceive;
	[TGVoipLock unlock];
	return value;
}

- (void)setLastReceive:(time_t)lastReceive {
	[TGVoipLock lock];
	_lastReceive = lastReceive;
	[TGVoipLock unlock];
}

- (void)noteDataReceived {
	self.lastReceive = time(NULL);
}

- (void)noteConnectionReady {
	self.lastReceive = time(NULL);
	[self endColdLaunchTask];
}

- (NSTimeInterval)healthCheckInterval {
	NSDateComponents *parts = [[NSCalendar currentCalendar]
		components:NSHourCalendarUnit
		  fromDate:[NSDate date]];
	NSInteger hour = [parts hour];
	return (hour >= 23 || hour < 7) ? kHealthIntervalNight : kHealthIntervalDay;
}

#pragma mark - lifecycle

- (void)applicationDidFinishLaunching:(UIApplication *)application {
	if (![self isLegacySystem] || ![TGBackgroundSession enabled])
		return;
	if (application.applicationState != UIApplicationStateBackground)
		return;

	self.launchedIntoBackground = YES;

	if ([application respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)]) {
		__weak typeof(self) weakSelf = self;
		UIBackgroundTaskIdentifier task = [application beginBackgroundTaskWithExpirationHandler:^{
			[weakSelf endColdLaunchTask];
		}];
		self.coldLaunchTask = task;
	}

	BOOL installed = [self installKeepAliveWithSource:@"cold_launch"];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kColdLaunchLeaseCap * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			[self endColdLaunchTask];
		});

	NSLog(@"BGSESSION cold background launch task=%d keepAlive=%d remaining=%.0f",
		(int)self.coldLaunchTask, installed ? 1 : 0, application.backgroundTimeRemaining);
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	if (![self isLegacySystem] || ![TGBackgroundSession enabled])
		return;
	[self installKeepAliveWithSource:@"background_enter"];
}

- (void)releasePrimarySocket {
	[TGVoipLock lock];
	TGVoipReleaseStreamsLocked();
	TGVoipSocket = -1;
	TGVoipMarked = 0;
	[TGVoipLock unlock];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	self.launchedIntoBackground = NO;
	[self endColdLaunchTask];
	[self endHealthTask];
	if (self.keepAliveInstalled &&
		[application respondsToSelector:@selector(clearKeepAliveTimeout)]) {
		[application clearKeepAliveTimeout];
		self.keepAliveInstalled = NO;
		NSLog(@"BGSESSION keep-alive cleared");
	}
}

- (BOOL)installKeepAliveWithSource:(NSString *)source {
	UIApplication *application = [UIApplication sharedApplication];
	if (![application respondsToSelector:@selector(setKeepAliveTimeout:handler:)])
		return NO;
	if (application.applicationState == UIApplicationStateActive)
		return NO;

	__weak typeof(self) weakSelf = self;
	BOOL installed = [application setKeepAliveTimeout:kKeepAliveTimeout handler:^{
		void (^wake)(void) = ^{
			[weakSelf handleKeepAliveWake];
		};
		if ([NSThread isMainThread])
			wake();
		else
			dispatch_async(dispatch_get_main_queue(), wake);
	}];
	self.keepAliveInstalled = installed;

	NSLog(@"BGSESSION keep-alive installed=%d timeout=%.0f health=%.0f source=%@",
		installed ? 1 : 0, kKeepAliveTimeout, [self healthCheckInterval], source);
	return installed;
}

#pragma mark - health

- (void)handleKeepAliveWake {
	UIApplication *application = [UIApplication sharedApplication];
	NSTimeInterval now = CFAbsoluteTimeGetCurrent();
	NSTimeInterval interval = [self healthCheckInterval];

	NSLog(@"BGSESSION wake state=%d remaining=%.0f voip=%d",
		(int)application.applicationState, application.backgroundTimeRemaining,
		TGVoipMarked);

	if (self.lastHealthCheck != 0.0 && now - self.lastHealthCheck + 1.0 < interval)
		return;
	self.lastHealthCheck = now;
	[self performHealthCheck];
}

- (void)performHealthCheck {
	UIApplication *application = [UIApplication sharedApplication];
	if (application.applicationState == UIApplicationStateActive)
		return;
	if (![TGBackgroundSession enabled])
		return;
	if (self.healthCheckRunning)
		return;

	time_t receivedAt = self.lastReceive;
	time_t age = receivedAt > 0 ? (time(NULL) - receivedAt) : LONG_MAX;
	BOOL connected = [TGClient shared].connectionState == TGConnectionStateReady;
	if (connected && age <= (time_t)[self healthCheckInterval]) {
		NSLog(@"BGSESSION health skipped rxAge=%ld", (long)age);
		return;
	}

	self.healthCheckRunning = YES;
	NSInteger generation = ++self.healthCheckGeneration;

	if ([application respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)]) {
		__weak typeof(self) weakSelf = self;
		self.healthTask = [application beginBackgroundTaskWithExpirationHandler:^{
			[weakSelf finishHealthCheck:generation reason:@"lease_expired" reconnect:NO];
		}];
	}

	NSLog(@"BGSESSION health begin gen=%lu rxAge=%ld state=%d remaining=%.0f",
		(unsigned long)generation, (long)age, (int)[TGClient shared].connectionState,
		application.backgroundTimeRemaining);

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] pingProxy:nil completion:^(double seconds) {
		BOOL failed = seconds < 0;
		[weakSelf finishHealthCheck:generation
							 reason:failed ? @"ping_failed" : @"ping_ok"
						  reconnect:failed];
	}];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kHealthProbeTimeout * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			[weakSelf finishHealthCheck:generation reason:@"timeout" reconnect:YES];
		});
}

- (void)finishHealthCheck:(NSUInteger)generation
				   reason:(NSString *)reason
				reconnect:(BOOL)reconnect {
	if (!self.healthCheckRunning || generation != self.healthCheckGeneration)
		return;
	self.healthCheckRunning = NO;

	NSLog(@"BGSESSION health end gen=%lu reason=%@ reconnect=%d",
		(unsigned long)generation, reason, reconnect ? 1 : 0);

	if (reconnect)
		[self forceReconnect];

	[self endHealthTask];
}

- (void)forceReconnect {
	TGClient *tg = [TGClient shared];
	[tg setNetworkTypeKind:@"none"];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			[tg setNetworkTypeKind:[TGReachabilityMonitor shared].currentNetworkTypeKind];
		});
}

- (void)endHealthTask {
	if (self.healthTask == UIBackgroundTaskInvalid)
		return;
	UIBackgroundTaskIdentifier task = self.healthTask;
	self.healthTask = UIBackgroundTaskInvalid;
	[[UIApplication sharedApplication] endBackgroundTask:task];
}

- (void)endColdLaunchTask {
	if (self.coldLaunchTask == UIBackgroundTaskInvalid)
		return;
	UIBackgroundTaskIdentifier task = self.coldLaunchTask;
	self.coldLaunchTask = UIBackgroundTaskInvalid;
	[[UIApplication sharedApplication] endBackgroundTask:task];
	NSLog(@"BGSESSION cold launch lease ended id=%d", (int)task);
}

#pragma mark - diagnostics

- (void)runDiagnosticProbe {
	NSTimeInterval started = CFAbsoluteTimeGetCurrent();
	[[TGClient shared] pingProxy:nil completion:^(double seconds) {
		NSLog(@"BGSESSION probe %@ after %.0f ms",
			seconds < 0 ? @"failed" : @"ok",
			(CFAbsoluteTimeGetCurrent() - started) * 1000.0);
	}];
}

- (NSString *)statusLine {
	time_t age = self.lastReceive > 0 ? (time(NULL) - self.lastReceive) : -1;
	return [NSString stringWithFormat:
			@"hook=%d voip=%d fd=%d keepAlive=%d coldLaunch=%d rxAge=%lds",
		self.hookInstalled ? 1 : 0, TGVoipMarked, TGVoipSocket,
		self.keepAliveInstalled ? 1 : 0, self.launchedIntoBackground ? 1 : 0, (long)age];
}

@end

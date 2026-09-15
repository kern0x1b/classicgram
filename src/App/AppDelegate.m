#import "TGFloodWaitNotice.h"
#import "TGFloodWaitText.h"
#import "AppDelegate.h"
#import "TGBotAddToChat.h"
#import "TGFriendlyError.h"
#import "TGVisibleAlerts.h"
#import "AppDelegate+Private.h"
#import "TGCapabilities.h"
#import "TGCustomEmojiCache.h"
#import "TGRichText.h"
#import "TGTextWarmup.h"
#import "TGMusicPlayerViewController.h"
#import "TGMusicPlayerBar.h"
#import <objc/runtime.h>
#import <execinfo.h>
#import <signal.h>
#import "TGLocalization.h"
#import "TGLazyFramework.h"
#import "TGLaunchSnapshot.h"
#import "TGPasscodeLock.h"
#import "RootViewController.h"
#import "TGHacks.h"
#import "TGLaunchScreenChoice.h"
#import "TGAccountManager.h"
#import "TGChatHistoryCache.h"
#import "TGClient.h"
#import "TGClient+Account.h"
#import "TGClient+UserStatus.h"
#import "TGClient+Translation.h"
#import "TGClient+Private.h"
#import "TGClient+Bots.h"
#import "TGClient+ChatList.h"
#import "TGClient+ChatState.h"
#import "TGTheme.h"
#import "TGSnackbar.h"
#import "TGSearchViewController.h"
#import "TGDeviceViewController.h"
#import "TGCall.h"
#import "TGCallViewController.h"
#import "TGVideoLoopback.h"
#import "TGTabBar.h"
#import "TGSystemCall.h"
#import "TGChatViewController.h"
#import "TGChatListViewController.h"
#import "TGChatFolderLinkPreviewViewController.h"
#import "TGTopicsViewController.h"
#import "TGNotificationManager.h"
#import "TGBackgroundSession.h"
#import "TGReachabilityMonitor.h"
#import "TGMusicPlayer.h"
#import "TGIcons.h"
#import "TGDiskCache.h"
#import "TGRemoteImageView.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#include <stdio.h>
#include <sys/sysctl.h>
#include <mach/mach.h>
#include <dlfcn.h>
#include <malloc/malloc.h>
#include <fcntl.h>
#include <sys/ucontext.h>
#include <unistd.h>

extern void TGEmojiPurgeImages(void);

static const NSInteger kAppBotStartAlertTag = 123;

static NSTimeInterval TGLaunchStarted = 0;
static NSTimeInterval TGOpenStarted = 0;
static BOOL TGOpenFrameSeen = NO;
static BOOL TGOpenSettledSeen = NO;
static unsigned long long TGResidentPeak = 0;
static volatile double TGMainPingAt = 0;

unsigned long long TGResidentBytes(void) {
	struct task_basic_info info;
	mach_msg_type_number_t count = TASK_BASIC_INFO_COUNT;
	if (task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &count) != KERN_SUCCESS)
		return 0;
	unsigned long long rss = (unsigned long long)info.resident_size;
	if (rss > TGResidentPeak)
		TGResidentPeak = rss;
	return rss;
}

static double TGProcessCPUSeconds(void) {
	double total = 0;
	struct task_basic_info basic;
	mach_msg_type_number_t count = TASK_BASIC_INFO_COUNT;
	if (task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&basic, &count) == KERN_SUCCESS) {
		total += basic.user_time.seconds + basic.user_time.microseconds / 1e6;
		total += basic.system_time.seconds + basic.system_time.microseconds / 1e6;
	}
	struct task_thread_times_info times;
	count = TASK_THREAD_TIMES_INFO_COUNT;
	if (task_info(mach_task_self(), TASK_THREAD_TIMES_INFO, (task_info_t)&times, &count) == KERN_SUCCESS) {
		total += times.user_time.seconds + times.user_time.microseconds / 1e6;
		total += times.system_time.seconds + times.system_time.microseconds / 1e6;
	}
	return total;
}

static unsigned int TGThreadCount(void) {
	thread_act_array_t threads;
	mach_msg_type_number_t count = 0;
	if (task_threads(mach_task_self(), &threads, &count) != KERN_SUCCESS)
		return 0;
	for (mach_msg_type_number_t i = 0; i < count; i++)
		mach_port_deallocate(mach_task_self(), threads[i]);
	vm_deallocate(mach_task_self(), (vm_address_t)threads, count * sizeof(thread_t));
	return (unsigned int)count;
}

void TGMemZoneReport(NSString *tag) {
	vm_address_t *zones = NULL;
	unsigned int count = 0;
	if (malloc_get_all_zones(mach_task_self(), NULL, &zones, &count) != KERN_SUCCESS)
		return;
	unsigned long long inUse = 0;
	for (NSInteger i = 0; i < count; i++) {
		malloc_zone_t *zone = (malloc_zone_t *)zones[i];
		if (!zone || !zone->introspect)
			continue;
		malloc_statistics_t stats;
		memset(&stats, 0, sizeof(stats));
		malloc_zone_statistics(zone, &stats);
		inUse += stats.size_in_use;
		if (stats.size_in_use > 262144)
			NSLog(@"PERF zone %@ %s in_use=%.2f MB allocated=%.2f MB blocks=%u",
				tag, malloc_get_zone_name(zone) ?: "unnamed",
				stats.size_in_use / 1048576.0, stats.size_allocated / 1048576.0,
				stats.blocks_in_use);
	}
	NSLog(@"PERF zone %@ TOTAL malloc in_use=%.2f MB", tag, inUse / 1048576.0);
}

static thread_t TGMainThreadPort = MACH_PORT_NULL;
volatile BOOL TGStackSamplingOn = NO;

static BOOL TGPeek(const void *address, void *into, size_t length) {
	vm_size_t got = 0;
	if (vm_read_overwrite(mach_task_self(), (vm_address_t)address, length,
			(vm_address_t)into, &got) != KERN_SUCCESS)
		return NO;
	return got == length;
}

static int TGCaptureMainStack(void **frames, int maximum) {
	if (TGMainThreadPort == MACH_PORT_NULL)
		return 0;
	if (thread_suspend(TGMainThreadPort) != KERN_SUCCESS)
		return 0;
	NSInteger found = 0;
#if defined(__arm__)
	_STRUCT_ARM_THREAD_STATE state;
	mach_msg_type_number_t count = ARM_THREAD_STATE_COUNT;
	if (thread_get_state(TGMainThreadPort, ARM_THREAD_STATE,
			(thread_state_t)&state, &count) == KERN_SUCCESS) {
		frames[found++] = (void *)state.__pc;
		if (state.__lr && found < maximum)
			frames[found++] = (void *)state.__lr;
		const void **link = (const void **)state.__r[7];
		while (found < maximum && link && ((uintptr_t)link & 3) == 0) {
			const void *next = NULL;
			const void *returnAddress = NULL;
			if (!TGPeek(link, &next, sizeof(next)))
				break;
			if (!TGPeek(link + 1, &returnAddress, sizeof(returnAddress)))
				break;
			if (!returnAddress)
				break;
			frames[found++] = (void *)returnAddress;
			if ((const void **)next <= link)
				break;
			link = (const void **)next;
		}
	}
#endif
	thread_resume(TGMainThreadPort);
	return found;
}

static void TGLogMainStack(void) {
	void *frames[48];
	NSInteger found = TGCaptureMainStack(frames, 48);
	if (found <= 0)
		return;
	char line[4000];
	size_t used = 0;
	for (NSInteger i = 0; i < found && used < sizeof(line) - 90; i++) {
		Dl_info info;
		memset(&info, 0, sizeof(info));
		const char *symbol = "?";
		const char *image = "?";
		if (dladdr(frames[i], &info)) {
			if (info.dli_sname)
				symbol = info.dli_sname;
			if (info.dli_fname) {
				const char *slash = strrchr(info.dli_fname, '/');
				image = slash ? slash + 1 : info.dli_fname;
			}
		}
		used += snprintf(line + used, sizeof(line) - used, "%s%s`%s",
			i ? " < " : "", image, symbol);
	}
	line[sizeof(line) - 1] = 0;
	NSLog(@"PERF stack | %s", line);
}

void TGRegionReport(NSString *tag) {
	vm_address_t address = 0;
	unsigned long long byTag[256];
	unsigned long long dirtyByTag[256];
	memset(byTag, 0, sizeof(byTag));
	memset(dirtyByTag, 0, sizeof(dirtyByTag));

	while (1) {
		vm_size_t size = 0;
		uint32_t depth = 1;
		struct vm_region_submap_info_64 info;
		mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
		if (vm_region_recurse_64(mach_task_self(), &address, &size, &depth,
				(vm_region_recurse_info_t)&info, &count) != KERN_SUCCESS)
			break;
		if (info.is_submap) {
			depth++;
			continue;
		}
		NSInteger slot = info.user_tag & 0xFF;
		byTag[slot] += (unsigned long long)info.pages_resident * vm_page_size;
		dirtyByTag[slot] += (unsigned long long)info.pages_dirtied * vm_page_size;
		address += size;
	}

	for (NSInteger i = 0; i < 256; i++) {
		if (byTag[i] < 1048576)
			continue;
		NSLog(@"PERF region %@ tag=%u resident=%.2f MB dirty=%.2f MB",
			tag, i, byTag[i] / 1048576.0, dirtyByTag[i] / 1048576.0);
	}
}

void TGMemMark(NSString *tag) {
	vm_address_t *zones = NULL;
	unsigned int count = 0;
	unsigned long long inUse = 0;
	if (malloc_get_all_zones(mach_task_self(), NULL, &zones, &count) == KERN_SUCCESS) {
		for (NSInteger i = 0; i < count; i++) {
			malloc_zone_t *zone = (malloc_zone_t *)zones[i];
			if (!zone || !zone->introspect)
				continue;
			malloc_statistics_t stats;
			memset(&stats, 0, sizeof(stats));
			malloc_zone_statistics(zone, &stats);
			inUse += stats.size_in_use;
		}
	}
	NSLog(@"PERF mem %@ rss=%.2f MB peak=%.2f MB heap=%.2f MB cpu=%.2f s threads=%u",
		tag, TGResidentBytes() / 1048576.0, TGResidentPeak / 1048576.0,
		inUse / 1048576.0, TGProcessCPUSeconds(), TGThreadCount());
}

static NSTimeInterval TGProcessStarted(void) {
	static NSTimeInterval started = -1;
	if (started >= 0)
		return started;
	int name[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
	struct kinfo_proc info;
	size_t length = sizeof(info);
	memset(&info, 0, sizeof(info));
	if (sysctl(name, 4, &info, &length, NULL, 0) != 0 || length == 0) {
		started = 0;
		return started;
	}
	NSTimeInterval unix = info.kp_proc.p_starttime.tv_sec +
		info.kp_proc.p_starttime.tv_usec / 1e6;
	started = unix - NSTimeIntervalSince1970;
	return started;
}

static double TGSinceTap(void) {
	NSTimeInterval started = TGProcessStarted();
	if (started <= 0)
		return -1;
	return ([NSDate timeIntervalSinceReferenceDate] - started) * 1000.0;
}

void TGRedirectLogToFile(void) {
	NSString *cache = [NSSearchPathForDirectoriesInDomains(
		NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString *log = [cache stringByAppendingPathComponent:@"log.txt"];
	NSString *lastlog = [cache stringByAppendingPathComponent:@"lastlog.txt"];
	[[NSFileManager defaultManager] removeItemAtPath:lastlog error:nil];
	[[NSFileManager defaultManager] moveItemAtPath:log toPath:lastlog error:nil];
	freopen(log.UTF8String, "a+", stderr);
	setvbuf(stderr, NULL, _IOLBF, 0);
}

void TGNoteImageReady(NSTimeInterval when) {
	if (when <= 0)
		return;
	NSTimeInterval started = TGProcessStarted();
	if (started <= 0)
		return;
	NSLog(@"PERF launch (tap +%.0f ms): image ready, dyld and the kernel done",
		(when - started) * 1000.0);
}

void TGMarkLaunchStage(NSString *stage) {
	if (TGLaunchStarted <= 0)
		TGLaunchStarted = [NSDate timeIntervalSinceReferenceDate];
	NSLog(@"PERF launch +%.0f ms (tap +%.0f ms): %@ rss=%.2f MB cpu=%.2f s",
		([NSDate timeIntervalSinceReferenceDate] - TGLaunchStarted) * 1000.0,
		TGSinceTap(), stage,
		TGResidentBytes() / 1048576.0, TGProcessCPUSeconds());
}

static void TGCaptureFrame(NSString *name) {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"tgCaptureFrames"])
		return;
	UIWindow *window = [[UIApplication sharedApplication] keyWindow];
	if (!window)
		return;
	CGFloat scale = [UIScreen mainScreen].scale;
	UIGraphicsBeginImageContextWithOptions(window.bounds.size, YES, scale);
	[window.layer renderInContext:UIGraphicsGetCurrentContext()];
	UIImage *shot = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	NSString *cache = [NSSearchPathForDirectoriesInDomains(
		NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	[UIImagePNGRepresentation(shot)
		writeToFile:[cache stringByAppendingPathComponent:name]
		 atomically:YES];
	NSLog(@"PERF captured %@", name);
}

void TGMarkFirstFrame(NSString *stage) {
	[CATransaction begin];
	[CATransaction setCompletionBlock:^{
		TGMarkLaunchStage(stage);
		TGCaptureFrame(@"firstframe.png");
	}];
	[CATransaction commit];
}

void TGBeginOpenTimingFromTap(void) {
	TGOpenStarted = [NSDate timeIntervalSinceReferenceDate];
	TGOpenFrameSeen = NO;
	TGOpenSettledSeen = NO;
}

void TGBeginOpenTiming(void) {
	if (TGOpenStarted > 0)
		return;
	TGOpenStarted = [NSDate timeIntervalSinceReferenceDate];
	TGOpenFrameSeen = NO;
	TGOpenSettledSeen = NO;
}

void TGMarkOpenStage(NSString *stage) {
	if (TGOpenStarted <= 0)
		return;
	NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - TGOpenStarted;
	if (elapsed > 20.0) {
		TGOpenStarted = 0;
		return;
	}
	NSLog(@"PERF open +%.0f ms: %@", elapsed * 1000.0, stage);
}

@interface TGIncomingCallRouter : NSObject
@end

@implementation TGIncomingCallRouter

- (void)callStateChanged:(NSNotification *)note {
	if ([TGCall shared].state != TGCallStatePending || [TGCall shared].outgoing)
		return;
	int64_t userId = [TGCall shared].peerUserId;
	[TGCallViewController presentForUserId:userId
									  name:[[TGClient shared] nameForUserId:userId]
								  outgoing:NO
									 video:NO];
}

@end

void TGMarkOpenFrame(NSString *stage) {
	if (TGOpenStarted <= 0 || TGOpenFrameSeen)
		return;
	TGOpenFrameSeen = YES;
	[CATransaction begin];
	[CATransaction setCompletionBlock:^{
		TGMarkOpenStage(stage);
		TGCaptureFrame(@"openframe.png");
	}];
	[CATransaction commit];
}

void TGMarkOpenSettledFrame(NSString *stage) {
	if (TGOpenStarted <= 0 || TGOpenSettledSeen)
		return;
	TGOpenSettledSeen = YES;
	[CATransaction begin];
	[CATransaction setCompletionBlock:^{
		TGMarkOpenStage(stage);
		TGOpenStarted = 0;
		TGCaptureFrame(@"settledframe.png");
	}];
	[CATransaction commit];
}

@interface AppDelegate ()
@property (nonatomic, strong) id passcodeUnlockObserverToken;
@property (nonatomic, strong) id notificationManagerOpenChatObserverToken;
@property (nonatomic, strong) id accountWillSwitchObserverToken;
@property (nonatomic, strong) id accountDidSwitchObserverToken;
@property (nonatomic, strong) id authStateObserverToken;
@property (nonatomic, strong) id clientErrorObserverToken;
@property (nonatomic, strong) id floodWaitObserverToken;
@end

@implementation AppDelegate

- (void)dealloc {
	if (self.authStateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.authStateObserverToken];
	if (self.clientErrorObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.clientErrorObserverToken];
	if (self.floodWaitObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.floodWaitObserverToken];
	if (self.passcodeUnlockObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.passcodeUnlockObserverToken];
	if (self.notificationManagerOpenChatObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.notificationManagerOpenChatObserverToken];
	if (self.accountWillSwitchObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.accountWillSwitchObserverToken];
	if (self.accountDidSwitchObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.accountDidSwitchObserverToken];
}

+ (void)tgPingMainThread {
	TGMainPingAt = [NSDate timeIntervalSinceReferenceDate];
}

+ (void)tgStackSamplerLoop {
	while (1) {
		if (TGStackSamplingOn) {
			@autoreleasepool {
				TGLogMainStack();
			}
		}
		usleep(25000);
	}
}

+ (void)tgMemorySamplerLoop {
	NSTimeInterval started = [NSDate timeIntervalSinceReferenceDate];
	double worstStall = 0;
	while (1) {
		@autoreleasepool {
			if (!TGPerfLogging()) {
				usleep(250000);
				continue;
			}
			NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
			double stall = TGMainPingAt > 0 ? (now - TGMainPingAt) : 0;
			if (stall > worstStall)
				worstStall = stall;
			NSLog(@"PERF sample +%.0f ms rss=%.2f MB peak=%.2f MB cpu=%.2f s stall=%.0f worst=%.0f threads=%u",
				(now - started) * 1000.0,
				TGResidentBytes() / 1048576.0,
				TGResidentPeak / 1048576.0,
				TGProcessCPUSeconds(),
				stall * 1000.0, worstStall * 1000.0, TGThreadCount());
		}
		usleep(250000);
	}
}

void TGStartMemorySampler(void) {
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		TGMainThreadPort = mach_thread_self();
		TGMainPingAt = [NSDate timeIntervalSinceReferenceDate];
		dispatch_async(dispatch_get_main_queue(), ^{
			[NSTimer scheduledTimerWithTimeInterval:0.05
											 target:[AppDelegate class]
										   selector:@selector(tgPingMainThread)
										   userInfo:nil
											repeats:YES];
		});
		[NSThread detachNewThreadSelector:@selector(tgMemorySamplerLoop)
								 toTarget:[AppDelegate class]
							   withObject:nil];
		[NSThread detachNewThreadSelector:@selector(tgStackSamplerLoop)
								 toTarget:[AppDelegate class]
							   withObject:nil];
	});
}

static void TGStartMemorySamplerIfRequested(void) {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"tgStacksAtLaunch"]) {
		TGStackSamplingOn = YES;
		TGStartMemorySampler();
	}
}

+ (void)tgWarmEmojiFont {
	@autoreleasepool {
		unichar units[2] = {0x2764, 0xFE0F};
		CTFontRef font = CTFontCreateWithName(CFSTR("AppleColorEmoji"), 14.0f, NULL);
		if (!font) {
			TGNoteTextWarm();
			return;
		}
		NSString *fontKey = (__bridge NSString *)kCTFontAttributeName;
		NSDictionary *attributes = [NSDictionary dictionaryWithObject:(__bridge id)font forKey:fontKey];
		NSAttributedString *string = [[NSAttributedString alloc]
			initWithString:[NSString stringWithCharacters:units length:2]
				attributes:attributes];
		CTLineRef line = CTLineCreateWithAttributedString(
			(__bridge CFAttributedStringRef)string);
		if (line) {
			CGFloat ascent = 0, descent = 0, leading = 0;
			CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
			CFRelease(line);
		}
		CFRelease(font);

		NSString *probe = [NSString stringWithCharacters:units length:2];
		NSArray *fonts = @[ [UIFont boldSystemFontOfSize:16.0f],
			[UIFont systemFontOfSize:14.0f],
			[UIFont systemFontOfSize:13.0f] ];
		for (UIFont *warm in fonts)
			[probe sizeWithFont:warm
				constrainedToSize:CGSizeMake(1000, 40)
					lineBreakMode:NSLineBreakByWordWrapping];
		TGNoteTextWarm();
	}
}

static UIBackgroundTaskIdentifier TGBackgroundTask;
static BOOL TGBackgroundTaskActive = NO;
static BOOL TGTDLibStartDeferred = NO;
static BOOL TGSafeMode = NO;
static int64_t TGPendingNotificationChatId = 0;
static int64_t TGPendingNotificationThreadId = 0;

static void TGEndBackgroundTask(void) {
	if (!TGBackgroundTaskActive)
		return;
	TGBackgroundTaskActive = NO;
	[[UIApplication sharedApplication] endBackgroundTask:TGBackgroundTask];
}

static const NSTimeInterval kBackgroundSuspendMargin = 20.0;
static const NSTimeInterval kLiveLocationSuspendRetryInterval = 20.0;
static const NSTimeInterval kBackgroundSuspendMaxLead = 4.0 * 60.0 * 60.0;

static void TGSuspendTDLibForBackground(void) {
	[[TGBackgroundSession shared] releasePrimarySocket];
	[[TGClient shared] suspendForBackgroundWithCompletion:^{
		TGEndBackgroundTask();
	}];
}

static BOOL TGHasActiveCall(void) {
	TGCallState state = [TGCall shared].state;
	return state != TGCallStateNone && state != TGCallStateEnded && state != TGCallStateFailed;
}

static void TGScheduleBackgroundSuspend(UIApplication *application) {
	NSTimeInterval lead = application.backgroundTimeRemaining - kBackgroundSuspendMargin;
	if (lead < 1.0)
		lead = 1.0;
	if (([TGClient shared].hasActiveLiveLocationShare || TGHasActiveCall()) && lead > kLiveLocationSuspendRetryInterval)
		lead = kLiveLocationSuspendRetryInterval;
	if (lead > kBackgroundSuspendMaxLead)
		lead = kBackgroundSuspendMaxLead;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(lead * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			if (!TGBackgroundTaskActive)
				return;
			if ([TGClient shared].hasActiveLiveLocationShare || TGHasActiveCall()) {
				TGScheduleBackgroundSuspend(application);
				return;
			}
			TGSuspendTDLibForBackground();
		});
}

static NSString *const TGUncleanLaunchesKey = @"tgUncleanLaunches";
static const NSUInteger kUncleanLaunchLimit = 4;
static const NSTimeInterval kUncleanLaunchWindow = 60.0;

static void TGClearUncleanLaunches(void) {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (![defaults objectForKey:TGUncleanLaunchesKey])
		return;
	[defaults removeObjectForKey:TGUncleanLaunchesKey];
	[defaults synchronize];
}

static void TGNoteUncleanLaunch(void) {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSArray *stored = [defaults arrayForKey:TGUncleanLaunchesKey];
	NSMutableArray *times = stored ? [stored mutableCopy] : [NSMutableArray array];
	[times addObject:@([NSDate timeIntervalSinceReferenceDate])];
	while (times.count > kUncleanLaunchLimit * 2)
		[times removeObjectAtIndex:0];
	[defaults setObject:times forKey:TGUncleanLaunchesKey];
	[defaults synchronize];
}

static BOOL TGShouldEnterSafeMode(void) {
	NSArray *times = [[NSUserDefaults standardUserDefaults] arrayForKey:TGUncleanLaunchesKey];
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	NSInteger recent = 0;
	for (NSNumber *stamp in times) {
		if (now - [stamp doubleValue] <= kUncleanLaunchWindow)
			recent++;
	}
	return recent >= kUncleanLaunchLimit;
}

static void TGWatchForIncomingCalls(void) {
	static TGIncomingCallRouter *router = nil;
	if (router)
		return;
	router = [[TGIncomingCallRouter alloc] init];
	[[NSNotificationCenter defaultCenter] addObserver:router
											 selector:@selector(callStateChanged:)
												 name:TGCallStateDidChangeNotification
											   object:nil];
	[TGSystemCall install];
}

- (void)buildWindowAndInitialUI {
	if (self.window)
		return;
	[TGClient shared].diskCachesDisabledForBackgroundLaunch = NO;
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	TGAuthState knownState = [TGClient shared].authState;
	BOOL wasSignedIn = [NSUserDefaults.standardUserDefaults boolForKey:@"tgWasSignedIn"];
	switch (TGLaunchScreenForAuthState(knownState, wasSignedIn)) {
		case TGLaunchScreenMain:
			[[TGClient shared] loadCachedChats];
			TGMarkLaunchStage(@"snapshot loaded");
			[self showMainUI];
			break;
		case TGLaunchScreenLogin:
			[self showLoginUI];
			break;
		case TGLaunchScreenLoading:
			[self showLoadingUI];
			break;
	}
	TGMarkLaunchStage(@"before makeKeyAndVisible");
	[self.window makeKeyAndVisible];
	TGMarkLaunchStage(@"window on screen");
	TGMarkFirstFrame(@"FIRST FRAME");
	self.deferredUIBuild = NO;
	if (knownState != TGAuthStateUnknown)
		[self applyAuthState:knownState];
}

- (BOOL)application:(UIApplication *)application
	didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	TGMarkLaunchStage(@"didFinishLaunching");
	TGInstallCrashLogging();
	BOOL isBackgroundLaunch = application.applicationState == UIApplicationStateBackground;
	TGSafeMode = TGShouldEnterSafeMode();
	if (TGSafeMode)
		NSLog(@"SAFE MODE: %lu unclean launches inside %.0fs - TDLib will not open "
			   "until the app is on screen and background delivery stays off",
			(unsigned long)kUncleanLaunchLimit, kUncleanLaunchWindow);
	if (!isBackgroundLaunch)
		TGNoteUncleanLaunch();
	[[TGBackgroundSession shared] applicationDidFinishLaunching:application];
	[[TGReachabilityMonitor shared] start];
	TGStartMemorySamplerIfRequested();
	[TGHacks hackSetAnimationDuration];
	[NSThread detachNewThreadSelector:@selector(tgWarmEmojiFont)
							 toTarget:[AppDelegate class]
						   withObject:nil];

	NSString *cache = [NSSearchPathForDirectoriesInDomains(
		NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];

	NSLog(@"start...");
	TGWatchForIncomingCalls();

	self.syncData = [[NSOperationQueue alloc] init];
	self.syncData.maxConcurrentOperationCount = 2;

	for (NSString *name in @[ @"s", @"peer", @"images", @"files", @"docThumbs" ]) {
		NSString *path = [cache stringByAppendingPathComponent:name];
		[NSFileManager.defaultManager createDirectoryAtPath:path
								withIntermediateDirectories:YES
												 attributes:nil
													  error:NULL];
		if ([name isEqualToString:@"s"])
			self.smallPhotoCache = path;
		else if ([name isEqualToString:@"peer"])
			self.peerPhotoCache = path;
		else if ([name isEqualToString:@"images"])
			self.imagesCache = path;
		else if ([name isEqualToString:@"files"])
			self.filesCache = path;
		else
			self.thumbDocCache = path;
	}

	self.showNotifications = [NSUserDefaults.standardUserDefaults
		boolForKey:@"showNotifications"];

	[[NSFileManager defaultManager] changeCurrentDirectoryPath:
			[[NSBundle mainBundle] bundlePath]];

	[[TGAccountManager shared] prepareForLaunch];
	[[TGChatHistoryCache shared] setAccountScope:
			[TGAccountManager scopeForSlot:[TGAccountManager shared].currentSlot]];
	[self watchAccountSwitching];

	NSString *databaseDirectory = [TGDiskCache databaseDirectory];

	if (isBackgroundLaunch) {
		self.deferredUIBuild = YES;
		[TGClient shared].diskCachesDisabledForBackgroundLaunch = YES;
		TGMarkLaunchStage(@"UI build deferred - background launch");
	} else {
		[self buildWindowAndInitialUI];
	}

	__weak typeof(self) weakSelf = self;
	self.passcodeUnlockObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGPasscodeLockDidUnlockNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf openPendingNotificationChat];
				}];
	[[TGPasscodeLock shared] applicationDidFinishLaunching];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			AppDelegate *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[TGLaunchSnapshot restoreShippedImage:@"snapshot capture removed"];
			if (![RootViewController iconBadgeWasPushed]) {
				NSInteger lastKnownBadge = 0;
				for (NSDictionary *account in [TGAccountManager shared].accounts)
					lastKnownBadge += [account[@"unread"] integerValue];
				[UIApplication sharedApplication].applicationIconBadgeNumber = lastKnownBadge < 0 ? 0 : lastKnownBadge;
			}
		});

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			[TGDiskCache sweep];
		});

	if (TGSafeMode) {
		TGTDLibStartDeferred = YES;
		NSLog(@"TDLib start deferred: state=%d safeMode=1",
			(int)application.applicationState);
	} else {
		[self startTDLib];
	}
	[TGDiskCache releaseDatabaseProtectionAtPath:databaseDirectory];

	UILocalNotification *launchNotification =
		launchOptions[UIApplicationLaunchOptionsLocalNotificationKey];
	if ([launchNotification isKindOfClass:[UILocalNotification class]]) {
		TGPendingNotificationChatId =
			[[TGNotificationManager shared] chatIdForLocalNotification:launchNotification];
		TGPendingNotificationThreadId =
			[[TGNotificationManager shared] threadIdForLocalNotification:launchNotification];
	}

	self.notificationManagerOpenChatObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGNotificationManagerDidRequestOpenChatNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf notificationManagerDidRequestOpenChat:note];
				}];

	[self installMusicPlayerBarHooks];
	[self installCrossLayerProviders];

	if ([self respondsToSelector:@selector(installHarnessCommandWatcher)])
		[self installHarnessCommandWatcher];

	NSURL *launchURL = launchOptions[UIApplicationLaunchOptionsURLKey];
	if ([launchURL isKindOfClass:[NSURL class]]) {
		__weak typeof(self) weakDelegate = self;
		dispatch_async(dispatch_get_main_queue(), ^{
			[weakDelegate handleAppURL:launchURL];
		});
	}

	TGMarkLaunchStage(@"didFinishLaunching returns");
	return YES;
}

- (void)installCrossLayerProviders {
	TGRichTextSetCustomEmojiImageProvider(^UIImage *(long long customEmojiId) {
		return TGCustomEmojiCachedImage(customEmojiId);
	});
	TGRichTextSetCustomEmojiImageRequester(^(long long customEmojiId) {
		TGCustomEmojiRequestImage(customEmojiId);
	});
	[TGCapabilities setVideoEncoderProbe:^BOOL {
		return [TGCall canSendVideo];
	}];
}

- (void)installMusicPlayerBarHooks {
	[TGMusicPlayerBar setHostProvider:^UIView * {
		UINavigationController *detail = [RootViewController detailNavigationController];
		if (detail && detail.isViewLoaded && detail.view.window)
			return detail.view;
		return nil;
	}];

	[TGMusicPlayerBar setFullPlayerPresenter:^{
		UIViewController *host = [UIApplication sharedApplication].keyWindow.rootViewController;
		while (host.presentedViewController)
			host = host.presentedViewController;
		if (!host)
			return;

		TGMusicPlayerViewController *screen = [[TGMusicPlayerViewController alloc] init];
		UINavigationController *navigation =
			[[UINavigationController alloc] initWithRootViewController:screen];
		[[TGTheme shared] styleNavigationBar:navigation.navigationBar];
		navigation.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
		[host presentViewController:navigation animated:YES completion:nil];
	}];
}

- (void)notificationManagerDidRequestOpenChat:(NSNotification *)note {
	int64_t chatId = [note.userInfo[TGNotificationManagerChatIdKey] longLongValue];
	[self openChatFromNotification:chatId];
}

#pragma mark - memory

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
	NSLog(@"memory warning: dropping discardable caches");
	[TGIcons flush];
	[TGRemoteImageView tgPurgeMemoryCache];
	[[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (void)applicationWillResignActive:(UIApplication *)application {
	[[TGPasscodeLock shared] applicationWillResignActive];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	[[TGPasscodeLock shared] applicationDidEnterBackground];
	[[TGClient shared] saveCachedChats];
	[TGIcons flush];
	[[NSURLCache sharedURLCache] removeAllCachedResponses];
	[[TGNotificationManager shared] applicationDidEnterBackground];
	[[TGBackgroundSession shared] applicationDidEnterBackground:application];

	[TGDiskCache reassertDatabaseProtectionAtPath:[TGDiskCache databaseDirectory]];

	if (![application respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)]) {
		[[TGBackgroundSession shared] releasePrimarySocket];
		[[TGClient shared] suspendForBackgroundWithCompletion:nil];
		return;
	}
	if (TGBackgroundTaskActive)
		return;

	TGBackgroundTaskActive = YES;
	TGBackgroundTask = [application beginBackgroundTaskWithExpirationHandler:^{
		TGSuspendTDLibForBackground();
	}];

	if (TGSafeMode) {
		TGSuspendTDLibForBackground();
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(25.0 * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{
				TGEndBackgroundTask();
			});
		return;
	}

	TGScheduleBackgroundSuspend(application);
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	if (self.deferredUIBuild)
		[self buildWindowAndInitialUI];
	[[TGPasscodeLock shared] applicationWillEnterForeground];
	[[TGBackgroundSession shared] applicationWillEnterForeground:application];
	TGEndBackgroundTask();
	[[TGClient shared] resumeFromBackground];
	[[TGClient shared] reopenForDiskCachesIfNeededWhileCallInProgress:TGHasActiveCall()];
}

- (void)applicationWillTerminate:(UIApplication *)application {
	[[TGClient shared] setSelfOnline:NO];
	TGClearUncleanLaunches();
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
	[[TGMusicPlayer shared] handleRemoteControlEvent:event];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	[[TGPasscodeLock shared] applicationDidBecomeActive];
	[[TGNotificationManager shared] applicationDidBecomeActive];
	[self openPendingNotificationChat];

	if (TGTDLibStartDeferred) {
		TGTDLibStartDeferred = NO;
		[self startTDLib];
	}

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30.0 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
				TGClearUncleanLaunches();
		});
}

- (void)openPendingNotificationChat {
	if (!TGPendingNotificationChatId)
		return;
	if ([[TGPasscodeLock shared] isLocked])
		return;
	int64_t chatId = TGPendingNotificationChatId;
	int64_t threadId = TGPendingNotificationThreadId;
	TGPendingNotificationChatId = 0;
	TGPendingNotificationThreadId = 0;
	[self openChatFromNotification:chatId focusMessageId:0 threadId:threadId];
}

- (void)application:(UIApplication *)application
	didReceiveLocalNotification:(UILocalNotification *)notification {
	int64_t chatId = [[TGNotificationManager shared]
		chatIdForLocalNotification:notification];
	if (!chatId)
		return;
	int64_t threadId = [[TGNotificationManager shared]
		threadIdForLocalNotification:notification];
	if (application.applicationState == UIApplicationStateActive) {
		[[TGNotificationManager shared] clearNotificationsForChat:chatId];
		return;
	}
	TGPendingNotificationChatId = chatId;
	TGPendingNotificationThreadId = threadId;
}

- (void)handleBotStartLinkURL:(NSURL *)url {
	NSString *link = url.absoluteString;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] botStartLinkInfo:link completion:^(NSDictionary *info) {
		AppDelegate *strongSelf = weakSelf;
		if (!strongSelf || !info)
			return;
		NSString *username = info[@"username"];
		if (!username.length)
			return;
		if ([info[@"inGroup"] boolValue] || [info[@"inChannel"] boolValue]) {
			[strongSelf addBotFromLink:link];
			return;
		}
		if ([info[@"autostart"] boolValue]) {
			[strongSelf startPendingAppBotLink:link];
			return;
		}
		strongSelf.pendingBotStartLink = link;
		NSString *askTitle = [NSString stringWithFormat:@"@%@", username];
		UIAlertView *ask = [UIAlertView alloc];
		ask = [ask initWithTitle:askTitle
						 message:TGL(@"Chat.StartAChatWithThisBot", @"Start a chat with this bot?")
						delegate:strongSelf
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"UserInfo.StartSecretChatStart", @"Start"), nil];
		ask.tag = kAppBotStartAlertTag;
		[ask show];
	}];
}

- (void)addBotFromLink:(NSString *)link {
	__weak typeof(self) weakSelf = self;
	[TGBotAddToChat presentForLink:link
					fromController:self.window.rootViewController
						completion:^(int64_t addedChatId, NSString *addError) {
							AppDelegate *strongSelf = weakSelf;
							if (!strongSelf)
								return;
							if (addedChatId) {
								[strongSelf openChatFromNotification:addedChatId];
								return;
							}
							if (!addError.length || [addError isEqualToString:@"cancelled"])
								return;
							[strongSelf showBotAddFailure:addError];
						}];
}

- (void)showBotAddFailure:(NSString *)errorCode {
	NSString *message = [errorCode isEqualToString:@"noChats"]
		? TGL(@"Bot.AddToChatNoChats", @"You have no groups or channels to add this bot to.")
		: TGFriendlyErrorText(errorCode, TGL(@"Login.UnknownError", @"An error occurred, please try again later."));
	dispatch_async(dispatch_get_main_queue(), ^{
		[TGSnackbar showInView:self.window.rootViewController.view text:message seconds:3 onCommit:nil];
	});
}

- (void)startPendingAppBotLink:(NSString *)link {
	if (!link.length)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] openBotStartLink:link completion:^(int64_t chatId, NSString *errorCode) {
		AppDelegate *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (chatId) {
			[strongSelf openChatFromNotification:chatId];
			return;
		}
		if ([errorCode isEqualToString:@"pickChat"]) {
			[strongSelf addBotFromLink:link];
			return;
		}
		if ([errorCode isEqualToString:@"unsupported"]) {
			[strongSelf showLinkCouldNotBeOpenedToast];
			return;
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			NSString *message = [errorCode isEqualToString:@"notFound"]
				? TGL(@"Resolve.ErrorNotFound", @"Sorry, this user doesn't seem to exist.")
				: TGFriendlyErrorText(errorCode, TGL(@"Login.UnknownError", @"An error occurred, please try again later."));
			[TGSnackbar showInView:strongSelf.window.rootViewController.view text:message seconds:3 onCommit:nil];
		});
	}];
}

- (void)handleChatFolderInviteLinkURL:(NSURL *)url {
	NSString *urlString = url.absoluteString;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatFolderInviteLinkFromDeepLink:urlString completion:^(NSString *inviteLink) {
		AppDelegate *strongSelf = weakSelf;
		if (!strongSelf || !inviteLink.length)
			return;
		dispatch_async(dispatch_get_main_queue(), ^{
			UINavigationController *nc = [strongSelf navigationControllerForPush];
			if (!nc)
				return;
			[TGChatFolderLinkPreviewViewController presentForInviteLink:inviteLink
					fromNavigationController:nc];
		});
	}];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (alertView.tag == kAppLanguagePackAlertTag) {
		[self handleLanguagePackAlert:alertView buttonIndex:buttonIndex];
		return;
	}

	if (alertView.tag == kAppJoinLinkAlertTag) {
		[self handleJoinLinkAlert:alertView buttonIndex:buttonIndex];
		return;
	}

	if (alertView.tag != kAppBotStartAlertTag)
		return;
	NSString *link = self.pendingBotStartLink;
	self.pendingBotStartLink = nil;
	if (buttonIndex == alertView.cancelButtonIndex || !link.length)
		return;
	[self startPendingAppBotLink:link];
}

- (void)openChatFromNotification:(int64_t)chatId {
	[self openChatFromNotification:chatId focusMessageId:0 threadId:0];
}

- (void)openChatFromNotification:(int64_t)chatId focusMessageId:(int64_t)messageId {
	[self openChatFromNotification:chatId focusMessageId:messageId threadId:0];
}

- (void)openChatFromNotification:(int64_t)chatId
				   focusMessageId:(int64_t)messageId
						 threadId:(int64_t)threadId {
	if (!chatId)
		return;
	if ([[TGPasscodeLock shared] isLocked]) {
		TGPendingNotificationChatId = chatId;
		TGPendingNotificationThreadId = threadId;
		return;
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		UITabBarController *tabs = (UITabBarController *)self.rootViewController;
		if (![tabs isKindOfClass:UITabBarController.class] || tabs.viewControllers.count < 2) {
			TGPendingNotificationChatId = chatId;
			TGPendingNotificationThreadId = threadId;
			return;
		}

		NSDictionary *found = [[TGClient shared] chatInfoForId:chatId];

		tabs.selectedIndex = kTabIndexChats;
		UINavigationController *nc = tabs.viewControllers[kTabIndexChats];
		[nc popToRootViewControllerAnimated:NO];

		if ([found[@"isForum"] boolValue] && !threadId) {
			TGTopicsViewController *topics = [[TGTopicsViewController alloc] init];
			topics.chatId = chatId;
			topics.chatTitle = found[@"title"];
			if (![RootViewController presentInDetail:topics])
				[nc pushViewController:topics animated:NO];
		} else {
			TGChatViewController *vc = [[TGChatViewController alloc] init];
			vc.chatId = chatId;
			vc.chatTitle = found[@"title"] ?: TGL(@"ChatList.UnnamedChat", @"Chat");
			vc.group = [found[@"isGroup"] boolValue];
			vc.focusMessageId = messageId;
			vc.threadId = threadId;
			if (![RootViewController presentInDetail:vc])
				[nc pushViewController:vc animated:NO];
		}

		[[TGNotificationManager shared] clearNotificationsForChat:chatId];
	});
}

#pragma mark - TDLib

- (void)startTDLib {
	TGClient *tg = [TGClient shared];
	__weak typeof(self) weakSelf = self;

	self.authStateObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGAuthStateDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
		AppDelegate *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf applyAuthState:(TGAuthState)[note.userInfo[TGAuthStateKey] integerValue]];
	}];

	self.clientErrorObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGClientErrorNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
		AppDelegate *strongSelf = weakSelf;
		NSString *msg = note.userInfo[TGClientErrorMessageKey];
		[strongSelf.loginCoordinator.loginViewController setBusy:NO];
		[strongSelf showMessage:msg];
	}];

	self.floodWaitObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGClientFloodWaitNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
		AppDelegate *strongSelf = weakSelf;
		NSString *text = TGFloodWaitNoticeText([note.userInfo[TGClientFloodWaitSecondsKey] integerValue]);
		if (!text.length || !strongSelf.window.rootViewController.view)
			return;
		[TGSnackbar showInView:strongSelf.window.rootViewController.view
						  text:text
					   seconds:3
					  onCommit:nil];
	}];

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		if (![tg start])
			NSLog(@"TDLib unavailable - libtdjson.dylib missing or unloadable");
	});
}

- (void)applyAuthState:(TGAuthState)state {
	TGClient *tg = [TGClient shared];
	NSLog(@"TDLIB AUTH: state %d", (int)state);

	if (state == TGAuthStateWaitPhoneNumber || state == TGAuthStateLoggingOut)
		[TGLaunchSnapshot restoreShippedImage:@"signed out"];

	if (state == TGAuthStateWaitPhoneNumber && [[TGAccountManager shared] handleLogOutOfCurrentAccount])
		return;

	switch (state) {
		case TGAuthStateWaitPhoneNumber:
			[self showLoginUI];
			[self.loginCoordinator.loginViewController setBusy:NO];
			break;
		case TGAuthStateWaitCode:
			[self showLoginUI];
			[self.loginCoordinator.loginViewController showCodeStepWithPhoneNumber:self.currentPhoneNumber];
			break;
		case TGAuthStateWaitEmailAddress:
			[self showLoginUI];
			[self.loginCoordinator.loginViewController showEmailStep];
			break;
		case TGAuthStateWaitEmailCode:
			[self showLoginUI];
			[self.loginCoordinator.loginViewController showEmailCodeStepWithPattern:tg.pendingEmailAddressPattern];
			break;
		case TGAuthStateWaitPassword:
			[self showLoginUI];
			[self.loginCoordinator.loginViewController showPasswordStepWithHint:tg.pendingPasswordHint recoveryEmailPattern:tg.pendingRecoveryEmailPattern];
			break;
		case TGAuthStateWaitRegistration:
			[self showLoginUI];
			[self.loginCoordinator.loginViewController showRegistrationStep];
			break;
		case TGAuthStateReady:
			NSLog(@"TDLIB AUTH: READY");
			[self.loginCoordinator.loginViewController setBusy:NO];
			[self showMainUI];
			[[TGNotificationManager shared] start];
			[self adoptSystemLanguagePackIfNeeded];
			if (TGPendingNotificationChatId) {
				int64_t pending = TGPendingNotificationChatId;
				int64_t pendingThread = TGPendingNotificationThreadId;
				TGPendingNotificationChatId = 0;
				TGPendingNotificationThreadId = 0;
				[self openChatFromNotification:pending focusMessageId:0 threadId:pendingThread];
			}
			break;
		case TGAuthStateClosed:
		case TGAuthStateLoggingOut:
			[self showLoginUI];
			break;
		default:
			break;
	}
}

- (void)adoptSystemLanguagePackIfNeeded {
	TGLocalization *localization = [TGLocalization shared];
	if (![localization wantsSystemLanguagePack])
		return;
	NSString *packId = [localization systemLanguagePackId];
	if (!packId.length)
		return;
	[localization rememberSystemLanguagePackAttempt];
	[[TGClient shared] applyLanguagePack:packId
							  completion:^(BOOL success, BOOL packNotFound) {
								  NSLog(@"language pack %@ for the system language: %@",
									  packId,
									  success ? @"installed"
											  : (packNotFound ? @"not offered by the server"
															  : @"could not be fetched"));
							  }];
}

#pragma mark - screens

- (void)showLoadingUI {
	UIViewController *vc = [[UIViewController alloc] init];
	vc.view.backgroundColor = [UIColor colorWithRed:0.87f green:0.89f blue:0.92f alpha:1.0f];

	UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	spinner.center = CGPointMake(vc.view.bounds.size.width / 2,
		vc.view.bounds.size.height / 2);
	spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
		UIViewAutoresizingFlexibleRightMargin |
		UIViewAutoresizingFlexibleTopMargin |
		UIViewAutoresizingFlexibleBottomMargin;
	[spinner startAnimating];
	[vc.view addSubview:spinner];

	[self.window setRootViewController:vc];
}

- (UITabBarController *)tabControllerForHarness {
	id candidate = self.rootViewController;
	if ([candidate isKindOfClass:UITabBarController.class])
		return candidate;

	UIViewController *windowRoot = [UIApplication sharedApplication].keyWindow.rootViewController;
	if ([windowRoot isKindOfClass:UISplitViewController.class]) {
		for (UIViewController *pane in [(UISplitViewController *)windowRoot viewControllers]) {
			if ([pane isKindOfClass:UITabBarController.class])
				return (UITabBarController *)pane;
			if ([pane isKindOfClass:UINavigationController.class]) {
				UIViewController *root = [(UINavigationController *)pane viewControllers].firstObject;
				if ([root isKindOfClass:UITabBarController.class])
					return (UITabBarController *)root;
			}
		}
	}
	if ([windowRoot isKindOfClass:UITabBarController.class])
		return (UITabBarController *)windowRoot;
	return nil;
}

- (UIViewController *)presentedControllerOnScreen {
	UIViewController *root = self.window.rootViewController;
	UIViewController *presented = root.presentedViewController;
	while (presented.presentedViewController)
		presented = presented.presentedViewController;
	if (!presented)
		return nil;
	if ([presented isKindOfClass:[UINavigationController class]])
		return [(UINavigationController *)presented topViewController];
	return presented;
}

- (UIViewController *)topControllerOnScreen {
	UIViewController *presented = [self presentedControllerOnScreen];
	if (presented)
		return presented;
	UINavigationController *detail = [RootViewController detailNavigationController];
	if (detail != nil && ![detail.topViewController isKindOfClass:NSClassFromString(@"TGDetailPlaceholderViewController")])
		return detail.topViewController;
	UITabBarController *tabs = [self tabControllerForHarness];
	if (!tabs || tabs.selectedIndex >= tabs.viewControllers.count)
		return nil;
	id nc = tabs.viewControllers[tabs.selectedIndex];
	return [nc isKindOfClass:UINavigationController.class]
		? [(UINavigationController *)nc topViewController]
		: nc;
}

- (UITableView *)firstTableViewIn:(UIView *)root {
	if ([root isKindOfClass:UITableView.class])
		return (UITableView *)root;
	for (UIView *sub in root.subviews) {
		UITableView *found = [self firstTableViewIn:sub];
		if (found)
			return found;
	}
	return nil;
}

- (UIScrollView *)deepestScrollViewIn:(UIView *)root {
	UIScrollView *found = nil;
	for (UIView *sub in root.subviews) {
		if ([sub isKindOfClass:UIScrollView.class])
			found = (UIScrollView *)sub;
		UIScrollView *nested = [self deepestScrollViewIn:sub];
		if (nested)
			found = nested;
	}
	return found;
}

- (void)showMainUI {
	if (!self.rootViewController)
		self.rootViewController = [[RootViewController alloc] init];
	UIViewController *wanted = self.rootViewController;
	if ([wanted isKindOfClass:[RootViewController class]]) {
		UISplitViewController *split = [(RootViewController *)wanted splitLayoutController];
		if (split)
			wanted = split;
	}
	if ([RootViewController isSplitLayoutActive])
		wanted = [self.window.rootViewController isKindOfClass:[UISplitViewController class]]
			? self.window.rootViewController
			: wanted;
	if (self.window.rootViewController != wanted) {
		self.loginCoordinator = nil;
		[self.window setRootViewController:wanted];
	}
}

- (void)watchAccountSwitching {
	__weak typeof(self) weakSelf = self;
	self.accountDidSwitchObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGAccountDidSwitchNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					(void)note;
					[[TGChatHistoryCache shared] setAccountScope:
							[TGAccountManager scopeForSlot:[TGAccountManager shared].currentSlot]];
				}];
	self.accountWillSwitchObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGAccountWillSwitchNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf tearDownUIForAccountSwitch];
				}];
}

- (void)tearDownUIForAccountSwitch {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(tearDownUIForAccountSwitch)
							   withObject:nil
							waitUntilDone:NO];
		return;
	}
	TGPendingNotificationChatId = 0;
	TGPendingNotificationThreadId = 0;
	TGDismissVisibleAlertsInWindows([UIApplication sharedApplication].windows);
	[[TGNotificationManager shared] discardEverythingForAccountSwitch];
	self.loginCoordinator = nil;
	self.rootViewController = nil;
	[RootViewController forgetSplitLayout];
	[self showLoadingUI];
}

- (void)showLoginUI {
	if (self.loginCoordinator)
		return;
	TGDismissVisibleAlertsInWindows([UIApplication sharedApplication].windows);

	TGLoginCoordinator *coordinator = [[TGLoginCoordinator alloc] initWithWindow:self.window];
	coordinator.cancellable = [TGAccountManager shared].addingAccount;

	__weak typeof(self) weakSelf = self;
	coordinator.onCancelled = ^{
		[[TGAccountManager shared] cancelAddingAccount];
	};
	coordinator.onPhoneSubmitted = ^(NSString *phoneNumber) {
		weakSelf.currentPhoneNumber = phoneNumber;
		[[TGClient shared] sendPhoneNumber:phoneNumber];
	};
	coordinator.onCodeSubmitted = ^(NSString *code) {
		[[TGClient shared] sendCode:code];
	};
	coordinator.onPasswordSubmitted = ^(NSString *password) {
		[[TGClient shared] sendPassword:password];
	};

	self.loginCoordinator = coordinator;
	[coordinator start];
	self.rootViewController = nil;
}

- (void)showMessage:(NSString *)msg {
	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:@""
						 message:msg
						delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

#pragma mark - remote control by URL

- (UIView *)firstResponderUnder:(UIView *)view {
	if (view.isFirstResponder)
		return view;
	for (UIView *sub in view.subviews) {
		UIView *found = [self firstResponderUnder:sub];
		if (found)
			return found;
	}
	return nil;
}

- (UISearchBar *)searchBarUnder:(UIView *)view {
	if ([view isKindOfClass:UISearchBar.class] && !view.hidden)
		return (UISearchBar *)view;
	for (UIView *sub in view.subviews) {
		UISearchBar *found = [self searchBarUnder:sub];
		if (found)
			return found;
	}
	return nil;
}

- (void)fireGestureRecognizer:(UIGestureRecognizer *)recognizer {
	NSArray *targets = [recognizer valueForKey:@"_targets"];
	for (id container in targets) {
		Ivar targetIvar = class_getInstanceVariable([container class], "_target");
		Ivar actionIvar = class_getInstanceVariable([container class], "_action");
		if (!targetIvar || !actionIvar)
			continue;
		id target = object_getIvar(container, targetIvar);
		SEL action = *(SEL *)((__bridge void *)container + ivar_getOffset(actionIvar));
		if (!target || !action || ![target respondsToSelector:action])
			continue;
		NSMethodSignature *signature = [target methodSignatureForSelector:action];
		NSInvocation *call = [NSInvocation invocationWithMethodSignature:signature];
		call.selector = action;
		call.target = target;
		if (signature.numberOfArguments > 2)
			[call setArgument:&recognizer atIndex:2];
		[call invoke];
	}
}

- (UINavigationController *)navigationControllerForPush {
	UINavigationController *detail = [RootViewController detailNavigationController];
	if (detail)
		return detail;

	UIViewController *top = self.rootViewController;
	if ([top isKindOfClass:UITabBarController.class])
		top = [(UITabBarController *)top selectedViewController];
	if ([top isKindOfClass:UISplitViewController.class])
		top = [[(UISplitViewController *)top viewControllers] lastObject];
	if ([top isKindOfClass:UINavigationController.class])
		return (UINavigationController *)top;
	return top.navigationController;
}

static int TGCrashLogDescriptor = -1;

static void TGOpenCrashLog(void) {
	NSString *cache = [NSSearchPathForDirectoriesInDomains(
		NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString *path = [cache stringByAppendingPathComponent:@"crash.txt"];
	TGCrashLogDescriptor = open(path.UTF8String, O_WRONLY | O_CREAT | O_APPEND, 0644);
}

static void TGWriteCrashLine(const char *text) {
	if (TGCrashLogDescriptor < 0 || !text)
		return;
	write(TGCrashLogDescriptor, text, strlen(text));
	write(TGCrashLogDescriptor, "\n", 1);
}

static void TGLogUncaughtException(NSException *exception) {
	TGWriteCrashLine([[NSString stringWithFormat:@"CRASH exception %@: %@",
		exception.name, exception.reason] UTF8String]);
	for (NSString *frame in [exception callStackSymbols])
		TGWriteCrashLine([[NSString stringWithFormat:@"CRASH   %@", frame] UTF8String]);
	NSLog(@"CRASH exception %@: %@", exception.name, exception.reason);
	fflush(stderr);
}

static void TGWriteCrashRegisters(void *context) {
	if (!context)
		return;
	ucontext_t *uc = (ucontext_t *)context;
	if (!uc->uc_mcontext)
		return;
	char line[160];
#if defined(__arm64__)
	const int registerCount = 28;
#else
	const int registerCount = 12;
#endif
	for (int i = 0; i <= registerCount; i++) {
#if defined(__arm64__)
		unsigned long value = (unsigned long)uc->uc_mcontext->__ss.__x[i];
#else
		unsigned long value = (unsigned long)uc->uc_mcontext->__ss.__r[i];
#endif
		const char *name = NULL;
		if (value && (value & 0x3) == 0 && value > 0x1000) {
			Class cls = object_getClass((__bridge id)(void *)value);
			if (cls)
				name = class_getName(cls);
		}
		snprintf(line, sizeof(line), "CRASH r%-2d 0x%08lx %s", i, value, name ? name : "");
		TGWriteCrashLine(line);
	}
}

static void TGLogFatalSignal(int number, siginfo_t *info, void *context) {
	void *frames[64];
	int count = backtrace(frames, 64);
	char header[] = "CRASH signal 00";
	header[13] = (char)('0' + (number / 10) % 10);
	header[14] = (char)('0' + number % 10);
	TGWriteCrashLine(header);
	TGWriteCrashRegisters(context);
	if (TGCrashLogDescriptor >= 0)
		backtrace_symbols_fd(frames, count, TGCrashLogDescriptor);
	signal(number, SIG_DFL);
	raise(number);
}

static void TGInstallFatalSignalHandler(int number) {
	struct sigaction action;
	memset(&action, 0, sizeof(action));
	action.sa_sigaction = TGLogFatalSignal;
	action.sa_flags = SA_SIGINFO | SA_NODEFER | SA_ONSTACK;
	sigemptyset(&action.sa_mask);
	sigaction(number, &action, NULL);
}

static void TGInstallCrashLogging(void) {
	TGOpenCrashLog();
	NSSetUncaughtExceptionHandler(&TGLogUncaughtException);
	TGInstallFatalSignalHandler(SIGSEGV);
	TGInstallFatalSignalHandler(SIGBUS);
	TGInstallFatalSignalHandler(SIGILL);
	TGInstallFatalSignalHandler(SIGABRT);
	TGInstallFatalSignalHandler(SIGTRAP);
}

@end

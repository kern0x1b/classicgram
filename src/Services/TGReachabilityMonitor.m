#import "TGReachabilityMonitor.h"
#import "TGClient+Network.h"

#include <string.h>
#include <netinet/in.h>

@interface TGReachabilityMonitor ()

@property (nonatomic, assign) SCNetworkReachabilityRef reachabilityRef;
@property (nonatomic, copy) NSString *currentNetworkTypeKind;
@property (nonatomic, assign) BOOL started;

- (void)tgReachabilityFlagsDidChange:(SCNetworkReachabilityFlags)flags;
- (void)applyNetworkTypeKind:(NSString *)kind;

@end

static void TGReachabilityCallback(SCNetworkReachabilityRef target,
									SCNetworkReachabilityFlags flags,
									void *info) {
	TGReachabilityMonitor *monitor = (__bridge TGReachabilityMonitor *)info;
	[monitor tgReachabilityFlagsDidChange:flags];
}

@implementation TGReachabilityMonitor

+ (instancetype)shared {
	static TGReachabilityMonitor *shared = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		shared = [[TGReachabilityMonitor alloc] init];
	});
	return shared;
}

- (id)init {
	self = [super init];
	if (!self)
		return nil;
	_currentNetworkTypeKind = @"other";
	return self;
}

- (void)start {
	if (self.started)
		return;
	self.started = YES;

	struct sockaddr_in address;
	memset(&address, 0, sizeof(address));
	address.sin_len = sizeof(address);
	address.sin_family = AF_INET;

	SCNetworkReachabilityRef ref = SCNetworkReachabilityCreateWithAddress(
		kCFAllocatorDefault, (const struct sockaddr *)&address);
	if (!ref)
		return;
	self.reachabilityRef = ref;

	SCNetworkReachabilityContext context = {0, (__bridge void *)self, NULL, NULL, NULL};
	if (SCNetworkReachabilitySetCallback(ref, TGReachabilityCallback, &context))
		SCNetworkReachabilityScheduleWithRunLoop(ref, CFRunLoopGetMain(), kCFRunLoopCommonModes);

	SCNetworkReachabilityFlags flags = 0;
	if (SCNetworkReachabilityGetFlags(ref, &flags))
		[self tgReachabilityFlagsDidChange:flags];
}

- (void)dealloc {
	if (_reachabilityRef) {
		SCNetworkReachabilityUnscheduleFromRunLoop(_reachabilityRef, CFRunLoopGetMain(), kCFRunLoopCommonModes);
		CFRelease(_reachabilityRef);
	}
}

- (void)tgReachabilityFlagsDidChange:(SCNetworkReachabilityFlags)flags {
	NSString *kind = TGReachabilityNetworkTypeKindForFlags(flags);
	if (![NSThread isMainThread]) {
		__weak typeof(self) weakSelf = self;
		dispatch_async(dispatch_get_main_queue(), ^{
			[weakSelf applyNetworkTypeKind:kind];
		});
		return;
	}
	[self applyNetworkTypeKind:kind];
}

- (void)applyNetworkTypeKind:(NSString *)kind {
	if ([self.currentNetworkTypeKind isEqualToString:kind])
		return;
	self.currentNetworkTypeKind = kind;
	[[TGClient shared] setNetworkTypeKind:kind];
}

@end

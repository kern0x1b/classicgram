#import "TGFrameTimeLogger.h"
#import <QuartzCore/QuartzCore.h>

static const double kFrameTimeReportEvery = 1.0;

@interface TGFrameTimeRecorder : NSObject
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic, assign) CFTimeInterval lastTimestamp;
@property (nonatomic, assign) CFTimeInterval reportedAt;
@property (nonatomic, assign) TGFrameTimeWindow window;
@end

static TGFrameTimeRecorder *sRecorder = nil;

@implementation TGFrameTimeRecorder

- (void)start {
	if (self.link)
		return;
	TGFrameTimeWindow window;
	TGFrameTimeWindowReset(&window);
	self.window = window;
	self.lastTimestamp = 0;
	self.reportedAt = 0;
	self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
	[self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)report {
	TGFrameTimeWindow window = self.window;
	if (window.frames < 1)
		return;
	NSLog(@"PERF frames n=%ld avg=%.1f fps worst=%.1f ms over=%ld",
		(long)window.frames,
		TGFrameTimeWindowAverageFps(window),
		window.worstDelta * 1000.0,
		(long)window.framesOverBudget);
	TGFrameTimeWindowReset(&window);
	self.window = window;
}

- (void)stop {
	if (!self.link)
		return;
	[self.link invalidate];
	self.link = nil;
	[self report];
}

- (void)tick:(CADisplayLink *)link {
	CFTimeInterval now = link.timestamp;
	if (self.lastTimestamp > 0) {
		TGFrameTimeWindow window = self.window;
		TGFrameTimeWindowAdd(&window, now - self.lastTimestamp);
		self.window = window;
	}
	self.lastTimestamp = now;
	if (self.reportedAt <= 0)
		self.reportedAt = now;
	if (now - self.reportedAt >= kFrameTimeReportEvery) {
		self.reportedAt = now;
		[self report];
	}
}

@end

void TGFrameTimeLoggingStart(void) {
	if (!sRecorder)
		sRecorder = [[TGFrameTimeRecorder alloc] init];
	[sRecorder start];
}

void TGFrameTimeLoggingStop(void) {
	[sRecorder stop];
}

BOOL TGFrameTimeLoggingActive(void) {
	return sRecorder.link != nil;
}

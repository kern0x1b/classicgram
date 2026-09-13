#import "TGResendCountdown.h"

@interface TGResendCountdown ()
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) NSInteger secondsRemaining;
@end

@implementation TGResendCountdown

- (void)startWithSeconds:(NSInteger)seconds {
	[self stop];
	self.secondsRemaining = seconds;
	if (seconds <= 0)
		return;
	self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
												   target:self
												 selector:@selector(tick)
												 userInfo:nil
												  repeats:YES];
}

- (void)tick {
	if (self.secondsRemaining > 0)
		self.secondsRemaining--;
	if (self.onTick)
		self.onTick(self.secondsRemaining);
	if (self.secondsRemaining <= 0) {
		[self.timer invalidate];
		self.timer = nil;
		if (self.onFinished)
			self.onFinished();
	}
}

- (void)stop {
	[self.timer invalidate];
	self.timer = nil;
	self.secondsRemaining = 0;
}

- (void)dealloc {
	[_timer invalidate];
}

@end

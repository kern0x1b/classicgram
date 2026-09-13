#import "TGSystemCall.h"

#import "TGCall.h"
#import "TGUserDisplayNameStore.h"
#import "TGLocalization.h"

#import <UIKit/UIKit.h>
#import <notify.h>

static NSString *const TGSystemCallPayloadName = @"systemcall.plist";

static const char *const TGSystemCallIncomingName = "com.kern0x1b.telegram.call.incoming";
static const char *const TGSystemCallEndedName = "com.kern0x1b.telegram.call.ended";
static const char *const TGSystemCallAnswerName = "com.kern0x1b.telegram.call.answer";
static const char *const TGSystemCallDeclineName = "com.kern0x1b.telegram.call.decline";

@interface TGSystemCall ()
@property (nonatomic, assign) BOOL announced;
@property (nonatomic, assign) int answerToken;
@property (nonatomic, assign) int declineToken;
@property (nonatomic, strong) id callStateChangedObserverToken;
@property (nonatomic, strong) id didEnterBackgroundObserverToken;
@end

@implementation TGSystemCall

+ (instancetype)shared {
	static TGSystemCall *s = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ s = [[TGSystemCall alloc] init]; });
	return s;
}

+ (void)install {
	[[self shared] start];
}

- (id)init {
	self = [super init];
	if (self) {
		_answerToken = NOTIFY_TOKEN_INVALID;
		_declineToken = NOTIFY_TOKEN_INVALID;
	}
	return self;
}

- (void)dealloc {
	if (self.callStateChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.callStateChangedObserverToken];
	if (self.didEnterBackgroundObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.didEnterBackgroundObserverToken];
}

- (void)start {
	static BOOL started = NO;
	if (started)
		return;
	started = YES;

	__weak __typeof__(self) weakSelf = self;
	self.callStateChangedObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGCallStateDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf callStateChanged:note];
				}];

	self.didEnterBackgroundObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIApplicationDidEnterBackgroundNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf callStateChanged:note];
				}];

	notify_register_dispatch(TGSystemCallAnswerName, &_answerToken,
		dispatch_get_main_queue(), ^(int token) {
			[weakSelf answerFromSystemUI];
		});
	notify_register_dispatch(TGSystemCallDeclineName, &_declineToken,
		dispatch_get_main_queue(), ^(int token) {
			[weakSelf declineFromSystemUI];
		});
}

#pragma mark - the payload the tweak reads

- (NSString *)payloadPath {
	NSString *caches = [NSSearchPathForDirectoriesInDomains(
		NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	return [caches stringByAppendingPathComponent:TGSystemCallPayloadName];
}

- (void)writePayloadForCall:(TGCall *)call {
	NSString *name = [TGUserDisplayNameStore nameForUserId:call.peerUserId];
	if (![name isKindOfClass:[NSString class]] || name.length == 0)
		name = @"Telegram";

	NSDictionary *payload = @{
		@"name" : name,
		@"subtitle" : call.video ? TGL(@"Call.StatusIncomingVideo", @"Telegram Video...")
								 : TGL(@"Call.StatusIncoming", @"Telegram Audio..."),
		@"callId" : @(call.callId),
		@"userId" : @(call.peerUserId),
		@"posted" : @(CFAbsoluteTimeGetCurrent()),
	};
	if (![payload writeToFile:[self payloadPath] atomically:YES])
		NSLog(@"TGSystemCall: could not write %@", [self payloadPath]);
}

- (void)removePayload {
	[[NSFileManager defaultManager] removeItemAtPath:[self payloadPath] error:nil];
}

#pragma mark - our side of the conversation

- (void)callStateChanged:(NSNotification *)note {
	TGCall *call = [TGCall shared];
	BOOL ringing = call.state == TGCallStatePending && !call.outgoing;

	if (ringing && !self.announced) {
		if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
			return;
		self.announced = YES;
		[self writePayloadForCall:call];
		notify_post(TGSystemCallIncomingName);
		return;
	}
	if (!ringing && self.announced) {
		self.announced = NO;
		notify_post(TGSystemCallEndedName);
		[self removePayload];
	}
}

#pragma mark - the tweak's side

- (void)answerFromSystemUI {
	TGCall *call = [TGCall shared];
	if (call.state != TGCallStatePending || call.outgoing)
		return;
	NSLog(@"TGSystemCall: answering call %d from the system alert", call.callId);
	[self presentCallScreenIfNeededForCall:call];
	[call accept];
}

- (void)declineFromSystemUI {
	TGCall *call = [TGCall shared];
	if (call.state != TGCallStatePending || call.outgoing)
		return;
	NSLog(@"TGSystemCall: declining call %d from the system alert", call.callId);
	[call hangUp];
}

- (void)presentCallScreenIfNeededForCall:(TGCall *)call {
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGCallStateDidChangeNotification
					  object:call];
}

@end

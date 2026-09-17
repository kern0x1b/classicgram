#import "TGCall.h"
#import "TGLazyFramework.h"
#import "TGClient.h"
#import "TGClient+Calls.h"
#import "TGCallRtcServers.h"
#import "TGCallsEngineSession.h"
#import "TGVideoCapture.h"
#import "TGVideoFrameView.h"
#import "TGBase64.h"
#import <AVFoundation/AVFoundation.h>
#import <dlfcn.h>

NSString *const TGCallStateDidChangeNotification = @"TGCallStateDidChangeNotification";
NSString *const TGCallVideoStateDidChangeNotification = @"TGCallVideoStateDidChangeNotification";
NSString *const TGCallPeerMediaStateDidChangeNotification = @"TGCallPeerMediaStateDidChangeNotification";

static NSString *const TGCallsEngineLibrary = @"Frameworks/libTGCallsEngine.dylib";
static NSString *const TGCallsEngineClassName = @"TGCallsEngineSession";

static NSString *TGCallsEnginePath(void) {
	return [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:TGCallsEngineLibrary];
}

static Class TGCallsEngineClass(void) {
	static Class engineClass = Nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		if (!dlopen(TGCallsEnginePath().fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL)) {
			NSLog(@"TGCall: the calls engine did not load: %s", dlerror());
			return;
		}
		Class candidate = NSClassFromString(TGCallsEngineClassName);
		if ([candidate conformsToProtocol:@protocol(TGCallsEngineSession)])
			engineClass = candidate;
	});
	return engineClass;
}

@interface TGCall ()
@property (nonatomic, assign) TGCallState state;
@property (nonatomic, assign) int32_t callId;
@property (nonatomic, assign) int64_t peerUserId;
@property (nonatomic, assign) BOOL outgoing;
@property (nonatomic, assign) BOOL muted;
@property (nonatomic, assign) BOOL video;
@property (nonatomic, assign) BOOL awaitingCallId;
@property (nonatomic, assign) BOOL pendingHangup;
@property (nonatomic, assign) int32_t cancelledCallId;
@property (nonatomic, strong) NSDate *establishedAt;
@property (nonatomic, strong) NSString *endReason;
@property (nonatomic, copy) NSArray *verificationEmojis;
@property (nonatomic, strong) id<TGCallsEngineSession> engine;
@property (nonatomic, strong) NSMutableArray *pendingSignaling;
@property (nonatomic, assign) BOOL localVideoActive;
@property (nonatomic, assign) BOOL remoteVideoActive;
@property (nonatomic, assign) BOOL localVideoRequested;
@property (nonatomic, strong) TGVideoCapture *videoCapture;
@property (nonatomic, weak) UIView *localPreviewContainer;
@property (nonatomic, weak) UIView *remoteVideoContainer;
@property (nonatomic, strong) TGVideoFrameView *remoteVideoView;
@end

@implementation TGCall

+ (BOOL)canSendVideo {
	return [TGVideoCapture isCameraAvailable] && [[NSFileManager defaultManager] fileExistsAtPath:TGCallsEnginePath()];
}

+ (NSArray *)libraryVersions {
	return [TGCallsEngineClass() libraryVersions] ?: @[];
}

+ (int32_t)maxLayer {
	return [TGCallsEngineClass() maxLayer];
}

+ (instancetype)shared {
	static TGCall *s = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ s = [[TGCall alloc] init]; });
	return s;
}

- (NSTimeInterval)duration {
	return self.establishedAt ? -[self.establishedAt timeIntervalSinceNow] : 0;
}

- (void)setState:(TGCallState)state {
	if (_state == state)
		return;
	_state = state;
	if (state == TGCallStateEstablished && !self.establishedAt)
		self.establishedAt = [NSDate date];
	if (self.onStateChanged)
		self.onStateChanged(state);
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGCallStateDidChangeNotification object:self];
}

#pragma mark - signalling

- (void)handleSignalingData:(NSData *)data {
	if (!data.length)
		return;
	if (self.engine) {
		[self.engine receiveSignalingData:data];
		return;
	}
	if (!self.pendingSignaling)
		self.pendingSignaling = [NSMutableArray array];
	[self.pendingSignaling addObject:data];
}

- (void)callUser:(int64_t)userId video:(BOOL)video {
	self.peerUserId = userId;
	self.outgoing = YES;
	self.video = video;
	self.localVideoRequested = video;
	self.muted = NO;
	self.pendingHangup = NO;
	self.cancelledCallId = 0;
	self.endReason = nil;
	if (!TGCallsEngineClass()) {
		self.awaitingCallId = NO;
		self.endReason = @"Call failed";
		self.state = TGCallStateFailed;
		return;
	}
	self.awaitingCallId = YES;
	self.state = TGCallStatePending;
	__weak __typeof__(self) weakSelf = self;
	[[TGClient shared] createCallToUserId:userId
									 video:video
								completion:^(int32_t callId, BOOL success){
		[weakSelf handleCreatedCallId:callId success:success];
	}];
}

- (void)handleCreatedCallId:(int32_t)callId success:(BOOL)success {
	if (!self.awaitingCallId)
		return;
	self.awaitingCallId = NO;

	if (!success || callId == 0){
		self.pendingHangup = NO;
		if (self.state == TGCallStateEnded || self.state == TGCallStateFailed)
			return;
		self.endReason = @"Call failed";
		[self teardown];
		self.state = TGCallStateFailed;
		return;
	}

	if (self.pendingHangup){
		self.pendingHangup = NO;
		self.cancelledCallId = callId;
		[[TGClient shared] discardCallId:callId
								 duration:0
									video:self.video
							   isDisconnected:NO
								 connectionId:0];
		return;
	}

	self.callId = callId;
}

- (void)accept {
	if (!self.callId)
		return;
	[[TGClient shared] acceptCallId:self.callId];
}

- (void)hangUp {
	if (self.callId)
		[[TGClient shared] discardCallId:self.callId
								duration:(NSInteger)[self duration]
								   video:self.video
							isDisconnected:NO
							  connectionId:[self.engine preferredRelayId]];
	else if (self.awaitingCallId)
		self.pendingHangup = YES;
	[self teardown];
	self.state = TGCallStateEnded;
}

- (void)discardAsDisconnected {
	if (self.callId)
		[[TGClient shared] discardCallId:self.callId
								 duration:(NSInteger)[self duration]
									video:self.video
							   isDisconnected:YES
								 connectionId:[self.engine preferredRelayId]];
}

- (void)handleUpdate:(NSDictionary *)call {
	int32_t callId = [call[@"id"] intValue];
	NSDictionary *state = call[@"state"];
	NSString *kind = TGTDLibTypeOf(state);
	BOOL incomingIsTerminal = [kind isEqualToString:@"callStateDiscarded"] ||
			[kind isEqualToString:@"callStateHangingUp"] ||
			[kind isEqualToString:@"callStateError"];

	if (callId != 0 && callId == self.cancelledCallId){
		if (incomingIsTerminal){
			self.cancelledCallId = 0;
		} else {
			[[TGClient shared] discardCallId:callId
									 duration:0
										video:[call[@"is_video"] boolValue]
								isDisconnected:NO
								  connectionId:0];
		}
		return;
	}

	if (self.awaitingCallId && self.callId == 0 && callId != 0){
		self.awaitingCallId = NO;
		if (self.pendingHangup){
			self.pendingHangup = NO;
			self.cancelledCallId = callId;
			if (!incomingIsTerminal)
				[[TGClient shared] discardCallId:callId
										 duration:0
											video:[call[@"is_video"] boolValue]
									isDisconnected:NO
									  connectionId:0];
			return;
		}
		self.callId = callId;
	}

	BOOL hasActiveCall = self.callId != 0 &&
			self.state != TGCallStateNone &&
			self.state != TGCallStateEnded &&
			self.state != TGCallStateFailed;
	if (hasActiveCall && callId != self.callId){
		NSLog(@"TGCall: second call %d arrived while call %d is active, declining it",
				callId, self.callId);
		if (!incomingIsTerminal && callId != 0)
			[[TGClient shared] discardCallId:callId
									 duration:0
										video:[call[@"is_video"] boolValue]
								isDisconnected:NO
								  connectionId:0];
		return;
	}

	BOOL outgoing = [call[@"is_outgoing"] boolValue];
	if (!outgoing && callId != self.callId){
		self.muted = NO;
		self.endReason = nil;
		self.pendingSignaling = nil;
	}
	self.callId = callId;
	self.peerUserId = [call[@"user_id"] longLongValue];
	self.outgoing = outgoing;
	self.video = [call[@"is_video"] boolValue];
	if (!self.outgoing)
		self.localVideoRequested = self.video;

	NSLog(@"TGCall: %@ (call %d, outgoing %d)", kind, self.callId, self.outgoing);

	if ([kind isEqualToString:@"callStatePending"]){
		self.state = TGCallStatePending;
	} else if ([kind isEqualToString:@"callStateExchangingKeys"]){
		self.state = TGCallStateExchangingKeys;
	} else if ([kind isEqualToString:@"callStateReady"]){
		[self startMediaWithState:state];
	} else if ([kind isEqualToString:@"callStateDiscarded"] ||
			   [kind isEqualToString:@"callStateHangingUp"]){
		NSString *reason = TGTDLibTypeOf(state[@"reason"]);
		NSLog(@"TGCall: discarded, reason %@", reason ?: @"(none)");
		self.endReason = [self humanReason:reason];
		[self teardown];
		self.state = TGCallStateEnded;
	} else if ([kind isEqualToString:@"callStateError"]){
		NSLog(@"TGCall: error %@ %@", state[@"error"][@"code"], state[@"error"][@"message"]);
		self.endReason = state[@"error"][@"message"];
		[self teardown];
		self.state = TGCallStateFailed;
	}
}

- (NSString *)humanReason:(NSString *)reason {
	if ([reason isEqualToString:@"callDiscardReasonDeclined"])       return @"Declined";
	if ([reason isEqualToString:@"callDiscardReasonMissed"])         return @"No answer";
	if ([reason isEqualToString:@"callDiscardReasonDisconnected"])   return @"Disconnected";
	if ([reason isEqualToString:@"callDiscardReasonHungUp"])         return @"Call ended";
	if ([reason isEqualToString:@"callDiscardReasonUpgradeToGroupCall"]) return @"Moved to a group call";
	return nil;
}

#pragma mark - media

- (void)activateCallAudioSession {
	AVAudioSession *session = [TGAVClass(AVAudioSession) sharedInstance];
	[session setCategory:TGAVString(AVAudioSessionCategoryPlayAndRecord)
			 withOptions:AVAudioSessionCategoryOptionAllowBluetooth
				   error:nil];
	[session setMode:TGAVString(AVAudioSessionModeVoiceChat) error:nil];
	[session setActive:YES error:nil];
	[self.engine setAudioSessionActive:YES];
}

- (void)reactivateAudioSessionAfterInterruption {
	if (!self.engine)
		return;
	[self activateCallAudioSession];
}

- (void)failMediaStart:(NSString *)problem {
	NSLog(@"TGCall: %@", problem);
	[self discardAsDisconnected];
	self.endReason = @"Call failed";
	[self teardown];
	self.state = TGCallStateFailed;
}

- (void)startMediaWithState:(NSDictionary *)state {
	if (self.engine)
		return;

	NSArray *emojis = state[@"emojis"];
	self.verificationEmojis = [emojis isKindOfClass:NSArray.class] ? emojis : nil;

	Class engineClass = TGCallsEngineClass();
	if (!engineClass){
		[self failMediaStart:@"the calls engine is not available"];
		return;
	}

	NSData *key = TGBase64Decode(state[@"encryption_key"]);
	if (key.length != 256){
		[self failMediaStart:[NSString stringWithFormat:@"encryption key is %lu bytes, expected 256", (unsigned long)key.length]];
		return;
	}

	NSArray *versions = state[@"protocol"][@"library_versions"];
	NSString *version = [versions isKindOfClass:NSArray.class] ? versions.firstObject : nil;
	if (![version isKindOfClass:NSString.class] || ![[engineClass libraryVersions] containsObject:version]){
		[self failMediaStart:[NSString stringWithFormat:@"the peer settled on protocol %@, which the engine does not speak", version]];
		return;
	}

	NSString *customParameters = [state[@"custom_parameters"] isKindOfClass:NSString.class] ? state[@"custom_parameters"] : nil;
	id<TGCallsEngineSession> engine = [[engineClass alloc] initWithVersion:version
															 encryptionKey:key
																  outgoing:self.outgoing
																  allowP2P:[state[@"allow_p2p"] boolValue]
																rtcServers:TGCallRtcServers(state[@"servers"], version)
														  customParameters:customParameters];

	__weak __typeof__(self) weakSelf = self;
	engine.onStateChanged = ^(TGCallsEngineState engineState){
		[weakSelf engineStateChanged:engineState];
	};
	engine.onSignalingData = ^(NSData *data){
		TGCall *strongSelf = weakSelf;
		if (strongSelf.callId)
			[[TGClient shared] sendSignalingData:TGBase64Encode(data) forCallId:strongSelf.callId];
	};
	engine.onRemoteMediaChanged = ^(BOOL audioMuted, BOOL videoActive){
		[weakSelf peerMediaChangedAudioMuted:audioMuted videoActive:videoActive];
	};
	engine.onRemoteVideoFrame = ^(const uint8_t *bgra, int width, int height, int bytesPerRow){
		[weakSelf.remoteVideoView presentBGRABytes:bgra width:width height:height bytesPerRow:bytesPerRow];
	};

	NSLog(@"TGCall: starting engine protocol %@ with %lu servers", version, (unsigned long)[state[@"servers"] count]);
	self.state = TGCallStateConnecting;
	self.engine = engine;
	[engine start];
	[engine setMuted:self.muted];
	[self activateCallAudioSession];

	NSArray *pending = self.pendingSignaling;
	self.pendingSignaling = nil;
	for (NSData *data in pending)
		[engine receiveSignalingData:data];

	if (self.video && self.localVideoRequested)
		[self startLocalCaptureIfNeeded];
}

- (void)engineStateChanged:(TGCallsEngineState)engineState {
	if (!self.engine)
		return;
	switch (engineState){
		case TGCallsEngineStateEstablished:
			self.state = TGCallStateEstablished;
			break;
		case TGCallsEngineStateReconnecting:
		case TGCallsEngineStateConnecting:
			self.state = TGCallStateConnecting;
			break;
		case TGCallsEngineStateFailed:
			[self failMediaStart:@"the engine lost the connection"];
			break;
	}
}

- (void)peerMediaChangedAudioMuted:(BOOL)audioMuted videoActive:(BOOL)videoActive {
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGCallPeerMediaStateDidChangeNotification
						  object:self
						userInfo:@{@"audioMuted" : @(audioMuted), @"videoPaused" : @(!videoActive)}];
	if (self.remoteVideoActive == videoActive)
		return;
	self.remoteVideoActive = videoActive;
	if (!videoActive)
		[self.remoteVideoView clear];
	[[NSNotificationCenter defaultCenter] postNotificationName:TGCallVideoStateDidChangeNotification object:self];
}

#pragma mark - video

- (void)startLocalCaptureIfNeeded {
	if (self.videoCapture || !self.engine)
		return;
	if (![TGVideoCapture isCameraAvailable]){
		NSLog(@"TGCall: no camera available, the call stays audio-only outbound");
		[[NSNotificationCenter defaultCenter] postNotificationName:TGCallVideoStateDidChangeNotification object:self];
		return;
	}

	TGVideoCapture *capture = [[TGVideoCapture alloc] init];
	id<TGCallsEngineSession> engine = self.engine;
	capture.onPixelBuffer = ^(CVPixelBufferRef pixelBuffer, int64_t presentationTimeUs){
		[engine pushCameraPixelBuffer:pixelBuffer];
	};
	[engine setCameraEnabled:YES];
	if (![capture start]){
		NSLog(@"TGCall: camera capture failed to start");
		[engine setCameraEnabled:NO];
		[[NSNotificationCenter defaultCenter] postNotificationName:TGCallVideoStateDidChangeNotification object:self];
		return;
	}
	self.videoCapture = capture;
	self.localVideoActive = YES;

	if (self.localPreviewContainer)
		[self attachPreviewLayerToContainer:self.localPreviewContainer];

	[[NSNotificationCenter defaultCenter] postNotificationName:TGCallVideoStateDidChangeNotification object:self];
}

- (void)attachPreviewLayerToContainer:(UIView *)container {
	AVCaptureVideoPreviewLayer *preview = self.videoCapture.previewLayer;
	if (!preview)
		return;
	preview.frame = container.bounds;
	[container.layer addSublayer:preview];
}

- (void)attachLocalPreviewToView:(UIView *)containerView {
	self.localPreviewContainer = containerView;
	if (self.videoCapture.previewLayer)
		[self attachPreviewLayerToContainer:containerView];
}

- (void)attachRemoteVideoToView:(UIView *)containerView {
	self.remoteVideoContainer = containerView;
	if (!self.remoteVideoView){
		TGVideoFrameView *view = [[TGVideoFrameView alloc] initWithFrame:containerView.bounds];
		view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.remoteVideoView = view;
	}
	self.remoteVideoView.frame = containerView.bounds;
	if (self.remoteVideoView.superview != containerView)
		[containerView addSubview:self.remoteVideoView];
}

- (void)detachVideoViews {
	[self.remoteVideoView removeFromSuperview];
	self.localPreviewContainer = nil;
	self.remoteVideoContainer = nil;
}

- (void)setLocalVideoEnabled:(BOOL)enabled {
	self.localVideoRequested = enabled;
	if (enabled){
		[self startLocalCaptureIfNeeded];
		[self.videoCapture setPaused:NO];
		if (self.videoCapture)
			[self.engine setCameraEnabled:YES];
	} else if (self.videoCapture){
		[self.videoCapture setPaused:YES];
		[self.engine setCameraEnabled:NO];
	}
	self.localVideoActive = enabled && self.videoCapture.isRunning;
	[[NSNotificationCenter defaultCenter] postNotificationName:TGCallVideoStateDidChangeNotification object:self];
}

- (BOOL)canSwitchCamera {
	return [self.videoCapture canSwitchCamera];
}

- (BOOL)frontCamera {
	return self.videoCapture.isFrontFacing;
}

- (void)switchCamera {
	[self.videoCapture switchCamera];
}

- (void)tearDownVideo {
	[self.videoCapture stop];
	self.videoCapture = nil;
	[self.remoteVideoView removeFromSuperview];
	self.remoteVideoView = nil;
	self.localPreviewContainer = nil;
	self.remoteVideoContainer = nil;
	self.localVideoActive = NO;
	self.remoteVideoActive = NO;
	self.localVideoRequested = NO;
}

- (void)setMuted:(BOOL)muted {
	_muted = muted;
	[self.engine setMuted:muted];
}

- (void)teardown {
	id<TGCallsEngineSession> engine = self.engine;
	self.engine = nil;
	self.pendingSignaling = nil;
	[self tearDownVideo];
	[engine setAudioSessionActive:NO];
	[engine stop];
	self.establishedAt = nil;
	self.callId = 0;
	[[TGAVClass(AVAudioSession) sharedInstance] setActive:NO error:nil];
}

@end

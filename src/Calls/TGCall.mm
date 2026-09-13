#import "TGCall.h"
#import "TGLazyFramework.h"
#import "TGClient.h"
#import "TGClient+Calls.h"
#import "TGCallReflector.h"
#import "TGCallMessages.h"
#import "TGCallIce.h"
#import "TGCallStun.h"
#include "TGCallCrypto.h"
#import <AVFoundation/AVFoundation.h>

#include "libtgvoip/VoIPController.h"
#include <openssl/aes.h>
#include <openssl/modes.h>
#include <openssl/rand.h>
#include <openssl/sha.h>

#include "libtgvoip/video/VideoSource.h"
#include "libtgvoip/video/VideoRenderer.h"
#include "libtgvoip/os/darwin/TGCallVideoSource.h"
#include "libtgvoip/os/darwin/TGCallVideoRenderer.h"
#include "libtgvoip/PrivateDefines.h"
#import "TGVideoCapture.h"
#import "TGVideoFrameView.h"
#import "TGBase64.h"

using namespace tgvoip;

NSString *const TGCallStateDidChangeNotification = @"TGCallStateDidChangeNotification";
NSString *const TGCallVideoStateDidChangeNotification = @"TGCallVideoStateDidChangeNotification";
NSString *const TGCallPeerMediaStateDidChangeNotification = @"TGCallPeerMediaStateDidChangeNotification";

namespace tgvoip {
	CryptoFunctions VoIPController::crypto;
}

#pragma mark - crypto

static void TGRandBytes(uint8_t *buffer, size_t length) {
	RAND_bytes(buffer, (int)length);
}

static void TGSha1(uint8_t *msg, size_t length, uint8_t *output) {
	SHA1(msg, length, output);
}

static void TGSha256(uint8_t *msg, size_t length, uint8_t *output) {
	SHA256(msg, length, output);
}

static void TGAesIgeEncrypt(uint8_t *in, uint8_t *out, size_t length,
							uint8_t *key, uint8_t *iv) {
	AES_KEY akey;
	AES_set_encrypt_key(key, 32 * 8, &akey);
	AES_ige_encrypt(in, out, length, &akey, iv, AES_ENCRYPT);
}

static void TGAesIgeDecrypt(uint8_t *in, uint8_t *out, size_t length,
							uint8_t *key, uint8_t *iv) {
	AES_KEY akey;
	AES_set_decrypt_key(key, 32 * 8, &akey);
	AES_ige_encrypt(in, out, length, &akey, iv, AES_DECRYPT);
}

static void TGAesCtrEncrypt(uint8_t *inout, size_t length, uint8_t *key,
							uint8_t *iv, uint8_t *ecount, uint32_t *num) {
	AES_KEY akey;
	AES_set_encrypt_key(key, 32 * 8, &akey);
	CRYPTO_ctr128_encrypt(inout, inout, length, &akey, iv, ecount, num,
						  (block128_f)AES_encrypt);
}

static void TGAesCbcEncrypt(uint8_t *in, uint8_t *out, size_t length,
							uint8_t *key, uint8_t *iv) {
	AES_KEY akey;
	AES_set_encrypt_key(key, 256, &akey);
	AES_cbc_encrypt(in, out, length, &akey, iv, AES_ENCRYPT);
}

static void TGAesCbcDecrypt(uint8_t *in, uint8_t *out, size_t length,
							uint8_t *key, uint8_t *iv) {
	AES_KEY akey;
	AES_set_decrypt_key(key, 256, &akey);
	AES_cbc_encrypt(in, out, length, &akey, iv, AES_DECRYPT);
}

static void TGInstallCrypto(void) {
	static BOOL installed = NO;
	if (installed)
		return;
	installed = YES;
	VoIPController::crypto.rand_bytes      = TGRandBytes;
	VoIPController::crypto.sha1            = TGSha1;
	VoIPController::crypto.sha256          = TGSha256;
	VoIPController::crypto.aes_ige_encrypt = TGAesIgeEncrypt;
	VoIPController::crypto.aes_ige_decrypt = TGAesIgeDecrypt;
	VoIPController::crypto.aes_ctr_encrypt = TGAesCtrEncrypt;
	VoIPController::crypto.aes_cbc_encrypt = TGAesCbcEncrypt;
	VoIPController::crypto.aes_cbc_decrypt = TGAesCbcDecrypt;
}

#pragma mark -

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
@property (nonatomic, strong) TGCallReflector *reflector;
@property (nonatomic, strong) NSMutableArray *reflectors;
@property (nonatomic, strong) NSData *callKey;
@property (nonatomic, strong) NSString *localUfrag;
@property (nonatomic, strong) NSString *localPwd;
@property (nonatomic, strong) NSString *reflectorHost;
@property (nonatomic, assign) uint32_t signallingSeq;
@property (nonatomic, assign) BOOL sentCandidates;
@property (nonatomic, assign) uint32_t currentSenderTag;
@property (nonatomic, strong) TGCallReflector *currentReflector;
@property (nonatomic, strong) NSString *peerUfrag;
@property (nonatomic, strong) NSString *peerPwd;
@property (nonatomic, strong) TGCallIce *ice;
@property (nonatomic, assign) BOOL localVideoActive;
@property (nonatomic, assign) BOOL remoteVideoActive;
@property (nonatomic, assign) NSTimeInterval remoteVideoLastFrameAt;
@property (nonatomic, strong) NSTimer *remoteVideoWatchdog;
@property (nonatomic, assign) BOOL localVideoRequested;
@property (nonatomic, strong) TGVideoCapture *videoCapture;
@property (nonatomic, weak) UIView *localPreviewContainer;
@property (nonatomic, weak) UIView *remoteVideoContainer;
@property (nonatomic, strong) TGVideoFrameView *remoteVideoView;
@property (nonatomic, assign) BOOL videoPipelineSetUp;
- (void)setUpVideoPipelineIfNeeded;
- (void)tearDownVideoPipeline;
- (void)startLocalCaptureIfNeeded;
- (void)attachPreviewLayerToContainer:(UIView *)container;
- (void)handleCreatedCallId:(int32_t)callId success:(BOOL)success;
- (void)activateCallAudioSession;
@end

@implementation TGCall {
	VoIPController *_controller;
	tgvoip::video::TGCallVideoSource *_videoSource;
	tgvoip::video::TGCallVideoRenderer *_videoRenderer;
}

+ (BOOL)canSendVideo {
	return !tgvoip::video::VideoSource::GetAvailableEncoders().empty();
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

- (NSString *)randomIceStringOfLength:(NSInteger)length {
	static NSString *alphabet = @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
	NSMutableString *out = [NSMutableString string];
	for (NSInteger i = 0; i < length; i++)
		[out appendFormat:@"%C", [alphabet characterAtIndex:arc4random_uniform((uint32_t)alphabet.length)]];
	return out;
}

- (void)sendOurCandidates {
	if (self.sentCandidates || !self.reflectorHost.length)
		return;
	self.sentCandidates = YES;

	self.localUfrag = [self randomIceStringOfLength:4];
	self.localPwd = [self randomIceStringOfLength:24];

	self.ice = [[TGCallIce alloc] init];
	self.ice.localUfrag = self.localUfrag;
	self.ice.localPwd = self.localPwd;
	__weak __typeof__(self) weakSelf = self;
	self.ice.transport = ^(NSData *packet){
		TGCall *strongSelf = weakSelf;

		if (strongSelf.currentSenderTag){
			[strongSelf.currentReflector ?: strongSelf.reflector sendPayload:packet
													   toTag:strongSelf.currentSenderTag];
			return;
		}
		for (TGCallReflector *reflector in strongSelf.reflectors)
			[reflector sendPayload:packet];
	};
	self.ice.onConnected = ^(NSString *address, uint16_t port){
		NSLog(@"TGCall: media path is %@:%u", address, port);
	};
	[self.ice start];

	NSMutableArray *candidates = [NSMutableArray array];
	NSInteger index = 0;
	for (TGCallReflector *reflector in self.reflectors){
		index++;
		NSString *hostname = [NSString stringWithFormat:@"reflector-%ld-%u.reflector",
				(long)index, reflector.localTag];

		[candidates addObject:[NSString stringWithFormat:
				@"candidate:%u 0 udp 41878272 %@ %u typ relay generation 0 "
				@"ufrag %@ network-id 9 network-cost 50",
				reflector.localTag, hostname, reflector.port, self.localUfrag]];
	}

	NSData *body = [TGCallMessages candidatesBody:candidates
											ufrag:self.localUfrag
											  pwd:self.localPwd];
	NSData *message = [TGCallMessages messageWithType:kCallMessageCandidates body:body];
	[self sendSignalling:message
					 seq:[TGCallMessages markSeq:++self.signallingSeq requiresAck:YES]];
	NSLog(@"TGCall: sent our candidates, ufrag=%@", self.localUfrag);
}

- (void)handleSignalingData:(NSData *)data {
	if (!self.callKey.length || !data.length)
		return;

	NSMutableData *out = [NSMutableData dataWithLength:data.length];
	uint32_t seq = 0;
	int size = TGCallDecryptPacket((const uint8_t *)self.callKey.bytes,
								   self.outgoing, 1 ,
								   (const uint8_t *)data.bytes, data.length,
								   (uint8_t *)out.mutableBytes, &seq);
	if (size <= 0){
		NSLog(@"TGCall: signalling %lu bytes did not decrypt", (unsigned long)data.length);
		return;
	}
	out.length = size;

	for (NSDictionary *message in [TGCallMessages parsePacket:out seq:seq]){
		uint8_t type = [message[@"type"] unsignedCharValue];
		uint32_t messageSeq = [message[@"seq"] unsignedIntValue];

		if ([TGCallMessages seqRequiresAck:messageSeq])
			[self sendSignalling:[TGCallMessages ackForSeq:messageSeq]
							 seq:++self.signallingSeq];

		if (type == kCallMessageMediaState){
			NSDictionary *mediaState = [TGCallMessages parseMediaState:message[@"body"]];
			if (mediaState){
				NSLog(@"TGCall: peer media state audioMuted=%@ videoPaused=%@",
						mediaState[@"audioMuted"], mediaState[@"videoPaused"]);
				[[NSNotificationCenter defaultCenter]
						postNotificationName:TGCallPeerMediaStateDidChangeNotification
									  object:self
									userInfo:mediaState];
			} else {
				NSLog(@"TGCall: peer media state message malformed, %lu bytes",
						(unsigned long)[message[@"body"] length]);
			}
			continue;
		}

		if (type != kCallMessageCandidates){
			NSLog(@"TGCall: signalling message type %d, %lu bytes", type,
					(unsigned long)[message[@"body"] length]);
			continue;
		}
		NSDictionary *ice = [TGCallMessages parseCandidates:message[@"body"]];
		self.peerUfrag = ice[@"ufrag"];
		self.peerPwd = ice[@"pwd"];
		self.ice.peerUfrag = self.peerUfrag;
		self.ice.peerPwd = self.peerPwd;
		NSLog(@"TGCall: peer ICE ufrag=%@ pwd=%@", self.peerUfrag, self.peerPwd);
		for (NSString *candidate in ice[@"candidates"]){
			NSLog(@"TGCall: peer candidate: %@", candidate);
			[self readPeerTagFromCandidate:candidate];
			[self.ice addPeerCandidate:candidate];
		}
	}
}

- (void)readPeerTagFromCandidate:(NSString *)candidate {
	NSRange marker = [candidate rangeOfString:@"reflector-"];
	if (marker.location == NSNotFound)
		return;

	NSString *tail = [candidate substringFromIndex:marker.location + marker.length];
	NSArray *parts = [[tail componentsSeparatedByString:@".reflector"][0]
			componentsSeparatedByString:@"-"];
	if (parts.count < 2)
		return;

	NSInteger index = [parts[0] integerValue];
	if (index < 1 || index > (NSInteger)self.reflectors.count)
		return;

	TGCallReflector *reflector = self.reflectors[index - 1];
	if (reflector.remoteTag)
		return;

	uint32_t tag = (uint32_t)[parts[1] longLongValue];
	reflector.remoteTag = tag;
	NSLog(@"TGCall: peer reflector tag %u", tag);
}

- (void)sendSignalling:(NSData *)plaintext seq:(uint32_t)seq {
	if (!self.callKey.length)
		return;

	NSMutableData *encrypted = [NSMutableData dataWithLength:plaintext.length + 32];
	int size = TGCallEncryptPacket((const uint8_t *)self.callKey.bytes,
								   self.outgoing, 1 ,
								   (const uint8_t *)plaintext.bytes, plaintext.length,
								   seq,
								   (uint8_t *)encrypted.mutableBytes);
	if (size <= 0)
		return;
	encrypted.length = size;

	[[TGClient shared] sendSignalingData:TGBase64Encode(encrypted)
							   forCallId:self.callId];
}

- (void)callUser:(int64_t)userId video:(BOOL)video {
	self.peerUserId = userId;
	self.outgoing = YES;
	self.video = video;
	self.localVideoRequested = video;
	self.muted = NO;
	self.pendingHangup = NO;
	self.awaitingCallId = YES;
	self.cancelledCallId = 0;
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
							  connectionId:_controller ? _controller->GetPreferredRelayID() : 0];
	else if (self.awaitingCallId)
		self.pendingHangup = YES;
	[self teardown];
	self.state = TGCallStateEnded;
}

- (void)handleUpdate:(NSDictionary *)call {
	int32_t callId = [call[@"id"] intValue];
	NSDictionary *state = call[@"state"];
	NSString *kind = TGTDLibTypeOf(state);

	if (callId != 0 && callId == self.cancelledCallId){
		BOOL incomingIsTerminal = [kind isEqualToString:@"callStateDiscarded"] ||
				[kind isEqualToString:@"callStateHangingUp"] ||
				[kind isEqualToString:@"callStateError"];
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
			BOOL incomingIsTerminal = [kind isEqualToString:@"callStateDiscarded"] ||
					[kind isEqualToString:@"callStateHangingUp"] ||
					[kind isEqualToString:@"callStateError"];
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
		BOOL incomingIsTerminal = [kind isEqualToString:@"callStateDiscarded"] ||
				[kind isEqualToString:@"callStateHangingUp"] ||
				[kind isEqualToString:@"callStateError"];
		if (!incomingIsTerminal && callId != 0)
			[[TGClient shared] discardCallId:callId
									 duration:0
										video:[call[@"is_video"] boolValue]
								isDisconnected:NO
								  connectionId:0];
		return;
	}

	BOOL outgoing = [call[@"is_outgoing"] boolValue];
	if (!outgoing && callId != self.callId)
		self.muted = NO;
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
	if ([session respondsToSelector:@selector(setPreferredIOBufferDuration:error:)])
		[session setPreferredIOBufferDuration:0.005 error:nil];
	[session setActive:YES error:nil];
}

- (void)reactivateAudioSessionAfterInterruption {
	if (!_controller)
		return;
	[self activateCallAudioSession];
}

- (void)startMediaWithState:(NSDictionary *)state {
	if (_controller)
		return;

	NSArray *emojis = state[@"emojis"];
	self.verificationEmojis = [emojis isKindOfClass:NSArray.class] ? emojis : nil;

	TGInstallCrypto();
	self.state = TGCallStateConnecting;

	[self activateCallAudioSession];

	NSData *key = TGBase64Decode(state[@"encryption_key"]);
	if (key.length != 256){
		NSLog(@"TGCall: encryption key is %lu bytes, expected 256",
				(unsigned long)key.length);
		if (self.callId)
			[[TGClient shared] discardCallId:self.callId
									 duration:(NSInteger)[self duration]
										video:self.video
								isDisconnected:YES
								  connectionId:0];
		[self teardown];
		self.state = TGCallStateFailed;
		return;
	}

	self.callKey = key;
	[self probeReflectorsIn:state key:key];

	std::vector<Endpoint> endpoints;
	for (NSDictionary *server in state[@"servers"]){
		NSDictionary *type = server[@"type"];
		if (![TGTDLibTypeOf(type) isEqualToString:@"callServerTypeTelegramReflector"])
			continue;

		NSData *peerTag = TGBase64Decode(type[@"peer_tag"]);
		unsigned char tag[16] = {0};
		if (peerTag.length >= 16)
			memcpy(tag, peerTag.bytes, 16);

		IPv4Address v4([server[@"ip_address"] UTF8String] ?: "");
		IPv6Address v6([server[@"ipv6_address"] UTF8String] ?: "");
		endpoints.push_back(Endpoint([server[@"id"] longLongValue],
									 (uint16_t)[server[@"port"] intValue],
									 v4, v6, Endpoint::Type::UDP_RELAY, tag));
	}

	if (endpoints.empty()){
		NSLog(@"TGCall: no reflector this build can use");
		if (self.callId)
			[[TGClient shared] discardCallId:self.callId
									 duration:(NSInteger)[self duration]
										video:self.video
								isDisconnected:YES
								  connectionId:0];
		[self teardown];
		self.state = TGCallStateFailed;
		return;
	}

	_controller = new VoIPController();

	VoIPController::Config config(30.0, 20.0, DATA_SAVING_NEVER,
								  false , false , false ,
								  false );
	config.enableVideoSend = self.video && self.localVideoRequested;
	config.enableVideoReceive = self.video;
	_controller->SetConfig(config);
	_controller->SetEncryptionKey((char *)key.bytes, self.outgoing);
	_controller->SetRemoteEndpoints(endpoints,
									[state[@"allow_p2p"] boolValue],
									[state[@"protocol"][@"max_layer"] intValue] ?: 65);

	VoIPController::Callbacks callbacks = {0};
	callbacks.connectionStateChanged = [](VoIPController *controller, int newState){
		dispatch_async(dispatch_get_main_queue(), ^{
			TGCall *call = [TGCall shared];
			switch (newState){
				case STATE_ESTABLISHED:
					call.state = TGCallStateEstablished;
					if (call.video)
						[call setUpVideoPipelineIfNeeded];
					break;
				case STATE_FAILED:
					if (call.callId)
						[[TGClient shared] discardCallId:call.callId
												 duration:(NSInteger)[call duration]
													video:call.video
											isDisconnected:YES
											  connectionId:controller->GetPreferredRelayID()];
					[call teardown];
					call.state = TGCallStateFailed;
					break;
				case STATE_RECONNECTING: call.state = TGCallStateConnecting; break;
				default: break;
			}
		});
	};
	_controller->SetCallbacks(callbacks);
	_controller->SetMicMute(self.muted);

	_controller->Start();
	_controller->Connect();
}

#pragma mark - video

- (void)setUpVideoPipelineIfNeeded {
	if (self.videoPipelineSetUp)
		return;
	self.videoPipelineSetUp = YES;

	_videoSource = new tgvoip::video::TGCallVideoSource();
	_videoRenderer = new tgvoip::video::TGCallVideoRenderer();

	__weak __typeof__(self) weakSelf = self;
	_videoRenderer->frameCallback = [weakSelf](const uint8_t* bgra, unsigned int width, unsigned int height, int stride){
		TGCall *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf.remoteVideoView presentBGRABytes:bgra width:(int)width height:(int)height bytesPerRow:stride];
		strongSelf.remoteVideoLastFrameAt = [NSDate timeIntervalSinceReferenceDate];
		if (!strongSelf.remoteVideoActive){
			dispatch_async(dispatch_get_main_queue(), ^{
				TGCall *innerSelf = weakSelf;
				if (!innerSelf || innerSelf.remoteVideoActive)
					return;
				innerSelf.remoteVideoActive = YES;
				[[NSNotificationCenter defaultCenter]
						postNotificationName:TGCallVideoStateDidChangeNotification object:innerSelf];
			});
		}
	};

	self.remoteVideoWatchdog = [NSTimer scheduledTimerWithTimeInterval:1.0
																 target:self
															   selector:@selector(checkRemoteVideoStillArriving)
															   userInfo:nil
																repeats:YES];

	_controller->SetVideoSource(_videoSource);
	_controller->SetVideoRenderer(_videoRenderer);

	if (self.localVideoRequested)
		[self startLocalCaptureIfNeeded];
}

- (void)startLocalCaptureIfNeeded {
	if (self.videoCapture)
		return;
	if (_videoSource && _videoSource->Failed()){
		NSLog(@"TGCall: outgoing video encoder failed to open (%s), continuing audio-only outbound",
				_videoSource->GetErrorDescription().c_str());
		[[NSNotificationCenter defaultCenter] postNotificationName:TGCallVideoStateDidChangeNotification object:self];
		return;
	}
	if (![TGVideoCapture isCameraAvailable]){
		NSLog(@"TGCall: no camera available, video call continues audio-only outbound");
		[[NSNotificationCenter defaultCenter] postNotificationName:TGCallVideoStateDidChangeNotification object:self];
		return;
	}

	TGVideoCapture *capture = [[TGVideoCapture alloc] init];
	tgvoip::video::TGCallVideoSource* videoSource = _videoSource;
	capture.onPixelBuffer = ^(CVPixelBufferRef pixelBuffer, int64_t presentationTimeUs){
		if (videoSource)
			videoSource->PushPixelBuffer(pixelBuffer, presentationTimeUs);
	};

	if (![capture start]){
		NSLog(@"TGCall: camera capture failed to start");
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
	} else if (self.videoCapture){
		[self.videoCapture setPaused:YES];
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

- (void)checkRemoteVideoStillArriving {
	if (!self.remoteVideoActive)
		return;
	NSTimeInterval sinceLastFrame = [NSDate timeIntervalSinceReferenceDate] - self.remoteVideoLastFrameAt;
	if (sinceLastFrame < 3.0)
		return;
	self.remoteVideoActive = NO;
	[[NSNotificationCenter defaultCenter] postNotificationName:TGCallVideoStateDidChangeNotification object:self];
}

- (void)tearDownVideoPipeline {
	[self.remoteVideoWatchdog invalidate];
	self.remoteVideoWatchdog = nil;
	[self.videoCapture stop];
	self.videoCapture = nil;
	[self.remoteVideoView removeFromSuperview];
	self.remoteVideoView = nil;
	self.localPreviewContainer = nil;
	self.remoteVideoContainer = nil;
	self.localVideoActive = NO;
	self.remoteVideoActive = NO;
	if (_videoRenderer){
		delete _videoRenderer;
		_videoRenderer = nullptr;
	}
	if (_videoSource){
		delete _videoSource;
		_videoSource = nullptr;
	}
	self.videoPipelineSetUp = NO;
	self.localVideoRequested = NO;
}

- (void)probeReflectorsIn:(NSDictionary *)state key:(NSData *)key {
	self.reflectors = [NSMutableArray array];
	__weak __typeof__(self) weakSelf = self;

	NSInteger index = 0;
	for (NSDictionary *server in state[@"servers"]){
		NSDictionary *type = server[@"type"];
		if (![TGTDLibTypeOf(type) isEqualToString:@"callServerTypeTelegramReflector"])
			continue;

		NSData *peerTag = TGBase64Decode(type[@"peer_tag"]);
		TGCallReflector *reflector = [[TGCallReflector alloc]
				initWithHost:server[@"ip_address"]
						port:(uint16_t)[server[@"port"] intValue]
					 peerTag:peerTag];
		__weak TGCallReflector *weakReflector = reflector;
		reflector.onPacket = ^(NSData *packet){
			weakSelf.currentReflector = weakReflector;
			[weakSelf inspectReflectorPacket:packet];
		};
		[reflector start];
		[self.reflectors addObject:reflector];

		NSLog(@"TGCall: reflector %ld at %@:%d, our tag %u", (long)++index,
				server[@"ip_address"], [server[@"port"] intValue], reflector.localTag);

		if (!self.reflector){
			self.reflector = reflector;
			self.reflectorHost = server[@"ip_address"];
		}
	}
	[self sendOurCandidates];
}

- (void)inspectReflectorPacket:(NSData *)packet {
	const uint8_t *bytes = (const uint8_t *)packet.bytes;
	if (packet.length < 4){
		NSLog(@"TGCall: %lu-byte reflector packet", (unsigned long)packet.length);
		return;
	}
	if (packet.length <= 32){
		NSLog(@"TGCall: reflector service packet, %lu bytes, first %02x%02x%02x%02x",
				(unsigned long)packet.length, bytes[0], bytes[1], bytes[2], bytes[3]);
		return;
	}

	static const size_t offsets[] = { 24, 16, 20, 0 };
	for (unsigned i = 0; i < sizeof(offsets) / sizeof(offsets[0]); i++){
		size_t offset = offsets[i];
		if (packet.length <= offset + 20)
			continue;
		NSData *payload = [packet subdataWithRange:
				NSMakeRange(offset, packet.length - offset)];
		if ([TGCallStun messageTypeOf:payload] < 0)
			continue;

		const uint8_t *raw = (const uint8_t *)packet.bytes;
		if (offset >= 24)
			memcpy(&_currentSenderTag, raw + 16, 4);
		if (offset >= 24)
			NSLog(@"hdr %02x%02x%02x%02x|%02x%02x%02x%02x|%02x%02x%02x%02x ours %08x",
					raw[12], raw[13], raw[14], raw[15],
					raw[16], raw[17], raw[18], raw[19],
					raw[20], raw[21], raw[22], raw[23],
					self.reflector.localTag);
		[self.ice handleRelayedPacket:payload];
		return;
	}

	if (packet.length > 32)
		NSLog(@"TGCall: %lu bytes from the reflector, not STUN",
				(unsigned long)packet.length);
}

- (void)setMuted:(BOOL)muted {
	_muted = muted;
	if (_controller)
		_controller->SetMicMute(muted);
}

- (void)teardown {
	self.sentCandidates = NO;
	self.callKey = nil;
	self.signallingSeq = 0;
	self.currentSenderTag = 0;
	self.currentReflector = nil;
	self.peerUfrag = nil;
	self.peerPwd = nil;
	self.localUfrag = nil;
	self.localPwd = nil;
	self.reflectorHost = nil;
	[self.ice stop];
	self.ice = nil;
	for (TGCallReflector *reflector in self.reflectors)
		[reflector stop];
	self.reflectors = nil;
	self.reflector = nil;
	if (_controller){
		_controller->Stop();
		delete _controller;
		_controller = NULL;
	}
	[self tearDownVideoPipeline];
	self.establishedAt = nil;
	self.callId = 0;
	AVAudioSession *session = [TGAVClass(AVAudioSession) sharedInstance];
	if ([session respondsToSelector:@selector(setPreferredIOBufferDuration:error:)])
		[session setPreferredIOBufferDuration:0.0 error:nil];
	[session setActive:NO error:nil];
}

@end


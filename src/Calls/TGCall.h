#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern NSString *const TGCallStateDidChangeNotification;
extern NSString *const TGCallVideoStateDidChangeNotification;
extern NSString *const TGCallPeerMediaStateDidChangeNotification;

typedef NS_ENUM(NSInteger, TGCallState) {
	TGCallStateNone = 0,
	TGCallStatePending,
	TGCallStateExchangingKeys,
	TGCallStateConnecting,
	TGCallStateEstablished,
	TGCallStateEnded,
	TGCallStateFailed
};

@interface TGCall : NSObject

+ (instancetype)shared;

+ (BOOL)canSendVideo;

@property (nonatomic, readonly) TGCallState state;
@property (nonatomic, readonly) int32_t callId;
@property (nonatomic, readonly) int64_t peerUserId;
@property (nonatomic, readonly) BOOL outgoing;
@property (nonatomic, readonly) BOOL muted;
@property (nonatomic, readonly) BOOL video;

@property (nonatomic, readonly) BOOL localVideoActive;
@property (nonatomic, readonly) BOOL remoteVideoActive;
@property (nonatomic, readonly) BOOL canSwitchCamera;
@property (nonatomic, readonly) BOOL frontCamera;

@property (nonatomic, readonly) NSString *endReason;
@property (nonatomic, readonly, copy) NSArray *verificationEmojis;

@property (nonatomic, copy) void (^onStateChanged)(TGCallState state);

- (void)callUser:(int64_t)userId video:(BOOL)video;
- (void)accept;
- (void)hangUp;
- (void)setMuted:(BOOL)muted;

- (void)attachLocalPreviewToView:(UIView *)containerView;
- (void)attachRemoteVideoToView:(UIView *)containerView;
- (void)detachVideoViews;
- (void)setLocalVideoEnabled:(BOOL)enabled;
- (void)switchCamera;

- (void)handleSignalingData:(NSData *)data;

- (void)handleUpdate:(NSDictionary *)call;

- (void)reactivateAudioSessionAfterInterruption;

- (NSTimeInterval)duration;

@end

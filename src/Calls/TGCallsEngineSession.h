#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

typedef NS_ENUM(NSInteger, TGCallsEngineState) {
	TGCallsEngineStateConnecting = 0,
	TGCallsEngineStateEstablished,
	TGCallsEngineStateReconnecting,
	TGCallsEngineStateFailed
};

@protocol TGCallsEngineSession <NSObject>

+ (NSArray *)libraryVersions;
+ (int32_t)maxLayer;

- (instancetype)initWithVersion:(NSString *)version
				  encryptionKey:(NSData *)encryptionKey
					   outgoing:(BOOL)outgoing
					   allowP2P:(BOOL)allowP2P
					 rtcServers:(NSArray *)rtcServers
			   customParameters:(NSString *)customParameters;

@property (nonatomic, copy) void (^onStateChanged)(TGCallsEngineState state);
@property (nonatomic, copy) void (^onSignalingData)(NSData *data);
@property (nonatomic, copy) void (^onRemoteMediaChanged)(BOOL audioMuted, BOOL videoActive);
@property (nonatomic, copy) void (^onRemoteVideoFrame)(const uint8_t *bgra, int width, int height, int bytesPerRow);

- (void)start;
- (void)receiveSignalingData:(NSData *)data;
- (void)setMuted:(BOOL)muted;
- (void)setAudioSessionActive:(BOOL)active;
- (void)setCameraEnabled:(BOOL)enabled;
- (void)pushCameraPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (int64_t)preferredRelayId;
- (void)stop;

@end

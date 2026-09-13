#import <Foundation/Foundation.h>

@interface TGCallReflector : NSObject

- (instancetype)initWithHost:(NSString *)host port:(uint16_t)port
					 peerTag:(NSData *)peerTag;

@property (nonatomic, readonly) uint32_t localTag;

@property (nonatomic, assign) uint32_t remoteTag;
@property (nonatomic, readonly) uint16_t port;

@property (nonatomic, copy) void (^onPacket)(NSData *payload);

- (BOOL)start;
- (void)stop;
- (void)sendPayload:(NSData *)payload;

- (void)sendPayload:(NSData *)payload toTag:(uint32_t)tag;

@end

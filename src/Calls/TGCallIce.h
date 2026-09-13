#import <Foundation/Foundation.h>

@interface TGCallIce : NSObject

@property (nonatomic, strong) NSString *localUfrag;
@property (nonatomic, strong) NSString *localPwd;
@property (nonatomic, strong) NSString *peerUfrag;
@property (nonatomic, strong) NSString *peerPwd;

@property (nonatomic, copy) void (^onConnected)(NSString *address, uint16_t port);

@property (nonatomic, copy) void (^onMedia)(NSData *packet);

@property (nonatomic, copy) void (^transport)(NSData *packet);

- (BOOL)start;
- (void)stop;

@property (nonatomic, strong) NSData *peerAddress;

- (void)addPeerCandidate:(NSString *)candidate;

- (void)handleRelayedPacket:(NSData *)packet;

@end

#import <Foundation/Foundation.h>

extern const uint8_t kCallMessageCandidates;
extern const uint8_t kCallMessageMediaState;
extern const uint8_t kCallMessageAudioData;

@interface TGCallMessages : NSObject

+ (NSArray *)parsePacket:(NSData *)plaintext seq:(uint32_t)packetSeq;

+ (NSData *)ackForSeq:(uint32_t)seq;

+ (BOOL)seqRequiresAck:(uint32_t)seq;

+ (NSDictionary *)parseCandidates:(NSData *)body;

+ (NSDictionary *)parseMediaState:(NSData *)body;

+ (NSData *)messageWithType:(uint8_t)type body:(NSData *)body;

+ (uint32_t)markSeq:(uint32_t)seq requiresAck:(BOOL)requiresAck;

+ (NSData *)candidatesBody:(NSArray *)candidates ufrag:(NSString *)ufrag pwd:(NSString *)pwd;

@end

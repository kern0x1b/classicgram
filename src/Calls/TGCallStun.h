#ifndef TG_CALL_STUN_H
#define TG_CALL_STUN_H

#import <Foundation/Foundation.h>

@interface TGCallStun : NSObject

+ (NSData *)bindingRequestWithUsername:(NSString *)username
							  password:(NSString *)password
							tieBreaker:(uint64_t)tieBreaker
						  useCandidate:(BOOL)useCandidate;

+ (NSData *)bindingResponseTo:(NSData *)request
					 password:(NSString *)password
				  fromAddress:(NSData *)address;

+ (int)messageTypeOf:(NSData *)packet;

@end

#endif

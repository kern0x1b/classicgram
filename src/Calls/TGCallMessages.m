#import "TGCallMessages.h"

const uint8_t kCallMessageCandidates = 1;
const uint8_t kCallMessageMediaState = 4;
const uint8_t kCallMessageAudioData = 5;

static const uint8_t kEmptyId = 0xFE;
static const uint8_t kAckId = 0xFF;

static uint32_t TGReadU32(const uint8_t *bytes) {
	return ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) |
		((uint32_t)bytes[2] << 8) | (uint32_t)bytes[3];
}

static void TGAppendU32(NSMutableData *data, uint32_t value) {
	uint8_t bytes[4] = {
		(uint8_t)(value >> 24), (uint8_t)(value >> 16),
		(uint8_t)(value >> 8), (uint8_t)value};
	[data appendBytes:bytes length:4];
}

static void TGAppendString(NSMutableData *data, NSString *string) {
	NSData *utf8 = [string dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
	TGAppendU32(data, (uint32_t)utf8.length);
	[data appendData:utf8];
}

@implementation TGCallMessages

+ (NSArray *)parsePacket:(NSData *)plaintext seq:(uint32_t)packetSeq {
	const uint8_t *bytes = (const uint8_t *)plaintext.bytes;
	NSInteger length = plaintext.length;
	NSInteger at = 0;
	NSMutableArray *messages = [NSMutableArray array];
	uint32_t currentSeq = packetSeq;

	while (at < length) {
		uint8_t type = bytes[at];

		if (type == kEmptyId || type == kAckId) {
			at += 1;
		} else {
			[messages addObject:@{
				@"type" : @(type),
				@"seq" : @(currentSeq),
				@"body" : [plaintext subdataWithRange:
						NSMakeRange(at + 1, length - at - 1)],
			}];
			return messages;
		}

		if (at + 4 > length)
			break;
		currentSeq = TGReadU32(bytes + at);
		at += 4;
	}
	return messages;
}

+ (NSData *)messageWithType:(uint8_t)type body:(NSData *)body {
	NSMutableData *packet = [NSMutableData data];
	[packet appendBytes:&type length:1];
	[packet appendData:body];
	return packet;
}

+ (BOOL)seqRequiresAck:(uint32_t)seq {
	return (seq & ((uint32_t)1 << 30)) != 0;
}

+ (NSData *)ackForSeq:(uint32_t)seq {
	NSMutableData *packet = [NSMutableData data];
	uint8_t empty = kEmptyId, ack = kAckId;
	[packet appendBytes:&empty length:1];
	TGAppendU32(packet, seq);
	[packet appendBytes:&ack length:1];
	return packet;
}

+ (uint32_t)markSeq:(uint32_t)seq requiresAck:(BOOL)requiresAck {
	return requiresAck ? (seq | ((uint32_t)1 << 30))
					   : (seq | ((uint32_t)1 << 31));
}

+ (NSData *)candidatesBody:(NSArray *)candidates ufrag:(NSString *)ufrag pwd:(NSString *)pwd {
	NSMutableData *body = [NSMutableData data];
	uint8_t count = (uint8_t)candidates.count;
	[body appendBytes:&count length:1];
	for (NSString *candidate in candidates)
		TGAppendString(body, candidate);
	TGAppendString(body, ufrag);
	TGAppendString(body, pwd);
	return body;
}

+ (NSDictionary *)parseCandidates:(NSData *)body {
	const uint8_t *bytes = (const uint8_t *)body.bytes;
	NSInteger length = body.length;
	NSInteger at = 0;

	if (length < 1)
		return nil;
	uint8_t count = bytes[at++];

	NSMutableArray *candidates = [NSMutableArray array];
	for (uint8_t i = 0; i < count; i++) {
		if (length < 4 || at > length - 4)
			return nil;
		uint32_t size = TGReadU32(bytes + at);
		at += 4;
		if (size > length - at)
			return nil;
		NSString *candidate = [[NSString alloc]
			initWithBytes:bytes + at
				   length:size
				 encoding:NSUTF8StringEncoding];
		if (candidate)
			[candidates addObject:candidate];
		at += size;
	}

	NSString *ufrag = nil, *pwd = nil;
	for (NSInteger i = 0; i < 2; i++) {
		if (length < 4 || at > length - 4)
			break;
		uint32_t size = TGReadU32(bytes + at);
		at += 4;
		if (size > length - at)
			break;
		NSString *value = [[NSString alloc]
			initWithBytes:bytes + at
				   length:size
				 encoding:NSUTF8StringEncoding];
		at += size;
		if (i == 0)
			ufrag = value;
		else
			pwd = value;
	}

	return @{
		@"candidates" : candidates,
		@"ufrag" : ufrag ?: @"",
		@"pwd" : pwd ?: @"",
	};
}

+ (NSDictionary *)parseMediaState:(NSData *)body {
	if (body.length < 1)
		return nil;

	uint8_t state = ((const uint8_t *)body.bytes)[0];
	uint8_t audioState = state & 0x01;
	uint8_t videoState = (state >> 1) & 0x03;
	if (videoState == 0x03)
		return nil;

	return @{
		@"audioMuted" : @(audioState == 0),
		@"videoPaused" : @(videoState != 0x02),
	};
}

@end

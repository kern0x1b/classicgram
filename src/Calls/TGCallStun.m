#import "TGCallStun.h"

#include <openssl/hmac.h>
#include <zlib.h>
#include <netinet/in.h>

static const uint32_t kMagicCookie = 0x2112A442;

static const uint16_t kAttrUsername = 0x0006;
static const uint16_t kAttrMessageInteg = 0x0008;
static const uint16_t kAttrXorMappedAddr = 0x0020;
static const uint16_t kAttrPriority = 0x0024;
static const uint16_t kAttrUseCandidate = 0x0025;
static const uint16_t kAttrIceControlling = 0x802A;
static const uint16_t kAttrFingerprint = 0x8028;

static void TGAppend16(NSMutableData *data, uint16_t value) {
	uint8_t bytes[2] = {(uint8_t)(value >> 8), (uint8_t)value};
	[data appendBytes:bytes length:2];
}

static void TGAppend32(NSMutableData *data, uint32_t value) {
	uint8_t bytes[4] = {(uint8_t)(value >> 24), (uint8_t)(value >> 16),
		(uint8_t)(value >> 8), (uint8_t)value};
	[data appendBytes:bytes length:4];
}

static void TGAppendAttribute(NSMutableData *data, uint16_t type, NSData *value) {
	TGAppend16(data, type);
	TGAppend16(data, (uint16_t)value.length);
	[data appendData:value];
	while (data.length % 4)
		[data appendBytes:"\0" length:1];
}

static void TGSetLength(NSMutableData *data, NSUInteger extra) {
	uint16_t length = (uint16_t)(data.length - 20 + extra);
	uint8_t *bytes = (uint8_t *)data.mutableBytes;
	bytes[2] = (uint8_t)(length >> 8);
	bytes[3] = (uint8_t)length;
}

static void TGAppendIntegrityAndFingerprint(NSMutableData *message, NSString *password) {
	TGSetLength(message, 24);
	NSData *key = [password dataUsingEncoding:NSUTF8StringEncoding];
	uint8_t digest[20];
	unsigned int digestLength = sizeof(digest);
	HMAC(EVP_sha1(), key.bytes, (int)key.length,
		message.bytes, message.length, digest, &digestLength);
	TGAppendAttribute(message, kAttrMessageInteg, [NSData dataWithBytes:digest length:20]);

	TGSetLength(message, 8);
	uLong crc = crc32(0L, Z_NULL, 0);
	crc = crc32(crc, message.bytes, (uInt)message.length);
	NSMutableData *value = [NSMutableData data];
	TGAppend32(value, (uint32_t)crc ^ 0x5354554e);
	TGAppendAttribute(message, kAttrFingerprint, value);
	TGSetLength(message, 0);
}

@implementation TGCallStun

+ (int)messageTypeOf:(NSData *)packet {
	if (packet.length < 20)
		return -1;
	const uint8_t *bytes = (const uint8_t *)packet.bytes;

	if ((bytes[0] & 0xC0) != 0)
		return -1;
	uint32_t cookie = ((uint32_t)bytes[4] << 24) | ((uint32_t)bytes[5] << 16) |
		((uint32_t)bytes[6] << 8) | bytes[7];
	if (cookie != kMagicCookie)
		return -1;
	return (bytes[0] << 8) | bytes[1];
}

+ (NSData *)bindingRequestWithUsername:(NSString *)username
							  password:(NSString *)password
							tieBreaker:(uint64_t)tieBreaker
						  useCandidate:(BOOL)useCandidate {
	NSMutableData *message = [NSMutableData data];
	TGAppend16(message, 0x0001);
	TGAppend16(message, 0);
	TGAppend32(message, kMagicCookie);
	uint8_t transaction[12];
	arc4random_buf(transaction, sizeof(transaction));
	[message appendBytes:transaction length:sizeof(transaction)];

	TGAppendAttribute(message, kAttrUsername,
		[username dataUsingEncoding:NSUTF8StringEncoding]);

	NSMutableData *priority = [NSMutableData data];
	TGAppend32(priority, 1853817087);
	TGAppendAttribute(message, kAttrPriority, priority);

	NSMutableData *tie = [NSMutableData data];
	TGAppend32(tie, (uint32_t)(tieBreaker >> 32));
	TGAppend32(tie, (uint32_t)tieBreaker);
	TGAppendAttribute(message, kAttrIceControlling, tie);

	if (useCandidate)
		TGAppendAttribute(message, kAttrUseCandidate, [NSData data]);

	TGAppendIntegrityAndFingerprint(message, password);
	return message;
}

+ (NSData *)bindingResponseTo:(NSData *)request
					 password:(NSString *)password
				  fromAddress:(NSData *)address {
	if (request.length < 20)
		return nil;

	NSMutableData *message = [NSMutableData data];
	TGAppend16(message, 0x0101);
	TGAppend16(message, 0);
	TGAppend32(message, kMagicCookie);

	[message appendBytes:((const uint8_t *)request.bytes) + 8 length:12];

	struct sockaddr_in unspecified;
	memset(&unspecified, 0, sizeof(unspecified));
	unspecified.sin_family = AF_INET;
	const struct sockaddr_in *from = address.length >= sizeof(struct sockaddr_in)
		? (const struct sockaddr_in *)address.bytes
		: &unspecified;
	NSMutableData *mapped = [NSMutableData data];
	uint8_t header[2] = {0, 1};
	[mapped appendBytes:header length:2];
	TGAppend16(mapped, ntohs(from->sin_port) ^ (uint16_t)(kMagicCookie >> 16));
	TGAppend32(mapped, ntohl(from->sin_addr.s_addr) ^ kMagicCookie);
	TGAppendAttribute(message, kAttrXorMappedAddr, mapped);

	TGAppendIntegrityAndFingerprint(message, password);
	return message;
}

@end

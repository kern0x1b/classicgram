#import "tg_call_stun_tests.h"
#import "TGCallStun.h"
#import <Foundation/Foundation.h>
#include <openssl/hmac.h>
#include <zlib.h>
#include <netinet/in.h>

static const uint32_t kTestMagicCookie = 0x2112A442;
static const uint16_t kTestAttrUsername = 0x0006;
static const uint16_t kTestAttrMessageIntegrity = 0x0008;
static const uint16_t kTestAttrXorMappedAddress = 0x0020;
static const uint16_t kTestAttrPriority = 0x0024;
static const uint16_t kTestAttrUseCandidate = 0x0025;
static const uint16_t kTestAttrIceControlling = 0x802A;
static const uint16_t kTestAttrFingerprint = 0x8028;

typedef struct {
	NSData *value;
	NSUInteger offset;
} TGTestStunAttribute;

static BOOL TGTestFindStunAttribute(NSData *message, uint16_t wantedType, TGTestStunAttribute *outAttribute) {
	const uint8_t *bytes = message.bytes;
	NSUInteger length = message.length;
	NSUInteger at = 20;

	while (at + 4 <= length) {
		uint16_t attributeType = (uint16_t)((bytes[at] << 8) | bytes[at + 1]);
		uint16_t attributeLength = (uint16_t)((bytes[at + 2] << 8) | bytes[at + 3]);
		NSUInteger valueStart = at + 4;
		if (valueStart + attributeLength > length)
			return NO;

		if (attributeType == wantedType) {
			outAttribute->value = [message subdataWithRange:NSMakeRange(valueStart, attributeLength)];
			outAttribute->offset = at;
			return YES;
		}

		NSUInteger paddedLength = attributeLength;
		while (paddedLength % 4)
			paddedLength++;
		at = valueStart + paddedLength;
	}
	return NO;
}

static uint32_t TGTestReadU32BigEndian(const uint8_t *bytes) {
	return ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) |
		((uint32_t)bytes[2] << 8) | (uint32_t)bytes[3];
}

static uint16_t TGTestReadU16BigEndian(const uint8_t *bytes) {
	return (uint16_t)((bytes[0] << 8) | bytes[1]);
}

static void TGTestPatchHeaderLength(NSMutableData *prefix, NSUInteger extraAttributeBytes) {
	uint16_t patchedLength = (uint16_t)(prefix.length - 20 + extraAttributeBytes);
	uint8_t *bytes = prefix.mutableBytes;
	bytes[2] = (uint8_t)(patchedLength >> 8);
	bytes[3] = (uint8_t)patchedLength;
}

static NSData *TGTestExpectedMessageIntegrity(NSData *message, NSUInteger integrityAttributeOffset, NSString *password) {
	NSMutableData *prefix = [[message subdataWithRange:NSMakeRange(0, integrityAttributeOffset)] mutableCopy];
	TGTestPatchHeaderLength(prefix, 24);

	NSData *key = [password dataUsingEncoding:NSUTF8StringEncoding];
	uint8_t digest[20];
	unsigned int digestLength = sizeof(digest);
	HMAC(EVP_sha1(), key.bytes, (int)key.length, prefix.bytes, prefix.length, digest, &digestLength);
	return [NSData dataWithBytes:digest length:digestLength];
}

static uint32_t TGTestExpectedFingerprint(NSData *message, NSUInteger fingerprintAttributeOffset) {
	NSMutableData *prefix = [[message subdataWithRange:NSMakeRange(0, fingerprintAttributeOffset)] mutableCopy];
	TGTestPatchHeaderLength(prefix, 8);

	uLong crc = crc32(0L, Z_NULL, 0);
	crc = crc32(crc, prefix.bytes, (uInt)prefix.length);
	return (uint32_t)crc ^ 0x5354554e;
}

static NSData *TGTestSockAddrIn(in_port_t port, uint32_t hostOrderAddress) {
	struct sockaddr_in address;
	memset(&address, 0, sizeof(address));
	address.sin_family = AF_INET;
	address.sin_port = htons(port);
	address.sin_addr.s_addr = htonl(hostOrderAddress);
	return [NSData dataWithBytes:&address length:sizeof(address)];
}

TGTestOutcome TGCallStunTestMessageTypeOfValidBindingRequest(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *request = [TGCallStun bindingRequestWithUsername:@"user" password:@"pass" tieBreaker:1 useCandidate:NO];

	TGTestExpectEqualInteger(&outcome, [TGCallStun messageTypeOf:request], 0x0001,
			"a binding request must report STUN type 0x0001");

	return outcome;
}

TGTestOutcome TGCallStunTestMessageTypeOfValidBindingResponse(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *request = [TGCallStun bindingRequestWithUsername:@"user" password:@"pass" tieBreaker:1 useCandidate:NO];
	NSData *response = [TGCallStun bindingResponseTo:request password:@"pass" fromAddress:[NSData data]];

	TGTestExpectEqualInteger(&outcome, [TGCallStun messageTypeOf:response], 0x0101,
			"a binding response must report STUN type 0x0101");

	return outcome;
}

TGTestOutcome TGCallStunTestMessageTypeOfRejectsBadMagicCookie(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[20];
	memset(raw, 0, sizeof(raw));
	NSData *packet = [NSData dataWithBytes:raw length:sizeof(raw)];

	TGTestExpectEqualInteger(&outcome, [TGCallStun messageTypeOf:packet], -1,
			"a packet without the STUN magic cookie must be rejected");

	return outcome;
}

TGTestOutcome TGCallStunTestMessageTypeOfRejectsTooShortPacket(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[10];
	memset(raw, 0, sizeof(raw));
	NSData *packet = [NSData dataWithBytes:raw length:sizeof(raw)];

	TGTestExpectEqualInteger(&outcome, [TGCallStun messageTypeOf:packet], -1,
			"a packet shorter than the 20-byte STUN header must be rejected, not read out of bounds");

	return outcome;
}

TGTestOutcome TGCallStunTestMessageTypeOfRejectsReservedClassBits(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *request = [TGCallStun bindingRequestWithUsername:@"user" password:@"pass" tieBreaker:1 useCandidate:NO];
	NSMutableData *malformed = [request mutableCopy];
	uint8_t *bytes = malformed.mutableBytes;
	bytes[0] |= 0xC0;

	TGTestExpectEqualInteger(&outcome, [TGCallStun messageTypeOf:malformed], -1,
			"the top two reserved bits of a STUN message being set must be rejected");

	return outcome;
}

TGTestOutcome TGCallStunTestBindingRequestHeaderAndCookie(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *request = [TGCallStun bindingRequestWithUsername:@"user" password:@"pass" tieBreaker:1 useCandidate:NO];
	const uint8_t *bytes = request.bytes;

	TGTestExpectTrue(&outcome, request.length >= 20, "a binding request must be at least the header length");
	TGTestExpectEqualLongLong(&outcome, TGTestReadU16BigEndian(bytes), 0x0001, "the message type must be binding request");
	TGTestExpectEqualLongLong(&outcome, TGTestReadU32BigEndian(bytes + 4), kTestMagicCookie,
			"bytes 4-7 must be the fixed STUN magic cookie");

	return outcome;
}

TGTestOutcome TGCallStunTestBindingRequestPriorityAttributeIsFixedValue(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *request = [TGCallStun bindingRequestWithUsername:@"user" password:@"pass" tieBreaker:1 useCandidate:NO];
	TGTestStunAttribute priority;
	BOOL found = TGTestFindStunAttribute(request, kTestAttrPriority, &priority);

	TGTestExpectTrue(&outcome, found, "the priority attribute must be present");
	if (found) {
		TGTestExpectEqualInteger(&outcome, priority.value.length, 4, "the priority attribute value must be 4 bytes");
		TGTestExpectEqualLongLong(&outcome, TGTestReadU32BigEndian(priority.value.bytes), 1853817087,
				"the priority attribute must carry the fixed priority value");
	}

	return outcome;
}

TGTestOutcome TGCallStunTestBindingRequestIceControllingEncodesTieBreaker(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint64_t tieBreaker = 0x0102030405060708ULL;
	NSData *request = [TGCallStun bindingRequestWithUsername:@"user" password:@"pass" tieBreaker:tieBreaker useCandidate:NO];
	TGTestStunAttribute iceControlling;
	BOOL found = TGTestFindStunAttribute(request, kTestAttrIceControlling, &iceControlling);

	TGTestExpectTrue(&outcome, found, "the ice-controlling attribute must be present");
	if (found) {
		TGTestExpectEqualInteger(&outcome, iceControlling.value.length, 8, "the ice-controlling attribute value must be 8 bytes");
		const uint8_t *bytes = iceControlling.value.bytes;
		uint64_t decoded = ((uint64_t)TGTestReadU32BigEndian(bytes) << 32) | TGTestReadU32BigEndian(bytes + 4);
		TGTestExpectEqualLongLong(&outcome, decoded, tieBreaker, "the tie breaker must round-trip as two big-endian halves");
	}

	return outcome;
}

TGTestOutcome TGCallStunTestBindingRequestUseCandidateAttributePresentWhenRequested(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *request = [TGCallStun bindingRequestWithUsername:@"user" password:@"pass" tieBreaker:1 useCandidate:YES];
	TGTestStunAttribute useCandidate;
	BOOL found = TGTestFindStunAttribute(request, kTestAttrUseCandidate, &useCandidate);

	TGTestExpectTrue(&outcome, found, "requesting useCandidate:YES must include the use-candidate attribute");
	if (found)
		TGTestExpectEqualInteger(&outcome, useCandidate.value.length, 0, "the use-candidate attribute must carry no value");

	return outcome;
}

TGTestOutcome TGCallStunTestBindingRequestUseCandidateAttributeAbsentWhenNotRequested(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *request = [TGCallStun bindingRequestWithUsername:@"user" password:@"pass" tieBreaker:1 useCandidate:NO];
	TGTestStunAttribute useCandidate;
	BOOL found = TGTestFindStunAttribute(request, kTestAttrUseCandidate, &useCandidate);

	TGTestExpectTrue(&outcome, !found, "requesting useCandidate:NO must omit the use-candidate attribute");

	return outcome;
}

TGTestOutcome TGCallStunTestBindingRequestUsernameAttributeMatchesInput(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *request = [TGCallStun bindingRequestWithUsername:@"userfrag" password:@"pass" tieBreaker:1 useCandidate:NO];
	TGTestStunAttribute username;
	BOOL found = TGTestFindStunAttribute(request, kTestAttrUsername, &username);

	TGTestExpectTrue(&outcome, found, "the username attribute must be present");
	if (found)
		TGTestExpectTrue(&outcome, [username.value isEqualToData:[@"userfrag" dataUsingEncoding:NSUTF8StringEncoding]],
				"the username attribute value must match the given username exactly");

	return outcome;
}

TGTestOutcome TGCallStunTestBindingRequestMessageIntegrityMatchesIndependentHmac(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *request = [TGCallStun bindingRequestWithUsername:@"user" password:@"secretpw" tieBreaker:1 useCandidate:YES];
	TGTestStunAttribute integrity;
	BOOL found = TGTestFindStunAttribute(request, kTestAttrMessageIntegrity, &integrity);

	TGTestExpectTrue(&outcome, found, "the message-integrity attribute must be present");
	if (found) {
		TGTestExpectEqualInteger(&outcome, integrity.value.length, 20, "an HMAC-SHA1 message-integrity value must be 20 bytes");
		NSData *expected = TGTestExpectedMessageIntegrity(request, integrity.offset, @"secretpw");
		TGTestExpectTrue(&outcome, [integrity.value isEqualToData:expected],
				"the message-integrity value must match an independently computed HMAC-SHA1 over the same prefix");
	}

	return outcome;
}

TGTestOutcome TGCallStunTestBindingRequestFingerprintMatchesIndependentCrc32(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *request = [TGCallStun bindingRequestWithUsername:@"user" password:@"secretpw" tieBreaker:1 useCandidate:YES];
	TGTestStunAttribute fingerprint;
	BOOL found = TGTestFindStunAttribute(request, kTestAttrFingerprint, &fingerprint);

	TGTestExpectTrue(&outcome, found, "the fingerprint attribute must be present");
	if (found) {
		TGTestExpectEqualInteger(&outcome, fingerprint.value.length, 4, "the fingerprint value must be 4 bytes");
		uint32_t expected = TGTestExpectedFingerprint(request, fingerprint.offset);
		uint32_t actual = TGTestReadU32BigEndian(fingerprint.value.bytes);
		TGTestExpectEqualLongLong(&outcome, actual, expected,
				"the fingerprint must match an independently computed CRC32 XORed with the STUN fingerprint constant");
	}

	return outcome;
}

TGTestOutcome TGCallStunTestBindingRequestHeaderLengthMatchesAttributeBytes(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *request = [TGCallStun bindingRequestWithUsername:@"user" password:@"pass" tieBreaker:1 useCandidate:YES];
	const uint8_t *bytes = request.bytes;
	uint16_t headerLength = TGTestReadU16BigEndian(bytes + 2);

	TGTestExpectEqualLongLong(&outcome, headerLength, request.length - 20,
			"the STUN header length field must equal the total message size minus the 20-byte header");

	return outcome;
}

TGTestOutcome TGCallStunTestBindingResponseCopiesTransactionIdFromRequest(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *request = [TGCallStun bindingRequestWithUsername:@"user" password:@"pass" tieBreaker:1 useCandidate:NO];
	NSData *response = [TGCallStun bindingResponseTo:request password:@"pass" fromAddress:[NSData data]];

	NSData *requestTransactionId = [request subdataWithRange:NSMakeRange(8, 12)];
	NSData *responseTransactionId = [response subdataWithRange:NSMakeRange(8, 12)];
	TGTestExpectTrue(&outcome, [requestTransactionId isEqualToData:responseTransactionId],
			"the response must echo back the request's 12-byte transaction id");

	return outcome;
}

TGTestOutcome TGCallStunTestBindingResponseTooShortRequestReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[5];
	memset(raw, 0, sizeof(raw));
	NSData *tooShort = [NSData dataWithBytes:raw length:sizeof(raw)];
	NSData *response = [TGCallStun bindingResponseTo:tooShort password:@"pass" fromAddress:[NSData data]];

	TGTestExpectTrue(&outcome, response == nil, "a request shorter than the STUN header must yield a nil response, not crash");

	return outcome;
}

TGTestOutcome TGCallStunTestBindingResponseXorMappedAddressRoundTrips(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *request = [TGCallStun bindingRequestWithUsername:@"user" password:@"pass" tieBreaker:1 useCandidate:NO];
	NSData *fromAddress = TGTestSockAddrIn(54321, 0xC0A80001);
	NSData *response = [TGCallStun bindingResponseTo:request password:@"pass" fromAddress:fromAddress];

	TGTestStunAttribute mapped;
	BOOL found = TGTestFindStunAttribute(response, kTestAttrXorMappedAddress, &mapped);

	TGTestExpectTrue(&outcome, found, "the xor-mapped-address attribute must be present");
	if (found) {
		const uint8_t *bytes = mapped.value.bytes;
		TGTestExpectEqualInteger(&outcome, mapped.value.length, 8, "an IPv4 xor-mapped-address value must be 8 bytes");
		TGTestExpectEqualInteger(&outcome, bytes[1], 1, "the address family byte must mark IPv4");

		uint16_t xorPort = TGTestReadU16BigEndian(bytes + 2);
		uint16_t decodedPort = xorPort ^ (uint16_t)(kTestMagicCookie >> 16);
		TGTestExpectEqualLongLong(&outcome, decodedPort, 54321, "the decoded port must match the original address's port");

		uint32_t xorAddress = TGTestReadU32BigEndian(bytes + 4);
		uint32_t decodedAddress = xorAddress ^ kTestMagicCookie;
		TGTestExpectEqualLongLong(&outcome, decodedAddress, 0xC0A80001, "the decoded address must match the original IPv4 address");
	}

	return outcome;
}

TGTestOutcome TGCallStunTestBindingResponseEmptyAddressYieldsZeroAddress(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *request = [TGCallStun bindingRequestWithUsername:@"user" password:@"pass" tieBreaker:1 useCandidate:NO];
	NSData *response = [TGCallStun bindingResponseTo:request password:@"pass" fromAddress:[NSData data]];

	TGTestStunAttribute mapped;
	BOOL found = TGTestFindStunAttribute(response, kTestAttrXorMappedAddress, &mapped);

	TGTestExpectTrue(&outcome, found, "the xor-mapped-address attribute must be present even with no source address given");
	if (found) {
		const uint8_t *bytes = mapped.value.bytes;
		uint16_t decodedPort = TGTestReadU16BigEndian(bytes + 2) ^ (uint16_t)(kTestMagicCookie >> 16);
		uint32_t decodedAddress = TGTestReadU32BigEndian(bytes + 4) ^ kTestMagicCookie;
		TGTestExpectEqualLongLong(&outcome, decodedPort, 0, "an empty source address must decode to port zero");
		TGTestExpectEqualLongLong(&outcome, decodedAddress, 0, "an empty source address must decode to address zero");
	}

	return outcome;
}

TGTestOutcome TGCallStunTestBindingResponseMessageIntegrityMatchesIndependentHmac(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *request = [TGCallStun bindingRequestWithUsername:@"user" password:@"secretpw" tieBreaker:1 useCandidate:NO];
	NSData *fromAddress = TGTestSockAddrIn(1, 1);
	NSData *response = [TGCallStun bindingResponseTo:request password:@"secretpw" fromAddress:fromAddress];

	TGTestStunAttribute integrity;
	BOOL found = TGTestFindStunAttribute(response, kTestAttrMessageIntegrity, &integrity);

	TGTestExpectTrue(&outcome, found, "the response's message-integrity attribute must be present");
	if (found) {
		NSData *expected = TGTestExpectedMessageIntegrity(response, integrity.offset, @"secretpw");
		TGTestExpectTrue(&outcome, [integrity.value isEqualToData:expected],
				"the response message-integrity must match an independently computed HMAC-SHA1 over the same prefix");
	}

	return outcome;
}

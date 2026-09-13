#import "tg_call_messages_tests.h"
#import "TGCallMessages.h"
#import <Foundation/Foundation.h>

static const uint8_t kTestEmptyMarker = 0xFE;
static const uint8_t kTestAckMarker = 0xFF;

static NSData *TGTestDataWithBytes(const uint8_t *bytes, NSUInteger length) {
	return [NSData dataWithBytes:bytes length:length];
}

static void TGTestAppendU32BigEndian(NSMutableData *data, uint32_t value) {
	uint8_t bytes[4] = {
		(uint8_t)(value >> 24), (uint8_t)(value >> 16),
		(uint8_t)(value >> 8), (uint8_t)value,
	};
	[data appendBytes:bytes length:4];
}

TGTestOutcome TGCallMessagesTestParsePacketEmptyInputReturnsEmptyArray(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *messages = [TGCallMessages parsePacket:[NSData data] seq:7];

	TGTestExpectEqualInteger(&outcome, messages.count, 0, "an empty packet must parse to zero messages");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParsePacketSingleMessageNoLeadingMarkers(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[] = {1, 'h', 'i'};
	NSArray *messages = [TGCallMessages parsePacket:TGTestDataWithBytes(raw, sizeof(raw)) seq:42];

	TGTestExpectEqualInteger(&outcome, messages.count, 1, "a packet with a real type byte up front must yield one message");
	NSDictionary *message = messages.firstObject;
	TGTestExpectEqualInteger(&outcome, [message[@"type"] intValue], 1, "the parsed type must match the leading byte");
	TGTestExpectEqualLongLong(&outcome, [message[@"seq"] unsignedIntValue], 42, "with no marker the seq must be the seq passed in");
	NSData *body = message[@"body"];
	TGTestExpectTrue(&outcome, [body isEqualToData:[NSData dataWithBytes:"hi" length:2]],
			"the body must be everything after the type byte");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParsePacketMessageAfterSingleMarkerUsesMarkerSeq(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[] = {kTestEmptyMarker, 0, 0, 0, 100, 4, 'x'};
	NSArray *messages = [TGCallMessages parsePacket:TGTestDataWithBytes(raw, sizeof(raw)) seq:1];

	TGTestExpectEqualInteger(&outcome, messages.count, 1, "a marker followed by a real message must still yield one message");
	NSDictionary *message = messages.firstObject;
	TGTestExpectEqualInteger(&outcome, [message[@"type"] intValue], 4, "the type must be the byte after the marker's seq");
	TGTestExpectEqualLongLong(&outcome, [message[@"seq"] unsignedIntValue], 100,
			"the seq must come from the marker, not the seq passed to parsePacket");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParsePacketMessageAfterMultipleMarkersUsesLastMarkerSeq(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[] = {
		kTestAckMarker, 0, 0, 0, 5,
		kTestEmptyMarker, 0, 0, 0, 9,
		4, 'y',
	};
	NSArray *messages = [TGCallMessages parsePacket:TGTestDataWithBytes(raw, sizeof(raw)) seq:1];

	TGTestExpectEqualInteger(&outcome, messages.count, 1, "several markers followed by a real message must still yield one message");
	NSDictionary *message = messages.firstObject;
	TGTestExpectEqualLongLong(&outcome, [message[@"seq"] unsignedIntValue], 9,
			"the seq must come from the most recent marker seen");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParsePacketOnlyMarkersReturnsEmptyArray(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[] = {kTestEmptyMarker, 0, 0, 0, 100};
	NSArray *messages = [TGCallMessages parsePacket:TGTestDataWithBytes(raw, sizeof(raw)) seq:1];

	TGTestExpectEqualInteger(&outcome, messages.count, 0, "a packet made only of markers carries no real message");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParsePacketTruncatedMarkerSeqReturnsEmptyArray(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[] = {kTestEmptyMarker, 0, 0, 0};
	NSArray *messages = [TGCallMessages parsePacket:TGTestDataWithBytes(raw, sizeof(raw)) seq:1];

	TGTestExpectEqualInteger(&outcome, messages.count, 0,
			"a marker whose 4-byte seq is cut short must not read past the buffer or crash");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParsePacketZeroLengthBodyDoesNotCrash(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[] = {4};
	NSArray *messages = [TGCallMessages parsePacket:TGTestDataWithBytes(raw, sizeof(raw)) seq:1];

	TGTestExpectEqualInteger(&outcome, messages.count, 1, "a lone type byte still yields a message, with an empty body");
	NSDictionary *message = messages.firstObject;
	NSData *body = message[@"body"];
	TGTestExpectEqualInteger(&outcome, body.length, 0, "the body must be empty, not out of bounds");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParsePacketAckForSeqRoundTripHasNoRealMessage(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *ack = [TGCallMessages ackForSeq:0xAABBCCDD];
	NSArray *messages = [TGCallMessages parsePacket:ack seq:1];

	TGTestExpectEqualInteger(&outcome, messages.count, 0, "an ack-only packet carries no real message when parsed back");

	return outcome;
}

TGTestOutcome TGCallMessagesTestAckForSeqEncodesMarkerAndSeqBigEndian(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *ack = [TGCallMessages ackForSeq:0xAABBCCDD];
	NSMutableData *expected = [NSMutableData data];
	uint8_t empty = kTestEmptyMarker, ackByte = kTestAckMarker;
	[expected appendBytes:&empty length:1];
	TGTestAppendU32BigEndian(expected, 0xAABBCCDD);
	[expected appendBytes:&ackByte length:1];

	TGTestExpectTrue(&outcome, [ack isEqualToData:expected],
			"an ack packet must be empty-marker, big-endian seq, ack-marker");

	return outcome;
}

TGTestOutcome TGCallMessagesTestMessageWithTypeBuildsTypeThenBody(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *body = [@"AB" dataUsingEncoding:NSUTF8StringEncoding];
	NSData *message = [TGCallMessages messageWithType:9 body:body];

	uint8_t expected[] = {9, 'A', 'B'};
	TGTestExpectTrue(&outcome, [message isEqualToData:TGTestDataWithBytes(expected, sizeof(expected))],
			"messageWithType must prepend the single type byte to the body");

	return outcome;
}

TGTestOutcome TGCallMessagesTestMessageWithTypeEmptyBody(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *message = [TGCallMessages messageWithType:kCallMessageAudioData body:[NSData data]];

	TGTestExpectEqualInteger(&outcome, message.length, 1, "an empty body must still leave the single type byte");
	const uint8_t *bytes = message.bytes;
	TGTestExpectEqualInteger(&outcome, bytes[0], kCallMessageAudioData, "the sole byte must be the given type");

	return outcome;
}

TGTestOutcome TGCallMessagesTestSeqRequiresAckTrueWhenBit30Set(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGCallMessages seqRequiresAck:((uint32_t)1 << 30)],
			"bit 30 set must report the seq requires an ack");

	return outcome;
}

TGTestOutcome TGCallMessagesTestSeqRequiresAckFalseWhenBit30Clear(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, ![TGCallMessages seqRequiresAck:((uint32_t)1 << 31)],
			"bit 31 alone must not report the seq requires an ack");
	TGTestExpectTrue(&outcome, ![TGCallMessages seqRequiresAck:0], "a zero seq must not require an ack");

	return outcome;
}

TGTestOutcome TGCallMessagesTestMarkSeqRequiresAckSetsBit30AndPreservesLowBits(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint32_t marked = [TGCallMessages markSeq:0x5 requiresAck:YES];

	TGTestExpectEqualLongLong(&outcome, marked, 0x40000005LL, "requiresAck:YES must OR in bit 30 and keep the low bits");
	TGTestExpectTrue(&outcome, [TGCallMessages seqRequiresAck:marked], "the marked seq must then report requiresAck");

	return outcome;
}

TGTestOutcome TGCallMessagesTestMarkSeqNotRequiresAckSetsBit31(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint32_t marked = [TGCallMessages markSeq:0x5 requiresAck:NO];

	TGTestExpectEqualLongLong(&outcome, marked, 0x80000005LL, "requiresAck:NO must OR in bit 31 and keep the low bits");
	TGTestExpectTrue(&outcome, ![TGCallMessages seqRequiresAck:marked],
			"a seq marked requiresAck:NO from a zero bit 30 must not report requiresAck");

	return outcome;
}

TGTestOutcome TGCallMessagesTestCandidatesRoundTripMultipleCandidates(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *candidates = @[@"candidate one", @"candidate two", @"candidate three"];
	NSData *body = [TGCallMessages candidatesBody:candidates ufrag:@"uf" pwd:@"pw"];
	NSDictionary *parsed = [TGCallMessages parseCandidates:body];

	TGTestExpectTrue(&outcome, parsed != nil, "a well-formed candidates body must parse");
	TGTestExpectTrue(&outcome, [parsed[@"candidates"] isEqualToArray:candidates],
			"the parsed candidates must match what was encoded, in order");
	TGTestExpectTrue(&outcome, [parsed[@"ufrag"] isEqualToString:@"uf"], "ufrag must round-trip");
	TGTestExpectTrue(&outcome, [parsed[@"pwd"] isEqualToString:@"pw"], "pwd must round-trip");

	return outcome;
}

TGTestOutcome TGCallMessagesTestCandidatesRoundTripZeroCandidates(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *body = [TGCallMessages candidatesBody:@[] ufrag:@"a" pwd:@"b"];
	NSDictionary *parsed = [TGCallMessages parseCandidates:body];

	TGTestExpectTrue(&outcome, parsed != nil, "a zero-candidate body must still parse");
	TGTestExpectEqualInteger(&outcome, [parsed[@"candidates"] count], 0, "zero candidates must round-trip as an empty array");
	TGTestExpectTrue(&outcome, [parsed[@"ufrag"] isEqualToString:@"a"], "ufrag must still round-trip with zero candidates");
	TGTestExpectTrue(&outcome, [parsed[@"pwd"] isEqualToString:@"b"], "pwd must still round-trip with zero candidates");

	return outcome;
}

TGTestOutcome TGCallMessagesTestCandidatesRoundTripEmptyStrings(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSData *body = [TGCallMessages candidatesBody:@[@""] ufrag:@"" pwd:@""];
	NSDictionary *parsed = [TGCallMessages parseCandidates:body];

	TGTestExpectTrue(&outcome, parsed != nil, "empty-string fields must still parse, not be mistaken for absent fields");
	TGTestExpectTrue(&outcome, [parsed[@"candidates"] isEqualToArray:@[@""]],
			"a single empty-string candidate must round-trip as an empty string, not be dropped");
	TGTestExpectTrue(&outcome, [parsed[@"ufrag"] isEqualToString:@""], "an empty ufrag must round-trip as empty, not nil");
	TGTestExpectTrue(&outcome, [parsed[@"pwd"] isEqualToString:@""], "an empty pwd must round-trip as empty, not nil");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParseCandidatesEmptyBodyReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *parsed = [TGCallMessages parseCandidates:[NSData data]];

	TGTestExpectTrue(&outcome, parsed == nil, "a body with no count byte at all must return nil, not crash");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParseCandidatesTruncatedCountOnlyReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[] = {1};
	NSDictionary *parsed = [TGCallMessages parseCandidates:TGTestDataWithBytes(raw, sizeof(raw))];

	TGTestExpectTrue(&outcome, parsed == nil,
			"a count byte claiming one candidate with no bytes following must return nil, not read out of bounds");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParseCandidatesTruncatedLengthPrefixReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[] = {1, 0, 0};
	NSDictionary *parsed = [TGCallMessages parseCandidates:TGTestDataWithBytes(raw, sizeof(raw))];

	TGTestExpectTrue(&outcome, parsed == nil,
			"a 4-byte length prefix cut short by the end of the buffer must return nil, not read out of bounds");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParseCandidatesTruncatedCandidateBodyReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSMutableData *raw = [NSMutableData data];
	uint8_t count = 1;
	[raw appendBytes:&count length:1];
	TGTestAppendU32BigEndian(raw, 10);
	[raw appendBytes:"short" length:5];

	NSDictionary *parsed = [TGCallMessages parseCandidates:raw];

	TGTestExpectTrue(&outcome, parsed == nil,
			"a declared candidate length longer than the remaining buffer must return nil, not read out of bounds");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParseCandidatesOversizedLengthClaimReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[] = {1, 0, 0, 0, 100, 'a', 'b'};
	NSDictionary *parsed = [TGCallMessages parseCandidates:TGTestDataWithBytes(raw, sizeof(raw))];

	TGTestExpectTrue(&outcome, parsed == nil,
			"a length field claiming far more bytes than are present must return nil, not read out of bounds");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParseCandidatesMissingUfragAndPwdDefaultToEmptyStrings(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[] = {0};
	NSDictionary *parsed = [TGCallMessages parseCandidates:TGTestDataWithBytes(raw, sizeof(raw))];

	TGTestExpectTrue(&outcome, parsed != nil, "a body with zero candidates and nothing after it must still parse");
	TGTestExpectTrue(&outcome, [parsed[@"ufrag"] isEqualToString:@""],
			"a missing ufrag must default to an empty string, not nil or a crash");
	TGTestExpectTrue(&outcome, [parsed[@"pwd"] isEqualToString:@""],
			"a missing pwd must default to an empty string, not nil or a crash");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParseMediaStateEmptyBodyReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *parsed = [TGCallMessages parseMediaState:[NSData data]];

	TGTestExpectTrue(&outcome, parsed == nil, "a body with no state byte at all must return nil, not crash");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParseMediaStateActiveAudioActiveVideo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[] = {0x05};
	NSDictionary *parsed = [TGCallMessages parseMediaState:TGTestDataWithBytes(raw, sizeof(raw))];

	TGTestExpectTrue(&outcome, parsed != nil, "active audio with active video must parse");
	TGTestExpectTrue(&outcome, ![parsed[@"audioMuted"] boolValue], "audio bit set to Active must report not muted");
	TGTestExpectTrue(&outcome, ![parsed[@"videoPaused"] boolValue], "video bits set to Active must report not paused");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParseMediaStateMutedAudioInactiveVideo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[] = {0x00};
	NSDictionary *parsed = [TGCallMessages parseMediaState:TGTestDataWithBytes(raw, sizeof(raw))];

	TGTestExpectTrue(&outcome, parsed != nil, "muted audio with inactive video must parse");
	TGTestExpectTrue(&outcome, [parsed[@"audioMuted"] boolValue], "audio bit clear must report muted");
	TGTestExpectTrue(&outcome, [parsed[@"videoPaused"] boolValue], "inactive video must report paused");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParseMediaStatePausedVideoReportsAsPaused(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[] = {0x03};
	NSDictionary *parsed = [TGCallMessages parseMediaState:TGTestDataWithBytes(raw, sizeof(raw))];

	TGTestExpectTrue(&outcome, parsed != nil, "active audio with paused video must parse");
	TGTestExpectTrue(&outcome, ![parsed[@"audioMuted"] boolValue], "audio bit set to Active must report not muted");
	TGTestExpectTrue(&outcome, [parsed[@"videoPaused"] boolValue], "the Paused video value must report as paused, distinct from Active");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParseMediaStateReservedVideoValueReturnsNil(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[] = {0x06};
	NSDictionary *parsed = [TGCallMessages parseMediaState:TGTestDataWithBytes(raw, sizeof(raw))];

	TGTestExpectTrue(&outcome, parsed == nil, "the reserved video bit pattern 0x3 must be rejected, not misread as a real state");

	return outcome;
}

TGTestOutcome TGCallMessagesTestParseMediaStateIgnoresTrailingBytes(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	uint8_t raw[] = {0x05, 0xFF, 0xAA};
	NSDictionary *parsed = [TGCallMessages parseMediaState:TGTestDataWithBytes(raw, sizeof(raw))];

	TGTestExpectTrue(&outcome, parsed != nil, "extra bytes after the single state byte must not break parsing");
	TGTestExpectTrue(&outcome, ![parsed[@"audioMuted"] boolValue], "the state must still be read from the first byte only");
	TGTestExpectTrue(&outcome, ![parsed[@"videoPaused"] boolValue], "the state must still be read from the first byte only");

	return outcome;
}

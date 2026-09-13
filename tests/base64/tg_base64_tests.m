#import "tg_base64_tests.h"
#import "../../src/TDLibClient/TGBase64.h"

static NSData *TGBase64TestData(const char *text) {
	return [NSData dataWithBytes:text length:strlen(text)];
}

TGTestOutcome TGBase64TestEncodeMatchesTheKnownVectors(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGBase64Encode(TGBase64TestData("f")) isEqualToString:@"Zg=="],
			"one byte encodes to two characters and two pad characters");
	TGTestExpectTrue(&outcome, [TGBase64Encode(TGBase64TestData("fo")) isEqualToString:@"Zm8="],
			"two bytes encode to three characters and one pad character");
	TGTestExpectTrue(&outcome, [TGBase64Encode(TGBase64TestData("foo")) isEqualToString:@"Zm9v"],
			"three bytes encode to four characters and no padding");
	TGTestExpectTrue(&outcome, [TGBase64Encode(TGBase64TestData("foobar")) isEqualToString:@"Zm9vYmFy"],
			"the RFC 4648 test vector");

	unsigned char high[] = {0xFB, 0xFF, 0xBF};
	TGTestExpectTrue(&outcome,
			[TGBase64Encode([NSData dataWithBytes:high length:3]) isEqualToString:@"+/+/"],
			"the last two alphabet characters are + and /, not the URL-safe pair");

	return outcome;
}

TGTestOutcome TGBase64TestEncodePadsEveryTailLength(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	for (NSInteger length = 1; length <= 32; length++) {
		NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)length];
		unsigned char *bytes = data.mutableBytes;
		for (NSInteger i = 0; i < length; i++)
			bytes[i] = (unsigned char)(i * 7 + 3);
		NSString *encoded = TGBase64Encode(data);
		TGTestExpectTrue(&outcome, encoded.length % 4 == 0,
				"every encoding is a whole number of four-character groups");
		TGTestExpectTrue(&outcome, [TGBase64Decode(encoded) isEqualToData:data],
				"what the encoder writes, the decoder reads back byte for byte");
	}

	return outcome;
}

TGTestOutcome TGBase64TestRoundTripsEveryByteValue(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSMutableData *all = [NSMutableData dataWithLength:256];
	unsigned char *bytes = all.mutableBytes;
	for (NSInteger i = 0; i < 256; i++)
		bytes[i] = (unsigned char)i;

	NSString *encoded = TGBase64Encode(all);
	TGTestExpectTrue(&outcome, encoded.length == 344,
			"256 bytes encode to 344 characters, padding included");
	TGTestExpectTrue(&outcome, [TGBase64Decode(encoded) isEqualToData:all],
			"every byte value survives the round trip, which is what a database key needs");

	NSMutableData *key = [NSMutableData dataWithLength:32];
	unsigned char *keyBytes = key.mutableBytes;
	for (NSInteger i = 0; i < 32; i++)
		keyBytes[i] = (unsigned char)(255 - i * 3);
	TGTestExpectTrue(&outcome, [TGBase64Decode(TGBase64Encode(key)) isEqualToData:key],
			"a 32-byte database encryption key round trips");

	return outcome;
}

TGTestOutcome TGBase64TestEncodeToleratesNilAndEmpty(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGBase64Encode(nil) isEqualToString:@""],
			"nil data encodes to an empty string, never to nil in a wire dictionary");
	TGTestExpectTrue(&outcome, [TGBase64Encode([NSData data]) isEqualToString:@""],
			"empty data encodes to an empty string");
	TGTestExpectTrue(&outcome, TGBase64Decode(@"") == nil,
			"an empty string decodes to no data");

	return outcome;
}

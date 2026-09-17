#import "tg_animated_sticker_format_tests.h"
#import "../../src/Media/TGAnimatedStickerFormat.h"

static NSData *TGTestBytes(const uint8_t *bytes, NSUInteger length) {
	return [NSData dataWithBytes:bytes length:length];
}

TGTestOutcome TGAnimatedStickerFormatTestEbmlHeaderIsWebM(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	const uint8_t webm[] = {0x1A, 0x45, 0xDF, 0xA3, 0x9F, 0x42, 0x86, 0x81};
	TGTestExpectTrue(&outcome, TGAnimatedStickerFormatOfBytes(TGTestBytes(webm, sizeof(webm))) == TGAnimatedStickerFormatWebM,
			"a file opening with the EBML magic is a WebM video sticker");

	return outcome;
}

TGTestOutcome TGAnimatedStickerFormatTestGzipHeaderIsTGS(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	const uint8_t tgs[] = {0x1F, 0x8B, 0x08, 0x00};
	TGTestExpectTrue(&outcome, TGAnimatedStickerFormatOfBytes(TGTestBytes(tgs, sizeof(tgs))) == TGAnimatedStickerFormatTGS,
			"a gzip stream is a TGS animated sticker");

	return outcome;
}

TGTestOutcome TGAnimatedStickerFormatTestWebPAndShortInputAreUnknown(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	const uint8_t riff[] = {'R', 'I', 'F', 'F', 0x10, 0x00, 0x00, 0x00};
	const uint8_t truncated[] = {0x1A, 0x45, 0xDF};
	TGTestExpectTrue(&outcome, TGAnimatedStickerFormatOfBytes(TGTestBytes(riff, sizeof(riff))) == TGAnimatedStickerFormatUnknown,
			"a still WebP sticker is neither animated format");
	TGTestExpectTrue(&outcome, TGAnimatedStickerFormatOfBytes(TGTestBytes(truncated, sizeof(truncated))) == TGAnimatedStickerFormatUnknown,
			"three bytes of the EBML magic are not enough to call it WebM");
	TGTestExpectTrue(&outcome, TGAnimatedStickerFormatOfBytes(nil) == TGAnimatedStickerFormatUnknown && TGAnimatedStickerFormatOfBytes((id)@"x") == TGAnimatedStickerFormatUnknown,
			"nothing, or something that is not data, is unknown");

	return outcome;
}

TGTestOutcome TGAnimatedStickerFormatTestFileSignatureIsReadFromDisk(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"tg-sticker-%u.webm", arc4random()]];
	const uint8_t webm[] = {0x1A, 0x45, 0xDF, 0xA3, 0x01};
	[TGTestBytes(webm, sizeof(webm)) writeToFile:path atomically:YES];

	TGTestExpectTrue(&outcome, TGAnimatedStickerFormatOfFile(path) == TGAnimatedStickerFormatWebM,
			"the format comes from the downloaded file's own first bytes");
	TGTestExpectTrue(&outcome, TGAnimatedStickerFormatOfFile([path stringByAppendingString:@".missing"]) == TGAnimatedStickerFormatUnknown,
			"a file that is not there is unknown rather than a crash");
	TGTestExpectTrue(&outcome, TGAnimatedStickerFormatOfFile(nil) == TGAnimatedStickerFormatUnknown,
			"no path is unknown");

	[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
	return outcome;
}

TGTestOutcome TGAnimatedStickerFormatTestDocNamesThatPlay(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGIsAnimatedStickerDocName(@"tgs") && TGIsAnimatedStickerDocName(@"webm"),
			"TGS and WebM sticker messages are both fetched and played");
	TGTestExpectTrue(&outcome, !TGIsAnimatedStickerDocName(@"") && !TGIsAnimatedStickerDocName(@"photo.webm.jpg") && !TGIsAnimatedStickerDocName(nil) && !TGIsAnimatedStickerDocName(@1),
			"any other document name, or none, stays a still sticker");

	return outcome;
}

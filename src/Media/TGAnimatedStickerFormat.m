#import "TGAnimatedStickerFormat.h"

static const uint8_t TGAnimatedStickerWebMSignature[] = {0x1A, 0x45, 0xDF, 0xA3};
static const uint8_t TGAnimatedStickerTGSSignature[] = {0x1F, 0x8B};

TGAnimatedStickerFormat TGAnimatedStickerFormatOfBytes(NSData *bytes) {
	if (![bytes isKindOfClass:NSData.class])
		return TGAnimatedStickerFormatUnknown;
	const uint8_t *head = (const uint8_t *)bytes.bytes;
	if (bytes.length >= sizeof(TGAnimatedStickerWebMSignature) &&
		memcmp(head, TGAnimatedStickerWebMSignature, sizeof(TGAnimatedStickerWebMSignature)) == 0)
		return TGAnimatedStickerFormatWebM;
	if (bytes.length >= sizeof(TGAnimatedStickerTGSSignature) &&
		memcmp(head, TGAnimatedStickerTGSSignature, sizeof(TGAnimatedStickerTGSSignature)) == 0)
		return TGAnimatedStickerFormatTGS;
	return TGAnimatedStickerFormatUnknown;
}

TGAnimatedStickerFormat TGAnimatedStickerFormatOfFile(NSString *path) {
	if (![path isKindOfClass:NSString.class] || !path.length)
		return TGAnimatedStickerFormatUnknown;
	NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
	NSData *head = [handle readDataOfLength:sizeof(TGAnimatedStickerWebMSignature)];
	[handle closeFile];
	return TGAnimatedStickerFormatOfBytes(head);
}

BOOL TGIsAnimatedStickerDocName(id docName) {
	return [docName isKindOfClass:NSString.class] &&
		([docName isEqualToString:@"tgs"] || [docName isEqualToString:@"webm"]);
}

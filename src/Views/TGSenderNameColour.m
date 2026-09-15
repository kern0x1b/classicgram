#import "TGSenderNameColour.h"

NSInteger TGSenderNameRgbForId(int64_t senderId) {
	static const NSInteger hexes[8] = {
		0xee4928, 0x41a903, 0xe09602, 0x0f94ed,
		0x8f3bf7, 0xfc4380, 0x00a1c4, 0xeb7002};
	return hexes[(NSUInteger)llabs(senderId) % 8];
}

NSInteger TGSenderNameRgb(NSNumber *accentRgb, int64_t senderId) {
	if ([accentRgb isKindOfClass:NSNumber.class])
		return [accentRgb integerValue];
	return TGSenderNameRgbForId(senderId);
}

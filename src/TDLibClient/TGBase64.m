#import "TGBase64.h"

NSData *TGBase64Decode(id value) {
	NSString *text = [value isKindOfClass:NSString.class] ? value : nil;
	if (!text.length)
		return nil;

	static signed char table[256];
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		static const char *alphabet =
			"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
		for (NSInteger i = 0; i < 256; i++)
			table[i] = -1;
		for (NSInteger i = 0; i < 64; i++)
			table[(unsigned char)alphabet[i]] = (signed char)i;
		table[(unsigned char)'-'] = 62;
		table[(unsigned char)'_'] = 63;
	});

	NSMutableData *out = nil;
	@autoreleasepool {
		NSData *ascii = [text dataUsingEncoding:NSASCIIStringEncoding];
		const unsigned char *src = ascii.bytes;
		NSInteger length = ascii.length;
		out = [[NSMutableData alloc] initWithCapacity:(length / 4) * 3 + 3];

		unsigned char chunk[3072];
		NSInteger filled = 0;
		unsigned int accumulator = 0;
		NSInteger bits = 0;
		for (NSInteger i = 0; i < length; i++) {
			signed char decoded = table[src[i]];
			if (decoded < 0)
				continue;
			accumulator = (accumulator << 6) | (unsigned int)decoded;
			bits += 6;
			if (bits >= 8) {
				bits -= 8;
				chunk[filled++] = (unsigned char)((accumulator >> bits) & 0xFF);
				if (filled == sizeof(chunk)) {
					[out appendBytes:chunk length:filled];
					filled = 0;
				}
			}
		}
		if (filled)
			[out appendBytes:chunk length:filled];
	}
	return out.length ? out : nil;
}

NSString *TGBase64Encode(NSData *data) {
	static const char alphabet[] =
		"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	NSInteger length = (NSInteger)data.length;
	if (length <= 0)
		return @"";

	const unsigned char *src = data.bytes;
	NSMutableData *out = [[NSMutableData alloc] initWithLength:(NSUInteger)((length + 2) / 3 * 4)];
	char *dst = out.mutableBytes;
	NSInteger written = 0;
	for (NSInteger i = 0; i < length; i += 3) {
		NSInteger remaining = length - i;
		unsigned int block = (unsigned int)src[i] << 16;
		if (remaining > 1)
			block |= (unsigned int)src[i + 1] << 8;
		if (remaining > 2)
			block |= (unsigned int)src[i + 2];

		dst[written++] = alphabet[(block >> 18) & 0x3F];
		dst[written++] = alphabet[(block >> 12) & 0x3F];
		dst[written++] = remaining > 1 ? alphabet[(block >> 6) & 0x3F] : '=';
		dst[written++] = remaining > 2 ? alphabet[block & 0x3F] : '=';
	}
	return [[NSString alloc] initWithBytes:out.bytes
								   length:(NSUInteger)written
								 encoding:NSASCIIStringEncoding] ?: @"";
}

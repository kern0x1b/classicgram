#include "TGCallCrypto.h"

#include <string.h>
#include <openssl/sha.h>
#include <openssl/aes.h>
#include <openssl/modes.h>

static int TGKeyOffsetForWriting(int outgoing, int signaling) {
	return (outgoing ? 0 : 8) + (signaling ? 128 : 0);
}

static int TGKeyOffsetForReading(int outgoing, int signaling) {
	return (outgoing ? 8 : 0) + (signaling ? 128 : 0);
}

static void TGPrepareKeyIv(const uint8_t *key, const uint8_t *msgKey, int x,
                           uint8_t aesKey[32], uint8_t aesIv[16]) {
	uint8_t a[SHA256_DIGEST_LENGTH];
	uint8_t b[SHA256_DIGEST_LENGTH];
	SHA256_CTX ctx;

	SHA256_Init(&ctx);
	SHA256_Update(&ctx, msgKey, 16);
	SHA256_Update(&ctx, key + x, 36);
	SHA256_Final(a, &ctx);

	SHA256_Init(&ctx);
	SHA256_Update(&ctx, key + 40 + x, 36);
	SHA256_Update(&ctx, msgKey, 16);
	SHA256_Final(b, &ctx);

	memcpy(aesKey,      a,      8);
	memcpy(aesKey + 8,  b + 8,  16);
	memcpy(aesKey + 24, a + 24, 8);

	memcpy(aesIv,      b,      4);
	memcpy(aesIv + 4,  a + 8,  8);
	memcpy(aesIv + 12, b + 24, 4);
}

static void TGAesCtr(const uint8_t *in, uint8_t *out, size_t length,
                     const uint8_t *aesKey, uint8_t *aesIv) {
	AES_KEY aes;
	unsigned char ecount[16] = {0};
	unsigned int offset = 0;
	AES_set_encrypt_key(aesKey, 256, &aes);
	CRYPTO_ctr128_encrypt(in, out, length, &aes, aesIv, ecount, &offset,
						  (block128_f)AES_encrypt);
}

static int TGDiffers(const uint8_t *a, const uint8_t *b, size_t size) {
	volatile int differs = 0;
	for (size_t i = 0; i < size; i++)
		differs |= (a[i] != b[i]);
	return differs;
}

int TGCallDecryptPacket(const uint8_t *key, int outgoing, int signaling,
                        const uint8_t *packet, size_t length,
                        uint8_t *out, uint32_t *seq) {
	if (length < 21)
		return -1;

	int x = TGKeyOffsetForReading(outgoing, signaling);

	uint8_t aesKey[32], aesIv[16];
	TGPrepareKeyIv(key, packet, x, aesKey, aesIv);

	size_t dataSize = length - 16;
	TGAesCtr(packet + 16, out, dataSize, aesKey, aesIv);

	uint8_t digest[SHA256_DIGEST_LENGTH];
	SHA256_CTX ctx;
	SHA256_Init(&ctx);
	SHA256_Update(&ctx, key + 88 + x, 32);
	SHA256_Update(&ctx, out, dataSize);
	SHA256_Final(digest, &ctx);

	if (TGDiffers(digest + 8, packet, 16))
		return -1;

	if (seq)
		*seq = ((uint32_t)out[0] << 24) | ((uint32_t)out[1] << 16) |
			   ((uint32_t)out[2] << 8)  |  (uint32_t)out[3];

	memmove(out, out + 4, dataSize - 4);
	return (int)(dataSize - 4);
}

int TGCallEncryptPacket(const uint8_t *key, int outgoing, int signaling,
                        const uint8_t *payload, size_t length,
                        uint32_t seq, uint8_t *out) {
	int x = TGKeyOffsetForWriting(outgoing, signaling);

	uint8_t *plain = out + 16;
	plain[0] = (uint8_t)(seq >> 24);
	plain[1] = (uint8_t)(seq >> 16);
	plain[2] = (uint8_t)(seq >> 8);
	plain[3] = (uint8_t)seq;
	memcpy(plain + 4, payload, length);
	size_t plainSize = length + 4;

	uint8_t digest[SHA256_DIGEST_LENGTH];
	SHA256_CTX ctx;
	SHA256_Init(&ctx);
	SHA256_Update(&ctx, key + 88 + x, 32);
	SHA256_Update(&ctx, plain, plainSize);
	SHA256_Final(digest, &ctx);
	memcpy(out, digest + 8, 16);

	uint8_t aesKey[32], aesIv[16];
	TGPrepareKeyIv(key, out, x, aesKey, aesIv);
	TGAesCtr(plain, plain, plainSize, aesKey, aesIv);

	return (int)(16 + plainSize);
}

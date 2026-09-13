#ifndef TG_CALL_CRYPTO_H
#define TG_CALL_CRYPTO_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int TGCallDecryptPacket(const uint8_t *key, int outgoing, int signaling,
	const uint8_t *packet, size_t length,
	uint8_t *out, uint32_t *seq);

int TGCallEncryptPacket(const uint8_t *key, int outgoing, int signaling,
	const uint8_t *payload, size_t length,
	uint32_t seq, uint8_t *out);

#ifdef __cplusplus
}
#endif

#endif

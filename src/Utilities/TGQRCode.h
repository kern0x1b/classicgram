#ifndef TGQRCODE_H_
#define TGQRCODE_H_

#include <stdint.h>

typedef struct {
	int size;
	uint8_t *modules;
} TGQRMatrix;

int TGQRCodeEncodeBytes(const uint8_t *bytes, int length, int eccLevel,
	TGQRMatrix *out);
int TGQRCodeEncodeString(const char *text, int eccLevel, TGQRMatrix *out);
void TGQRMatrixRelease(TGQRMatrix *matrix);

#endif

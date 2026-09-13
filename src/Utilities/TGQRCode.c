#include <stdlib.h>
#include <string.h>

#include "TGQRCode.h"
#include "quirc/quirc_internal.h"

#define TGQR_MAX_BLOCKS 256
#define TGQR_MAX_ECC 68

static uint8_t tgqr_exp[512];
static uint8_t tgqr_log[256];
static volatile int tgqr_tables_ready;

static void tgqr_build_tables(void) {
	int i;
	int x = 1;

	if (tgqr_tables_ready)
		return;
	for (i = 0; i < 255; i++) {
		tgqr_exp[i] = (uint8_t)x;
		tgqr_log[x] = (uint8_t)i;
		x <<= 1;
		if (x & 0x100)
			x ^= 0x11d;
	}
	for (i = 255; i < 512; i++)
		tgqr_exp[i] = tgqr_exp[i - 255];
	tgqr_tables_ready = 1;
}

static uint8_t tgqr_mul(uint8_t a, uint8_t b) {
	if (!a || !b)
		return 0;
	return tgqr_exp[(int)tgqr_log[a] + (int)tgqr_log[b]];
}

static void tgqr_generator(int degree, uint8_t *descending) {
	uint8_t poly[TGQR_MAX_ECC + 1];
	int length = 1;
	int i;
	int j;

	memset(poly, 0, sizeof(poly));
	poly[0] = 1;
	for (i = 0; i < degree; i++) {
		poly[length] = 0;
		length++;
		for (j = length - 1; j >= 1; j--)
			poly[j] = poly[j - 1] ^ tgqr_mul(poly[j], tgqr_exp[i]);
		poly[0] = tgqr_mul(poly[0], tgqr_exp[i]);
	}
	for (i = 0; i < degree; i++)
		descending[i] = poly[degree - 1 - i];
}

static void tgqr_remainder(const uint8_t *data, int length,
                           const uint8_t *generator, int degree, uint8_t *ecc) {
	int i;
	int j;

	memset(ecc, 0, (size_t)degree);
	for (i = 0; i < length; i++) {
		uint8_t factor = data[i] ^ ecc[0];
		memmove(ecc, ecc + 1, (size_t)(degree - 1));
		ecc[degree - 1] = 0;
		for (j = 0; j < degree; j++)
			ecc[j] ^= tgqr_mul(generator[j], factor);
	}
}

static int tgqr_count_bits(int version) {
	return version < 10 ? 8 : 16;
}

static int tgqr_data_words(const struct quirc_version_info *info,
                           int eccLevel, int *blockCount, int *longCount) {
	const struct quirc_rs_params *small = &info->ecc[eccLevel];
	int longs;
	int blocks;

	if (small->bs <= 0 || small->ns <= 0)
		return 0;
	longs = (info->data_bytes - small->bs * small->ns) / (small->bs + 1);
	if (longs < 0)
		return 0;
	blocks = longs + small->ns;
	if (blocks > TGQR_MAX_BLOCKS)
		return 0;
	if (blockCount)
		*blockCount = blocks;
	if (longCount)
		*longCount = longs;
	return small->dw * blocks + longs;
}

static int tgqr_pick_version(int length, int eccLevel) {
	int version;

	for (version = 1; version <= QUIRC_MAX_VERSION; version++) {
		int words = tgqr_data_words(&quirc_version_db[version], eccLevel,
		                            NULL, NULL);
		int needed = 4 + tgqr_count_bits(version) + length * 8;

		if (words > 0 && words * 8 >= needed)
			return version;
	}
	return 0;
}

struct tgqr_canvas {
	int size;
	uint8_t *modules;
	uint8_t *fixed;
};

static void tgqr_put(struct tgqr_canvas *canvas, int x, int y, int dark) {
	if (x < 0 || y < 0 || x >= canvas->size || y >= canvas->size)
		return;
	canvas->modules[y * canvas->size + x] = dark ? 1 : 0;
	canvas->fixed[y * canvas->size + x] = 1;
}

static int tgqr_get(const struct tgqr_canvas *canvas, int x, int y) {
	if (x < 0 || y < 0 || x >= canvas->size || y >= canvas->size)
		return 0;
	return canvas->modules[y * canvas->size + x];
}

static int tgqr_bit(uint32_t value, int index) {
	return (int)((value >> index) & 1);
}

static void tgqr_draw_format(struct tgqr_canvas *canvas, int eccLevel,
                             int mask) {
	uint32_t data = (uint32_t)((eccLevel << 3) | mask);
	uint32_t rem = data;
	uint32_t bits;
	int i;

	for (i = 0; i < 10; i++)
		rem = (rem << 1) ^ ((rem >> 9) * 0x537);
	bits = ((data << 10) | rem) ^ 0x5412;

	for (i = 0; i <= 5; i++)
		tgqr_put(canvas, 8, i, tgqr_bit(bits, i));
	tgqr_put(canvas, 8, 7, tgqr_bit(bits, 6));
	tgqr_put(canvas, 8, 8, tgqr_bit(bits, 7));
	tgqr_put(canvas, 7, 8, tgqr_bit(bits, 8));
	for (i = 9; i < 15; i++)
		tgqr_put(canvas, 14 - i, 8, tgqr_bit(bits, i));

	for (i = 0; i < 8; i++)
		tgqr_put(canvas, canvas->size - 1 - i, 8, tgqr_bit(bits, i));
	for (i = 8; i < 15; i++)
		tgqr_put(canvas, 8, canvas->size - 15 + i, tgqr_bit(bits, i));
	tgqr_put(canvas, 8, canvas->size - 8, 1);
}

static void tgqr_draw_version(struct tgqr_canvas *canvas, int version) {
	uint32_t rem = (uint32_t)version;
	uint32_t bits;
	int i;

	if (version < 7)
		return;
	for (i = 0; i < 12; i++)
		rem = (rem << 1) ^ ((rem >> 11) * 0x1f25);
	bits = ((uint32_t)version << 12) | rem;
	for (i = 0; i < 18; i++) {
		int bit = tgqr_bit(bits, i);
		int a = canvas->size - 11 + i % 3;
		int b = i / 3;

		tgqr_put(canvas, a, b, bit);
		tgqr_put(canvas, b, a, bit);
	}
}

static void tgqr_draw_finder(struct tgqr_canvas *canvas, int x, int y) {
	int dx;
	int dy;

	for (dy = -4; dy <= 4; dy++) {
		for (dx = -4; dx <= 4; dx++) {
			int ax = dx < 0 ? -dx : dx;
			int ay = dy < 0 ? -dy : dy;
			int distance = ax > ay ? ax : ay;

			tgqr_put(canvas, x + dx, y + dy,
			         distance != 2 && distance != 4);
		}
	}
}

static void tgqr_draw_alignment(struct tgqr_canvas *canvas, int x, int y) {
	int dx;
	int dy;

	for (dy = -2; dy <= 2; dy++) {
		for (dx = -2; dx <= 2; dx++) {
			int ax = dx < 0 ? -dx : dx;
			int ay = dy < 0 ? -dy : dy;
			int distance = ax > ay ? ax : ay;

			tgqr_put(canvas, x + dx, y + dy, distance != 1);
		}
	}
}

static void tgqr_draw_function_patterns(struct tgqr_canvas *canvas,
                                        const struct quirc_version_info *info,
                                        int version, int eccLevel) {
	int positions[QUIRC_MAX_ALIGNMENT];
	int count = 0;
	int i;
	int j;

	for (i = 0; i < canvas->size; i++) {
		tgqr_put(canvas, 6, i, i % 2 == 0);
		tgqr_put(canvas, i, 6, i % 2 == 0);
	}

	tgqr_draw_finder(canvas, 3, 3);
	tgqr_draw_finder(canvas, canvas->size - 4, 3);
	tgqr_draw_finder(canvas, 3, canvas->size - 4);

	for (i = 0; i < QUIRC_MAX_ALIGNMENT; i++) {
		if (info->apat[i] == 0)
			break;
		positions[count++] = info->apat[i];
	}
	for (i = 0; i < count; i++) {
		for (j = 0; j < count; j++) {
			int corner = (i == 0 && j == 0)
			             || (i == 0 && j == count - 1)
			             || (i == count - 1 && j == 0);

			if (!corner)
				tgqr_draw_alignment(canvas, positions[i], positions[j]);
		}
	}

	tgqr_draw_format(canvas, eccLevel, 0);
	tgqr_draw_version(canvas, version);
}

static void tgqr_place_codewords(struct tgqr_canvas *canvas,
                                 const uint8_t *raw, int rawLength) {
	int bitCount = rawLength * 8;
	int index = 0;
	int right;

	for (right = canvas->size - 1; right >= 1; right -= 2) {
		int vertical;

		if (right == 6)
			right = 5;
		for (vertical = 0; vertical < canvas->size; vertical++) {
			int step;

			for (step = 0; step < 2; step++) {
				int x = right - step;
				int upward = ((right + 1) & 2) == 0;
				int y = upward ? canvas->size - 1 - vertical : vertical;
				int bit = 0;

				if (canvas->fixed[y * canvas->size + x])
					continue;
				if (index < bitCount)
					bit = (raw[index >> 3] >> (7 - (index & 7))) & 1;
				canvas->modules[y * canvas->size + x] = (uint8_t)bit;
				index++;
			}
		}
	}
}

static int tgqr_mask_bit(int mask, int x, int y) {
	switch (mask) {
	case 0: return (x + y) % 2 == 0;
	case 1: return y % 2 == 0;
	case 2: return x % 3 == 0;
	case 3: return (x + y) % 3 == 0;
	case 4: return (y / 2 + x / 3) % 2 == 0;
	case 5: return x * y % 2 + x * y % 3 == 0;
	case 6: return (x * y % 2 + x * y % 3) % 2 == 0;
	default: return ((x + y) % 2 + x * y % 3) % 2 == 0;
	}
}

static void tgqr_apply_mask(struct tgqr_canvas *canvas, int mask) {
	int x;
	int y;

	for (y = 0; y < canvas->size; y++) {
		for (x = 0; x < canvas->size; x++) {
			if (canvas->fixed[y * canvas->size + x])
				continue;
			canvas->modules[y * canvas->size + x] ^=
					(uint8_t)tgqr_mask_bit(mask, x, y);
		}
	}
}

static int tgqr_line_penalty(const int *colours, const int *runs, int count,
                             int size) {
	int penalty = 0;
	int i;

	for (i = 0; i < count; i++) {
		if (runs[i] >= 5)
			penalty += runs[i] - 2;
	}
	for (i = 0; i + 4 < count; i++) {
		int unit = runs[i];
		int before;
		int after;

		if (colours[i] != 1 || unit <= 0)
			continue;
		if (runs[i + 1] != unit || runs[i + 2] != unit * 3
				|| runs[i + 3] != unit || runs[i + 4] != unit)
			continue;
		before = i >= 1 ? runs[i - 1] : size;
		after = i + 5 < count ? runs[i + 5] : size;
		if (before >= unit * 4 && after >= unit)
			penalty += 40;
		if (after >= unit * 4 && before >= unit)
			penalty += 40;
	}
	return penalty;
}

static int tgqr_penalty(const struct tgqr_canvas *canvas) {
	int size = canvas->size;
	int penalty = 0;
	int dark = 0;
	int x;
	int y;
	int *colours = malloc(sizeof(int) * (size_t)size);
	int *runs = malloc(sizeof(int) * (size_t)size);
	int deviation;
	int total;

	if (!colours || !runs) {
		free(colours);
		free(runs);
		return 0;
	}

	for (y = 0; y < size; y++) {
		int count = 0;

		for (x = 0; x < size; x++) {
			int value = tgqr_get(canvas, x, y);

			if (count && colours[count - 1] == value) {
				runs[count - 1]++;
			} else {
				colours[count] = value;
				runs[count] = 1;
				count++;
			}
			dark += value;
		}
		penalty += tgqr_line_penalty(colours, runs, count, size);
	}

	for (x = 0; x < size; x++) {
		int count = 0;

		for (y = 0; y < size; y++) {
			int value = tgqr_get(canvas, x, y);

			if (count && colours[count - 1] == value) {
				runs[count - 1]++;
			} else {
				colours[count] = value;
				runs[count] = 1;
				count++;
			}
		}
		penalty += tgqr_line_penalty(colours, runs, count, size);
	}

	for (y = 0; y + 1 < size; y++) {
		for (x = 0; x + 1 < size; x++) {
			int value = tgqr_get(canvas, x, y);

			if (value == tgqr_get(canvas, x + 1, y)
					&& value == tgqr_get(canvas, x, y + 1)
					&& value == tgqr_get(canvas, x + 1, y + 1))
				penalty += 3;
		}
	}

	total = size * size;
	deviation = dark * 20 - total * 10;
	if (deviation < 0)
		deviation = -deviation;
	deviation = (deviation + total - 1) / total - 1;
	if (deviation > 0)
		penalty += deviation * 10;

	free(colours);
	free(runs);
	return penalty;
}

int TGQRCodeEncodeBytes(const uint8_t *bytes, int length, int eccLevel,
                        TGQRMatrix *out) {
	const struct quirc_version_info *info;
	const struct quirc_rs_params *small;
	struct tgqr_canvas canvas;
	uint8_t generator[TGQR_MAX_ECC];
	uint8_t *message = NULL;
	uint8_t *raw = NULL;
	uint8_t *best = NULL;
	int version;
	int blocks = 0;
	int longs = 0;
	int words;
	int eccWords;
	int countBits;
	int bitIndex;
	int writeIndex;
	int bestPenalty = 0;
	int mask;
	int i;
	int j;
	int pad;

	if (!out || !bytes || length < 0)
		return -1;
	if (eccLevel < 0 || eccLevel > 3)
		return -1;

	tgqr_build_tables();

	version = tgqr_pick_version(length, eccLevel);
	if (!version)
		return -1;

	info = &quirc_version_db[version];
	small = &info->ecc[eccLevel];
	words = tgqr_data_words(info, eccLevel, &blocks, &longs);
	eccWords = small->bs - small->dw;
	if (words <= 0 || eccWords <= 0 || eccWords > TGQR_MAX_ECC)
		return -1;

	countBits = tgqr_count_bits(version);

	message = calloc((size_t)words, 1);
	raw = calloc((size_t)info->data_bytes, 1);
	if (!message || !raw)
		goto fail;

	bitIndex = 0;
	for (i = 0; i < 4; i++) {
		if (((0x4 >> (3 - i)) & 1))
			message[bitIndex >> 3] |= (uint8_t)(0x80 >> (bitIndex & 7));
		bitIndex++;
	}
	for (i = countBits - 1; i >= 0; i--) {
		if ((length >> i) & 1)
			message[bitIndex >> 3] |= (uint8_t)(0x80 >> (bitIndex & 7));
		bitIndex++;
	}
	for (i = 0; i < length; i++) {
		for (j = 7; j >= 0; j--) {
			if ((bytes[i] >> j) & 1)
				message[bitIndex >> 3] |= (uint8_t)(0x80 >> (bitIndex & 7));
			bitIndex++;
		}
	}
	bitIndex += 4;
	if (bitIndex > words * 8)
		bitIndex = words * 8;
	bitIndex = (bitIndex + 7) & ~7;
	pad = 0;
	for (i = bitIndex / 8; i < words; i++) {
		message[i] = pad ? 0x11 : 0xec;
		pad = !pad;
	}

	writeIndex = 0;
	for (j = 0; j <= small->dw; j++) {
		for (i = 0; i < blocks; i++) {
			int blockWords = i < small->ns ? small->dw : small->dw + 1;
			int offset = i < small->ns
					? i * small->dw
					: small->ns * small->dw + (i - small->ns) * (small->dw + 1);

			if (j < blockWords)
				raw[writeIndex++] = message[offset + j];
		}
	}

	tgqr_generator(eccWords, generator);
	for (i = 0; i < blocks; i++) {
		uint8_t parity[TGQR_MAX_ECC];
		int blockWords = i < small->ns ? small->dw : small->dw + 1;
		int offset = i < small->ns
				? i * small->dw
				: small->ns * small->dw + (i - small->ns) * (small->dw + 1);

		tgqr_remainder(message + offset, blockWords, generator, eccWords,
		               parity);
		for (j = 0; j < eccWords; j++)
			raw[words + j * blocks + i] = parity[j];
	}

	canvas.size = version * 4 + 17;
	canvas.modules = calloc((size_t)(canvas.size * canvas.size), 1);
	canvas.fixed = calloc((size_t)(canvas.size * canvas.size), 1);
	best = calloc((size_t)(canvas.size * canvas.size), 1);
	if (!canvas.modules || !canvas.fixed || !best) {
		free(canvas.modules);
		free(canvas.fixed);
		goto fail;
	}

	tgqr_draw_function_patterns(&canvas, info, version, eccLevel);
	tgqr_place_codewords(&canvas, raw, info->data_bytes);

	for (mask = 0; mask < 8; mask++) {
		int penalty;

		tgqr_apply_mask(&canvas, mask);
		tgqr_draw_format(&canvas, eccLevel, mask);
		penalty = tgqr_penalty(&canvas);
		if (mask == 0 || penalty < bestPenalty) {
			bestPenalty = penalty;
			memcpy(best, canvas.modules, (size_t)(canvas.size * canvas.size));
		}
		tgqr_apply_mask(&canvas, mask);
	}

	free(canvas.modules);
	free(canvas.fixed);
	free(message);
	free(raw);

	out->size = canvas.size;
	out->modules = best;
	return 0;

fail:
	free(message);
	free(raw);
	free(best);
	return -1;
}

int TGQRCodeEncodeString(const char *text, int eccLevel, TGQRMatrix *out) {
	if (!text)
		return -1;
	return TGQRCodeEncodeBytes((const uint8_t *)text, (int)strlen(text),
	                           eccLevel, out);
}

void TGQRMatrixRelease(TGQRMatrix *matrix) {
	if (!matrix)
		return;
	free(matrix->modules);
	matrix->modules = NULL;
	matrix->size = 0;
}

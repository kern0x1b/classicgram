#ifndef OPUS_HEADER_H
#define OPUS_HEADER_H

#include <ogg/ogg.h>

typedef struct {
   int version;
   int channels;
   int preskip;
   ogg_uint32_t input_sample_rate;
   int gain;
   int channel_mapping;

   int nb_streams;
   int nb_coupled;
   unsigned char stream_map[255];
} OpusHeader;

int opus_header_parse(const unsigned char *header, int len, OpusHeader *h);
int opus_header_to_packet(const OpusHeader *h, unsigned char *packet, int len);

extern const int wav_permute_matrix[8][8];

#endif

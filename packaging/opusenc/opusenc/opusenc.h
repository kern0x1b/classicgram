#ifndef __OPUSENC_H
#define __OPUSENC_H

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif
#include "opus_types.h"
#include <ogg/ogg.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef ENABLE_NLS
#include <libintl.h>
#define _(X) gettext(X)
#else
#define _(X) (X)
#define textdomain(X)
#define bindtextdomain(X, Y)
#endif
#ifdef gettext_noop
#define N_(X) gettext_noop(X)
#else
#define N_(X) (X)
#endif

typedef struct
{
    void *readdata;
    opus_int64 total_samples_per_channel;
    int rawmode;
    int channels;
    long rate;
    int gain;
    int samplesize;
    int endianness;
    char *infilename;
    int ignorelength;
    int skip;
    int extraout;
    char *comments;
    int comments_length;
    int copy_comments;
} oe_enc_opt;

typedef struct
{
    int (*id_func)(unsigned char *buf, int len);
    int id_data_len;
    int (*open_func)(FILE *in, oe_enc_opt *opt, unsigned char *buf, int buflen);
    void (*close_func)(void *);
    char *format;
    char *description;
} input_format;

typedef struct OggOpusComments OggOpusComments;
typedef struct OggOpusEnc OggOpusEnc;

OggOpusComments *ope_comments_create(void);
int ope_comments_add(OggOpusComments *comments, const char *tag, const char *val);
void ope_comments_destroy(OggOpusComments *comments);

OggOpusEnc *ope_encoder_create_file(const char *path, OggOpusComments *comments, int rate, int channels, int family, int *error);
int ope_encoder_write(OggOpusEnc *enc, const short *pcm, int samples_per_channel);
int ope_encoder_drain(OggOpusEnc *enc);
void ope_encoder_destroy(OggOpusEnc *enc);

#ifdef __OBJC__
@interface TGOggOpusWriter : NSObject

- (bool)begin:(NSFileHandle *)fileHandle;
- (bool)writeFrame:(uint8_t *)framePcmBytes frameByteCount:(NSUInteger)frameByteCount;
- (NSUInteger)encodedBytes;
- (NSTimeInterval)encodedDuration;

@end
#endif

#endif


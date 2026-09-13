#import "opusenc.h"

#include "opus.h"
#include "opus_multistream.h"

#include <ogg/ogg.h>

#include "opus_header.h"

static bool comment_init(char **comments, int* length, const char *vendor_string);
__unused static bool comment_add(char **comments, int* length, char *tag, char *val);
static bool comment_pad(char **comments, int* length, int amount);

static inline int writeOggPage(ogg_page *page, NSFileHandle *fileHandle)
{
    int written = page->header_len + page->body_len;

    [fileHandle writeData:[[NSData alloc] initWithBytesNoCopy:page->header length:page->header_len freeWhenDone:false]];
    [fileHandle writeData:[[NSData alloc] initWithBytesNoCopy:page->body length:page->body_len freeWhenDone:false]];

    return MAX(0, written);
}

@interface TGOggOpusWriter ()
{
    NSFileHandle *_fileHandle;

    OpusEncoder *_encoder;
    uint8_t *_packet;

    oe_enc_opt inopt;

    ogg_stream_state os;
    ogg_page og;
    ogg_packet op;
    ogg_int64_t last_granulepos;
    ogg_int64_t enc_granulepos;
    int last_segments;
    int eos;
    OpusHeader header;

    ogg_int32_t _packetId;
    int size_segments;

    opus_int64 nb_encoded;
    opus_int64 bytes_written;
    opus_int64 pages_out;
    opus_int64 total_bytes;
    opus_int64 total_samples;
    opus_int32 nb_samples;
    opus_int32 peak_bytes;
    opus_int32 min_bytes;

    int max_frame_bytes;
    opus_int32 bitrate;
    opus_int32 rate;
    opus_int32 coding_rate;
    opus_int32 frame_size;
    int with_cvbr;
    int max_ogg_delay;
    int comment_padding;
    int serialno;
    opus_int32 lookahead;
}

@end

@implementation TGOggOpusWriter

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        bitrate = 20 * 1024;
        rate = 48000;
        coding_rate = 16000;
        frame_size = 960;
        with_cvbr = 1;
        max_ogg_delay = 48000;
        comment_padding = 512;

        _packetId = -1;
    }
    return self;
}

- (void)cleanup
{
    if (_encoder != NULL)
    {
        opus_encoder_destroy(_encoder);
        _encoder = NULL;
    }

    ogg_stream_clear(&os);

    if (_packet != NULL)
    {
        free(_packet);
        _packet = NULL;
    }
}

- (bool)begin:(NSFileHandle *)fileHandle
{
    _fileHandle = fileHandle;

    inopt.channels = 1;
    inopt.rate = coding_rate=rate;
    inopt.gain = 0;
    inopt.samplesize = 16;
    inopt.endianness = 0;
    inopt.rawmode = 0;
    inopt.ignorelength = 0;
    inopt.copy_comments = 0;

    arc4random_buf(&serialno, sizeof(serialno));

    const char *opus_version = opus_get_version_string();
    comment_init(&inopt.comments, &inopt.comments_length, opus_version);

    bitrate = 16 * 1024;

    inopt.rawmode = 1;
    inopt.ignorelength = 1;
    inopt.samplesize = 16;

    inopt.rate = rate;
    inopt.channels = 1;
    inopt.skip = 0;

    if (rate > 24000)
        coding_rate = 48000;
    else if (rate > 16000)
        coding_rate = 24000;
    else if (rate > 12000)
        coding_rate = 16000;
    else if (rate > 8000)
        coding_rate = 12000;
    else
        coding_rate = 8000;

    if (rate != coding_rate)
    {
        NSLog(@"Invalid rate");
        return false;
    }

    header.channels = 1;
    header.channel_mapping = 0;
    header.input_sample_rate = rate;
    header.gain = inopt.gain;
    header.nb_streams = 1;

    int result = OPUS_OK;
    _encoder = opus_encoder_create(coding_rate, 1, OPUS_APPLICATION_AUDIO, &result);
    if (result != OPUS_OK)
    {
        NSLog(@"Error cannot create encoder: %s", opus_strerror(result));
        return false;
    }

    min_bytes = max_frame_bytes = (1275 * 3 + 7) * header.nb_streams;
    _packet = malloc(max_frame_bytes);

    result = opus_encoder_ctl(_encoder, OPUS_SET_BITRATE(bitrate));
    if (result != OPUS_OK)
    {
        NSLog(@"Error OPUS_SET_BITRATE returned: %s", opus_strerror(result));
        return false;
    }

#ifdef OPUS_SET_LSB_DEPTH
    result = opus_encoder_ctl(_encoder, OPUS_SET_LSB_DEPTH(MAX(8, MIN(24, inopt.samplesize))));
    if (result != OPUS_OK)
    {
        NSLog(@"Warning OPUS_SET_LSB_DEPTH returned: %s", opus_strerror(result));
    }
#endif

    result = opus_encoder_ctl(_encoder, OPUS_GET_LOOKAHEAD(&lookahead));
    if (result != OPUS_OK)
    {
        NSLog(@"Error OPUS_GET_LOOKAHEAD returned: %s", opus_strerror(result));
        return false;
    }

    inopt.skip += lookahead;

    header.preskip = (int)(inopt.skip * (48000.0 / coding_rate));

    inopt.extraout = (int)(header.preskip * (rate / 48000.0));

    if (ogg_stream_init(&os, serialno) == -1)
    {
        NSLog(@"Error: stream init failed");
        return false;
    }

    {
        unsigned char header_data[100];
        int packet_size = opus_header_to_packet(&header, header_data, 100);
        op.packet = header_data;
        op.bytes = packet_size;
        op.b_o_s = 1;
        op.e_o_s = 0;
        op.granulepos = 0;
        op.packetno = 0;
        ogg_stream_packetin(&os, &op);

        while ((result = ogg_stream_flush(&os, &og)))
        {
            if (!result)
                break;

            int pageBytesWritten = writeOggPage(&og, _fileHandle);
            if (pageBytesWritten != og.header_len + og.body_len)
            {
                NSLog(@"Error: failed writing header to output stream");
                return false;
            }
            bytes_written += pageBytesWritten;
            pages_out++;
        }

        comment_pad(&inopt.comments, &inopt.comments_length, comment_padding);
        op.packet = (unsigned char *)inopt.comments;
        op.bytes = inopt.comments_length;
        op.b_o_s = 0;
        op.e_o_s = 0;
        op.granulepos = 0;
        op.packetno = 1;
        ogg_stream_packetin(&os, &op);
    }

    while ((result = ogg_stream_flush(&os, &og)))
    {
        if (result == 0)
            break;

        int writtenPageBytes = writeOggPage(&og, _fileHandle);
        if (writtenPageBytes != og.header_len + og.body_len)
        {
            NSLog(@"Error: failed writing header to output stream");
            return false;
        }

        bytes_written += writtenPageBytes;
        pages_out++;
    }

    free(inopt.comments);

    return true;
}

- (bool)writeFrame:(uint8_t *)framePcmBytes frameByteCount:(NSUInteger)frameByteCount
{
    nb_samples = -1;

    int cur_frame_size = frame_size;
    _packetId++;

    if (nb_samples < 0)
    {
        nb_samples = frameByteCount / 2;
        total_samples += nb_samples;
        if (nb_samples < frame_size)
            op.e_o_s = 1;
        else
            op.e_o_s = 0;
    }
    op.e_o_s |= eos;

    int nbBytes = 0;

    if (nb_samples != 0)
    {
        uint8_t *paddedFrameBytes = framePcmBytes;
        bool freePaddedFrameBytes = false;

        if (nb_samples < cur_frame_size)
        {
            paddedFrameBytes = malloc(cur_frame_size * 2);
            freePaddedFrameBytes = true;

            memcpy(paddedFrameBytes, framePcmBytes, frameByteCount);
            memset(paddedFrameBytes + nb_samples * 2, 0, cur_frame_size * 2 - nb_samples * 2);
        }

        nbBytes = opus_encode(_encoder, (opus_int16 *)paddedFrameBytes, cur_frame_size, _packet, max_frame_bytes / 10);
        if (freePaddedFrameBytes)
        {
            free(paddedFrameBytes);
            paddedFrameBytes = NULL;
        }

        if (nbBytes < 0)
        {
            NSLog(@"Encoding failed: %s. Aborting.", opus_strerror(nbBytes));
            return false;
        }

        nb_encoded += cur_frame_size;
        enc_granulepos += cur_frame_size * 48000 / coding_rate;
        total_bytes += nbBytes;
        size_segments = (nbBytes + 255) / 255;
        peak_bytes = MAX(nbBytes, peak_bytes);
        min_bytes = MIN(nbBytes, min_bytes);
    }

    while ((((size_segments<=255)&&(last_segments+size_segments>255)) ||
            (enc_granulepos-last_granulepos>max_ogg_delay)) &&
           ogg_stream_flush_fill(&os, &og, 255 * 255))
    {
        if (ogg_page_packets(&og) != 0)
            last_granulepos = ogg_page_granulepos(&og);

        last_segments -= og.header[26];
        int writtenPageBytes = writeOggPage(&og, _fileHandle);
        if (writtenPageBytes != og.header_len + og.body_len)
        {
            NSLog(@"Error: failed writing data to output stream");
            return false;
        }
        bytes_written += writtenPageBytes;
        pages_out++;
    }

    op.packet = (unsigned char *)_packet;
    op.bytes = nbBytes;
    op.b_o_s = 0;
    op.granulepos = enc_granulepos;
    if (op.e_o_s)
    {
        op.granulepos = ((total_samples * 48000 + rate - 1) / rate) + header.preskip;
    }
    op.packetno = 2 + _packetId;
    ogg_stream_packetin(&os, &op);
    last_segments += size_segments;

    while ((op.e_o_s || (enc_granulepos + (frame_size * 48000 / coding_rate) - last_granulepos > max_ogg_delay) ||
            (last_segments >= 255)) ? ogg_stream_flush_fill(&os, &og, 255 * 255) : ogg_stream_pageout_fill(&os, &og, 255 * 255))
    {
        if (ogg_page_packets(&og) != 0)
            last_granulepos = ogg_page_granulepos(&og);
        last_segments -= og.header[26];
        int writtenPageBytes = writeOggPage(&og, _fileHandle);
        if (writtenPageBytes != og.header_len + og.body_len)
        {
            NSLog(@"Error: failed writing data to output stream");
            return false;
        }
        bytes_written += writtenPageBytes;
        pages_out++;
    }

    return true;
}

- (NSUInteger)encodedBytes
{
    return (NSUInteger)bytes_written;
}

- (NSTimeInterval)encodedDuration
{
    return total_samples / (NSTimeInterval)coding_rate;
}

@end

#define readint(buf, base) (((buf[base+3]<<24)&0xff000000)| \
                           ((buf[base+2]<<16)&0xff0000)| \
                           ((buf[base+1]<<8)&0xff00)| \
                           (buf[base]&0xff))
#define writeint(buf, base, val) do{ buf[base+3]=((val)>>24)&0xff; \
                                     buf[base+2]=((val)>>16)&0xff; \
                                     buf[base+1]=((val)>>8)&0xff; \
                                     buf[base]=(val)&0xff; \
                                 }while(0)

static bool comment_init(char **comments, int *length, const char *vendor_string)
{
    int vendor_length = strlen(vendor_string);
    int user_comment_list_length = 0;
    int len = 8 + 4 + vendor_length + 4;
    char *p = (char *)malloc(len);
    memcpy(p, "OpusTags", 8);
    writeint(p, 8, vendor_length);
    memcpy(p + 12, vendor_string, vendor_length);
    writeint(p, 12 + vendor_length, user_comment_list_length);
    *length = len;
    *comments = p;

    return true;
}

bool comment_add(char **comments, int* length, char *tag, char *val)
{
    char *p = *comments;
    int vendor_length = readint(p, 8);
    int user_comment_list_length = readint(p, 8 + 4 + vendor_length);
    int tag_len = (tag ? strlen(tag) + 1 : 0);
    int val_len = strlen(val);
    int len = (*length) + 4 + tag_len + val_len;

    p = (char *)realloc(p, len);

    writeint(p, *length, tag_len+val_len);
    if (tag)
    {
        memcpy(p + *length + 4, tag, tag_len);
        (p+*length+4)[tag_len-1] = '=';
    }
    memcpy(p + *length + 4 + tag_len, val, val_len);
    writeint(p, 8 + 4 + vendor_length, user_comment_list_length + 1);
    *comments = p;
    *length = len;

    return true;
}

static bool comment_pad(char **comments, int* length, int amount)
{
    if (amount > 0)
    {
        char *p = *comments;

        int newlen = (*length + amount + 255) / 255 * 255 - 1;
        p = realloc(p, newlen);
        for (NSInteger i = *length; i < newlen; i++)
        {
            p[i] = 0;
        }
        *comments = p;
        *length = newlen;
    }

    return true;
}

#undef readint
#undef writeint

struct OggOpusComments {
    char *artist;
    char *title;
};

struct OggOpusEnc {
    TGOggOpusWriter *writer;
    NSFileHandle *fileHandle;
};

OggOpusComments *ope_comments_create(void) {
    return calloc(1, sizeof(OggOpusComments));
}

int ope_comments_add(OggOpusComments *comments, const char *tag, const char *val) {
    if (!comments || !tag || !val) return -1;
    if (strcmp(tag, "ARTIST") == 0) comments->artist = strdup(val);
    if (strcmp(tag, "TITLE") == 0) comments->title = strdup(val);
    return 0;
}

void ope_comments_destroy(OggOpusComments *comments) {
    if (!comments) return;
    if (comments->artist) free(comments->artist);
    if (comments->title) free(comments->title);
    free(comments);
}

OggOpusEnc *ope_encoder_create_file(const char *path, OggOpusComments *comments, int rate, int channels, int family, int *error) {
    NSString *nsPath = [NSString stringWithUTF8String:path];
    [[NSFileManager defaultManager] createFileAtPath:nsPath contents:nil attributes:nil];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:nsPath];
    if (!handle) {
        if (error) *error = -1;
        return NULL;
    }
    TGOggOpusWriter *writer = [[TGOggOpusWriter alloc] init];
    if (![writer begin:handle]) {
        [handle closeFile];
        if (error) *error = -1;
        return NULL;
    }
    OggOpusEnc *enc = calloc(1, sizeof(OggOpusEnc));
    enc->writer = writer;
    enc->fileHandle = handle;
    if (error) *error = 0;
    return enc;
}

int ope_encoder_write(OggOpusEnc *enc, const short *pcm, int samples_per_channel) {
    if (!enc || !enc->writer) return -1;
    NSInteger byteCount = samples_per_channel * 2;
    bool ok = [enc->writer writeFrame:(uint8_t *)pcm frameByteCount:byteCount];
    return ok ? 0 : -1;
}

int ope_encoder_drain(OggOpusEnc *enc) {
    return 0;
}

void ope_encoder_destroy(OggOpusEnc *enc) {
    if (!enc) return;
    if (enc->fileHandle) {
        [enc->fileHandle closeFile];
    }
    free(enc);
}

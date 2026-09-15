#if !defined(_opusfile_h)
# define _opusfile_h (1)

# if defined(__cplusplus)
extern "C" {
# endif

# include <stdarg.h>
# include <stdio.h>
# include <ogg/ogg.h>
# include "opus_multistream.h"

# if !defined(OP_GNUC_PREREQ)
#  if defined(__GNUC__)&&defined(__GNUC_MINOR__)
#   define OP_GNUC_PREREQ(_maj,_min) \
 ((__GNUC__<<16)+__GNUC_MINOR__>=((_maj)<<16)+(_min))
#  else
#   define OP_GNUC_PREREQ(_maj,_min) 0
#  endif
# endif

# if OP_GNUC_PREREQ(4,0)
#  pragma GCC visibility push(default)
# endif

typedef struct OpusHead          OpusHead;
typedef struct OpusTags          OpusTags;
typedef struct OpusPictureTag    OpusPictureTag;
typedef struct OpusServerInfo    OpusServerInfo;
typedef struct OpusFileCallbacks OpusFileCallbacks;
typedef struct OggOpusFile       OggOpusFile;

# if OP_GNUC_PREREQ(3,4)
#  define OP_WARN_UNUSED_RESULT __attribute__((__warn_unused_result__))
# else
#  define OP_WARN_UNUSED_RESULT
# endif
# if OP_GNUC_PREREQ(3,4)
#  define OP_ARG_NONNULL(_x) __attribute__((__nonnull__(_x)))
# else
#  define OP_ARG_NONNULL(_x)
# endif

#define OP_FALSE         (-1)

#define OP_EOF           (-2)

#define OP_HOLE          (-3)

#define OP_EREAD         (-128)

#define OP_EFAULT        (-129)

#define OP_EIMPL         (-130)

#define OP_EINVAL        (-131)

#define OP_ENOTFORMAT    (-132)

#define OP_EBADHEADER    (-133)

#define OP_EVERSION      (-134)

#define OP_ENOTAUDIO     (-135)

#define OP_EBADPACKET    (-136)

#define OP_EBADLINK      (-137)

#define OP_ENOSEEK       (-138)

#define OP_EBADTIMESTAMP (-139)

#define OPUS_CHANNEL_COUNT_MAX (255)

struct OpusHead{
  int           version;

  int           channel_count;

  unsigned      pre_skip;

  opus_uint32   input_sample_rate;

  int           output_gain;

  int           mapping_family;

  int           stream_count;

  int           coupled_count;

  unsigned char mapping[OPUS_CHANNEL_COUNT_MAX];
};

struct OpusTags{
  char **user_comments;

  int   *comment_lengths;

  int    comments;

  char  *vendor;
};

#define OP_PIC_FORMAT_UNKNOWN (-1)

#define OP_PIC_FORMAT_URL     (0)

#define OP_PIC_FORMAT_JPEG    (1)

#define OP_PIC_FORMAT_PNG     (2)

#define OP_PIC_FORMAT_GIF     (3)

struct OpusPictureTag{
  opus_int32     type;

  char          *mime_type;

  char          *description;

  opus_uint32    width;

  opus_uint32    height;

  opus_uint32    depth;

  opus_uint32    colors;

  opus_uint32    data_length;

  unsigned char *data;

  int            format;
};

OP_WARN_UNUSED_RESULT int opus_head_parse(OpusHead *_head,
 const unsigned char *_data,size_t _len) OP_ARG_NONNULL(2);

ogg_int64_t opus_granule_sample(const OpusHead *_head,ogg_int64_t _gp)
 OP_ARG_NONNULL(1);

OP_WARN_UNUSED_RESULT int opus_tags_parse(OpusTags *_tags,
 const unsigned char *_data,size_t _len) OP_ARG_NONNULL(2);

int opus_tags_copy(OpusTags *_dst,const OpusTags *_src) OP_ARG_NONNULL(1);

void opus_tags_init(OpusTags *_tags) OP_ARG_NONNULL(1);

int opus_tags_add(OpusTags *_tags,const char *_tag,const char *_value)
 OP_ARG_NONNULL(1) OP_ARG_NONNULL(2) OP_ARG_NONNULL(3);

int opus_tags_add_comment(OpusTags *_tags,const char *_comment)
 OP_ARG_NONNULL(1) OP_ARG_NONNULL(2);

const char *opus_tags_query(const OpusTags *_tags,const char *_tag,int _count)
 OP_ARG_NONNULL(1) OP_ARG_NONNULL(2);

int opus_tags_query_count(const OpusTags *_tags,const char *_tag)
 OP_ARG_NONNULL(1) OP_ARG_NONNULL(2);

int opus_tags_get_track_gain(const OpusTags *_tags,int *_gain_q8)
 OP_ARG_NONNULL(1) OP_ARG_NONNULL(2);

void opus_tags_clear(OpusTags *_tags) OP_ARG_NONNULL(1);

int opus_tagcompare(const char *_tag_name,const char *_comment);

int opus_tagncompare(const char *_tag_name,int _tag_len,const char *_comment);

OP_WARN_UNUSED_RESULT int opus_picture_tag_parse(OpusPictureTag *_pic,
 const char *_tag) OP_ARG_NONNULL(1) OP_ARG_NONNULL(2);

void opus_picture_tag_init(OpusPictureTag *_pic) OP_ARG_NONNULL(1);

void opus_picture_tag_clear(OpusPictureTag *_pic) OP_ARG_NONNULL(1);

#define OP_SSL_SKIP_CERTIFICATE_CHECK_REQUEST (6464)
#define OP_HTTP_PROXY_HOST_REQUEST            (6528)
#define OP_HTTP_PROXY_PORT_REQUEST            (6592)
#define OP_HTTP_PROXY_USER_REQUEST            (6656)
#define OP_HTTP_PROXY_PASS_REQUEST            (6720)
#define OP_GET_SERVER_INFO_REQUEST            (6784)

#define OP_URL_OPT(_request) ((_request)+(char *)0)

#define OP_CHECK_INT(_x) ((void)((_x)==(opus_int32)0),(opus_int32)(_x))
#define OP_CHECK_CONST_CHAR_PTR(_x) ((_x)+((_x)-(const char *)(_x)))
#define OP_CHECK_SERVER_INFO_PTR(_x) ((_x)+((_x)-(OpusServerInfo *)(_x)))

struct OpusServerInfo{
  char        *name;

  char        *description;

  char        *genre;

  char        *url;

  char        *server;

  char        *content_type;

  opus_int32   bitrate_kbps;

  int          is_public;

  int          is_ssl;
};

void opus_server_info_init(OpusServerInfo *_info) OP_ARG_NONNULL(1);

void opus_server_info_clear(OpusServerInfo *_info) OP_ARG_NONNULL(1);

#define OP_SSL_SKIP_CERTIFICATE_CHECK(_b) \
 OP_URL_OPT(OP_SSL_SKIP_CERTIFICATE_CHECK_REQUEST),OP_CHECK_INT(_b)

#define OP_HTTP_PROXY_HOST(_host) \
 OP_URL_OPT(OP_HTTP_PROXY_HOST_REQUEST),OP_CHECK_CONST_CHAR_PTR(_host)

#define OP_HTTP_PROXY_PORT(_port) \
 OP_URL_OPT(OP_HTTP_PROXY_PORT_REQUEST),OP_CHECK_INT(_port)

#define OP_HTTP_PROXY_USER(_user) \
 OP_URL_OPT(OP_HTTP_PROXY_USER_REQUEST),OP_CHECK_CONST_CHAR_PTR(_user)

#define OP_HTTP_PROXY_PASS(_pass) \
 OP_URL_OPT(OP_HTTP_PROXY_PASS_REQUEST),OP_CHECK_CONST_CHAR_PTR(_pass)

#define OP_GET_SERVER_INFO(_info) \
 OP_URL_OPT(OP_GET_SERVER_INFO_REQUEST),OP_CHECK_SERVER_INFO_PTR(_info)

typedef int (*op_read_func)(void *_stream,unsigned char *_ptr,int _nbytes);

typedef int (*op_seek_func)(void *_stream,opus_int64 _offset,int _whence);

typedef opus_int64 (*op_tell_func)(void *_stream);

typedef int (*op_close_func)(void *_stream);

struct OpusFileCallbacks{
  op_read_func  read;

  op_seek_func  seek;

  op_tell_func  tell;

  op_close_func close;
};

OP_WARN_UNUSED_RESULT void *op_fopen(OpusFileCallbacks *_cb,
 const char *_path,const char *_mode) OP_ARG_NONNULL(1) OP_ARG_NONNULL(2)
 OP_ARG_NONNULL(3);

OP_WARN_UNUSED_RESULT void *op_fdopen(OpusFileCallbacks *_cb,
 int _fd,const char *_mode) OP_ARG_NONNULL(1) OP_ARG_NONNULL(3);

OP_WARN_UNUSED_RESULT void *op_freopen(OpusFileCallbacks *_cb,
 const char *_path,const char *_mode,void *_stream) OP_ARG_NONNULL(1)
 OP_ARG_NONNULL(2) OP_ARG_NONNULL(3) OP_ARG_NONNULL(4);

OP_WARN_UNUSED_RESULT void *op_mem_stream_create(OpusFileCallbacks *_cb,
 const unsigned char *_data,size_t _size) OP_ARG_NONNULL(1);

OP_WARN_UNUSED_RESULT void *op_url_stream_vcreate(OpusFileCallbacks *_cb,
 const char *_url,va_list _ap) OP_ARG_NONNULL(1) OP_ARG_NONNULL(2);

OP_WARN_UNUSED_RESULT void *op_url_stream_create(OpusFileCallbacks *_cb,
 const char *_url,...) OP_ARG_NONNULL(1) OP_ARG_NONNULL(2);

int op_test(OpusHead *_head,
 const unsigned char *_initial_data,size_t _initial_bytes);

OP_WARN_UNUSED_RESULT OggOpusFile *op_open_file(const char *_path,int *_error)
 OP_ARG_NONNULL(1);

OP_WARN_UNUSED_RESULT OggOpusFile *op_open_memory(const unsigned char *_data,
 size_t _size,int *_error);

OP_WARN_UNUSED_RESULT OggOpusFile *op_vopen_url(const char *_url,
 int *_error,va_list _ap) OP_ARG_NONNULL(1);

OP_WARN_UNUSED_RESULT OggOpusFile *op_open_url(const char *_url,
 int *_error,...) OP_ARG_NONNULL(1);

OP_WARN_UNUSED_RESULT OggOpusFile *op_open_callbacks(void *_source,
 const OpusFileCallbacks *_cb,const unsigned char *_initial_data,
 size_t _initial_bytes,int *_error) OP_ARG_NONNULL(2);

OP_WARN_UNUSED_RESULT OggOpusFile *op_test_file(const char *_path,int *_error)
 OP_ARG_NONNULL(1);

OP_WARN_UNUSED_RESULT OggOpusFile *op_test_memory(const unsigned char *_data,
 size_t _size,int *_error);

OP_WARN_UNUSED_RESULT OggOpusFile *op_vtest_url(const char *_url,
 int *_error,va_list _ap) OP_ARG_NONNULL(1);

OP_WARN_UNUSED_RESULT OggOpusFile *op_test_url(const char *_url,
 int *_error,...) OP_ARG_NONNULL(1);

OP_WARN_UNUSED_RESULT OggOpusFile *op_test_callbacks(void *_source,
 const OpusFileCallbacks *_cb,const unsigned char *_initial_data,
 size_t _initial_bytes,int *_error) OP_ARG_NONNULL(2);

int op_test_open(OggOpusFile *_of) OP_ARG_NONNULL(1);

void op_free(OggOpusFile *_of);

int op_seekable(const OggOpusFile *_of) OP_ARG_NONNULL(1);

int op_link_count(const OggOpusFile *_of) OP_ARG_NONNULL(1);

opus_uint32 op_serialno(const OggOpusFile *_of,int _li) OP_ARG_NONNULL(1);

int op_channel_count(const OggOpusFile *_of,int _li) OP_ARG_NONNULL(1);

opus_int64 op_raw_total(const OggOpusFile *_of,int _li) OP_ARG_NONNULL(1);

ogg_int64_t op_pcm_total(const OggOpusFile *_of,int _li) OP_ARG_NONNULL(1);

const OpusHead *op_head(const OggOpusFile *_of,int _li) OP_ARG_NONNULL(1);

const OpusTags *op_tags(const OggOpusFile *_of,int _li) OP_ARG_NONNULL(1);

int op_current_link(const OggOpusFile *_of) OP_ARG_NONNULL(1);

opus_int32 op_bitrate(const OggOpusFile *_of,int _li) OP_ARG_NONNULL(1);

opus_int32 op_bitrate_instant(OggOpusFile *_of) OP_ARG_NONNULL(1);

opus_int64 op_raw_tell(const OggOpusFile *_of) OP_ARG_NONNULL(1);

ogg_int64_t op_pcm_tell(const OggOpusFile *_of) OP_ARG_NONNULL(1);

int op_raw_seek(OggOpusFile *_of,opus_int64 _byte_offset) OP_ARG_NONNULL(1);

int op_pcm_seek(OggOpusFile *_of,ogg_int64_t _pcm_offset) OP_ARG_NONNULL(1);

#define OP_DEC_FORMAT_SHORT (7008)

#define OP_DEC_FORMAT_FLOAT (7040)

#define OP_DEC_USE_DEFAULT  (6720)

typedef int (*op_decode_cb_func)(void *_ctx,OpusMSDecoder *_decoder,void *_pcm,
 const ogg_packet *_op,int _nsamples,int _nchannels,int _format,int _li);

void op_set_decode_callback(OggOpusFile *_of,
 op_decode_cb_func _decode_cb,void *_ctx) OP_ARG_NONNULL(1);

#define OP_HEADER_GAIN   (0)

#define OP_TRACK_GAIN    (3008)

#define OP_ABSOLUTE_GAIN (3009)

int op_set_gain_offset(OggOpusFile *_of,
 int _gain_type,opus_int32 _gain_offset_q8) OP_ARG_NONNULL(1);

void op_set_dither_enabled(OggOpusFile *_of,int _enabled) OP_ARG_NONNULL(1);

OP_WARN_UNUSED_RESULT int op_read(OggOpusFile *_of,
 opus_int16 *_pcm,int _buf_size,int *_li) OP_ARG_NONNULL(1);

OP_WARN_UNUSED_RESULT int op_read_float(OggOpusFile *_of,
 float *_pcm,int _buf_size,int *_li) OP_ARG_NONNULL(1);

OP_WARN_UNUSED_RESULT int op_read_stereo(OggOpusFile *_of,
 opus_int16 *_pcm,int _buf_size) OP_ARG_NONNULL(1);

OP_WARN_UNUSED_RESULT int op_read_float_stereo(OggOpusFile *_of,
 float *_pcm,int _buf_size) OP_ARG_NONNULL(1);

# if OP_GNUC_PREREQ(4,0)
#  pragma GCC visibility pop
# endif

# if defined(__cplusplus)
}
# endif

#endif

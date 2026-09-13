#if !defined(_opusfile_internal_h)
# define _opusfile_internal_h (1)

# if !defined(_REENTRANT)
#  define _REENTRANT
# endif
# if !defined(_GNU_SOURCE)
#  define _GNU_SOURCE
# endif
# if !defined(_LARGEFILE_SOURCE)
#  define _LARGEFILE_SOURCE
# endif
# if !defined(_LARGEFILE64_SOURCE)
#  define _LARGEFILE64_SOURCE
# endif
# if !defined(_FILE_OFFSET_BITS)
#  define _FILE_OFFSET_BITS 64
# endif

# include <stdlib.h>
# include "opusfile.h"

typedef struct OggOpusLink OggOpusLink;

# if defined(OP_FIXED_POINT)

typedef opus_int16 op_sample;

# else

typedef float      op_sample;

#  if defined(OPUS_GET_EXPERT_FRAME_DURATION_REQUEST)

#   define OP_SOFT_CLIP (1)
#  endif

# endif

# if OP_GNUC_PREREQ(4,2)

#  pragma GCC diagnostic ignored "-Wparentheses"
# elif defined(_MSC_VER)

#  pragma warning(disable:4554)

#  pragma warning(disable:4996)
# endif

# if OP_GNUC_PREREQ(3,0)

#  define OP_LIKELY(_x) (__builtin_expect(!!(_x),1))
#  define OP_UNLIKELY(_x) (__builtin_expect(!!(_x),0))
# else
#  define OP_LIKELY(_x)   (!!(_x))
#  define OP_UNLIKELY(_x) (!!(_x))
# endif

# if defined(OP_ENABLE_ASSERTIONS)
#  if OP_GNUC_PREREQ(2,5)||__SUNPRO_C>=0x590
__attribute__((noreturn))
#  endif
void op_fatal_impl(const char *_str,const char *_file,int _line);

#  define OP_FATAL(_str) (op_fatal_impl(_str,__FILE__,__LINE__))

#  define OP_ASSERT(_cond) \
  do{ \
    if(OP_UNLIKELY(!(_cond)))OP_FATAL("assertion failed: " #_cond); \
  } \
  while(0)
#  define OP_ALWAYS_TRUE(_cond) OP_ASSERT(_cond)

# else
#  define OP_FATAL(_str) abort()
#  define OP_ASSERT(_cond)
#  define OP_ALWAYS_TRUE(_cond) ((void)(_cond))
# endif

# define OP_INT64_MAX (2*(((ogg_int64_t)1<<62)-1)|1)
# define OP_INT64_MIN (-OP_INT64_MAX-1)
# define OP_INT32_MAX (2*(((ogg_int32_t)1<<30)-1)|1)
# define OP_INT32_MIN (-OP_INT32_MAX-1)

# define OP_MIN(_a,_b)        ((_a)<(_b)?(_a):(_b))
# define OP_MAX(_a,_b)        ((_a)>(_b)?(_a):(_b))
# define OP_CLAMP(_lo,_x,_hi) (OP_MAX(_lo,OP_MIN(_x,_hi)))

#define OP_ADV_OFFSET(_offset,_amount) \
 (OP_MIN(_offset,OP_INT64_MAX-(_amount))+(_amount))

# define OP_NCHANNELS_MAX (8)

# define  OP_NOTOPEN   (0)

# define  OP_PARTOPEN  (1)
# define  OP_OPENED    (2)

# define  OP_STREAMSET (3)

# define  OP_INITSET   (4)

struct OggOpusLink{
  opus_int64   offset;

  opus_int64   data_offset;

  opus_int64   end_offset;

  ogg_int64_t  pcm_end;

  ogg_int64_t  pcm_start;

  ogg_uint32_t serialno;

  OpusHead     head;

  OpusTags     tags;
};

struct OggOpusFile{
  OpusFileCallbacks  callbacks;

  void              *source;

  int                seekable;

  int                nlinks;

  OggOpusLink       *links;

  int                nserialnos;

  int                cserialnos;

  ogg_uint32_t      *serialnos;

  opus_int64         offset;

  opus_int64         end;

  ogg_sync_state     oy;

  int                ready_state;

  int                cur_link;

  opus_int32         cur_discard_count;

  ogg_int64_t        prev_packet_gp;

  opus_int64         bytes_tracked;

  ogg_int64_t        samples_tracked;

  ogg_stream_state   os;

  ogg_packet         op[255];

  int                op_pos;

  int                op_count;

  OpusMSDecoder     *od;

  op_decode_cb_func  decode_cb;

  void              *decode_cb_ctx;

  int                od_stream_count;

  int                od_coupled_count;

  int                od_channel_count;

  unsigned char      od_mapping[OP_NCHANNELS_MAX];

  op_sample         *od_buffer;

  int                od_buffer_pos;

  int                od_buffer_size;

  int                gain_type;

  opus_int32         gain_offset_q8;

#if !defined(OP_FIXED_POINT)
# if defined(OP_SOFT_CLIP)
  float              clip_state[OP_NCHANNELS_MAX];
# endif
  float              dither_a[OP_NCHANNELS_MAX*4];
  float              dither_b[OP_NCHANNELS_MAX*4];
  opus_uint32        dither_seed;
  int                dither_mute;
  int                dither_disabled;

  int                state_channel_count;
#endif
};

int op_strncasecmp(const char *_a,const char *_b,int _n);

#endif

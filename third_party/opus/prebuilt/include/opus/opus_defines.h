#ifndef OPUS_DEFINES_H
#define OPUS_DEFINES_H

#include "opus_types.h"

#ifdef __cplusplus
extern "C" {
#endif

#define OPUS_OK                0

#define OPUS_BAD_ARG          -1

#define OPUS_BUFFER_TOO_SMALL -2

#define OPUS_INTERNAL_ERROR   -3

#define OPUS_INVALID_PACKET   -4

#define OPUS_UNIMPLEMENTED    -5

#define OPUS_INVALID_STATE    -6

#define OPUS_ALLOC_FAIL       -7

#ifndef OPUS_EXPORT
# if defined(WIN32)
#  ifdef OPUS_BUILD
#   define OPUS_EXPORT __declspec(dllexport)
#  else
#   define OPUS_EXPORT
#  endif
# elif defined(__GNUC__) && defined(OPUS_BUILD)
#  define OPUS_EXPORT __attribute__ ((visibility ("default")))
# else
#  define OPUS_EXPORT
# endif
#endif

# if !defined(OPUS_GNUC_PREREQ)
#  if defined(__GNUC__)&&defined(__GNUC_MINOR__)
#   define OPUS_GNUC_PREREQ(_maj,_min) \
 ((__GNUC__<<16)+__GNUC_MINOR__>=((_maj)<<16)+(_min))
#  else
#   define OPUS_GNUC_PREREQ(_maj,_min) 0
#  endif
# endif

#if (!defined(__STDC_VERSION__) || (__STDC_VERSION__ < 199901L) )
# if OPUS_GNUC_PREREQ(3,0)
#  define OPUS_RESTRICT __restrict__
# elif (defined(_MSC_VER) && _MSC_VER >= 1400)
#  define OPUS_RESTRICT __restrict
# else
#  define OPUS_RESTRICT
# endif
#else
# define OPUS_RESTRICT restrict
#endif

#if (!defined(__STDC_VERSION__) || (__STDC_VERSION__ < 199901L) )
# if OPUS_GNUC_PREREQ(2,7)
#  define OPUS_INLINE __inline__
# elif (defined(_MSC_VER))
#  define OPUS_INLINE __inline
# else
#  define OPUS_INLINE
# endif
#else
# define OPUS_INLINE inline
#endif

#if defined(__GNUC__) && OPUS_GNUC_PREREQ(3, 4)
# define OPUS_WARN_UNUSED_RESULT __attribute__ ((__warn_unused_result__))
#else
# define OPUS_WARN_UNUSED_RESULT
#endif
#if !defined(OPUS_BUILD) && defined(__GNUC__) && OPUS_GNUC_PREREQ(3, 4)
# define OPUS_ARG_NONNULL(_x)  __attribute__ ((__nonnull__(_x)))
#else
# define OPUS_ARG_NONNULL(_x)
#endif

#define OPUS_SET_APPLICATION_REQUEST         4000
#define OPUS_GET_APPLICATION_REQUEST         4001
#define OPUS_SET_BITRATE_REQUEST             4002
#define OPUS_GET_BITRATE_REQUEST             4003
#define OPUS_SET_MAX_BANDWIDTH_REQUEST       4004
#define OPUS_GET_MAX_BANDWIDTH_REQUEST       4005
#define OPUS_SET_VBR_REQUEST                 4006
#define OPUS_GET_VBR_REQUEST                 4007
#define OPUS_SET_BANDWIDTH_REQUEST           4008
#define OPUS_GET_BANDWIDTH_REQUEST           4009
#define OPUS_SET_COMPLEXITY_REQUEST          4010
#define OPUS_GET_COMPLEXITY_REQUEST          4011
#define OPUS_SET_INBAND_FEC_REQUEST          4012
#define OPUS_GET_INBAND_FEC_REQUEST          4013
#define OPUS_SET_PACKET_LOSS_PERC_REQUEST    4014
#define OPUS_GET_PACKET_LOSS_PERC_REQUEST    4015
#define OPUS_SET_DTX_REQUEST                 4016
#define OPUS_GET_DTX_REQUEST                 4017
#define OPUS_SET_VBR_CONSTRAINT_REQUEST      4020
#define OPUS_GET_VBR_CONSTRAINT_REQUEST      4021
#define OPUS_SET_FORCE_CHANNELS_REQUEST      4022
#define OPUS_GET_FORCE_CHANNELS_REQUEST      4023
#define OPUS_SET_SIGNAL_REQUEST              4024
#define OPUS_GET_SIGNAL_REQUEST              4025
#define OPUS_GET_LOOKAHEAD_REQUEST           4027

#define OPUS_GET_SAMPLE_RATE_REQUEST         4029
#define OPUS_GET_FINAL_RANGE_REQUEST         4031
#define OPUS_GET_PITCH_REQUEST               4033
#define OPUS_SET_GAIN_REQUEST                4034
#define OPUS_GET_GAIN_REQUEST                4045
#define OPUS_SET_LSB_DEPTH_REQUEST           4036
#define OPUS_GET_LSB_DEPTH_REQUEST           4037
#define OPUS_GET_LAST_PACKET_DURATION_REQUEST 4039
#define OPUS_SET_EXPERT_FRAME_DURATION_REQUEST 4040
#define OPUS_GET_EXPERT_FRAME_DURATION_REQUEST 4041
#define OPUS_SET_PREDICTION_DISABLED_REQUEST 4042
#define OPUS_GET_PREDICTION_DISABLED_REQUEST 4043

#define __opus_check_int(x) (((void)((x) == (opus_int32)0)), (opus_int32)(x))
#define __opus_check_int_ptr(ptr) ((ptr) + ((ptr) - (opus_int32*)(ptr)))
#define __opus_check_uint_ptr(ptr) ((ptr) + ((ptr) - (opus_uint32*)(ptr)))
#define __opus_check_val16_ptr(ptr) ((ptr) + ((ptr) - (opus_val16*)(ptr)))

#define OPUS_AUTO                           -1000
#define OPUS_BITRATE_MAX                       -1

#define OPUS_APPLICATION_VOIP                2048

#define OPUS_APPLICATION_AUDIO               2049

#define OPUS_APPLICATION_RESTRICTED_LOWDELAY 2051

#define OPUS_SIGNAL_VOICE                    3001
#define OPUS_SIGNAL_MUSIC                    3002
#define OPUS_BANDWIDTH_NARROWBAND            1101
#define OPUS_BANDWIDTH_MEDIUMBAND            1102
#define OPUS_BANDWIDTH_WIDEBAND              1103
#define OPUS_BANDWIDTH_SUPERWIDEBAND         1104
#define OPUS_BANDWIDTH_FULLBAND              1105

#define OPUS_FRAMESIZE_ARG                   5000
#define OPUS_FRAMESIZE_2_5_MS                5001
#define OPUS_FRAMESIZE_5_MS                  5002
#define OPUS_FRAMESIZE_10_MS                 5003
#define OPUS_FRAMESIZE_20_MS                 5004
#define OPUS_FRAMESIZE_40_MS                 5005
#define OPUS_FRAMESIZE_60_MS                 5006

#define OPUS_SET_COMPLEXITY(x) OPUS_SET_COMPLEXITY_REQUEST, __opus_check_int(x)

#define OPUS_GET_COMPLEXITY(x) OPUS_GET_COMPLEXITY_REQUEST, __opus_check_int_ptr(x)

#define OPUS_SET_BITRATE(x) OPUS_SET_BITRATE_REQUEST, __opus_check_int(x)

#define OPUS_GET_BITRATE(x) OPUS_GET_BITRATE_REQUEST, __opus_check_int_ptr(x)

#define OPUS_SET_VBR(x) OPUS_SET_VBR_REQUEST, __opus_check_int(x)

#define OPUS_GET_VBR(x) OPUS_GET_VBR_REQUEST, __opus_check_int_ptr(x)

#define OPUS_SET_VBR_CONSTRAINT(x) OPUS_SET_VBR_CONSTRAINT_REQUEST, __opus_check_int(x)

#define OPUS_GET_VBR_CONSTRAINT(x) OPUS_GET_VBR_CONSTRAINT_REQUEST, __opus_check_int_ptr(x)

#define OPUS_SET_FORCE_CHANNELS(x) OPUS_SET_FORCE_CHANNELS_REQUEST, __opus_check_int(x)

#define OPUS_GET_FORCE_CHANNELS(x) OPUS_GET_FORCE_CHANNELS_REQUEST, __opus_check_int_ptr(x)

#define OPUS_SET_MAX_BANDWIDTH(x) OPUS_SET_MAX_BANDWIDTH_REQUEST, __opus_check_int(x)

#define OPUS_GET_MAX_BANDWIDTH(x) OPUS_GET_MAX_BANDWIDTH_REQUEST, __opus_check_int_ptr(x)

#define OPUS_SET_BANDWIDTH(x) OPUS_SET_BANDWIDTH_REQUEST, __opus_check_int(x)

#define OPUS_SET_SIGNAL(x) OPUS_SET_SIGNAL_REQUEST, __opus_check_int(x)

#define OPUS_GET_SIGNAL(x) OPUS_GET_SIGNAL_REQUEST, __opus_check_int_ptr(x)

#define OPUS_SET_APPLICATION(x) OPUS_SET_APPLICATION_REQUEST, __opus_check_int(x)

#define OPUS_GET_APPLICATION(x) OPUS_GET_APPLICATION_REQUEST, __opus_check_int_ptr(x)

#define OPUS_GET_LOOKAHEAD(x) OPUS_GET_LOOKAHEAD_REQUEST, __opus_check_int_ptr(x)

#define OPUS_SET_INBAND_FEC(x) OPUS_SET_INBAND_FEC_REQUEST, __opus_check_int(x)

#define OPUS_GET_INBAND_FEC(x) OPUS_GET_INBAND_FEC_REQUEST, __opus_check_int_ptr(x)

#define OPUS_SET_PACKET_LOSS_PERC(x) OPUS_SET_PACKET_LOSS_PERC_REQUEST, __opus_check_int(x)

#define OPUS_GET_PACKET_LOSS_PERC(x) OPUS_GET_PACKET_LOSS_PERC_REQUEST, __opus_check_int_ptr(x)

#define OPUS_SET_DTX(x) OPUS_SET_DTX_REQUEST, __opus_check_int(x)

#define OPUS_GET_DTX(x) OPUS_GET_DTX_REQUEST, __opus_check_int_ptr(x)

#define OPUS_SET_LSB_DEPTH(x) OPUS_SET_LSB_DEPTH_REQUEST, __opus_check_int(x)

#define OPUS_GET_LSB_DEPTH(x) OPUS_GET_LSB_DEPTH_REQUEST, __opus_check_int_ptr(x)

#define OPUS_SET_EXPERT_FRAME_DURATION(x) OPUS_SET_EXPERT_FRAME_DURATION_REQUEST, __opus_check_int(x)

#define OPUS_GET_EXPERT_FRAME_DURATION(x) OPUS_GET_EXPERT_FRAME_DURATION_REQUEST, __opus_check_int_ptr(x)

#define OPUS_SET_PREDICTION_DISABLED(x) OPUS_SET_PREDICTION_DISABLED_REQUEST, __opus_check_int(x)

#define OPUS_GET_PREDICTION_DISABLED(x) OPUS_GET_PREDICTION_DISABLED_REQUEST, __opus_check_int_ptr(x)

#define OPUS_RESET_STATE 4028

#define OPUS_GET_FINAL_RANGE(x) OPUS_GET_FINAL_RANGE_REQUEST, __opus_check_uint_ptr(x)

#define OPUS_GET_BANDWIDTH(x) OPUS_GET_BANDWIDTH_REQUEST, __opus_check_int_ptr(x)

#define OPUS_GET_SAMPLE_RATE(x) OPUS_GET_SAMPLE_RATE_REQUEST, __opus_check_int_ptr(x)

#define OPUS_SET_GAIN(x) OPUS_SET_GAIN_REQUEST, __opus_check_int(x)

#define OPUS_GET_GAIN(x) OPUS_GET_GAIN_REQUEST, __opus_check_int_ptr(x)

#define OPUS_GET_LAST_PACKET_DURATION(x) OPUS_GET_LAST_PACKET_DURATION_REQUEST, __opus_check_int_ptr(x)

#define OPUS_GET_PITCH(x) OPUS_GET_PITCH_REQUEST, __opus_check_int_ptr(x)

OPUS_EXPORT const char *opus_strerror(int error);

OPUS_EXPORT const char *opus_get_version_string(void);

#ifdef __cplusplus
}
#endif

#endif

#ifndef WEBP_WEBP_TYPES_H_
#define WEBP_WEBP_TYPES_H_

#include <stddef.h>

#ifndef _MSC_VER
#include <inttypes.h>
#ifdef __STRICT_ANSI__
#define WEBP_INLINE
#else
#define WEBP_INLINE inline
#endif
#else
typedef signed   char int8_t;
typedef unsigned char uint8_t;
typedef signed   short int16_t;
typedef unsigned short uint16_t;
typedef signed   int int32_t;
typedef unsigned int uint32_t;
typedef unsigned long long int uint64_t;
typedef long long int int64_t;
#define WEBP_INLINE __forceinline
#endif

#ifndef WEBP_EXTERN

#define WEBP_EXTERN(type) extern type
#endif

#define WEBP_ABI_IS_INCOMPATIBLE(a, b) (((a) >> 8) != ((b) >> 8))

#endif

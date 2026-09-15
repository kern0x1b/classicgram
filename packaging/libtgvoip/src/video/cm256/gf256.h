#ifndef GF256_H
#define GF256_H

#include <stdint.h>
#include <string.h>
#include "export.h"

#if defined(USE_SSSE3)

#ifdef _MSC_VER

    #define GF256_M128 __m128i

    #define GF256_RESTRICT_KW __restrict

    #define GF256_FORCE_INLINE __forceinline

    #define GF256_ALIGNED __declspec(align(16))

    #include <tmmintrin.h>
    #include <emmintrin.h>

#else

    #define GF256_M128 __m128i

    #define GF256_RESTRICT_KW __restrict__

    #define GF256_FORCE_INLINE __attribute__((always_inline)) inline

    #define GF256_ALIGNED __attribute__((aligned(16)))

    #include <x86intrin.h>

#endif

#elif defined(USE_NEON)

    #include "sse2neon.h"

    #define GF256_M128 __m128i

    #define GF256_RESTRICT_KW __restrict__

    #define GF256_FORCE_INLINE __attribute__((always_inline)) inline

    #define GF256_ALIGNED __attribute__((aligned(16)))

#endif

#if defined(NO_RESTRICT)
    #define GF256_RESTRICT
#else
    #define GF256_RESTRICT GF256_RESTRICT_KW
#endif

#ifndef nullptr
    #define nullptr NULL
#endif

#ifdef _MSC_VER
    #pragma warning(push)
    #pragma warning(disable: 4324)
#endif

class CM256CC_API gf256_ctx
{
public:
    gf256_ctx();
    ~gf256_ctx();

    bool isInitialized() const { return initialized; }

    static void gf256_add_mem(void * GF256_RESTRICT vx, const void * GF256_RESTRICT vy, int bytes);

    static void gf256_add2_mem(void * GF256_RESTRICT vz, const void * GF256_RESTRICT vx, const void * GF256_RESTRICT vy, int bytes);

    static void gf256_addset_mem(void * GF256_RESTRICT vz, const void * GF256_RESTRICT vx, const void * GF256_RESTRICT vy, int bytes);

    static void gf256_memswap(void * GF256_RESTRICT vx, void * GF256_RESTRICT vy, int bytes);

    static GF256_FORCE_INLINE uint8_t gf256_add(const uint8_t x, const uint8_t y)
    {
        return x ^ y;
    }

    GF256_FORCE_INLINE uint8_t gf256_mul(uint8_t x, uint8_t y)
    {
        return GF256_MUL_TABLE[((unsigned)y << 8) + x];
    }

    GF256_FORCE_INLINE uint8_t gf256_div(uint8_t x, uint8_t y)
    {
        return GF256_DIV_TABLE[((unsigned)y << 8) + x];
    }

    GF256_FORCE_INLINE uint8_t gf256_inv(uint8_t x)
    {
        return GF256_INV_TABLE[x];
    }

    GF256_FORCE_INLINE unsigned char getMatrixElement(const unsigned char x_i, const unsigned char x_0, const unsigned char y_j)
    {
        return gf256_div(gf256_add(y_j, x_0), gf256_add(x_i, y_j));
    }

    void gf256_mul_mem(void * GF256_RESTRICT vz, const void * GF256_RESTRICT vx, uint8_t y, int bytes);

    void gf256_muladd_mem(void * GF256_RESTRICT vz, uint8_t y, const void * GF256_RESTRICT vx, int bytes);

    GF256_FORCE_INLINE void gf256_div_mem(void * GF256_RESTRICT vz,
                                                 const void * GF256_RESTRICT vx, uint8_t y, int bytes)
    {
        gf256_mul_mem(vz, vx, GF256_INV_TABLE[y], bytes);
    }

    unsigned Polynomial;

    uint16_t GF256_LOG_TABLE[256];
    uint8_t GF256_EXP_TABLE[512 * 2 + 1];

    uint8_t GF256_MUL_TABLE[256 * 256];
    uint8_t GF256_DIV_TABLE[256 * 256];
    uint8_t GF256_INV_TABLE[256];

    GF256_ALIGNED GF256_M128 MM256_TABLE_LO_Y[256];
    GF256_ALIGNED GF256_M128 MM256_TABLE_HI_Y[256];

private:
    int gf256_init_();

    void gf255_poly_init(int polynomialIndex);
    void gf256_explog_init();
    void gf256_muldiv_init();
    void gf256_inv_init();
    void gf256_muladd_mem_init();

    static bool IsLittleEndian()
    {
        int x = 1;
        char *y = (char *) &x;

        return *y != 0;
    }

    static const int GF256_GEN_POLY_COUNT = 16;
    static const uint8_t GF256_GEN_POLY[GF256_GEN_POLY_COUNT];
    static const int DefaultPolynomialIndex = 3;

    bool initialized;
};

#ifdef _MSC_VER
    #pragma warning(pop)
#endif

#endif

#ifndef CM256_H
#define CM256_H

#include <assert.h>
#include "gf256.h"
#include "export.h"

class CM256CC_API CM256
{
public:

    typedef struct cm256_encoder_params_t {
        int OriginalCount;

        int RecoveryCount;

        int BlockBytes;
    } cm256_encoder_params;

    typedef struct cm256_block_t {
        void* Block;

        unsigned char Index;

    } cm256_block;

    CM256();
    ~CM256();

    bool isInitialized() const { return m_initialized; };

    int cm256_encode(
        cm256_encoder_params params,
        cm256_block* originals,
        void* recoveryBlocks);

    int cm256_decode(
        cm256_encoder_params params,
        cm256_block* blocks);

    static inline unsigned char cm256_get_recovery_block_index(cm256_encoder_params params, int recoveryBlockIndex)
    {
        assert(recoveryBlockIndex >= 0 && recoveryBlockIndex < params.RecoveryCount);
        return (unsigned char)(params.OriginalCount + recoveryBlockIndex);
    }
    static inline unsigned char cm256_get_original_block_index(cm256_encoder_params params, int originalBlockIndex)
    {
        (void) params;
        assert(originalBlockIndex >= 0 && originalBlockIndex < params.OriginalCount);
        return (unsigned char)(originalBlockIndex);
    }

private:
    class CM256CC_API CM256Decoder
    {
    public:
        CM256Decoder(gf256_ctx& gf256Ctx);
        ~CM256Decoder();

        cm256_encoder_params Params;

        cm256_block* Recovery[256];
        int RecoveryCount;

        cm256_block* Original[256];
        int OriginalCount;

        uint8_t ErasuresIndices[256];

        bool Initialize(cm256_encoder_params& params, cm256_block* blocks);

        void DecodeM1();

        void Decode();

        void GenerateLDUDecomposition(uint8_t* matrix_L, uint8_t* diag_D, uint8_t* matrix_U);

    private:
        gf256_ctx& m_gf256Ctx;
    };

    void cm256_encode_block(
        cm256_encoder_params params,
        cm256_block* originals,
        int recoveryBlockIndex,
        void* recoveryBlock);

    gf256_ctx m_gf256Ctx;
    bool m_initialized;
};

#endif

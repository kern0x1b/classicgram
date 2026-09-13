#ifndef WEBP_WEBP_ENCODE_H_
#define WEBP_WEBP_ENCODE_H_

#include "./types.h"

#ifdef __cplusplus
extern "C" {
#endif

#define WEBP_ENCODER_ABI_VERSION 0x0202

typedef struct WebPConfig WebPConfig;
typedef struct WebPPicture WebPPicture;
typedef struct WebPAuxStats WebPAuxStats;
typedef struct WebPMemoryWriter WebPMemoryWriter;

WEBP_EXTERN(int) WebPGetEncoderVersion(void);

WEBP_EXTERN(size_t) WebPEncodeRGB(const uint8_t* rgb,
                                  int width, int height, int stride,
                                  float quality_factor, uint8_t** output);
WEBP_EXTERN(size_t) WebPEncodeBGR(const uint8_t* bgr,
                                  int width, int height, int stride,
                                  float quality_factor, uint8_t** output);
WEBP_EXTERN(size_t) WebPEncodeRGBA(const uint8_t* rgba,
                                   int width, int height, int stride,
                                   float quality_factor, uint8_t** output);
WEBP_EXTERN(size_t) WebPEncodeBGRA(const uint8_t* bgra,
                                   int width, int height, int stride,
                                   float quality_factor, uint8_t** output);

WEBP_EXTERN(size_t) WebPEncodeLosslessRGB(const uint8_t* rgb,
                                          int width, int height, int stride,
                                          uint8_t** output);
WEBP_EXTERN(size_t) WebPEncodeLosslessBGR(const uint8_t* bgr,
                                          int width, int height, int stride,
                                          uint8_t** output);
WEBP_EXTERN(size_t) WebPEncodeLosslessRGBA(const uint8_t* rgba,
                                           int width, int height, int stride,
                                           uint8_t** output);
WEBP_EXTERN(size_t) WebPEncodeLosslessBGRA(const uint8_t* bgra,
                                           int width, int height, int stride,
                                           uint8_t** output);

typedef enum WebPImageHint {
  WEBP_HINT_DEFAULT = 0,
  WEBP_HINT_PICTURE,
  WEBP_HINT_PHOTO,
  WEBP_HINT_GRAPH,
  WEBP_HINT_LAST
} WebPImageHint;

struct WebPConfig {
  int lossless;
  float quality;
  int method;

  WebPImageHint image_hint;

  int target_size;

  float target_PSNR;

  int segments;
  int sns_strength;
  int filter_strength;
  int filter_sharpness;
  int filter_type;

  int autofilter;
  int alpha_compression;

  int alpha_filtering;

  int alpha_quality;

  int pass;

  int show_compressed;

  int preprocessing;

  int partitions;

  int partition_limit;

  int emulate_jpeg_size;

  int thread_level;
  int low_memory;

  uint32_t pad[5];
};

typedef enum WebPPreset {
  WEBP_PRESET_DEFAULT = 0,
  WEBP_PRESET_PICTURE,
  WEBP_PRESET_PHOTO,
  WEBP_PRESET_DRAWING,
  WEBP_PRESET_ICON,
  WEBP_PRESET_TEXT
} WebPPreset;

WEBP_EXTERN(int) WebPConfigInitInternal(WebPConfig*, WebPPreset, float, int);

static WEBP_INLINE int WebPConfigInit(WebPConfig* config) {
  return WebPConfigInitInternal(config, WEBP_PRESET_DEFAULT, 75.f,
                                WEBP_ENCODER_ABI_VERSION);
}

static WEBP_INLINE int WebPConfigPreset(WebPConfig* config,
                                        WebPPreset preset, float quality) {
  return WebPConfigInitInternal(config, preset, quality,
                                WEBP_ENCODER_ABI_VERSION);
}

WEBP_EXTERN(int) WebPValidateConfig(const WebPConfig* config);

struct WebPAuxStats {
  int coded_size;

  float PSNR[5];
  int block_count[3];
  int header_bytes[2];

  int residual_bytes[3][4];

  int segment_size[4];
  int segment_quant[4];
  int segment_level[4];

  int alpha_data_size;
  int layer_data_size;

  uint32_t lossless_features;

  int histogram_bits;
  int transform_bits;
  int cache_bits;
  int palette_size;
  int lossless_size;

  uint32_t pad[4];
};

typedef int (*WebPWriterFunction)(const uint8_t* data, size_t data_size,
                                  const WebPPicture* picture);

struct WebPMemoryWriter {
  uint8_t* mem;
  size_t   size;
  size_t   max_size;
  uint32_t pad[1];
};

WEBP_EXTERN(void) WebPMemoryWriterInit(WebPMemoryWriter* writer);

WEBP_EXTERN(int) WebPMemoryWrite(const uint8_t* data, size_t data_size,
                                 const WebPPicture* picture);

typedef int (*WebPProgressHook)(int percent, const WebPPicture* picture);

typedef enum WebPEncCSP {
  WEBP_YUV420 = 0,
  WEBP_YUV422 = 1,
  WEBP_YUV444 = 2,
  WEBP_YUV400 = 3,
  WEBP_CSP_UV_MASK = 3,

  WEBP_YUV420A = 4,
  WEBP_YUV422A = 5,
  WEBP_YUV444A = 6,
  WEBP_YUV400A = 7,
  WEBP_CSP_ALPHA_BIT = 4
} WebPEncCSP;

typedef enum WebPEncodingError {
  VP8_ENC_OK = 0,
  VP8_ENC_ERROR_OUT_OF_MEMORY,
  VP8_ENC_ERROR_BITSTREAM_OUT_OF_MEMORY,
  VP8_ENC_ERROR_NULL_PARAMETER,
  VP8_ENC_ERROR_INVALID_CONFIGURATION,
  VP8_ENC_ERROR_BAD_DIMENSION,
  VP8_ENC_ERROR_PARTITION0_OVERFLOW,
  VP8_ENC_ERROR_PARTITION_OVERFLOW,
  VP8_ENC_ERROR_BAD_WRITE,
  VP8_ENC_ERROR_FILE_TOO_BIG,
  VP8_ENC_ERROR_USER_ABORT,
  VP8_ENC_ERROR_LAST
} WebPEncodingError;

#define WEBP_MAX_DIMENSION 16383

struct WebPPicture {
  int use_argb;

  WebPEncCSP colorspace;
  int width, height;
  uint8_t *y, *u, *v;
  int y_stride, uv_stride;
  uint8_t* a;
  int a_stride;
  uint32_t pad1[2];

  uint32_t* argb;
  int argb_stride;
  uint32_t pad2[3];

  WebPWriterFunction writer;
  void* custom_ptr;

  int extra_info_type;

  uint8_t* extra_info;

  WebPAuxStats* stats;

  WebPEncodingError error_code;

  WebPProgressHook progress_hook;

  void* user_data;

  uint32_t pad3[3];

  uint8_t *u0, *v0;
  int uv0_stride;

  uint32_t pad4[7];

  void* memory_;
  void* memory_argb_;
  void* pad5[2];
};

WEBP_EXTERN(int) WebPPictureInitInternal(WebPPicture*, int);

static WEBP_INLINE int WebPPictureInit(WebPPicture* picture) {
  return WebPPictureInitInternal(picture, WEBP_ENCODER_ABI_VERSION);
}

WEBP_EXTERN(int) WebPPictureAlloc(WebPPicture* picture);

WEBP_EXTERN(void) WebPPictureFree(WebPPicture* picture);

WEBP_EXTERN(int) WebPPictureCopy(const WebPPicture* src, WebPPicture* dst);

WEBP_EXTERN(int) WebPPictureDistortion(
    const WebPPicture* src, const WebPPicture* ref,
    int metric_type,
    float result[5]);

WEBP_EXTERN(int) WebPPictureCrop(WebPPicture* picture,
                                 int left, int top, int width, int height);

WEBP_EXTERN(int) WebPPictureView(const WebPPicture* src,
                                 int left, int top, int width, int height,
                                 WebPPicture* dst);

WEBP_EXTERN(int) WebPPictureIsView(const WebPPicture* picture);

WEBP_EXTERN(int) WebPPictureRescale(WebPPicture* pic, int width, int height);

WEBP_EXTERN(int) WebPPictureImportRGB(
    WebPPicture* picture, const uint8_t* rgb, int rgb_stride);

WEBP_EXTERN(int) WebPPictureImportRGBA(
    WebPPicture* picture, const uint8_t* rgba, int rgba_stride);

WEBP_EXTERN(int) WebPPictureImportRGBX(
    WebPPicture* picture, const uint8_t* rgbx, int rgbx_stride);

WEBP_EXTERN(int) WebPPictureImportBGR(
    WebPPicture* picture, const uint8_t* bgr, int bgr_stride);
WEBP_EXTERN(int) WebPPictureImportBGRA(
    WebPPicture* picture, const uint8_t* bgra, int bgra_stride);
WEBP_EXTERN(int) WebPPictureImportBGRX(
    WebPPicture* picture, const uint8_t* bgrx, int bgrx_stride);

WEBP_EXTERN(int) WebPPictureARGBToYUVA(WebPPicture* picture,
                                       WebPEncCSP colorspace);

WEBP_EXTERN(int) WebPPictureARGBToYUVADithered(
    WebPPicture* picture, WebPEncCSP colorspace, float dithering);

WEBP_EXTERN(int) WebPPictureYUVAToARGB(WebPPicture* picture);

WEBP_EXTERN(void) WebPCleanupTransparentArea(WebPPicture* picture);

WEBP_EXTERN(int) WebPPictureHasTransparency(const WebPPicture* picture);

WEBP_EXTERN(void) WebPBlendAlpha(WebPPicture* pic, uint32_t background_rgb);

WEBP_EXTERN(int) WebPEncode(const WebPConfig* config, WebPPicture* picture);

#ifdef __cplusplus
}
#endif

#endif

#ifndef LIBTGVOIP_TGVP8CODEC_H
#define LIBTGVOIP_TGVP8CODEC_H

#include <stdint.h>
#include <vector>
#include "../Buffers.h"

namespace tgvoip{
	namespace video{
		class TGVP8Encoder{
		public:
			TGVP8Encoder();
			~TGVP8Encoder();
			bool Open(unsigned int width, unsigned int height, unsigned int fps, uint32_t bitrateBps, int cpuUsed);
			void Close();
			void SetBitrate(uint32_t bitrateBps);
			void RequestKeyFrame();
			bool EncodeI420(const uint8_t* yPlane, int yStride,
							 const uint8_t* uPlane, int uStride,
							 const uint8_t* vPlane, int vStride,
							 int64_t ptsUs,
							 std::vector<Buffer>& outPackets, bool& outKeyframe);
			unsigned int width=0;
			unsigned int height=0;
			double lastEncodeMs=0;
			uint32_t framesEncoded=0;
			uint32_t framesDropped=0;
		private:
			void* ctx=nullptr;
			void* img=nullptr;
			bool opened=false;
			bool keyframeRequested=true;
			uint32_t currentBitrate=0;
			int64_t frameIndex=0;
		};

		class TGVP8Decoder{
		public:
			TGVP8Decoder();
			~TGVP8Decoder();
			bool Open();
			void Close();
			bool DecodeToI420(const uint8_t* data, size_t length,
							   const uint8_t** outY, int* outYStride,
							   const uint8_t** outU, int* outUStride,
							   const uint8_t** outV, int* outVStride,
							   unsigned int* outWidth, unsigned int* outHeight);
			double lastDecodeMs=0;
			uint32_t framesDecoded=0;
			uint32_t framesFailed=0;
		private:
			void* ctx=nullptr;
			bool opened=false;
		};

	}
}

#endif

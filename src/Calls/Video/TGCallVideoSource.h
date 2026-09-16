#ifndef LIBTGVOIP_TGCALLVIDEOSOURCE_H
#define LIBTGVOIP_TGCALLVIDEOSOURCE_H

#include "libtgvoip/video/VideoSource.h"
#include "TGVP8Codec.h"
#include <CoreVideo/CoreVideo.h>
#include <functional>
#include <vector>

namespace tgvoip{
	namespace video{
		class TGCallVideoSource : public VideoSource{
		public:
			TGCallVideoSource();
			virtual ~TGCallVideoSource();
			virtual void Start() override;
			virtual void Stop() override;
			virtual void Reset(uint32_t codec, int maxResolution) override;
			virtual void RequestKeyFrame() override;
			virtual void SetBitrate(uint32_t bitrate) override;

			void PushPixelBuffer(CVPixelBufferRef pixelBuffer, int64_t ptsUs);

			std::function<void(double encodeMs, uint32_t framesEncoded, uint32_t framesDropped)> statsCallback;

		private:
			void EncodeWithVP8(CVPixelBufferRef pixelBuffer, int64_t ptsUs);

			uint32_t codec=0;
			bool running=false;
			uint32_t targetBitrate=220*1024;
			unsigned int targetWidth=320;
			unsigned int targetHeight=240;

			TGVP8Encoder vp8;

			std::vector<uint8_t> chromaScratchU;
			std::vector<uint8_t> chromaScratchV;

			uint32_t framesSinceLog=0;
			double lastStatsLogAt=0;
		};

	}
}

#endif

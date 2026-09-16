#ifndef LIBTGVOIP_TGCALLVIDEORENDERER_H
#define LIBTGVOIP_TGCALLVIDEORENDERER_H

#include "libtgvoip/video/VideoRenderer.h"
#include "TGVP8Codec.h"
#include <functional>
#include <vector>

namespace tgvoip{
	namespace video{
		class TGCallVideoRenderer : public VideoRenderer{
		public:
			TGCallVideoRenderer();
			virtual ~TGCallVideoRenderer();
			virtual void Reset(uint32_t codec, unsigned int width, unsigned int height, std::vector<Buffer>& csd) override;
			virtual void DecodeAndDisplay(Buffer frame, uint32_t pts) override;
			virtual void SetStreamEnabled(bool enabled) override;

			std::function<void(const uint8_t* bgra, unsigned int width, unsigned int height, int bytesPerRow)> frameCallback;
			std::function<void(double decodeMs, uint32_t decoded, uint32_t failed)> statsCallback;

		private:
			void DecodeWithVP8(Buffer& frame);

			uint32_t codec=0;
			bool enabled=true;

			TGVP8Decoder vp8;

			std::vector<uint8_t> bgraScratch;

			uint32_t framesSinceLog=0;
			double lastStatsLogAt=0;
		};

	}
}

#endif

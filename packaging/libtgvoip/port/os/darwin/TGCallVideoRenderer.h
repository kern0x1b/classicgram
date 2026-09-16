#ifndef LIBTGVOIP_TGCALLVIDEORENDERER_H
#define LIBTGVOIP_TGCALLVIDEORENDERER_H

#include "../../video/VideoRenderer.h"
#include "../../video/TGVP8Codec.h"
#include <CoreVideo/CoreVideo.h>
#include <CoreMedia/CoreMedia.h>
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
			virtual void SetRotation(uint16_t rotation) override;
			virtual void SetStreamPaused(bool paused) override;

			std::function<void(const uint8_t* bgra, unsigned int width, unsigned int height, int bytesPerRow)> frameCallback;
			std::function<void(double decodeMs, uint32_t decoded, uint32_t failed)> statsCallback;

			void VTDecoderCallback(OSStatus status, CVImageBufferRef imageBuffer);

		private:
			void OpenVideoToolbox(std::vector<Buffer>& csd);
			void CloseVideoToolbox();
			void DecodeWithVideoToolbox(Buffer& frame);
			void DecodeWithVP8(Buffer& frame);
			void DeliverBGRAFromPixelBuffer(CVPixelBufferRef pixelBuffer);

			uint32_t codec=0;
			unsigned int frameWidth=0;
			unsigned int frameHeight=0;
			bool enabled=true;
			bool paused=false;

			void* vtSession=nullptr;
			void* formatDesc=nullptr;
			TGVP8Decoder vp8;

			std::vector<uint8_t> bgraScratch;

			double emaDecodeMs=0;
			uint32_t framesSinceLog=0;
			double lastStatsLogAt=0;
		};

	}
}

#endif

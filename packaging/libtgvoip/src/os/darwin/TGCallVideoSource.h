#ifndef LIBTGVOIP_TGCALLVIDEOSOURCE_H
#define LIBTGVOIP_TGCALLVIDEOSOURCE_H

#include "../../video/VideoSource.h"
#include "../../video/TGVP8Codec.h"
#include <CoreVideo/CoreVideo.h>
#include <CoreMedia/CoreMedia.h>
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

			void VTEncoderCallback(OSStatus status, CMSampleBufferRef sampleBuffer, uint32_t vtFlags);

		private:
			void OpenVideoToolbox();
			void CloseVideoToolbox();
			void EncodeWithVideoToolbox(CVPixelBufferRef pixelBuffer, int64_t ptsUs);
			void EncodeWithVP8(CVPixelBufferRef pixelBuffer, int64_t ptsUs);
			void UpdateCSDFromFormatDescription(CMFormatDescriptionRef format);
			void SetEncoderBitrateAndLimit(uint32_t bitrate);

			uint32_t codec=0;
			bool running=false;
			bool needCSD=true;
			bool keyframeRequested=true;
			uint32_t targetBitrate=220*1024;
			unsigned int targetWidth=320;
			unsigned int targetHeight=240;
			unsigned int targetFps=15;

			void* vtSession=nullptr;
			TGVP8Encoder vp8;

			std::vector<uint8_t> chromaScratchU;
			std::vector<uint8_t> chromaScratchV;

			double emaEncodeMs=0;
			uint32_t framesSinceLog=0;
			double lastStatsLogAt=0;
		};

	}
}

#endif

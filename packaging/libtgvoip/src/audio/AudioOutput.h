#ifndef LIBTGVOIP_AUDIOOUTPUT_H
#define LIBTGVOIP_AUDIOOUTPUT_H

#include <stdint.h>
#include <string>
#include <vector>
#include <memory>
#include "../MediaStreamItf.h"

namespace tgvoip{
class AudioInputDevice;
class AudioOutputDevice;

namespace audio{
class AudioOutput : public MediaStreamItf{
public:
	AudioOutput();
	AudioOutput(std::string deviceID);
	virtual ~AudioOutput();
	virtual bool IsPlaying()=0;
	static int32_t GetEstimatedDelay();
	virtual std::string GetCurrentDevice();
	virtual void SetCurrentDevice(std::string deviceID);

	static void EnumerateDevices(std::vector<AudioOutputDevice>& devs);
	bool IsInitialized();

protected:
	std::string currentDevice;
	bool failed;
	static int32_t estimatedDelay;
};
}}

#endif

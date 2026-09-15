#include "VideoSource.h"

using namespace tgvoip;
using namespace tgvoip::video;

bool VideoSource::Failed(){
	return failed;
}

std::string VideoSource::GetErrorDescription(){
	return error;
}

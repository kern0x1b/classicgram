#import "TGLiveLocationMessageIdRemap.h"

int64_t TGRemappedLiveLocationMessageId(int64_t currentLiveLocationMessageId, int64_t oldMessageId, int64_t newMessageId) {
	if (!oldMessageId || !newMessageId)
		return currentLiveLocationMessageId;
	if (currentLiveLocationMessageId != oldMessageId)
		return currentLiveLocationMessageId;
	return newMessageId;
}

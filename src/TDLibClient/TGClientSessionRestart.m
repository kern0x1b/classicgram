#import "TGClientSessionRestart.h"

BOOL TGSessionNeedsRestartForDiskCaches(BOOL running, BOOL parametersSent,
	BOOL parametersUsedDiskCaches, BOOL diskCachesWantedNow, BOOL callInProgress) {
	if (!running || !parametersSent)
		return NO;
	if (parametersUsedDiskCaches || !diskCachesWantedNow)
		return NO;
	return !callInProgress;
}

#import "TGPerfLogging.h"

static volatile BOOL TGPerfLoggingOn = NO;

BOOL TGPerfLogging(void) {
	return TGPerfLoggingOn;
}

void TGSetPerfLogging(BOOL enabled) {
	TGPerfLoggingOn = enabled;
}

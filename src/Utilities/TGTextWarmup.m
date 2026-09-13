#import "TGTextWarmup.h"

static dispatch_semaphore_t TGTextWarmGate(void) {
	static dispatch_semaphore_t gate = NULL;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		gate = dispatch_semaphore_create(0);
	});
	return gate;
}

void TGWaitForTextWarm(void) {
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		dispatch_semaphore_wait(TGTextWarmGate(),
			dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)));
	});
}

void TGNoteTextWarm(void) {
	dispatch_semaphore_signal(TGTextWarmGate());
}

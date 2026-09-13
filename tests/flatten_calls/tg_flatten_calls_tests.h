#ifndef TG_HOST_TESTS_FLATTEN_CALLS_TESTS_H
#define TG_HOST_TESTS_FLATTEN_CALLS_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGFlattenCallsTestMapsEcho(void);
TGTestOutcome TGFlattenCallsTestMapsNoise(void);
TGTestOutcome TGFlattenCallsTestMapsInterruptions(void);
TGTestOutcome TGFlattenCallsTestMapsDistortedSpeech(void);
TGTestOutcome TGFlattenCallsTestMapsSilentLocal(void);
TGTestOutcome TGFlattenCallsTestMapsSilentRemote(void);
TGTestOutcome TGFlattenCallsTestMapsDropped(void);
TGTestOutcome TGFlattenCallsTestMapsDistortedVideo(void);
TGTestOutcome TGFlattenCallsTestMapsPixelatedVideo(void);
TGTestOutcome TGFlattenCallsTestUnknownKeyReturnsNil(void);
TGTestOutcome TGFlattenCallsTestNilArgumentReturnsNil(void);
TGTestOutcome TGFlattenCallsTestWrongTypeArgumentReturnsNil(void);

#endif

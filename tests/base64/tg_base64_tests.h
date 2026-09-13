#ifndef TG_HOST_TESTS_BASE64_TESTS_H
#define TG_HOST_TESTS_BASE64_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGBase64TestEncodeMatchesTheKnownVectors(void);
TGTestOutcome TGBase64TestEncodePadsEveryTailLength(void);
TGTestOutcome TGBase64TestRoundTripsEveryByteValue(void);
TGTestOutcome TGBase64TestEncodeToleratesNilAndEmpty(void);

#endif

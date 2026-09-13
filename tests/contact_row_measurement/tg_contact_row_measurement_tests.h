#ifndef TG_HOST_TESTS_CONTACT_ROW_MEASUREMENT_TESTS_H
#define TG_HOST_TESTS_CONTACT_ROW_MEASUREMENT_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGContactRowMeasurementTestTheSameRowKeepsItsMeasurement(void);
TGTestOutcome TGContactRowMeasurementTestAnyChangedInputThrowsItAway(void);

#endif

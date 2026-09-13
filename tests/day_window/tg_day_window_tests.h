#ifndef TG_HOST_TESTS_DAY_WINDOW_TESTS_H
#define TG_HOST_TESTS_DAY_WINDOW_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGDayWindowTestAnOrdinaryDayHoldsItsOwnHours(void);
TGTestOutcome TGDayWindowTestTheLongDayHoldsTwentyFiveHours(void);
TGTestOutcome TGDayWindowTestTheShortDayHoldsTwentyThree(void);
TGTestOutcome TGDayWindowTestBeforeTheDayIsNeverInIt(void);

#endif

#ifndef TG_HOST_TESTS_CLOCK_MARKER_TESTS_H
#define TG_HOST_TESTS_CLOCK_MARKER_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGClockMarkerTestEnglishMarkerIsFound(void);
TGTestOutcome TGClockMarkerTestLowercaseMarkerIsFound(void);
TGTestOutcome TGClockMarkerTestLocalisedMarkerIsFound(void);
TGTestOutcome TGClockMarkerTestTwentyFourHourTimeHasNoMarker(void);
TGTestOutcome TGClockMarkerTestBodyKeepsTheTimeAndDropsTheSpace(void);
TGTestOutcome TGClockMarkerTestMissingInputIsHandled(void);

#endif

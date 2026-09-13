#ifndef TG_HOST_TESTS_FRAME_TIME_WINDOW_TESTS_H
#define TG_HOST_TESTS_FRAME_TIME_WINDOW_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGFrameTimeWindowTestASteadyRunReportsItsRate(void);
TGTestOutcome TGFrameTimeWindowTestALateFrameIsCountedAndKept(void);
TGTestOutcome TGFrameTimeWindowTestNonsenseDeltasAreIgnored(void);

#endif

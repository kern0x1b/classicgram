#ifndef TG_HOST_TESTS_LAUNCH_SCREEN_CHOICE_TESTS_H
#define TG_HOST_TESTS_LAUNCH_SCREEN_CHOICE_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGLaunchScreenChoiceTestShowsTheScreenTheAuthStateAsksFor(void);
TGTestOutcome TGLaunchScreenChoiceTestOnlySpinsWhileTheStateIsUnknown(void);

#endif

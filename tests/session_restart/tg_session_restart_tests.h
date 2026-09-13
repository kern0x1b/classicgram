#ifndef TG_HOST_TESTS_SESSION_RESTART_TESTS_H
#define TG_HOST_TESTS_SESSION_RESTART_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGSessionRestartTestRestartsTheCacheLessBackgroundSession(void);
TGTestOutcome TGSessionRestartTestLeavesEveryOtherSessionAlone(void);

#endif

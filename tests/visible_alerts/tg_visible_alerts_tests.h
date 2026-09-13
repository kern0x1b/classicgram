#ifndef TG_HOST_TESTS_VISIBLE_ALERTS_TESTS_H
#define TG_HOST_TESTS_VISIBLE_ALERTS_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGVisibleAlertsTestFindsAlertsAnywhereInTheWindows(void);
TGTestOutcome TGVisibleAlertsTestDismissesThemAndDropsTheirDelegates(void);

#endif

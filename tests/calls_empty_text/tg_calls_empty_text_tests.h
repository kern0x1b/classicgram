#ifndef TG_HOST_TESTS_CALLS_EMPTY_TEXT_TESTS_H
#define TG_HOST_TESTS_CALLS_EMPTY_TEXT_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGCallsEmptyTextTestAFailedHistorySaysSo(void);
TGTestOutcome TGCallsEmptyTextTestAnEmptyHistoryNamesItsFilter(void);
TGTestOutcome TGCallsEmptyTextTestNothingIsSaidWhileLoading(void);
TGTestOutcome TGCallsEmptyTextTestCallsOnScreenSayNothing(void);

#endif

#ifndef TG_HOST_TESTS_TABLE_RELOAD_COALESCER_TESTS_H
#define TG_HOST_TESTS_TABLE_RELOAD_COALESCER_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGTableReloadCoalescerTestManyArrivalsCostOneReload(void);
TGTestOutcome TGTableReloadCoalescerTestALaterArrivalReloadsAgain(void);

#endif

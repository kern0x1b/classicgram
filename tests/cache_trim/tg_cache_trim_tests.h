#ifndef TG_HOST_TESTS_CACHE_TRIM_TESTS_H
#define TG_HOST_TESTS_CACHE_TRIM_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGCacheTrimTestNothingGoesUntilTheCacheIsFull(void);
TGTestOutcome TGCacheTrimTestTheOldestRowsGoFirst(void);

#endif

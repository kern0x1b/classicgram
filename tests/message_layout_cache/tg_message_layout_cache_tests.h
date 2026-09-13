#ifndef TG_HOST_TESTS_MESSAGE_LAYOUT_CACHE_TESTS_H
#define TG_HOST_TESTS_MESSAGE_LAYOUT_CACHE_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGMessageLayoutCacheTestASecondLookIsTheSameLayout(void);
TGTestOutcome TGMessageLayoutCacheTestAFullCacheKeepsWhatWasReadLast(void);

#endif

#ifndef TG_HOST_TESTS_BLOCKED_LIST_PAGING_TESTS_H
#define TG_HOST_TESTS_BLOCKED_LIST_PAGING_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGBlockedListPagingTestAShortPageEndsTheList(void);
TGTestOutcome TGBlockedListPagingTestAFullPageKeepsGoingUntilTheTotalIsReached(void);

#endif

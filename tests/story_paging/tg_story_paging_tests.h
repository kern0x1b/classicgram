#ifndef TG_HOST_TESTS_STORY_PAGING_TESTS_H
#define TG_HOST_TESTS_STORY_PAGING_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGStoryPagingTestReportsMoreWhileTheServerTotalIsNotReached(void);
TGTestOutcome TGStoryPagingTestStopsOnAnEmptyPageOrAnUnknownTotal(void);

#endif

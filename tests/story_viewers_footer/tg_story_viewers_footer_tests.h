#ifndef TG_HOST_TESTS_STORY_VIEWERS_FOOTER_TESTS_H
#define TG_HOST_TESTS_STORY_VIEWERS_FOOTER_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGStoryViewersFooterTestAFailedLoadSaysSo(void);
TGTestOutcome TGStoryViewersFooterTestAnEmptyListIsNotAFailure(void);
TGTestOutcome TGStoryViewersFooterTestRowsSayNothing(void);
TGTestOutcome TGStoryViewersFooterTestRowsOutrankALaterFailure(void);

#endif

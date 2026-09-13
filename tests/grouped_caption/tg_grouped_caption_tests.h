#ifndef TG_HOST_TESTS_GROUPED_CAPTION_TESTS_H
#define TG_HOST_TESTS_GROUPED_CAPTION_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGGroupedCaptionTestASectionWithNoFooterKeepsItsGap(void);
TGTestOutcome TGGroupedCaptionTestAFooterIsAsTallAsItsText(void);
TGTestOutcome TGGroupedCaptionTestARowReadsAsTheOriginalDid(void);

#endif

#ifndef TG_HOST_TESTS_SECTION_HEADER_TITLE_TESTS_H
#define TG_HOST_TESTS_SECTION_HEADER_TITLE_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGSectionHeaderTitleTestAnEmptySectionHasNoHeader(void);
TGTestOutcome TGSectionHeaderTitleTestASectionWithRowsKeepsIts(void);
TGTestOutcome TGSectionHeaderTitleTestMissingTitleIsHandled(void);

#endif

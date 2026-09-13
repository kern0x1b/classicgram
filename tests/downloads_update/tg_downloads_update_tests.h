#ifndef TG_HOST_TESTS_DOWNLOADS_UPDATE_TESTS_H
#define TG_HOST_TESTS_DOWNLOADS_UPDATE_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGDownloadsUpdateTestSummaryReadsTheTotals(void);
TGTestOutcome TGDownloadsUpdateTestAnotherUpdateCarriesNoSummary(void);
TGTestOutcome TGDownloadsUpdateTestListMembershipDecidesTheReload(void);
TGTestOutcome TGDownloadsUpdateTestMissingInputIsHandled(void);

#endif

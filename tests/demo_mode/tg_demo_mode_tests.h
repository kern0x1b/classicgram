#ifndef TG_HOST_TESTS_DEMO_MODE_TESTS_H
#define TG_HOST_TESTS_DEMO_MODE_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGDemoModeTestReadsTheFlag(void);
TGTestOutcome TGDemoModeTestAnswersTheRequestsAScreenNeeds(void);
TGTestOutcome TGDemoModeTestTransportKeepsTheRequestExtra(void);
TGTestOutcome TGDemoModeTestCarriesNoRealAccountData(void);
TGTestOutcome TGDemoModeTestShowsEveryKindOfMessage(void);
TGTestOutcome TGDemoModeTestServesItsOwnFiles(void);

#endif

#ifndef TG_HOST_TESTS_FAILED_MESSAGE_TITLE_TESTS_H
#define TG_HOST_TESTS_FAILED_MESSAGE_TITLE_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGFailedMessageTitleTestAWireCodeIsNeverShown(void);
TGTestOutcome TGFailedMessageTitleTestASentenceIsKept(void);
TGTestOutcome TGFailedMessageTitleTestNoReasonFallsBack(void);

#endif

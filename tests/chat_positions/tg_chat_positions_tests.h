#ifndef TG_HOST_TESTS_CHAT_POSITIONS_TESTS_H
#define TG_HOST_TESTS_CHAT_POSITIONS_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGChatPositionsTestOrderArrivesAsAString(void);
TGTestOutcome TGChatPositionsTestEachListHasItsOwnOrder(void);
TGTestOutcome TGChatPositionsTestPinnedIsReadPerList(void);
TGTestOutcome TGChatPositionsTestAChatOutOfAListHasNoOrder(void);
TGTestOutcome TGChatPositionsTestMalformedPositionsAreIgnored(void);

#endif

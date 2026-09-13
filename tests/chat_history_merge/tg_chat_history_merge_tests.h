#ifndef TG_HOST_TESTS_CHAT_HISTORY_MERGE_TESTS_H
#define TG_HOST_TESTS_CHAT_HISTORY_MERGE_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGChatHistoryMergeTestPrependsOlderInOrder(void);
TGTestOutcome TGChatHistoryMergeTestRefusesPagesThatAddNothing(void);

#endif

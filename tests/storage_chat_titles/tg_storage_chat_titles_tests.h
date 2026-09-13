#ifndef TG_HOST_TESTS_STORAGE_CHAT_TITLES_TESTS_H
#define TG_HOST_TESTS_STORAGE_CHAT_TITLES_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGStorageChatTitlesTestAsksOnlyForTheRowsWithoutATitle(void);
TGTestOutcome TGStorageChatTitlesTestFillsTheResolvedTitlesAndKeepsTheRest(void);

#endif

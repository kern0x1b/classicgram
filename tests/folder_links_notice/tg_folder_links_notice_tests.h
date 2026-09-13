#ifndef TG_HOST_TESTS_FOLDER_LINKS_NOTICE_TESTS_H
#define TG_HOST_TESTS_FOLDER_LINKS_NOTICE_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGFolderLinksNoticeTestAFailedLoadSaysSo(void);
TGTestOutcome TGFolderLinksNoticeTestASuccessfulLoadSaysNothing(void);
TGTestOutcome TGFolderLinksNoticeTestLinksAlreadyKnownStaySilent(void);

#endif

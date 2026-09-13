#ifndef TG_HOST_TESTS_SETTING_VALUE_TEXT_TESTS_H
#define TG_HOST_TESTS_SETTING_VALUE_TEXT_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGSettingValueTextTestAFailedFetchIsNotAnAnswer(void);
TGTestOutcome TGSettingValueTextTestALoadedValueIsShown(void);
TGTestOutcome TGSettingValueTextTestAPendingFetchShowsDots(void);
TGTestOutcome TGSettingValueTextTestACountIsNotZeroWhenUnread(void);

#endif

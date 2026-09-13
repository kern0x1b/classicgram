#ifndef TG_HOST_TESTS_MESSAGE_REPLY_TESTS_H
#define TG_HOST_TESTS_MESSAGE_REPLY_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGMessageReplyTestNoReplyMeansNoReplyTo(void);
TGTestOutcome TGMessageReplyTestAPlainReplyCarriesOnlyTheMessageId(void);
TGTestOutcome TGMessageReplyTestAQuotedReplyCarriesTheQuoteAndItsEntities(void);

#endif

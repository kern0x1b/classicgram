#ifndef TG_HOST_TESTS_CONTACT_PHOTO_MATCH_TESTS_H
#define TG_HOST_TESTS_CONTACT_PHOTO_MATCH_TESTS_H

#import "../support/tg_test.h"

TGTestOutcome TGContactPhotoMatchTestARowWantsItsOwnPhoto(void);
TGTestOutcome TGContactPhotoMatchTestAnythingElseIsNotAMatch(void);
TGTestOutcome TGContactPhotoMatchTestARowKnowsItsOwnUser(void);

#endif

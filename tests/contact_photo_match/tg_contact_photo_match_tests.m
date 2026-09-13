#import "tg_contact_photo_match_tests.h"
#import "../../src/Screens/Contacts/TGContactPhotoMatch.h"

TGTestOutcome TGContactPhotoMatchTestARowWantsItsOwnPhoto(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *user = @{ @"id" : @(4242), @"photoFileId" : @(77) };
	TGTestExpectTrue(&outcome, TGContactRowWantsPhotoFileId(user, @(77)) == YES,
			"a row whose photo just arrived must take it");
	TGTestExpectTrue(&outcome, TGContactRowWantsPhotoFileId(user, @(78)) == NO,
			"a row must ignore another row's photo");

	return outcome;
}

TGTestOutcome TGContactPhotoMatchTestAnythingElseIsNotAMatch(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGContactRowWantsPhotoFileId(nil, @(77)) == NO,
			"a row with no user behind it takes nothing");
	TGTestExpectTrue(&outcome, TGContactRowWantsPhotoFileId(@{ @"id" : @(1) }, @(77)) == NO,
			"a row with no photo of its own takes nothing");
	TGTestExpectTrue(&outcome, TGContactRowWantsPhotoFileId(@{ @"photoFileId" : @"77" }, @(77)) == NO,
			"a photo id that arrived as a string is not silently compared as a number");
	TGTestExpectTrue(&outcome, TGContactRowWantsPhotoFileId(@{ @"photoFileId" : @(0) }, @(0)) == NO,
			"a row with no photo id must not match the absent-photo id");
	TGTestExpectTrue(&outcome, TGContactRowWantsPhotoFileId(@{ @"photoFileId" : @(77) }, nil) == NO,
			"nothing matches when no file arrived");

	return outcome;
}

TGTestOutcome TGContactPhotoMatchTestARowKnowsItsOwnUser(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *user = @{ @"id" : @(4242), @"photoFileId" : @(77) };
	TGTestExpectTrue(&outcome, TGContactRowIsUserId(user, @(4242)) == YES,
			"a row must take the answer that was asked for it");
	TGTestExpectTrue(&outcome, TGContactRowIsUserId(user, @(4243)) == NO,
			"a row must ignore another row's answer");
	TGTestExpectTrue(&outcome, TGContactRowIsUserId(nil, @(4242)) == NO,
			"a row with no user behind it takes nothing");
	TGTestExpectTrue(&outcome, TGContactRowIsUserId(@{ @"id" : @"4242" }, @(4242)) == NO,
			"an id that arrived as a string is not silently compared as a number");
	TGTestExpectTrue(&outcome, TGContactRowIsUserId(@{ @"id" : @(0) }, @(0)) == NO,
			"the absent id matches nothing");

	return outcome;
}

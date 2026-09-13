#import "tg_avatar_row_key_tests.h"
#import "../../src/Companions/TGAvatarRowKey.h"

TGTestOutcome TGAvatarRowKeyTestOnlyTheWaitingRowTakesThePhoto(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGAvatarRowKeyMatches(@(4242), @(4242)) == YES,
			"the row that asked for the photo takes it");
	TGTestExpectTrue(&outcome, TGAvatarRowKeyMatches(@(4242), @(9)) == NO,
			"another row does not redraw for it");
	TGTestExpectTrue(&outcome, TGAvatarRowKeyMatches(nil, @(4242)) == NO,
			"a row with no key of its own takes nothing");
	TGTestExpectTrue(&outcome, TGAvatarRowKeyMatches(@(0), @(0)) == NO,
			"the absent key matches nothing, so an empty row never redraws");
	TGTestExpectTrue(&outcome, TGAvatarRowKeyMatches(@(4242), nil) == NO,
			"nothing matches when no photo arrived");

	return outcome;
}

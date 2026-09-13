#import "tg_password_check_outcome_tests.h"

#import "../../src/Screens/Settings/TGPasswordCheckOutcome.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGPasswordCheckOutcomeTestWrongVersusNotChecked(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			TGPasswordCheckOutcomeForError(@"PASSWORD_HASH_INVALID", NO) ==
					TGPasswordCheckOutcomeWrongPassword,
			"the server saying the hash is wrong means the password is wrong");
	TGTestExpectTrue(&outcome,
			TGPasswordCheckOutcomeForError(@"Timeout", NO) == TGPasswordCheckOutcomeNotChecked,
			"a timeout means the password was never checked; the screen used to tell the reader "
			"their two-step password was wrong when the request had simply not arrived");
	TGTestExpectTrue(&outcome,
			TGPasswordCheckOutcomeForError(nil, NO) == TGPasswordCheckOutcomeNotChecked,
			"an error with no message at all is not evidence about the password");
	TGTestExpectTrue(&outcome,
			TGPasswordCheckOutcomeForError(@"FLOOD_WAIT_42", NO) == TGPasswordCheckOutcomeNotChecked,
			"and a flood wait says nothing about the password either");
	TGTestExpectTrue(&outcome,
			TGPasswordCheckOutcomeForError(nil, YES) == TGPasswordCheckOutcomeAccepted,
			"an answer that arrived is the password being accepted");

	return outcome;
}

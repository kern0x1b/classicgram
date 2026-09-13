#import "tg_form_save_state_tests.h"

#import "../../src/Utilities/TGFormSaveState.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGFormSaveStateTestAFailedReadIsNotAnEmptyForm(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGFormCanSave(YES, YES, NO),
			"a form whose state could not be read cannot be saved; saving the blank fields it "
			"would otherwise show writes an empty address, an empty greeting, an empty Close "
			"Friends list or a group with every permission off over the real one");
	TGTestExpectTrue(&outcome, !TGFormCanSave(NO, NO, NO),
			"and nothing saves before the state arrives");
	TGTestExpectTrue(&outcome, !TGFormCanSave(YES, NO, YES),
			"a form the account may not edit stays unsaveable even when it read fine");
	TGTestExpectTrue(&outcome, TGFormCanSave(YES, NO, NO),
			"a form that read its settings and may be edited saves");

	return outcome;
}

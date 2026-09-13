#import "tg_contact_row_measurement_tests.h"
#import "../../src/Screens/Contacts/Cells/TGContactRowMeasurement.h"

TGTestOutcome TGContactRowMeasurementTestTheSameRowKeepsItsMeasurement(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			TGContactRowMeasurementIsFresh(@"Oleksii", 19, 22, 260, @"Oleksii", 19, 22, 260) == YES,
			"the same name at the same size keeps its measurement across layout passes");
	TGTestExpectTrue(&outcome,
			TGContactRowMeasurementIsFresh(@"Oleksii", 19, 22, 260,
				[NSString stringWithFormat:@"Olek%@", @"sii"], 19, 22, 260) == YES,
			"an equal string built another way is still the same text");
	TGTestExpectTrue(&outcome,
			TGContactRowMeasurementIsFresh(nil, 0, 0, 0, nil, 0, 0, 0) == YES,
			"an empty row measured as empty stays measured");

	return outcome;
}

TGTestOutcome TGContactRowMeasurementTestAnyChangedInputThrowsItAway(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			TGContactRowMeasurementIsFresh(@"Oleksii", 19, 22, 260, @"Kseniia", 19, 22, 260) == NO,
			"a reused cell with another name must measure again");
	TGTestExpectTrue(&outcome,
			TGContactRowMeasurementIsFresh(@"Oleksii", 19, 22, 260, @"Oleksii", 17, 22, 260) == NO,
			"a smaller font must measure again");
	TGTestExpectTrue(&outcome,
			TGContactRowMeasurementIsFresh(@"Oleksii", 19, 22, 260, @"Oleksii", 19, 24, 260) == NO,
			"a taller line must measure again");
	TGTestExpectTrue(&outcome,
			TGContactRowMeasurementIsFresh(@"Oleksii", 19, 22, 260, @"Oleksii", 19, 22, 300) == NO,
			"a rotation that widens the row must measure again");
	TGTestExpectTrue(&outcome,
			TGContactRowMeasurementIsFresh(nil, 19, 22, 260, @"Oleksii", 19, 22, 260) == NO,
			"a row that had nothing to measure before must measure now");

	return outcome;
}

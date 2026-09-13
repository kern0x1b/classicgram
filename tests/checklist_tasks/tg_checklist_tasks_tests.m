#import "tg_checklist_tasks_tests.h"
#import "../../src/Screens/Chat/TGChecklistTasks.h"

static NSDictionary *TGChecklistTasksTestTask(int32_t taskId, NSString *text) {
	return @{@"id" : @(taskId), @"text" : text};
}

TGTestOutcome TGChecklistTasksTestNextIdStartsAtOneForAnEmptyChecklist(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualInteger(&outcome, TGNextChecklistTaskId(@[]), 1,
			"the first task added to an empty checklist takes id 1");
	TGTestExpectEqualInteger(&outcome, TGNextChecklistTaskId(nil), 1,
			"a message with no task array yet must still yield a usable first id");

	return outcome;
}

TGTestOutcome TGChecklistTasksTestNextIdSkipsPastTheHighestExistingId(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *tasks = @[ TGChecklistTasksTestTask(1, @"a"), TGChecklistTasksTestTask(2, @"b") ];

	TGTestExpectEqualInteger(&outcome, TGNextChecklistTaskId(tasks), 3,
			"a new task must take an id above every existing one, or TDLib rejects the duplicate");

	return outcome;
}

TGTestOutcome TGChecklistTasksTestNextIdIgnoresGapsAndOrdering(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *gapped = @[ TGChecklistTasksTestTask(7, @"a"), TGChecklistTasksTestTask(2, @"b") ];
	TGTestExpectEqualInteger(&outcome, TGNextChecklistTaskId(gapped), 8,
			"deleting tasks leaves gaps in the id sequence: the next id follows the highest, not the count, "
			"and the array's order must not matter");

	NSArray *negative = @[ TGChecklistTasksTestTask(-3, @"a") ];
	TGTestExpectEqualInteger(&outcome, TGNextChecklistTaskId(negative), 1,
			"an id at or below zero cannot lower the floor below 1");

	return outcome;
}

TGTestOutcome TGChecklistTasksTestReplaceRewritesOnlyTheNamedTask(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *tasks = @[ TGChecklistTasksTestTask(1, @"milk"),
		TGChecklistTasksTestTask(2, @"bread"),
		TGChecklistTasksTestTask(3, @"eggs") ];
	NSArray *updated = TGChecklistTasksByReplacingTaskId(tasks, 2, @"rye bread");

	TGTestExpectEqualInteger(&outcome, (NSInteger)updated.count, 3,
			"editing a task must not change how many tasks the checklist has");
	TGTestExpectTrue(&outcome, [updated[1][@"text"] isEqualToString:@"rye bread"],
			"the edited task carries its new text");
	TGTestExpectTrue(&outcome, [updated[0][@"text"] isEqualToString:@"milk"] &&
			[updated[2][@"text"] isEqualToString:@"eggs"],
			"every other task keeps its text: this array is sent as the whole checklist, so a dropped or "
			"rewritten neighbour would overwrite the real one");
	TGTestExpectEqualInteger(&outcome, [updated[1][@"id"] intValue], 2,
			"the edited task keeps its own id");

	return outcome;
}

TGTestOutcome TGChecklistTasksTestReplaceLeavesTheChecklistAloneForAMissingId(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *tasks = @[ TGChecklistTasksTestTask(1, @"milk") ];
	NSArray *updated = TGChecklistTasksByReplacingTaskId(tasks, 99, @"nothing");

	TGTestExpectEqualInteger(&outcome, (NSInteger)updated.count, 1,
			"an id that is not in the checklist must leave it intact");
	TGTestExpectTrue(&outcome, [updated[0][@"text"] isEqualToString:@"milk"],
			"and must not rewrite an unrelated task");

	return outcome;
}

TGTestOutcome TGChecklistTasksTestRemoveDropsOnlyTheNamedTask(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *tasks = @[ TGChecklistTasksTestTask(1, @"milk"),
		TGChecklistTasksTestTask(2, @"bread") ];
	NSArray *updated = TGChecklistTasksByRemovingTaskId(tasks, 1);

	TGTestExpectEqualInteger(&outcome, (NSInteger)updated.count, 1,
			"removing one task of two leaves one");
	TGTestExpectEqualInteger(&outcome, [updated[0][@"id"] intValue], 2,
			"the survivor keeps its original id rather than being renumbered");
	TGTestExpectEqualInteger(&outcome,
			(NSInteger)TGChecklistTasksByRemovingTaskId(tasks, 99).count, 2,
			"removing an id that is not there must not silently drop a task");

	return outcome;
}

TGTestOutcome TGChecklistTasksTestNonDictionaryEntriesAreSkippedEverywhere(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *tasks = @[ TGChecklistTasksTestTask(1, @"milk"), @"not a task", @42 ];

	TGTestExpectEqualInteger(&outcome, TGNextChecklistTaskId(tasks), 2,
			"a malformed entry must not throw while scanning for the next id");
	TGTestExpectEqualInteger(&outcome,
			(NSInteger)TGChecklistTasksByReplacingTaskId(tasks, 1, @"oat milk").count, 1,
			"the rebuilt checklist carries only real tasks, so a malformed entry cannot reach TDLib");
	TGTestExpectEqualInteger(&outcome,
			(NSInteger)TGChecklistTasksByRemovingTaskId(tasks, 1).count, 0,
			"removing the only real task leaves an empty checklist rather than the malformed leftovers");

	return outcome;
}

TGTestOutcome TGChecklistTasksTestReplaceAndRemoveNeverCarryTheDoneFlag(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *tasks = @[ @{@"id" : @1, @"text" : @"milk", @"done" : @YES} ];
	NSArray *replaced = TGChecklistTasksByReplacingTaskId(tasks, 1, @"oat milk");
	NSArray *kept = TGChecklistTasksByRemovingTaskId(tasks, 99);

	TGTestExpectTrue(&outcome, replaced[0][@"done"] == nil && kept[0][@"done"] == nil,
			"inputChecklistTask has no completion field in the schema, so the rebuilt task must carry id and "
			"text only: sending a done flag would be an unknown field on the wire");
	TGTestExpectEqualInteger(&outcome, (NSInteger)[(NSDictionary *)replaced[0] count], 2,
			"a rebuilt task is exactly id and text");

	return outcome;
}

#import "tg_table_reload_coalescer_tests.h"
#import "../../src/Views/TGTableReloadCoalescer.h"

static void TGDrainMainQueue(void) {
	[[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
}

TGTestOutcome TGTableReloadCoalescerTestManyArrivalsCostOneReload(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	UITableView *table = [[UITableView alloc] init];
	TGTableReloadCoalescer *coalescer = [[TGTableReloadCoalescer alloc] initWithTableView:table];
	for (NSInteger i = 0; i < 40; i++)
		[coalescer setNeedsReload];

	TGTestExpectTrue(&outcome, table.tgReloadCount == 0,
			"nothing is reloaded while the arrivals are still coming in");
	TGTestExpectTrue(&outcome, coalescer.reloadPending == YES,
			"a reload is owed after the first arrival");

	TGDrainMainQueue();

	TGTestExpectTrue(&outcome, table.tgReloadCount == 1,
			"forty photos arriving in one turn cost one reload, not forty");
	TGTestExpectTrue(&outcome, coalescer.reloadPending == NO,
			"nothing is owed once the reload has run");

	return outcome;
}

TGTestOutcome TGTableReloadCoalescerTestALaterArrivalReloadsAgain(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	UITableView *table = [[UITableView alloc] init];
	TGTableReloadCoalescer *coalescer = [[TGTableReloadCoalescer alloc] initWithTableView:table];
	[coalescer setNeedsReload];
	TGDrainMainQueue();
	[coalescer setNeedsReload];
	TGDrainMainQueue();

	TGTestExpectTrue(&outcome, table.tgReloadCount == 2,
			"an arrival after the table settled must reload it again");

	TGTableReloadCoalescer *orphan = [[TGTableReloadCoalescer alloc] initWithTableView:nil];
	[orphan setNeedsReload];
	TGTestExpectTrue(&outcome, orphan.reloadPending == NO,
			"a coalescer with no table left owes nothing");

	return outcome;
}

#import "tg_storage_chat_titles_tests.h"
#import "../../src/Wire/Flatten/TGFlattenStorage.h"

static NSDictionary *TGStorageTestRow(long long chatId, NSString *title, long long size) {
	return @{@"chatId" : @(chatId), @"title" : title ?: @"", @"size" : @(size), @"count" : @1};
}

TGTestOutcome TGStorageChatTitlesTestAsksOnlyForTheRowsWithoutATitle(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *rows = @[
		TGStorageTestRow(-100500, @"", 900),
		TGStorageTestRow(77, @"Мамуля", 800),
		TGStorageTestRow(0, @"", 700),
		TGStorageTestRow(-100500, @"", 600),
		@"not a row",
	];
	NSArray *missing = TGStorageChatIdsMissingTitles(rows);

	TGTestExpectEqualLongLong(&outcome, (long long)missing.count, 1,
			"only the untitled chat needs a lookup, asked for once");
	TGTestExpectEqualLongLong(&outcome, [[missing firstObject] longLongValue], -100500,
			"the untitled chat's own id is the one to look up");
	TGTestExpectEqualLongLong(&outcome, (long long)TGStorageChatIdsMissingTitles(nil).count, 0,
			"no rows means nothing to look up, not a crash");

	return outcome;
}

TGTestOutcome TGStorageChatTitlesTestFillsTheResolvedTitlesAndKeepsTheRest(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *rows = @[
		TGStorageTestRow(-100500, @"", 900),
		TGStorageTestRow(77, @"Мамуля", 800),
		TGStorageTestRow(0, @"", 700),
		TGStorageTestRow(-100999, @"", 600),
	];
	NSArray *filled = TGStorageChatRowsWithTitles(rows, @{@(-100500) : @"Kolos", @(-100999) : @""});

	TGTestExpectEqualLongLong(&outcome, (long long)filled.count, 4,
			"every row survives the title merge");
	TGTestExpectTrue(&outcome, [filled[0][@"title"] isEqualToString:@"Kolos"],
			"a resolved title lands on its row");
	TGTestExpectEqualLongLong(&outcome, [filled[0][@"size"] longLongValue], 900,
			"the row keeps the size it was measured with");
	TGTestExpectTrue(&outcome, [filled[1][@"title"] isEqualToString:@"Мамуля"],
			"a row that already had a title keeps it");
	TGTestExpectTrue(&outcome, [filled[2][@"title"] isEqualToString:@""],
			"the chatless row stays untitled so the screen can call it other files");
	TGTestExpectTrue(&outcome, [filled[3][@"title"] isEqualToString:@""],
			"a lookup that came back empty leaves the row as it was");

	return outcome;
}
